// State and behaviour of the Studio (/studio/[slug]): the design document,
// the chosen variant and colour, autosave with the backend's price, undo,
// switching variants (layers follow their area key), templates, and adding
// to the cart (print files + mockups, priced by the backend from the files).
// An admin opening ?template=<id> edits that template instead of a design.
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import type { InjectionKey } from 'vue';
import { ApiError, getApiErrorMessage } from '~/composables/useApi';
import { claimGuestMedia, dataUrlToBlob } from '~/composables/useMediaUpload';
import type { DesignDocument, ImageSource, Layer } from '~/lib/design/document';
import {
  areaMethod, BACKGROUND_PREFIX, copyToPartner, crops, designMethodOf, designProblems, effectiveLayers, emptyDocument, fitIntoStrips,
  fitScale, isBackgroundLayer, isCopy, placeInZone, linkable, MONO_COLOR, newLayerId, normaliseDocument,
  printScaleOf, problemCount as countProblems, settleStrips, sizedAreas, sizeMm, sticksOut, syncedFrom, syncTargets,
  zoneBox,
} from '~/lib/design/document';
import { measureAreas, printJobs, usedAreas } from '~/lib/design/output';
import { queryKeys } from '~/lib/queryKeys';
import type { AdminTemplate, CatalogMethod, PrintArea, PublicProductDetail, PublicTemplate, Quote } from '~/types/catalog';
import { fontString, layoutText, prepareAssets, renderPrintFile } from '~/lib/design/render';
import { loadFontFace } from '~/lib/design/fonts';
import { isPlacedModelAnchor, METHOD_LABELS } from '~/types/catalog';
import { faceOf, isDialArea, newDialLayer } from '~/lib/design/dial';

export interface StudioDesign {
  id: string;
  version: number;
  product_slug: string;
  variant_id: number;
  color_id: number;
  document: DesignDocument;
  quote: Quote | null;
  issues: string[];
}

interface LocalDraft {
  variantId: number;
  colorId: number;
  size?: string | null;
  document: DesignDocument;
  // Older drafts had no stamp. They sat under one key per product, so the
  // next person on this computer saw yesterday's mug. Missing or stale
  // stamps are dropped instead of resumed.
  savedAt?: number;
}

// Prefix shared with claimGuestMedia, which rewrites guest image URLs in
// these drafts when they move into the account at sign-in.
const LOCAL_PREFIX = 'enjoy:editor:studio:';
const LOCAL_MAX_AGE_MS = 12 * 60 * 60 * 1000;
const SAVE_DELAY_MS = 1500;
const HISTORY_LIMIT = 60;

function readLocal(slug: string): LocalDraft | null {
  try {
    const raw = localStorage.getItem(LOCAL_PREFIX + slug);
    if (!raw) return null;
    const draft = JSON.parse(raw) as LocalDraft;
    if (!draft.savedAt || Date.now() - draft.savedAt > LOCAL_MAX_AGE_MS) {
      writeLocal(slug, null);
      return null;
    }
    return draft;
  }
  catch {
    return null;
  }
}

function writeLocal(slug: string, draft: LocalDraft | null) {
  try {
    if (draft) localStorage.setItem(LOCAL_PREFIX + slug, JSON.stringify({ ...draft, savedAt: Date.now() }));
    else localStorage.removeItem(LOCAL_PREFIX + slug);
  }
  catch {
    // Storage unavailable (private mode): the design lives only in this tab.
  }
}

/** What "Hududni tozalash" takes off an area: the customer's own elements. */
const clearable = (l: Layer) => !l.dial && !isBackgroundLayer(l);

/** Clock numerals follow their face: its shape and its zone, on any type. */
function refitDials(doc: DesignDocument, areas: PrintArea[]): DesignDocument {
  return {
    ...doc,
    layers: doc.layers.map((l) => {
      const area = l.dial && areas.find(a => a.key === l.area);
      const fresh = area ? newDialLayer(area, l.dial!.color) : null;
      if (!area || !fresh) return l;
      return { ...l, x_mm: fresh.x_mm, y_mm: fresh.y_mm, w_mm: fresh.w_mm, h_mm: fresh.h_mm, rotation: 0, dial: { ...l.dial!, ...faceOf(area) } };
    }),
  };
}

/** A design without clock numerals gets them on every clock face, placed on top. */
function withDials(doc: DesignDocument, areas: PrintArea[]): DesignDocument {
  const missing = areas.filter(a => isDialArea(a) && !doc.layers.some(l => l.area === a.key && l.dial));
  if (!missing.length) return doc;
  const dials = missing.map(a => newDialLayer(a, contrastInk('#ffffff'))).filter(Boolean) as Layer[];
  return dials.length ? { ...doc, layers: [...doc.layers, ...dials] } : doc;
}

/** The document on another shape: layers follow their area key with their
 * millimetres, a layer whose area is missing is parked (area null: kept,
 * not printed), and links that are no longer a pair are dropped. */
function fitToShape(doc: DesignDocument, areas: PrintArea[]): DesignDocument {
  const keys = new Set(areas.map(a => a.key));
  return {
    ...doc,
    layers: doc.layers.map(l => (l.area !== null && !keys.has(l.area) ? { ...l, area: null } : l)),
    links: doc.links.filter((link) => {
      const source = areas.find(a => a.key === link.source);
      const target = areas.find(a => a.key === link.target);
      return Boolean(source && target && linkable(source, target));
    }),
  };
}

export function usePublicProduct(slug: Ref<string>) {
  const api = useApi();
  return useQuery({
    queryKey: computed(() => ['catalog', 'product', slug.value] as const),
    queryFn: () => api.get<PublicProductDetail>(`/catalog/products/${slug.value}/`),
    retry: (count, error) => !(error instanceof ApiError && error.status === 404) && count < 2,
  });
}

export function useProductTemplates(slug: Ref<string>) {
  const api = useApi();
  return useQuery({
    queryKey: computed(() => ['catalog', 'templates', slug.value] as const),
    queryFn: () => api.get<PublicTemplate[]>(`/catalog/products/${slug.value}/templates/`),
    staleTime: 60_000,
  });
}

/** Ink that shows on the product: white on dark bodies, near-black otherwise. */
export function contrastInk(hex: string): string {
  const [r, g, b] = [1, 3, 5].map(i => Number.parseInt(hex.slice(i, i + 2), 16) / 255) as [number, number, number];
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.45 ? '#ffffff' : '#111827';
}

/** Parses an ID or integer query param safely from route.query. */
export function parseQueryNum(v: unknown): number | null {
  if (typeof v === 'number' && !Number.isNaN(v)) return v;
  if (typeof v === 'string') {
    const trimmed = v.trim();
    if (/^\d+$/.test(trimmed)) return Number(trimmed);
  }
  if (Array.isArray(v) && v.length > 0) {
    return parseQueryNum(v[0]);
  }
  return null;
}

/** Parses a trimmed string query param safely from route.query. */
export function parseQueryStr(v: unknown): string | null {
  if (typeof v === 'string') {
    const trimmed = v.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (Array.isArray(v) && v.length > 0) {
    return parseQueryStr(v[0]);
  }
  return null;
}

export function useStudio(slug: Ref<string>) {
  const api = useApi();
  const route = useRoute();
  const router = useRouter();
  const localePath = useLocalePath();
  const { t } = useI18n();
  const authed = useAuthState();
  const authModal = useAuthModal();
  const queryClient = useQueryClient();
  const { upload } = useMediaUpload();
  const productQuery = usePublicProduct(slug);
  const product = computed(() => productQuery.data.value ?? null);
  const templatesQuery = useProductTemplates(slug);

  const variantId = ref<number | null>(null);
  const colorId = ref<number | null>(null);
  // The chosen clothing size, null on products that have none.
  const sizeLabel = ref<string | null>(null);
  const doc = ref<DesignDocument>(emptyDocument());
  const selectedArea = ref<string | null>(null);
  const selectedLayer = ref<string | null>(null);
  const designId = ref<string | null>(null);
  const version = ref(0);
  const quote = ref<Quote | null>(null);
  const saveState = ref<'idle' | 'pending' | 'saving' | 'saved' | 'error'>('idle');
  const saveError = ref<string | null>(null);
  const notice = ref<string | null>(null);
  const ready = ref(false);
  // An earlier design (saved, local or a template being edited) was opened.
  const resumed = ref(false);
  // The print method chosen for a design with no layers yet ("Bosish usuli").
  const preferredMethod = ref<CatalogMethod | null>(null);
  // Images uploaded in this session, offered again in "Yuklash".
  const uploads = ref<ImageSource[]>([]);
  // Admin editing a template (?template=<id>): no design is saved meanwhile.
  const editingTemplate = ref<AdminTemplate | null>(null);

  const variant = computed(() => product.value?.variants.find(v => v.id === variantId.value) ?? null);
  const color = computed(() => variant.value?.colors.find(c => c.id === colorId.value) ?? null);
  const sizes = computed(() => variant.value?.sizes ?? []);
  const sizesInStock = computed(() => sizes.value.filter(s => s.is_available));
  const size = computed(() => sizesInStock.value.find(s => s.label === sizeLabel.value) ?? null);
  /** This type is sold by size: one must be chosen before the cart. */
  const needsSize = computed(() => sizesInStock.value.length > 0);
  const shape = computed(() => product.value?.shapes.find(s => s.id === variant.value?.shape_id) ?? null);
  // How much of every print area the chosen size may use. The areas keep
  // their millimetres (layer coordinates are absolute, so changing size
  // never moves a design) and only their zones shrink — which is enough to
  // shrink the guides, the 3D decal, the measured area and the print files
  // all at once. `printSize` is what the design is then checked against.
  const printScale = computed(() => printScaleOf(size.value));
  const printSize = computed(() => (size.value && printScale.value < 1
    ? { label: size.value.label, scale: printScale.value }
    : null));
  const areas = computed(() => sizedAreas(shape.value?.areas ?? [], printScale.value));
  /** What the chosen size prints on an area, in centimetres — what the size
   * picker shows next to the label so the consequence is never a surprise. */
  function printAreaCm(area: PrintArea, scale = printScale.value): { w: number; h: number } {
    const mm = sizeMm(area, scale);
    return { w: Math.round(mm.w / 10 * 10) / 10, h: Math.round(mm.h / 10 * 10) / 10 };
  }
  /** The biggest area of the shape at a size, in centimetres: the one line
   * a size picker can show ("40 × 40 sm"). */
  function sizePrintArea(label: string | null): { w: number; h: number } | null {
    const chosen = sizesInStock.value.find(x => x.label === label) ?? null;
    const biggest = (shape.value?.areas ?? []).reduce<PrintArea | null>(
      (best, a) => (!best || Number(a.width_mm) * Number(a.height_mm) > Number(best.width_mm) * Number(best.height_mm) ? a : best),
      null,
    );
    return biggest ? printAreaCm(biggest, printScaleOf(chosen)) : null;
  }
  const methods = computed<CatalogMethod[]>(() => variant.value?.methods ?? []);
  const layers = computed(() => doc.value.layers);
  // Every change to the layers (or the shape) moves the laser strips with
  // them in the same step, so whatever draws the document sees both at once
  // and undo brings both back.
  watch([doc, areas], () => {
    const settled = settleStrips(doc.value, areas.value);
    if (settled !== doc.value) doc.value = settled;
  }, { flush: 'sync', immediate: true });
  // What gets printed: placed layers plus copies on linked partner areas.
  const effective = computed(() => effectiveLayers(doc.value, areas.value));
  const layer = computed(() => layers.value.find(l => l.id === selectedLayer.value) ?? null);
  const templates = computed(() => (templatesQuery.data.value ?? []).filter(t => t.variant_ids.includes(variantId.value ?? -1)));
  // The colour each area is printed on, from the 3D model (a dial stays white
  // whatever the frame colour); until it is known, the chosen colour.
  const surfaceColors = ref<Record<string, string>>({});
  const surfaceHex = computed(() => (selectedArea.value ? surfaceColors.value[selectedArea.value] : undefined) ?? color.value?.hex ?? '#ffffff');
  // Default colour of new text and graphics on that surface.
  const inkColor = computed(() => contrastInk(surfaceHex.value));
  // The whole design is printed one way — colour print or laser engraving:
  // what its layers use, else the one chosen, else the type's first.
  const designMethod = computed(() => designMethodOf(doc.value.layers, methods.value, preferredMethod.value));

  // By layer id; a copy's problem is also reported on its source layer.
  const problems = computed(() => designProblems(
    effective.value, areas.value, methods.value, designMethod.value, doc.value.strips, printSize.value,
  ));
  const problemCount = computed(() => countProblems(problems.value));
  // Not a problem, only worth saying: what sticks out of the zone is cropped.
  const croppedCount = computed(() => effective.value.filter(l => !isCopy(l.id) && sticksOut(l, areas.value, effective.value, doc.value.strips)).length);
  const placedCount = computed(() => effective.value.length);
  const blocked = computed(() => problemCount.value > 0 || placedCount.value === 0);

  // Price shown right away from the catalog; the backend's quote replaces
  // it once the next save comes back (same variant and colour only).
  const liveQuote = computed(() => {
    const q = quote.value;
    const matches = q && q.variant_id === variantId.value && q.color_id === colorId.value
      && (q.size ?? null) === sizeLabel.value;
    return matches ? q : null;
  });
  const provisionalPrice = computed(() => {
    if (!variant.value || !color.value) return null;
    const methodsPart = quote.value?.methods.reduce((sum, m) => sum + Number(m.surcharge), 0) ?? 0;
    return Number(variant.value.base_price) + Number(color.value.surcharge) + Number(size.value?.surcharge ?? 0) + methodsPart;
  });

  // ── History ──
  const past: string[] = [];
  const future: string[] = [];
  const canUndo = ref(false);
  const canRedo = ref(false);
  const snapshot = () => JSON.stringify({ v: variantId.value, c: colorId.value, d: doc.value });
  function restore(raw: string) {
    const s = JSON.parse(raw) as { v: number; c: number; d: DesignDocument };
    variantId.value = s.v;
    colorId.value = s.c;
    doc.value = s.d;
    if (selectedLayer.value && !s.d.layers.some(l => l.id === selectedLayer.value)) selectedLayer.value = null;
  }
  function checkpoint() {
    past.push(snapshot());
    if (past.length > HISTORY_LIMIT) past.shift();
    future.length = 0;
    canUndo.value = true;
    canRedo.value = false;
  }
  function undo() {
    const prev = past.pop();
    if (!prev) return;
    future.push(snapshot());
    restore(prev);
    canUndo.value = past.length > 0;
    canRedo.value = true;
  }
  function redo() {
    const next = future.pop();
    if (!next) return;
    past.push(snapshot());
    restore(next);
    canUndo.value = true;
    canRedo.value = future.length > 0;
  }

  // ── Editing ──
  /** Changes a layer without a history step (live dragging). */
  function patchLayer(id: string, patch: Partial<Layer>) {
    doc.value = { ...doc.value, layers: doc.value.layers.map(l => (l.id === id ? { ...l, ...patch } : l)) };
  }
  function updateLayer(id: string, patch: Partial<Layer>) {
    checkpoint();
    patchLayer(id, patch);
  }
  function addLayer(l: Layer) {
    checkpoint();
    const dialIdx = doc.value.layers.findIndex(x => x.area === l.area && Boolean(x.dial));
    if (dialIdx !== -1 && !l.dial) {
      const list = [...doc.value.layers];
      list.splice(dialIdx, 0, l);
      doc.value = { ...doc.value, layers: list };
    }
    else {
      doc.value = { ...doc.value, layers: [...doc.value.layers, l] };
    }
    selectedLayer.value = l.id;
  }
  function removeLayer(id: string) {
    checkpoint();
    doc.value = { ...doc.value, layers: doc.value.layers.filter(l => l.id !== id) };
    if (selectedLayer.value === id) selectedLayer.value = null;
  }
  /** The next layer up (1) or down (-1) in the same area, if any. */
  function neighbour(id: string, step: -1 | 1): number {
    const list = doc.value.layers;
    const i = list.findIndex(l => l.id === id);
    if (i < 0) return -1;
    let j = i + step;
    while (j >= 0 && j < list.length && list[j]!.area !== list[i]!.area) j += step;
    return j >= 0 && j < list.length ? j : -1;
  }
  const canMove = (id: string, step: -1 | 1) => neighbour(id, step) >= 0;
  function moveLayer(id: string, step: -1 | 1) {
    const list = [...doc.value.layers];
    const i = list.findIndex(l => l.id === id);
    const j = neighbour(id, step);
    if (i < 0 || j < 0) return;
    checkpoint();
    [list[i], list[j]] = [list[j]!, list[i]!];
    doc.value = { ...doc.value, layers: list };
  }

  /** Drag and drop in "Qatlamlar": `id` goes right above `aboveId` (null:
   * to the bottom of its area). One undo step. */
  function reorderLayer(id: string, aboveId: string | null) {
    const list = [...doc.value.layers];
    const from = list.findIndex(l => l.id === id);
    if (from < 0 || id === aboveId) return;
    checkpoint();
    const [moved] = list.splice(from, 1);
    let to = aboveId ? list.findIndex(l => l.id === aboveId) + 1 : list.findIndex(l => l.area === moved!.area);
    if (to < 0) to = 0;
    list.splice(to, 0, moved!);
    doc.value = { ...doc.value, layers: list };
  }

  /** The customer's lock (the Studio's own can't be lifted). */
  function setLocked(id: string, on: boolean) {
    const l = doc.value.layers.find(x => x.id === id);
    if (!l || l.locked === 'system') return;
    updateLayer(id, { locked: on ? 'user' : undefined });
  }

  /** The method a new layer in the area gets: the design's, if the area has it. */
  function defaultMethod(areaKey: string): CatalogMethod | null {
    const area = areas.value.find(a => a.key === areaKey);
    const m = designMethod.value;
    return area && m && areaMethod(area, m) ? m : null;
  }

  /** A layer on another method: mono methods turn the ink black, text keeps
   * the method's minimum size, and it shrinks and moves into the zone. */
  async function convertLayer(l: Layer, m: CatalogMethod): Promise<Layer> {
    let next: Layer = { ...l, method: m };
    const area = areas.value.find(a => a.key === l.area);
    const target = area ? areaMethod(area, m) : undefined;
    if (!target) return next; // parked: it keeps no zone
    if (!target.colors_allowed) {
      if (next.text) next = { ...next, text: { ...next.text, color: MONO_COLOR } };
      if (next.graphic) next = { ...next, graphic: { ...next.graphic, color: MONO_COLOR } };
    }
    const f = fitScale(next, target);
    if (next.text) {
      const min = target.min_font_mm ? Number(target.min_font_mm) : 0;
      const text = { ...next.text, size_mm: Number(Math.max(min, next.text.size_mm * f).toFixed(2)) };
      await loadFontFace(fontString(text, 64), text.content);
      const layout = layoutText(text);
      next = { ...next, text, w_mm: layout.w_mm, h_mm: layout.h_mm };
    }
    else if (f < 1 && (!crops(next) || target.strip_width_mm)) {
      next = { ...next, w_mm: next.w_mm * f, h_mm: next.h_mm * f };
    }
    return placeInZone(next, target);
  }

  /** Puts the whole design on one method (one undo step). Refused, with the
   * reason, when an area holding layers doesn't have that method. */
  async function setDesignMethod(m: CatalogMethod): Promise<string | null> {
    if (!methods.value.includes(m)) return t('studio.method.notOnVariant');
    const missing = areas.value.find(a => !areaMethod(a, m) && doc.value.layers.some(l => l.area === a.key));
    if (missing) return t('studio.method.missingInArea', { area: missing.name, method: METHOD_LABELS[m] });
    preferredMethod.value = m;
    if (doc.value.layers.every(l => l.method === m)) return null;
    const converted = await Promise.all(doc.value.layers.map(l => convertLayer(l, m)));
    checkpoint();
    doc.value = { ...doc.value, layers: fitIntoStrips(converted, areas.value, doc.value.strips) };
    return null;
  }

  /** After a type change: a method the new type lacks becomes one it has;
   * layers whose area lacks it are parked. Part of the type change's undo step. */
  async function fitMethodToVariant() {
    const m = preferredMethod.value && methods.value.includes(preferredMethod.value) ? preferredMethod.value : methods.value[0];
    if (!m || doc.value.layers.every(l => l.method === m)) return;
    const converted = await Promise.all(doc.value.layers.map(async (l) => {
      const area = areas.value.find(a => a.key === l.area);
      return area && !areaMethod(area, m) ? { ...l, method: m, area: null } : convertLayer(l, m);
    }));
    doc.value = { ...doc.value, layers: fitIntoStrips(converted, areas.value, doc.value.strips) };
    notice.value = t('studio.method.switched', { method: METHOD_LABELS[m] });
  }

  // ── Templates ──
  /** Starts over from a template: its layers (with new ids) replace the
   * design; "Ortga" brings the previous design back. */
  function applyTemplate(template: PublicTemplate) {
    checkpoint();
    const copied = template.document.layers.map(l => ({ ...structuredClone(toRaw(l)), id: newLayerId() }));
    const fitted = fitToShape({
      version: 1, layers: copied, links: [...(template.document.links ?? [])], strips: [...(template.document.strips ?? [])],
    }, areas.value);
    doc.value = { ...fitted, layers: fitIntoStrips(fitted.layers, areas.value, fitted.strips) };
    selectedLayer.value = null;
    selectedArea.value = copied.find(l => l.area !== null)?.area ?? selectedArea.value;
  }

  // ── Variant, colour and size ──
  /** Keeps the chosen size on the current type: the first one in stock. */
  function ensureSize() {
    if (!sizesInStock.value.some(s => s.label === sizeLabel.value)) {
      sizeLabel.value = sizesInStock.value[0]?.label ?? null;
    }
  }
  watch(variant, ensureSize);

  function pickSize(label: string) {
    if (sizesInStock.value.some(s => s.label === label)) sizeLabel.value = label;
  }

  function pickColor(id: number) {
    if (id === colorId.value) return;
    checkpoint();
    colorId.value = id;
  }

  // ── The print face in the product's colour ("fon") ──
  // Where the printed face isn't the product's colour (a clock's white dial
  // in a green frame, a mug white outside and coloured inside) the customer
  // may print the face in that colour too: a filled shape under the design
  // on every colour-printed area, recoloured with the product.
  const background = computed(() => doc.value.layers.some(isBackgroundLayer));
  const canBackground = computed(() => {
    const hex = color.value?.hex.toLowerCase();
    return Boolean(hex) && designMethod.value === 'uv'
      && areas.value.some(a => areaMethod(a, 'uv') && (surfaceColors.value[a.key] ?? '#ffffff').toLowerCase() !== hex);
  });

  function setBackground(on: boolean) {
    checkpoint();
    const rest = doc.value.layers.filter(l => !isBackgroundLayer(l));
    const hex = color.value?.hex;
    const fills: Layer[] = [];
    for (const a of on && hex ? areas.value : []) {
      const m = areaMethod(a, 'uv');
      if (!m || syncedFrom(doc.value, a.key)) continue;
      const z = zoneBox(m);
      const round = isPlacedModelAnchor(a.anchor) && a.anchor.round === true;
      fills.push({
        id: `${BACKGROUND_PREFIX}${newLayerId()}`, area: a.key, method: 'uv', kind: 'graphic',
        x_mm: (z.x0 + z.x1) / 2, y_mm: (z.y0 + z.y1) / 2, w_mm: z.x1 - z.x0, h_mm: z.y1 - z.y0, rotation: 0,
        graphic: { library: 'shape', name: round ? 'circle' : 'square', color: hex! },
      });
    }
    doc.value = { ...doc.value, layers: [...fills, ...rest] };
  }

  // A smaller size prints a smaller box, so the fill (and the clock
  // numerals, which are laid out on the face) are laid out again for it.
  watch(printScale, () => {
    if (!ready.value) return;
    doc.value = refitDials(doc.value, areas.value);
    if (background.value) setBackground(true);
  });

  // The fill follows the product's colour.
  watch(color, (c) => {
    if (!c || !background.value) return;
    doc.value = {
      ...doc.value,
      layers: doc.value.layers.map(l => (isBackgroundLayer(l) && l.graphic ? { ...l, graphic: { ...l.graphic, color: c.hex } } : l)),
    };
  });

  /** What switching to a variant would do to the layers. */
  function previewVariantSwitch(id: number) {
    const next = product.value?.variants.find(v => v.id === id);
    const nextShape = product.value?.shapes.find(s => s.id === next?.shape_id);
    if (!next || !nextShape) return null;
    const keys = new Set(nextShape.areas.map(a => a.key));
    const lost = layers.value.filter(l => l.area !== null && !keys.has(l.area)).length;
    const shapeChanges = next.shape_id !== variant.value?.shape_id;
    return { shapeChanges, lost };
  }

  /** Switches the type, optionally straight to one of its colours (one undo step). */
  function pickVariant(id: number, wantedColor: number | null = null) {
    const next = product.value?.variants.find(v => v.id === id);
    const nextShape = product.value?.shapes.find(s => s.id === next?.shape_id);
    if (!next || !nextShape) return;
    if (id === variantId.value) {
      if (wantedColor !== null) pickColor(wantedColor);
      return;
    }
    checkpoint();
    const keys = new Set(nextShape.areas.map(a => a.key));
    variantId.value = id;
    if (wantedColor !== null && next.colors.some(c => c.id === wantedColor)) colorId.value = wantedColor;
    else if (!next.colors.some(c => c.id === colorId.value)) colorId.value = next.colors[0]?.id ?? null;
    doc.value = withDials(refitDials(fitToShape(doc.value, nextShape.areas), nextShape.areas), nextShape.areas);
    if (!selectedArea.value || !keys.has(selectedArea.value)) selectedArea.value = nextShape.areas[0]?.key ?? null;
    void fitMethodToVariant();
  }

  // ── Synced areas ("Sinxronlash") ──
  /** Sets which areas show the source's design (one undo step). A newly
   * synced area's own layers are parked, not lost; an area no longer synced
   * keeps editable copies of what it showed. */
  function setSync(sourceKey: string, targets: string[]) {
    const source = areas.value.find(a => a.key === sourceKey);
    if (!source) return;
    const current = syncTargets(doc.value, sourceKey);
    const removed = current.filter(t => !targets.includes(t));
    const added = targets.filter(t => !current.includes(t));
    if (!removed.length && !added.length) return;
    checkpoint();
    const own = doc.value.layers.filter(l => l.area === sourceKey);
    const copies = removed.flatMap((key) => {
      const target = areas.value.find(a => a.key === key);
      return target ? own.map(l => ({ ...copyToPartner(l, source, target), id: newLayerId() })) : [];
    });
    doc.value = {
      ...doc.value,
      layers: [...doc.value.layers.map(l => (l.area && added.includes(l.area) ? { ...l, area: null } : l)), ...copies],
      links: [
        ...doc.value.links.filter(l => !(l.source === sourceKey && removed.includes(l.target))),
        ...added.map(target => ({ source: sourceKey, target })),
      ],
    };
  }

  // How much "Tozalash" would take off the open area (0: nothing to clear).
  const clearCount = computed(() => doc.value.layers.filter(l => l.area === selectedArea.value && clearable(l)).length);

  /** "Tozalash": everything the customer put on the area goes in one undo
   * step. A clock's numerals and the colour fill stay — they belong to the
   * product, not to the design, and have their own switches. */
  function clearArea(key: string) {
    const gone = new Set(doc.value.layers.filter(l => l.area === key && clearable(l)).map(l => l.id));
    if (!gone.size) return;
    checkpoint();
    doc.value = { ...doc.value, layers: doc.value.layers.filter(l => !gone.has(l.id)) };
    if (selectedLayer.value && gone.has(selectedLayer.value)) selectedLayer.value = null;
  }

  // ── Loading ──
  function applyDesign(d: StudioDesign) {
    designId.value = d.id;
    version.value = d.version;
    quote.value = d.quote;
    variantId.value = d.variant_id;
    colorId.value = d.color_id;
    doc.value = normaliseDocument(d.document);
  }

  function useDefaults() {
    const first = product.value?.variants[0];
    variantId.value = first?.id ?? null;
    colorId.value = first?.colors[0]?.id ?? null;
  }

  /** A saved variant or colour that went off sale falls back to the first on sale. */
  function ensureOnSale() {
    if (!variant.value) {
      if (variantId.value !== null) notice.value = t('studio.notice.variantOffSale');
      useDefaults();
      doc.value = fitToShape(doc.value, shape.value?.areas ?? []);
    }
    else if (!color.value) {
      colorId.value = variant.value.colors[0]?.id ?? null;
    }
    ensureSize();
    selectedArea.value = areas.value[0]?.key ?? null;
  }

  async function load() {
    ready.value = false;
    await productQuery.suspense();
    if (!product.value) return;
    const wanted = typeof route.query.design === 'string' ? route.query.design : null;
    const template = typeof route.query.template === 'string' ? Number(route.query.template) : null;
    // A design picked in the gallery ("Shu dizayndan boshlash").
    const from = typeof route.query.from === 'string' ? Number(route.query.from) : null;
    // Guest drafts only. A leftover from another person on this computer
    // must not open — or be saved into — the signed-in account.
    const local = authed.value ? null : readLocal(slug.value);
    if (authed.value) writeLocal(slug.value, null);
    if (template && authed.value) {
      const t = await api.get<AdminTemplate>(`/admin/catalog/templates/${template}/`);
      editingTemplate.value = t;
      variantId.value = t.variant_ids[0] ?? null;
      colorId.value = variant.value?.colors[0]?.id ?? null;
      doc.value = normaliseDocument(structuredClone(t.document));
      resumed.value = true;
    }
    else if (wanted && authed.value) {
      const d = await api.get<StudioDesign>(`/studio/designs/${wanted}/`);
      if (d.product_slug !== slug.value) {
        await router.replace({ path: localePath(`/studio/${d.product_slug}`), query: { design: d.id } });
        return;
      }
      applyDesign(d);
      resumed.value = true;
    }
    else if (from) {
      useDefaults();
      await templatesQuery.suspense();
      const picked = (templatesQuery.data.value ?? []).find(t => t.id === from) ?? null;
      const q = route.query;
      const onSale = product.value.variants.filter(v => !picked || picked.variant_ids.includes(v.id));
      const chosen = onSale.find(v => String(v.id) === q.variant) ?? onSale[0];
      if (chosen) {
        variantId.value = chosen.id;
        colorId.value = (chosen.colors.find(c => String(c.id) === q.color) ?? chosen.colors[0])?.id ?? null;
      }
      ensureOnSale();
      if (picked) applyTemplate(picked);
      else doc.value = withDials(doc.value, shape.value?.areas ?? []);
      const { from: _, ...rest } = route.query;
      await router.replace({ query: { ...rest, variant: variantId.value ?? undefined, color: colorId.value ?? undefined } });
    }
    else if (local) {
      variantId.value = local.variantId;
      colorId.value = local.colorId;
      sizeLabel.value = local.size ?? null;
      doc.value = withDials(normaliseDocument(local.document), shape.value?.areas ?? []);
      resumed.value = true;
    }
    else {
      useDefaults();
      // A new design from the product page (?variant=&color=&size=).
      const q = route.query;
      const wantedVariant = product.value.variants.find(v => String(v.id) === q.variant);
      if (wantedVariant) {
        variantId.value = wantedVariant.id;
        colorId.value = (wantedVariant.colors.find(c => String(c.id) === q.color) ?? wantedVariant.colors[0])?.id ?? null;
        if (typeof q.size === 'string') sizeLabel.value = q.size; // ensureOnSale drops one out of stock
      }
      doc.value = withDials(doc.value, shape.value?.areas ?? []);
    }
    ensureOnSale();
    ready.value = true;
  }

  /** After sign-in: the guest's local draft becomes the account's design.
   * Both the sign-in watcher and signIn() call it; they share one run. */
  let adopting: Promise<void> | null = null;
  function adoptLocal(): Promise<void> {
    adopting ??= (async () => {
      await claimGuestMedia(api);
      const local = readLocal(slug.value);
      if (local) doc.value = normaliseDocument(local.document); // URLs rewritten by the claim
      await save();
      if (designId.value) {
        writeLocal(slug.value, null);
        await router.replace({ query: { ...route.query, design: designId.value } });
      }
    })().finally(() => {
      adopting = null;
    });
    return adopting;
  }

  /** Sign-in modal for a guest; true once signed in with the draft in the account. */
  async function signIn(reason: string): Promise<boolean> {
    await save();
    if (!(await authModal.requireAuth(reason))) return false;
    if (!designId.value && !editingTemplate.value) await adoptLocal();
    return true;
  }

  // ── Saving ──
  let timer: ReturnType<typeof setTimeout> | null = null;
  let running: Promise<void> | null = null;
  let again = false;

  function schedule() {
    if (!ready.value) return;
    saveState.value = 'pending';
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => void save(), SAVE_DELAY_MS);
  }

  const measure = () => measureAreas(areas.value, effective.value, doc.value.strips);

  // The Studio's five views, uploaded, waiting to go with the next save
  // ("Dizaynlarim" shows them): taken on "Saqlash" and when adding to the cart.
  let pendingPreviews: string[] | null = null;

  async function saveOnce() {
    if (!variantId.value || !colorId.value) return;
    const areasCm2 = await measure();
    const previews = pendingPreviews;
    const body = {
      variant_id: variantId.value, color_id: colorId.value, size: sizeLabel.value, document: doc.value,
      areas_cm2: areasCm2,
      ...(previews && authed.value && !editingTemplate.value ? { previews } : {}),
    };
    if (!authed.value || editingTemplate.value) {
      // Guests keep the design in this browser; a template being edited is
      // saved only with "Shablonni saqlash". Either way the price is quoted.
      if (!authed.value) {
        writeLocal(slug.value, {
          variantId: variantId.value, colorId: colorId.value, size: sizeLabel.value, document: doc.value,
        });
      }
      quote.value = await api.post<Quote>('/catalog/quote/', {
        variant_id: variantId.value, color_id: colorId.value, quantity: 1, size: sizeLabel.value, areas_cm2: areasCm2,
      });
      return;
    }
    const saved = designId.value
      ? await api.put<StudioDesign>(`/studio/designs/${designId.value}/`, { ...body, version: version.value })
      : await api.post<StudioDesign>('/studio/designs/', body);
    const created = !designId.value;
    if (pendingPreviews === previews) pendingPreviews = null;
    designId.value = saved.id;
    version.value = saved.version;
    quote.value = saved.quote;
    // A saved design doesn't keep the size, so a product sold by size is
    // priced again with the one chosen here.
    if (needsSize.value) {
      quote.value = await api.post<Quote>('/catalog/quote/', {
        variant_id: variantId.value, color_id: colorId.value, quantity: 1, size: sizeLabel.value, areas_cm2: areasCm2,
      });
    }
    if (created) await router.replace({ query: { ...route.query, design: saved.id } });
  }

  async function save(): Promise<void> {
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    if (running) {
      again = true;
      return running;
    }
    saveState.value = 'saving';
    running = (async () => {
      try {
        do {
          again = false;
          await saveOnce();
        } while (again);
        saveState.value = 'saved';
        saveError.value = null;
      }
      catch (err) {
        if (err instanceof ApiError && err.status === 409 && designId.value) {
          // Another tab saved first: take its version.
          applyDesign(await api.get<StudioDesign>(`/studio/designs/${designId.value}/`));
          notice.value = t('studio.notice.changedElsewhere');
          saveState.value = 'saved';
        }
        else {
          saveState.value = 'error';
          saveError.value = getApiErrorMessage(err, t('studio.save.failedNetwork'));
        }
      }
      finally {
        running = null;
      }
    })();
    return running;
  }

  /** Saves the design with the five views of the product as it is now
   * (captureFrames: flush() first, as for the cart). A view that can't be
   * taken or uploaded doesn't stop the save. */
  async function saveWithPreviews(captureFrames: (areas: string[]) => Promise<string[]>) {
    if (authed.value && !editingTemplate.value) {
      try {
        const used = usedAreas(effective.value);
        const frames = await captureFrames(used.length || !selectedArea.value ? used : [selectedArea.value]);
        if (frames.length) {
          pendingPreviews = await Promise.all(frames.map(async frame => (await upload(await dataUrlToBlob(frame), 'design')).id));
        }
      }
      catch (err) {
        console.error('[studio] the design’s views could not be saved', err);
      }
    }
    await save();
  }

  watch([doc, variantId, colorId, sizeLabel], schedule);
  watch(authed, (value, old) => {
    if (value && !old && ready.value && !designId.value && !editingTemplate.value) void adoptLocal();
  });
  onBeforeUnmount(() => {
    if (timer) {
      clearTimeout(timer);
      void save();
    }
  });

  // ── Cart ──
  const cartState = ref<'idle' | 'working' | 'confirm' | 'done' | 'error'>('idle');
  const cartStep = ref('');
  const cartProgress = ref<number | null>(null); // share of the steps done (the stage's loader bar)
  const cartError = ref<string | null>(null);
  const confirmQuote = ref<Quote | null>(null);
  let pendingItem: Record<string, unknown> | null = null;

  async function addToCart(quantity: number, captureFrames: (areas: string[]) => Promise<string[]>) {
    cartError.value = null;
    if (!authed.value && !(await signIn(t('studio.cart.signIn')))) return;
    if (blocked.value) {
      cartError.value = placedCount.value === 0 ? t('studio.cart.addSomething') : t('studio.cart.fixProblems');
      return;
    }
    if (needsSize.value && !sizeLabel.value) {
      cartError.value = t('studio.cart.pickSize');
      return;
    }
    cartState.value = 'working';
    // Steps: saving, each print file (drawn + uploaded), the views, each
    // view's upload, the cart request. Five views until they are taken.
    let done = 0;
    let total = 0;
    const step = (text: string, finished = 0) => {
      done += finished;
      cartStep.value = text;
      cartProgress.value = total ? done / total : null;
    };
    const painted = () => new Promise(resolve => requestAnimationFrame(() => setTimeout(resolve)));
    try {
      step(t('studio.cart.steps.saving'));
      await save();
      step(t('studio.cart.steps.preparing'));
      await prepareAssets(layers.value);
      const jobs = printJobs(areas.value, effective.value, printScale.value);
      let views = 5;
      total = 1 + jobs.length * 2 + 1 + views + 1;
      const uploads = () => jobs.length + views;
      let uploaded = 0;
      step(t('studio.cart.steps.preparing'), 1);
      const files: Array<{ area: string; method: CatalogMethod; media_id: string }> = [];
      for (const [i, job] of jobs.entries()) {
        step(t('studio.cart.steps.printFiles', { done: i + 1, total: jobs.length }));
        const blob = await renderPrintFile(job.area, job.method, effective.value, doc.value.strips, job.scale);
        step(t('studio.cart.steps.uploading', { done: uploaded + 1, total: uploads() }), 1);
        const media = await upload(blob, 'print');
        uploaded++;
        step(cartStep.value, 1);
        files.push({ area: job.area.key, method: job.method.method, media_id: media.id });
      }
      step(t('studio.cart.steps.views'));
      await painted(); // the text is on screen before the views block the page
      // Five views of the product (the cart and the order show them as a
      // gallery), uploaded side by side, kept in order.
      const frames = await captureFrames(usedAreas(effective.value));
      total += frames.length - views;
      views = frames.length;
      step(t('studio.cart.steps.uploading', { done: Math.min(uploaded + 1, uploads()), total: uploads() }), 1);
      const mockups = await Promise.all(frames.map(async (frame) => {
        const id = (await upload(await dataUrlToBlob(frame), 'design')).id;
        uploaded++;
        step(t('studio.cart.steps.uploading', { done: Math.min(uploaded + 1, uploads()), total: uploads() }), 1);
        return id;
      }));
      // The same views become the design's own in "Dizaynlarim".
      pendingPreviews = mockups;
      void save();
      pendingItem = {
        design_id: designId.value, variant_id: variantId.value, color_id: colorId.value, size: sizeLabel.value, quantity,
        document: doc.value, files, mockups,
      };
      step(t('studio.cart.steps.adding'));
      await postItem(liveQuote.value?.unit_price ?? String(provisionalPrice.value ?? 0));
    }
    catch (err) {
      cartState.value = 'error';
      cartError.value = getApiErrorMessage(err, err instanceof Error ? err.message : t('studio.cart.failed'));
    }
  }

  async function postItem(expected: string) {
    try {
      await api.post('/cart/items/', { ...pendingItem, expected_unit_price: expected });
      pendingItem = null;
      writeLocal(slug.value, null);
      cartState.value = 'done';
      await queryClient.invalidateQueries({ queryKey: queryKeys.cart });
    }
    catch (err) {
      if (err instanceof ApiError && err.status === 409 && err.data.quote) {
        confirmQuote.value = err.data.quote as Quote;
        cartState.value = 'confirm';
        return;
      }
      throw err;
    }
  }

  /** The customer accepted the price computed from the print files. */
  async function confirmPrice() {
    if (!confirmQuote.value || !pendingItem) return;
    cartStep.value = t('studio.cart.steps.adding');
    cartProgress.value = null;
    cartState.value = 'working';
    try {
      await postItem(confirmQuote.value.unit_price);
      quote.value = confirmQuote.value;
    }
    catch (err) {
      cartState.value = 'error';
      cartError.value = getApiErrorMessage(err, t('studio.cart.failed'));
    }
  }

  function cancelCart() {
    pendingItem = null;
    confirmQuote.value = null;
    cartState.value = 'idle';
  }

  return {
    productQuery, product, variant, color, shape, areas, methods, document: doc, layers, effective, layer, problemCount,
    setSync, clearArea, clearCount, templatesQuery, templates, applyTemplate, editingTemplate, designMethod, setDesignMethod,
    uploads, inkColor, surfaceColors, surfaceHex, canMove, background, canBackground, setBackground, reorderLayer, setLocked,
    variantId, colorId, sizeLabel, sizes, sizesInStock, size, needsSize, pickSize, printScale, printSize,
    printAreaCm, sizePrintArea,
    selectedArea, selectedLayer, designId, quote, liveQuote, provisionalPrice,
    problems, placedCount, blocked, croppedCount, saveState, saveError, notice, ready, resumed,
    canUndo, canRedo, undo, redo, checkpoint,
    patchLayer, updateLayer, addLayer, removeLayer, moveLayer, defaultMethod,
    pickColor, pickVariant, previewVariantSwitch, load, save, saveWithPreviews, signIn,
    cartState, cartStep, cartProgress, cartError, confirmQuote, addToCart, confirmPrice, cancelCart,
  };
}

export type Studio = ReturnType<typeof useStudio>;

export const STUDIO_KEY: InjectionKey<Studio> = Symbol('studio');

export function useStudioContext(): Studio {
  const studio = inject(STUDIO_KEY);
  if (!studio) throw new Error('useStudioContext() must be used inside the Studio page');
  return studio;
}
