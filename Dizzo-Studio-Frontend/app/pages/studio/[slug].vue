<script setup lang="ts">
// The Studio: one editor for every product. What it shows depends only on
// the catalog — the variant's shape (cylinder, plane, disc or GLB model),
// its print areas and methods — never on the product's name.
//
// Layout: the Studio's own top bar; on the left a rail of tools whose panel
// opens beside it; the product in 3D on the stage (the design is edited on
// it; "Tekis ko‘rinish" swaps in the flat editor of the area); under the
// stage the order card: type, colour, print method, price and the cart.
// On phones the tools sit in a bottom bar and panels open as sheets.
import { useQueryClient } from '@tanstack/vue-query';
import type { TextPreset } from '~/components/studio/panels/TextPanel.vue';
import ElementsPanel from '~/components/studio/panels/ElementsPanel.vue';
import type { ElementPick } from '~/lib/design/stickers';
import { isMonoSticker } from '~/lib/design/stickers';
import TemplatesPanel from '~/components/studio/panels/TemplatesPanel.vue';
import TextPanel from '~/components/studio/panels/TextPanel.vue';
import UploadsPanel from '~/components/studio/panels/UploadsPanel.vue';
import DialPanel from '~/components/studio/panels/DialPanel.vue';
import StudioEditor, { FLAT_PAD } from '~/components/studio/StudioEditor.vue';
import StudioLayerProps from '~/components/studio/StudioLayerProps.vue';
import StudioLayers from '~/components/studio/StudioLayers.vue';
import StudioPreview from '~/components/studio/StudioPreview.vue';
import StudioSidebar from '~/components/studio/StudioSidebar.vue';
import type { AreaItem } from '~/components/studio/StudioAreaItems.vue';
import StudioAreaItems from '~/components/studio/StudioAreaItems.vue';
import type { SyncOption } from '~/components/studio/StudioSyncDialog.vue';
import StudioSyncDialog from '~/components/studio/StudioSyncDialog.vue';
import type { TemplateForm } from '~/components/studio/StudioTemplateSave.vue';
import { fontString, layoutText, loadImage } from '~/lib/design/render';
import StudioTemplateSave from '~/components/studio/StudioTemplateSave.vue';
import StudioTopbar from '~/components/studio/StudioTopbar.vue';
import { getApiErrorMessage } from '~/composables/useApi';
import { dataUrlToBlob, DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import { resizeImageToBlob } from '~/composables/useImageResize';
import { STUDIO_KEY, useStudio, contrastInk } from '~/composables/useStudio';
import type { GraphicSource, ImageSource, Layer } from '~/lib/design/document';
import {
  areaMethod, clampInto, crops, fitScale, isBackgroundLayer, isLocked, linkable, mirrored, MONO_COLOR, newLayerId, placeInStrip, printTargets,
  printZone, syncedFrom, syncTargets,
} from '~/lib/design/document';
import { isDialArea, newDialLayer } from '~/lib/design/dial';
import { resolveGraphic } from '~/lib/design/graphics';
import { ENGRAVE_TINT } from '~/lib/three/materials';
import type { AdminTemplate } from '~/types/catalog';
import { METHOD_LABELS } from '~/types/catalog';

definePageMeta({ layout: 'studio', key: route => String(route.params.slug) });

const route = useRoute();
const { t } = useI18n();
const localePath = useLocalePath();
const slug = computed(() => String(route.params.slug));
const studio = useStudio(slug);
provide(STUDIO_KEY, studio);
const {
  productQuery, product, variant, color, shape, areas, methods, layers, layer, selectedArea, selectedLayer, problems,
  notice, ready, canUndo, canRedo, undo, redo, checkpoint, patchLayer, updateLayer, addLayer, removeLayer, moveLayer,
  defaultMethod, addToCart, effective, document: doc, setSync, clearArea, clearCount, variantId, pickVariant,
  previewVariantSwitch, templates, templatesQuery, applyTemplate, editingTemplate, uploads, inkColor, surfaceColors, surfaceHex, canMove, designMethod,
  saveState, save, saveWithPreviews, signIn, cartState, placedCount, reorderLayer, setLocked,
  cartStep, cartProgress, colorId,
} = studio;
const authed = useAuthState();
const { upload } = useMediaUpload();
const api = useApi();
const queryClient = useQueryClient();
const isAdmin = useIsAdmin();
// Saving as a template: only for an admin who came from the admin panel
// (its "Shablon qo‘shish" opens ?as=template) or is editing a template.
const templateMode = computed(() => isAdmin.value && (route.query.as === 'template' || Boolean(editingTemplate.value)));
const adminProducts = useCatalogAdminList();
// Wide screens: read at once (the Studio renders in the browser only), so
// the side panel is there from the first frame instead of popping in.
const desktopQuery = import.meta.client ? window.matchMedia('(min-width: 1024px)') : null;
const isDesktop = ref(desktopQuery?.matches ?? false);
useEventListener(desktopQuery, 'change', (event: MediaQueryListEvent) => {
  isDesktop.value = event.matches;
});

useHead(() => ({ title: product.value ? t('studio.page.title', { name: product.value.name }) : 'Dizzo Studio' }));



// ── Tools ──
type Tool = 'text' | 'uploads' | 'dial' | 'templates' | 'elements' | 'options' | 'layers';
const isClock = computed(() => areas.value.some(isDialArea));
const clockDialLayer = computed(() => {
  return layers.value.find(l => Boolean(l.dial) && (selectedArea.value ? l.area === selectedArea.value : true))
    ?? layers.value.find(l => Boolean(l.dial))
    ?? null;
});
const TOOL_ICONS = computed<Array<{ id: Exclude<Tool, 'options'>; icon: string }>>(() => {
  const base: Array<{ id: Exclude<Tool, 'options'>; icon: string }> = [
    { id: 'text', icon: 'lucide:type' },
    { id: 'uploads', icon: 'lucide:image' },
  ];
  if (isClock.value) {
    base.push({ id: 'dial', icon: 'lucide:clock-3' });
  }
  base.push(
    { id: 'templates', icon: 'lucide:layout-grid' },
    { id: 'elements', icon: 'lucide:shapes' },
    { id: 'layers', icon: 'lucide:layers' },
  );
  return base;
});
const TOOLS = computed(() => TOOL_ICONS.value.map(tool => ({ ...tool, label: t(`studio.tools.${tool.id}`) })));
// Wide screens open on "Galereya" (its skeleton shows while it loads).
const tool = ref<Tool | null>(isDesktop.value ? 'templates' : null);
const toolTitle = computed(() => {
  if (tool.value === 'options') return t('studio.tools.options');
  return TOOLS.value.find(x => x.id === tool.value)?.label ?? '';
});

/** Phones: a sheet closes once its choice is on the design, so a second
 * tap doesn't stack another copy on top. */
function doneOnPhone() {
  if (!isDesktop.value) tool.value = null;
}

function openTool(id: Tool) {
  tool.value = !isDesktop.value && tool.value === id ? null : id;
}
// Wide screens always show one tool's panel; phones start with every
// sheet closed (the customer opens one when they need it).
watch(isDesktop, (desktop) => {
  if (desktop && !tool.value) tool.value = 'text';
  if (!desktop) tool.value = null;
});
// On wide screens the panel stays open: it only switches between tools.
watch(tool, (open) => {
  if (!open && isDesktop.value) tool.value = 'text';
});

const previewRef = ref<InstanceType<typeof StudioPreview> | null>(null);
const propsRef = ref<InstanceType<typeof StudioLayerProps> | null>(null);
const busy = ref(false);
const actionError = ref<string | null>(null);
const loadError = ref<string | null>(null);
const toast = ref<string | null>(null);
let toastTimer: ReturnType<typeof setTimeout> | null = null;
function showToast(message: string) {
  toast.value = message;
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toast.value = null), 2600);
}

const area = computed(() => areas.value.find(a => a.key === selectedArea.value) ?? null);
const selectedLayerArea = computed(() => areas.value.find(a => a.key === layer.value?.area) ?? null);
const engraveTint = computed(() => (variant.value ? ENGRAVE_TINT[variant.value.material] : '#3f3f46'));
// Synced areas: the open area's source (it's read-only then), its targets,
// and the areas it could sync with.
const linkedFrom = computed(() => {
  const key = area.value ? syncedFrom(doc.value, area.value.key) : null;
  return areas.value.find(a => a.key === key) ?? null;
});
const syncedTo = computed(() => (area.value ? syncTargets(doc.value, area.value.key) : []));
const syncOpen = ref(false);
const syncOptions = computed<SyncOption[]>(() => {
  const source = area.value;
  if (!source) return [];
  return areas.value.filter(a => linkable(source, a)).map((a) => {
    const from = syncedFrom(doc.value, a.key);
    const blocked = syncTargets(doc.value, a.key).length
      ? t('studio.sync.blockedSource')
      : from && from !== source.key ? t('studio.sync.blockedTarget', { name: areas.value.find(x => x.key === from)?.name ?? from }) : null;
    return { area: a, mirror: mirrored(source, a), own: layers.value.filter(l => l.area === a.key).length, blocked };
  });
});
// The stage's corner: the open area's name opens this list (in both views),
// and on a shape with several areas the three dots open its actions.
const areaItems = computed<AreaItem[]>(() => areas.value.map((a) => {
  const from = syncedFrom(doc.value, a.key);
  return {
    area: a,
    own: layers.value.filter(l => l.area === a.key).length,
    from: from ? areas.value.find(x => x.key === from)?.name ?? from : null,
    targets: syncTargets(doc.value, a.key).length,
  };
}));
const canAdd = computed(() => Boolean(area.value && !linkedFrom.value && defaultMethod(area.value.key)));
const imagesForPanel = computed(() => {
  const seen = new Map<string, ImageSource>();
  for (const img of [...uploads.value, ...layers.value.flatMap(l => (l.image ? [l.image] : []))]) seen.set(img.media_id, img);
  return [...seen.values()];
});

onMounted(async () => {
  try {
    await studio.load();
    await templatesQuery.suspense();
    // No ready designs for this product: "Matn" instead, unless the customer already picked a tool.
    if (isDesktop.value && tool.value === 'templates' && !templates.value.length) tool.value = 'text';
  }
  catch (err) {
    loadError.value = getApiErrorMessage(err, t('studio.page.openFailed'));
  }
});

// Selecting a layer in another area opens that area; with nothing
// selected the settings panel gives way to "Matn" (closed on phones).
watch(layer, (l) => {
  if (l?.area && l.area !== selectedArea.value) selectedArea.value = l.area;
  if (!l && tool.value === 'options') tool.value = isDesktop.value ? 'text' : null;
});

function onKey(event: KeyboardEvent) {
  const target = event.target as HTMLElement | null;
  if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
    event.preventDefault();
    if (event.shiftKey) redo();
    else undo();
  }
  else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'y') {
    event.preventDefault();
    redo();
  }
}
onMounted(() => window.addEventListener('keydown', onKey));
onBeforeUnmount(() => window.removeEventListener('keydown', onKey));

// ── The stage ──
const view3d = ref(false); // the 3D view filling the screen
// The design is edited on the product in 3D; the flat editor of the area
// (always fitted, no zoom) is there for precise work when asked for.
const flat = ref(false); // the product in 3D first; the flat editor on request

const stageRef = ref<HTMLElement | null>(null);
// The flat editor's stage is as tall as the area needs, so the same room
// is left on every side (within the usual limits).
const stageSize = ref({ width: 0, lg: false });
useResizeObserver(stageRef, ([entry]) => {
  stageSize.value = { width: entry!.contentRect.width, lg: window.innerWidth >= 1024 };
});
const flatStageStyle = computed(() => {
  const { width, lg } = stageSize.value;
  if (!flat.value || view3d.value || !area.value || !width) return null;
  const ideal = (width - 2 * FLAT_PAD) * Number(area.value.height_mm) / Number(area.value.width_mm) + 2 * FLAT_PAD;
  const max = lg ? Math.max(420, window.innerHeight - 404) : width;
  return { height: `${Math.round(Math.min(max, Math.max(200, ideal)))}px` };
});

// ── The selected element's toolbar: floating a little under where it was
// pressed (or under the stage's middle), fixed on screen, taking no room ──
const toolbarAt = ref<{ x: number; y: number } | null>(null);
const pressing = ref(false);
const TOOLBAR_GAP = 84; // px under the press (about 2–3 cm on a screen)
const onButton = (event: Event) => Boolean((event.target as HTMLElement | null)?.closest('button, a, [role="group"]'));
function onStageDown(event: PointerEvent) {
  if (!onButton(event)) pressing.value = true;
}
function onStageUp(event: PointerEvent) {
  if (!pressing.value) return;
  pressing.value = false;
  toolbarAt.value = { x: event.clientX, y: event.clientY + TOOLBAR_GAP };
}
/** Where the toolbar goes when the element was chosen elsewhere (layers list, adding). */
function stageAnchor() {
  const r = stageRef.value?.getBoundingClientRect();
  return r ? { x: r.left + r.width / 2, y: r.top + r.height * 0.62 } : null;
}
watch(selectedLayer, (id, old) => {
  if (id && id !== old && !pressing.value) toolbarAt.value = stageAnchor();
});
const toolbarStyle = computed(() => {
  const at = toolbarAt.value ?? stageAnchor();
  if (!at || !import.meta.client) return {};
  const half = 190;
  const x = Math.min(window.innerWidth - half - 8, Math.max(half + 8, at.x));
  const y = Math.min(window.innerHeight - 64, Math.max(72, at.y));
  return { left: `${x}px`, top: `${y}px` };
});
const zoom3d = ref(100); // % of the framed view, from StudioPreview
const zoomIn = () => previewRef.value?.zoomBy(0.8);
const zoomOut = () => previewRef.value?.zoomBy(1.25);
const zoomReset = () => previewRef.value?.resetView();

// ── Adding layers ──
/** Where a new layer goes: the open area and its default method. */
function target() {
  const current = area.value;
  const method = current && !linkedFrom.value ? defaultMethod(current.key) : null;
  if (!current || !method) {
    actionError.value = linkedFrom.value
      ? t('studio.add.linked', { name: linkedFrom.value.name })
      : current && designMethod.value
        ? t('studio.add.noMethod', { area: current.name, method: METHOD_LABELS[designMethod.value] })
        : t('studio.add.notAllowed');
    return null;
  }
  actionError.value = null;
  const m = areaMethod(current, method)!;
  // With a strip, new layers go into it, where the design already is.
  return { area: current, method, m, zone: printZone(current, m, layers.value, doc.value.strips), ink: m.colors_allowed ? inkColor.value : MONO_COLOR };
}

/** The zone's centre, stepped down-right past layers already sitting there
 * (and with a strip, where it fits one strip with the area's layers). */
function freeSpot(t: NonNullable<ReturnType<typeof target>>, w: number, h: number) {
  let spot = { x_mm: (t.zone.x0 + t.zone.x1) / 2, y_mm: (t.zone.y0 + t.zone.y1) / 2, w_mm: w, h_mm: h, rotation: 0 };
  const own = layers.value.filter(l => l.area === t.area.key);
  const taken = (x: number, y: number) => own.some(l => Math.hypot(l.x_mm - x, l.y_mm - y) < 1);
  for (let i = 0; i < 6 && taken(spot.x_mm, spot.y_mm); i++) {
    spot = clampInto({ ...spot, x_mm: spot.x_mm + 6, y_mm: spot.y_mm + 6 }, t.zone);
  }
  const placed = placeInStrip({ ...spot, id: '', area: t.area.key, method: t.method, kind: 'image' }, t.area, t.m, own, doc.value.strips);
  return { x_mm: placed.x_mm, y_mm: placed.y_mm };
}

function placeImage(image: ImageSource) {
  const t = target();
  if (!t) return;
  const maxW = Math.min((t.zone.x1 - t.zone.x0) * 0.7, t.m.max_width_mm ? Number(t.m.max_width_mm) : Infinity);
  const maxH = Math.min((t.zone.y1 - t.zone.y0) * 0.7, t.m.max_height_mm ? Number(t.m.max_height_mm) : Infinity);
  const scale = Math.min(maxW / image.px_w, maxH / image.px_h);
  const [w, h] = [image.px_w * scale, image.px_h * scale];
  addLayer({ id: newLayerId(), area: t.area.key, method: t.method, kind: 'image', ...freeSpot(t, w, h), w_mm: w, h_mm: h, rotation: 0, image });
  doneOnPhone();
}

async function uploadImage(file: File) {
  actionError.value = null;
  if (!MEDIA_IMAGE_TYPES.includes(file.type)) {
    actionError.value = t('studio.uploads.wrongType');
    return;
  }
  busy.value = true;
  try {
    // Very large photos are scaled down (still far above print resolution).
    const blob = file.size > DESIGN_IMAGE_MAX_MB * 1024 * 1024
      ? await resizeImageToBlob(file, 6000, 0.92, file.type === 'image/png' ? 'image/png' : 'image/jpeg')
      : file;
    const media = await upload(blob, 'design');
    const img = await loadImage(media.url);
    const image = { media_id: media.id, url: media.url, px_w: img.naturalWidth, px_h: img.naturalHeight };
    uploads.value = [image, ...uploads.value];
    placeImage(image);
  }
  catch (err) {
    actionError.value = getApiErrorMessage(err, err instanceof Error ? err.message : t('studio.uploads.failed'));
  }
  finally {
    busy.value = false;
  }
}

const TEXT_SIZE_MM = 24;

async function addText(preset: TextPreset) {
  const t = target();
  if (!t) return;
  // Every new text is 24 mm (smaller, in whole mm, only when it wouldn't fit).
  const minFont = Math.ceil(t.m.min_font_mm ? Number(t.m.min_font_mm) : 3);
  const text = {
    content: preset.content, font: preset.font, color: t.ink, align: 'center' as const, bold: preset.bold, italic: preset.italic,
    size_mm: Math.max(minFont, TEXT_SIZE_MM),
  };
  await document.fonts.load(fontString(text, 64), text.content);
  let layout = layoutText(text);
  const room = (t.zone.x1 - t.zone.x0) * 0.9;
  if (layout.w_mm > room) {
    text.size_mm = Math.max(minFont, Math.floor((text.size_mm * room) / layout.w_mm));
    layout = layoutText(text);
  }
  addLayer({
    id: newLayerId(), area: t.area.key, method: t.method, kind: 'text',
    ...freeSpot(t, layout.w_mm, layout.h_mm), w_mm: layout.w_mm, h_mm: layout.h_mm, rotation: 0, text,
  });
  if (!isDesktop.value) {
    doneOnPhone();
    return;
  }
  tool.value = 'options';
  await nextTick();
  propsRef.value?.focusText();
}

function addGraphic(library: GraphicSource['library'], name: string) {
  const t = target();
  const def = resolveGraphic({ library, name });
  if (!t || !def) return;
  const zoneW = t.zone.x1 - t.zone.x0;
  const zoneH = t.zone.y1 - t.zone.y0;
  // Lines span the zone's width; everything else is a third of its short side.
  const long = def.width / def.height > 5;
  const k = long ? (zoneW * 0.6) / def.width : (Math.min(zoneW, zoneH) * 0.35) / Math.max(def.width, def.height);
  const [w, h] = [def.width * k, def.height * k];
  addLayer({
    id: newLayerId(), area: t.area.key, method: t.method, kind: 'graphic',
    ...freeSpot(t, w, h), w_mm: w, h_mm: h, rotation: 0, graphic: { library, name, color: t.ink },
  });
  doneOnPhone();
}

/** A sticker: many-coloured, drawn as it is, a third of the zone's short side. */
function addSticker(pick: ElementPick) {
  const t = target();
  if (!t) return;
  const k = (Math.min(t.zone.x1 - t.zone.x0, t.zone.y1 - t.zone.y0) * 0.4) / Math.max(pick.w, pick.h);
  const [w, h] = [pick.w * k, pick.h * k];
  addLayer({
    id: newLayerId(), area: t.area.key, method: t.method, kind: 'graphic',
    ...freeSpot(t, w, h), w_mm: w, h_mm: h, rotation: 0,
    graphic: { library: 'sticker', name: pick.name, color: isMonoSticker(pick.name) ? t.ink : MONO_COLOR },
  });
  doneOnPhone();
}

function addElement(pick: ElementPick) {
  if (pick.library === 'sticker') addSticker(pick);
  else addGraphic(pick.library, pick.name);
}

function onAddDial(areaKey?: string) {
  const targetKey = areaKey || selectedArea.value || areas.value[0]?.key;
  const targetArea = areas.value.find(a => a.key === targetKey);
  if (!targetArea) return;
  const ink = contrastInk(surfaceColors.value[targetArea.key] || color.value?.hex || '#ffffff');
  const dial = newDialLayer(targetArea, ink);
  if (dial) {
    addLayer(dial);
    selectedLayer.value = dial.id;
    tool.value = 'dial';
  }
}

/** The selected element to the middle of its zone, across (x) or down (y). */
function centerLayer(axis: 'x' | 'y') {
  const l = layer.value;
  const a = areas.value.find(x => x.key === l?.area);
  const m = l && a ? areaMethod(a, l.method) : undefined;
  if (!l || !m || isLocked(l) || !a) return;
  // With a strip: the middle of the strip the rest of the design is in.
  const z = printZone(a, m, layers.value.filter(x => x.id !== l.id), doc.value.strips);
  const moved = { ...l, ...(axis === 'x' ? { x_mm: (z.x0 + z.x1) / 2 } : { y_mm: (z.y0 + z.y1) / 2 }) };
  const placed = placeInStrip(moved, a, m, layers.value.filter(x => x.area === l.area), doc.value.strips);
  updateLayer(l.id, { x_mm: placed.x_mm, y_mm: placed.y_mm });
}

function duplicate(id: string) {
  const source = layers.value.find(l => l.id === id);
  if (!source) return;
  const copy: Layer = { ...(JSON.parse(JSON.stringify(source)) as Layer), id: newLayerId(), x_mm: source.x_mm + 5, y_mm: source.y_mm + 5 };
  const a = areas.value.find(x => x.key === copy.area);
  const m = a ? areaMethod(a, copy.method) : undefined;
  addLayer(a && m ? placeInStrip(copy, a, m, layers.value.filter(x => x.area === copy.area), doc.value.strips) : copy);
}

/** Puts a parked layer into the open area, shrinking it to fit if needed. */
function place(id: string) {
  if (linkedFrom.value) {
    actionError.value = t('studio.add.linkedPlace', { name: linkedFrom.value.name });
    return;
  }
  const l = layers.value.find(x => x.id === id);
  const current = area.value;
  const method = current ? defaultMethod(current.key) : null;
  if (!l || !current || !method) {
    if (current && designMethod.value) actionError.value = t('studio.add.noMethodShort', { area: current.name, method: METHOD_LABELS[designMethod.value] });
    return;
  }
  const m = areaMethod(current, method)!;
  let next: Layer = { ...l, area: current.key, method };
  if (!m.colors_allowed) {
    if (next.text) next = { ...next, text: { ...next.text, color: MONO_COLOR } };
    if (next.graphic) next = { ...next, graphic: { ...next.graphic, color: MONO_COLOR } };
  }
  const f = crops(next) && !m.strip_width_mm ? 1 : fitScale(next, m);
  if (f < 1 && !next.text) next = { ...next, w_mm: next.w_mm * f, h_mm: next.h_mm * f };
  updateLayer(id, placeInStrip(next, current, m, layers.value.filter(x => x.area === current.key), doc.value.strips));
}

function onCanvasSelect(id: string | null) {
  selectedLayer.value = id;
  if (id && isDesktop.value && tool.value !== 'layers') tool.value = 'options';
}

// ── Type ("Tur"): every type in a row under the stage, the current one
// marked. Its picture is the chosen colour's primary (first) gallery picture where
// this type has that colour; otherwise the first available colour's primary picture.
const variantPhoto = (v: NonNullable<typeof product.value>['variants'][number]) => {
  if (color.value) {
    const targetName = color.value.name?.trim().toLowerCase();
    const targetHex = color.value.hex?.trim().toLowerCase();
    const matching = v.colors.find(c =>
      (c.name && c.name.trim().toLowerCase() === targetName)
      || (c.hex && c.hex.trim().toLowerCase() === targetHex),
    );
    if (matching?.images?.[0]) return matching.images[0];
    if (matching?.card_image_url) return matching.card_image_url;
  }
  const firstWithImage = v.colors.find(c => c.images && c.images.length > 0);
  if (firstWithImage?.images?.[0]) return firstWithImage.images[0];
  return v.colors.find(c => c.card_image_url)?.card_image_url ?? v.main_image_url ?? v.variant_main_image ?? v.images[0] ?? null;
};
const pendingVariant = ref<{ id: number; colorId: number | null; lost: number } | null>(null);

function chooseVariant(id: number, wantedColor: number | null) {
  const preview = previewVariantSwitch(id);
  if (preview?.shapeChanges && preview.lost > 0) {
    pendingVariant.value = { id, colorId: wantedColor, lost: preview.lost };
    return;
  }
  pickVariant(id, wantedColor);
}

function confirmVariant() {
  if (pendingVariant.value) pickVariant(pendingVariant.value.id, pendingVariant.value.colorId);
  pendingVariant.value = null;
}

// ── Share ──
const shareUrl = () => `${window.location.origin}${localePath(`/studio/${slug.value}`)}`;

/** The product exactly as the customer sees it now. */
async function mockupFile(): Promise<File | null> {
  const frame = await previewRef.value?.captureView();
  if (!frame) return null;
  const blob = await dataUrlToBlob(frame);
  return new File([blob], `${slug.value}-${t('studio.shots.fileSuffix')}.${blob.type === 'image/png' ? 'png' : 'jpg'}`, { type: blob.type });
}

/** Downloads `blob` under `name`. */
function download(blob: Blob, name: string) {
  const href = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = href;
  a.download = name;
  a.click();
  URL.revokeObjectURL(href);
}

// "Rasmga olish" opens a choice: the five views the cart and "Dizaynlarim"
// get (larger, zipped in the browser), or the product exactly as it stands
// on the stage now. Both are drawn without the editing marks.
const SHOT_PX = 1600;
// A tenth of the picture free on each side — the framing captureView uses.
const SHOT_MARGIN_PX = 160;
const shooting = ref(false);
const shotOpen = ref(false);
const shotPreviews = ref<{ set: string[]; view: string | null }>({ set: [], view: null });
const shotPreviewing = ref(false);

async function openShots() {
  shotOpen.value = true;
  if (shotPreviews.value.view || shotPreviewing.value) return;
  shotPreviewing.value = true;
  try {
    const used = [...new Set(printTargets(effective.value).map(t => t.area))];
    const areasFor = used.length ? used : selectedArea.value ? [selectedArea.value] : [];
    shotPreviews.value = {
      set: await captureFrames(areasFor, 320),
      view: (await previewRef.value?.captureView()) ?? null,
    };
  }
  catch {
    shotPreviews.value = { set: [], view: null }; // the pictures themselves still work
  }
  finally {
    shotPreviewing.value = false;
  }
}

/** The product as it stands on the stage: one picture, same backdrop as the set. */
async function downloadView() {
  if (shooting.value) return;
  shooting.value = true;
  actionError.value = null;
  try {
    const frame = await previewRef.value?.captureView();
    if (!frame) throw new Error(t('studio.shots.notReady'));
    const blob = await dataUrlToBlob(frame);
    const ext = blob.type === 'image/jpeg' ? 'jpg' : 'png';
    download(blob, `${slug.value}-${t('studio.shots.fileSuffix')}.${ext}`);
    shotOpen.value = false;
    showToast(t('studio.shots.downloadedOne'));
  }
  catch (err) {
    actionError.value = err instanceof Error ? err.message : t('studio.shots.failed');
  }
  finally {
    shooting.value = false;
  }
}

async function downloadShots() {
  if (shooting.value) return;
  shooting.value = true;
  actionError.value = null;
  try {
    const used = [...new Set(printTargets(effective.value).map(t => t.area))];
    const frames = await captureFrames(used.length ? used : selectedArea.value ? [selectedArea.value] : [], SHOT_PX);
    if (!frames.length) throw new Error(t('studio.shots.notReady'));
    const files: Record<string, Uint8Array> = {};
    for (const [i, frame] of frames.entries()) {
      files[`${slug.value}-${i + 1}.jpg`] = new Uint8Array(await (await dataUrlToBlob(frame)).arrayBuffer());
    }
    // JPEG is compressed already: stored as it is, so the zip is instant.
    const { zipSync } = await import('fflate');
    download(new Blob([zipSync(files, { level: 0 })], { type: 'application/zip' }), `${slug.value}-${t('studio.shots.fileSuffix')}.zip`);
    shotOpen.value = false;
    showToast(t('studio.shots.downloaded', frames.length));
  }
  catch (err) {
    actionError.value = err instanceof Error ? err.message : t('studio.shots.failed');
  }
  finally {
    shooting.value = false;
  }
}

async function share(how: 'link' | 'image' | 'native') {
  try {
    if (how === 'link') {
      await navigator.clipboard.writeText(shareUrl());
      showToast(t('studio.share.copied'));
    }
    else if (how === 'image') {
      await openShots(); // the same choice as the stage's button
    }
    else {
      const file = await mockupFile();
      const data: ShareData = { title: product.value?.name, text: t('studio.share.text'), url: shareUrl() };
      if (file && navigator.canShare?.({ files: [file] })) data.files = [file];
      await navigator.share(data);
    }
  }
  catch (err) {
    if (err instanceof DOMException && err.name === 'AbortError') return; // the share sheet was closed
    actionError.value = err instanceof Error ? err.message : t('studio.share.failed');
  }
}

// ── Templates ──
function useTemplate(template: Parameters<typeof applyTemplate>[0]) {
  applyTemplate(template);
  doneOnPhone();
  showToast(t('studio.templates.applied', { name: template.name }));
}

const templateSaveOpen = ref(false);
const templateBusy = ref(false);
const templateError = ref<string | null>(null);
async function saveTemplate(form: TemplateForm) {
  templateBusy.value = true;
  templateError.value = null;
  try {
    const productId = adminProducts.data.value?.find(p => p.slug === slug.value)?.id;
    if (!productId) throw new Error(t('studio.templateSave.productMissing'));
    await previewRef.value?.flush();
    const used = effective.value.find(l => l.area !== null)?.area ?? selectedArea.value ?? '';
    const [frame] = previewRef.value?.captureFrames([used]) ?? [];
    if (!frame) throw new Error(t('studio.shots.notReady'));
    const preview = await upload(await dataUrlToBlob(frame), 'design');
    // The gallery's five pictures, from the same views as a saved design —
    // but cut out, not glued to the editor's grey backdrop, so the catalog
    // can put them on whatever it likes. WebP keeps the transparency and
    // brings a 1600 px PNG down to a sane size.
    const printed = [...new Set(printTargets(effective.value).map(target => target.area))];
    const shots = (await previewRef.value?.captureCutouts(printed.length ? printed : [used], SHOT_PX, SHOT_MARGIN_PX)) ?? [];
    const images: string[] = [];
    for (const shot of shots.slice(0, 5)) {
      images.push((await upload(await resizeImageToBlob(await dataUrlToBlob(shot), SHOT_PX, 0.9, 'image/webp'), 'catalog')).id);
    }
    const body = { ...form, document: doc.value, preview_media_id: preview.id, images, color_id: colorId.value };
    const saved = editingTemplate.value
      ? await api.put<AdminTemplate>(`/admin/catalog/templates/${editingTemplate.value.id}/`, body)
      : await api.post<AdminTemplate>(`/admin/catalog/products/${productId}/templates/`, body);
    if (editingTemplate.value) editingTemplate.value = saved;
    await queryClient.invalidateQueries({ queryKey: ['catalog', 'templates', slug.value] });
    templateSaveOpen.value = false;
    showToast(t('studio.templateSave.saved', { name: saved.name }));
  }
  catch (err) {
    templateError.value = getApiErrorMessage(err, err instanceof Error ? err.message : t('studio.save.failedDesign'));
  }
  finally {
    templateBusy.value = false;
  }
}

// After saving or adding to the cart: where next.
const doneDialog = ref<'saved' | 'cart' | null>(null);
const quantity = ref(1);
watch(cartState, (state) => {
  if (state === 'done') doneDialog.value = 'cart';
});

/** Saves in the account: guests sign in (or register) first, then it saves. */
async function saveNow() {
  if (editingTemplate.value) {
    templateSaveOpen.value = true;
    return;
  }
  if (!authed.value) {
    await save(); // kept in this browser meanwhile
    if (!(await signIn(t('studio.save.signIn')))) return;
  }
  // With the five views "Dizaynlarim" shows.
  await saveWithPreviews(captureFrames);
  if (saveState.value === 'saved') doneDialog.value = 'saved';
  else showToast(t('studio.save.failedToast'));
}

function addFromDialog() {
  doneDialog.value = null;
  void onAddToCart(quantity.value);
}

/** The five views of the product for the cart, "Dizaynlarim" and the
 * picture zip (`size`: larger there). */
async function captureFrames(used: string[], size?: number) {
  await previewRef.value?.flush();
  return previewRef.value?.captureFrames(used, size) ?? [];
}

async function onAddToCart(quantity: number) {
  await addToCart(quantity, captureFrames);
}

const stageBtn = 'size-11 rounded-xl border-transparent bg-white/95 text-slate-700 shadow-sm backdrop-blur hover:bg-white';
</script>

<template>
  <div class="flex h-full flex-col">
    <div
      v-if="productQuery.isError.value || loadError"
      class="mx-auto mt-16 max-w-md rounded-2xl border border-border bg-card p-6 text-center"
    >
      <p class="text-lg font-bold text-foreground">
        {{ loadError ?? $t('studio.page.notFound') }}
      </p>
      <p class="mt-2 text-sm text-muted-foreground">
        {{ $t('studio.page.notFoundHint') }}
      </p>
      <UiButton
        as-child
        class="mt-4"
      >
        <NuxtLink :to="localePath('/catalog')">
          {{ $t('studio.page.backToCatalog') }}
        </NuxtLink>
      </UiButton>
    </div>

    <!-- Loading: the Studio's own shape in grey, so nothing jumps. -->
    <div
      v-else-if="!product || !ready"
      class="flex h-full flex-col"
      role="status"
      :aria-label="$t('studio.page.preparing')"
    >
      <div class="flex h-14 shrink-0 items-center gap-3 px-3 sm:h-16 sm:px-4">
        <UiSkeleton class="size-9 rounded-md" />
        <UiSkeleton class="hidden h-9 w-44 md:block lg:h-10 lg:w-48" />
        <UiSkeleton class="h-5 w-32 md:absolute md:left-1/2 md:-translate-x-1/2" />
        <div class="ml-auto flex items-center gap-1.5">
          <UiSkeleton class="size-8 rounded-md" />
          <UiSkeleton class="size-8 rounded-md" />
          <UiSkeleton class="hidden h-10 w-32 rounded-xl md:block" />
          <UiSkeleton class="size-9 rounded-md" />
        </div>
      </div>
      <div class="flex min-h-0 flex-1 gap-3 px-2 pb-16 sm:px-3 lg:pb-3">
        <UiSkeleton class="hidden w-[94px] shrink-0 rounded-2xl lg:block" />
        <UiSkeleton class="hidden w-[280px] shrink-0 rounded-2xl lg:block" />
        <div class="min-w-0 flex-1 space-y-3">
          <!-- The stage itself (no placeholder box): the brand's loader while the product and its model come. -->
          <div class="relative aspect-square w-full overflow-hidden rounded-2xl border border-border/60 bg-[#e9ebef] sm:aspect-[4/3] lg:aspect-auto lg:h-[max(420px,calc(100dvh-404px))]">
            <StageLoader
              show
              immediate
              :text="$t('studio.preview.loading')"
            />
          </div>
          <UiSkeleton class="h-48 w-full rounded-2xl" />
        </div>
      </div>
    </div>

    <template v-else>
      <StudioTopbar
        :product-name="variant?.name ?? product.name"
        :area-name="areas.length > 1 ? area?.name ?? null : null"
        :can-undo="canUndo"
        :can-redo="canRedo"
        :zoom="flat ? null : zoom3d"
        :template-mode="templateMode"
        @save-template="templateSaveOpen = true"
        @undo="undo"
        @redo="redo"
        @zoom-in="zoomIn"
        @zoom-out="zoomOut"
        @zoom-reset="zoomReset"
        @save="saveNow"
        @share="share"
      />

      <div class="flex min-h-0 flex-1 gap-3 px-2 pb-16 sm:px-3 lg:pb-3">
        <!-- Tools: a rail on desktop, a bar at the bottom on phones. -->
        <nav
          class="fixed inset-x-0 bottom-0 z-40 flex gap-1 overflow-x-auto border-t border-border bg-white/95 px-2 py-1.5 backdrop-blur lg:static lg:w-[94px] lg:shrink-0 lg:flex-col lg:gap-1.5 lg:overflow-visible lg:rounded-2xl lg:border lg:border-border/70 lg:bg-card lg:p-2"
          :aria-label="$t('studio.tools.label')"
        >
          <UiButton
            v-for="item in TOOLS"
            :key="item.id"
            variant="ghost"
            class="h-[58px] min-w-[70px] flex-1 flex-col gap-1 p-1 text-[11px] font-medium lg:h-[78px] lg:w-full lg:flex-none"
            :class="tool === item.id ? 'bg-primary/10 text-primary hover:bg-primary/15 hover:text-primary' : 'text-slate-600'"
            :aria-pressed="tool === item.id"
            @click="openTool(item.id)"
          >
            <span class="relative flex">
              <Icon
                :name="item.icon"
                class="text-[22px]"
              />
              <span
                v-if="item.id === 'layers' && layers.length"
                class="absolute -right-2.5 -top-1.5 min-w-4 rounded-full bg-slate-900 px-1 text-center text-[9px] leading-4 text-white"
              >{{ layers.length }}</span>
            </span>
            {{ item.label }}
          </UiButton>
        </nav>

        <!-- Phones: the dimmed page behind an open tool sheet; a tap closes it. -->
        <Transition
          enter-active-class="transition-opacity duration-300"
          enter-from-class="opacity-0"
          leave-active-class="transition-opacity duration-200"
          leave-to-class="opacity-0"
        >
          <div
            v-if="!isDesktop && tool"
            class="fixed inset-0 z-20 bg-slate-900/40 backdrop-blur-xs lg:hidden"
            aria-hidden="true"
            @click="tool = null"
          />
        </Transition>

        <!-- The open tool's panel: beside the rail, or a sheet on phones
             that slides up from above the bottom bar. -->
        <Transition
          enter-active-class="max-lg:transition-transform max-lg:duration-300 max-lg:ease-out"
          enter-from-class="max-lg:translate-y-full"
          leave-active-class="max-lg:transition-transform max-lg:duration-200 max-lg:ease-in"
          leave-to-class="max-lg:translate-y-full"
        >
          <section
            v-if="tool"
            class="fixed inset-x-0 bottom-14 z-30 flex max-h-[72dvh] flex-col rounded-t-3xl border border-border/70 bg-card shadow-overlay lg:static lg:max-h-none lg:w-[280px] lg:shrink-0 lg:rounded-2xl lg:shadow-none"
            :aria-label="toolTitle"
          >
            <header class="flex items-center justify-between gap-2 px-5 pb-2 pt-4">
              <h2 class="text-[15px] font-bold text-foreground">
                {{ toolTitle }}
              </h2>
              <UiButton
                v-if="!isDesktop"
                variant="ghost"
                size="icon-sm"
                class="-mr-2 rounded-full text-muted-foreground"
                :aria-label="$t('studio.common.close')"
                @click="tool = null"
              >
                <Icon name="lucide:x" />
              </UiButton>
            </header>
            <div class="min-h-0 flex-1 overflow-y-auto px-5 pb-5 pt-2">
              <TextPanel
                v-if="tool === 'text'"
                :disabled="!canAdd"
                @add="addText"
              />
              <UploadsPanel
                v-else-if="tool === 'uploads'"
                :images="imagesForPanel"
                :busy="busy"
                :disabled="!canAdd"
                @upload="uploadImage"
                @place="placeImage"
              />
              <DialPanel
                v-else-if="tool === 'dial'"
                :dial-layer="clockDialLayer"
                :area="area"
                :color-hex="color?.hex"
                :surface-hex="surfaceHex"
                @add="onAddDial(selectedArea ?? areas[0]?.key)"
                @update="(changes) => { if (clockDialLayer) updateLayer(clockDialLayer.id, { dial: { ...clockDialLayer.dial!, ...changes } }); }"
                @remove="() => { if (clockDialLayer) removeLayer(clockDialLayer.id); }"
              />
              <TemplatesPanel
                v-else-if="tool === 'templates'"
                :templates="templates"
                :loading="templatesQuery.isLoading.value"
                @apply="useTemplate"
              />
              <ElementsPanel
                v-else-if="tool === 'elements'"
                :disabled="!canAdd"
                @add="addElement"
                @place-image="placeImage"
              />
              <template v-else-if="tool === 'options'">
                <StudioLayerProps
                  v-if="layer"
                  ref="propsRef"
                  :key="layer.id"
                  :layer="layer"
                  :area="selectedLayerArea"
                  :problems="problems[layer.id] ?? []"
                  :can-forward="canMove(layer.id, 1)"
                  :can-backward="canMove(layer.id, -1)"
                  @begin="checkpoint"
                  @patch="(p: Partial<Layer>) => patchLayer(layer!.id, p)"
                  @update="(p: Partial<Layer>) => updateLayer(layer!.id, p)"
                  @remove="removeLayer(layer!.id)"
                  @duplicate="duplicate(layer!.id)"
                  @move="(step: -1 | 1) => moveLayer(layer!.id, step)"
                  @lock="(on: boolean) => setLocked(layer!.id, on)"
                />
              </template>
              <StudioLayers
                v-else-if="tool === 'layers'"
                :layers="layers"
                :areas="areas"
                :selected-area="selectedArea"
                :selected-id="selectedLayer"
                :problems="problems"
                :linked-from="linkedFrom?.name ?? null"
                @select="(id: string) => selectedLayer = id"
                @reorder="reorderLayer"
                @lock="setLocked"
                @remove="removeLayer"
                @place="place"
                @add-dial="onAddDial"
              />
            </div>
          </section>
        </Transition>

        <main class="min-h-0 min-w-0 flex-1 space-y-3 overflow-y-auto overflow-x-hidden overscroll-contain pb-3">
          <!-- The stage: the product in 3D (or the flat editor over it). -->
          <div
            ref="stageRef"
            class="overflow-hidden bg-[#e9ebef]"
            :class="view3d
              ? 'fixed inset-0 z-50'
              : flatStageStyle
                ? 'relative rounded-2xl border border-border/60'
                : 'relative aspect-square rounded-2xl border border-border/60 sm:aspect-[4/3] lg:aspect-auto lg:h-[max(420px,calc(100dvh-404px))]'"
            :style="flatStageStyle ?? undefined"
            @pointerdown.capture="onStageDown"
            @pointerup.capture="onStageUp"
            @pointercancel.capture="pressing = false"
          >
            <StudioPreview
              v-if="shape && variant && color"
              ref="previewRef"
              :shape="shape"
              :material="variant.material"
              :color-hex="color.hex"
              :layers="effective"
              :strips="doc.strips"
              :selected-area="selectedArea"
              :editable="!flat"
              :selected-id="selectedLayer"
              :methods="methods"
              :problems="problems"
              :locked-area="linkedFrom ? selectedArea : null"
              :white-underbase="variant.white_underbase"
              @surface="surfaceColors = $event"
              @select-area="(key: string) => selectedArea = key"
              @select="onCanvasSelect"
              @begin="checkpoint"
              @patch="patchLayer"
              @remove="removeLayer"
              @zoom="(z: number) => zoom3d = z"
              @edit-text="(id: string) => { selectedLayer = id; tool = 'options'; nextTick(() => propsRef?.focusText()); }"
            />

            <div
              v-if="flat && area && color"
              class="absolute inset-0 z-10 bg-[#e9ebef]"
            >
              <StudioEditor
                :area="area"
                :layers="effective"
                :strips="doc.strips"
                :readonly="Boolean(linkedFrom)"
                :selected-id="selectedLayer"
                :methods="methods"
                :color-hex="surfaceHex"
                :engrave-tint="engraveTint"
                :problems="problems"
                @select="onCanvasSelect"
                @begin="checkpoint"
                @patch="patchLayer"
                @remove="removeLayer"
                @edit-text="(id: string) => { selectedLayer = id; tool = 'options'; nextTick(() => propsRef?.focusText()); }"
              />
            </div>

            <!-- "Savatga qo‘shish" at work: its real steps over the stage. -->
            <StageLoader
              class="z-30 rounded-2xl"
              :show="cartState === 'working'"
              :text="cartStep"
              :progress="cartProgress"
              veil="soft"
            />

            <!-- Top left: the area's actions (the side itself is named in the top bar) and notices. -->
            <div class="pointer-events-none absolute left-3 right-40 top-3 z-20 flex flex-col items-start gap-2">
              <div class="pointer-events-auto flex flex-wrap items-center gap-2">
                <UiDropdownMenu v-if="area && areas.length > 1">
                  <UiDropdownMenuTrigger as-child>
                    <UiButton
                      variant="outline"
                      size="icon-sm"
                      class="border-transparent bg-white/95 shadow-sm"
                      :title="$t('studio.areas.actions')"
                      :aria-label="$t('studio.areas.actions')"
                    >
                      <Icon name="lucide:ellipsis-vertical" />
                    </UiButton>
                  </UiDropdownMenuTrigger>
                  <UiDropdownMenuContent
                    align="start"
                    class="w-60"
                  >
                    <UiDropdownMenuSub>
                      <UiDropdownMenuSubTrigger>
                        <Icon name="lucide:layout-template" />
                        {{ $t('studio.areas.switch') }}
                      </UiDropdownMenuSubTrigger>
                      <UiDropdownMenuSubContent class="w-60">
                        <StudioAreaItems
                          :items="areaItems"
                          :selected="selectedArea"
                          @pick="(key: string) => selectedArea = key"
                        />
                      </UiDropdownMenuSubContent>
                    </UiDropdownMenuSub>
                    <UiDropdownMenuSeparator />
                    <UiDropdownMenuItem
                      :disabled="Boolean(linkedFrom) || !syncOptions.length"
                      @select="syncOpen = true"
                    >
                      <Icon name="lucide:link-2" />
                      {{ $t('studio.areas.sync') }}<template v-if="syncedTo.length">
                        · {{ syncedTo.length }}
                      </template>
                    </UiDropdownMenuItem>
                    <UiDropdownMenuSeparator />
                    <!-- Starting this side over: one undo step brings it back. -->
                    <UiDropdownMenuItem
                      variant="destructive"
                      :disabled="Boolean(linkedFrom) || clearCount === 0"
                      @select="area && clearArea(area.key)"
                    >
                      <Icon name="lucide:eraser" />
                      {{ $t('studio.areas.clear') }}<template v-if="clearCount">
                        · {{ clearCount }}
                      </template>
                    </UiDropdownMenuItem>
                  </UiDropdownMenuContent>
                </UiDropdownMenu>
              </div>
              <p
                v-if="linkedFrom && area"
                class="pointer-events-auto flex max-w-md flex-wrap items-center gap-2 rounded-xl border border-primary/30 bg-primary/10 px-3 py-2 text-xs text-foreground shadow-sm"
              >
                <Icon
                  name="lucide:link-2"
                  class="text-sm"
                />
                {{ $t('studio.areas.linkedWith', { name: linkedFrom.name }) }}
                <UiButton
                  variant="link"
                  size="xs"
                  class="h-auto p-0"
                  @click="selectedArea = linkedFrom.key"
                >
                  {{ $t('studio.areas.editSource') }}
                </UiButton>
                <UiButton
                  variant="link"
                  size="xs"
                  class="h-auto p-0"
                  @click="setSync(linkedFrom.key, syncTargets(doc, linkedFrom.key).filter(k => k !== area!.key))"
                >
                  {{ $t('studio.areas.unsync') }}
                </UiButton>
              </p>
              <p
                v-if="notice"
                class="pointer-events-auto flex max-w-md items-start gap-2 rounded-xl border border-sky-200 bg-sky-50 py-1.5 pl-3 pr-1.5 text-xs text-sky-900 shadow-sm"
              >
                <span class="py-1">{{ notice }}</span>
                <UiButton
                  variant="ghost"
                  size="icon-xs"
                  :aria-label="$t('studio.common.close')"
                  @click="notice = null"
                >
                  <Icon name="lucide:x" />
                </UiButton>
              </p>
              <p
                v-if="actionError"
                class="pointer-events-auto flex max-w-md items-start gap-2 rounded-xl border border-destructive/30 bg-rose-50 py-1.5 pl-3 pr-1.5 text-xs text-destructive shadow-sm"
              >
                <span class="py-1">{{ actionError }}</span>
                <UiButton
                  variant="ghost"
                  size="icon-xs"
                  :aria-label="$t('studio.common.close')"
                  @click="actionError = null"
                >
                  <Icon name="lucide:x" />
                </UiButton>
              </p>

            </div>

            <!-- Top right, stacked so they cover less of the design: the pictures,
                 reset, full screen (the flat / 3D
                 toggle sits in the bottom right corner). -->
            <div class="absolute right-3 top-3 z-20 flex flex-col gap-2">
              <UiButton
                variant="outline"
                size="icon"
                :class="stageBtn"
                :disabled="shooting"
                :title="$t('studio.shots.title')"
                :aria-label="$t('studio.shots.title')"
                @click="openShots()"
              >
                <Icon
                  :name="shooting ? 'lucide:loader-circle' : 'lucide:camera'"
                  class="text-xl"
                  :class="shooting ? 'animate-spin' : ''"
                />
              </UiButton>
              <UiButton
                v-if="!flat"
                variant="outline"
                size="icon"
                :class="stageBtn"
                :title="$t('studio.stage.resetView')"
                :aria-label="$t('studio.stage.resetView')"
                @click="previewRef?.resetView()"
              >
                <Icon
                  name="lucide:rotate-cw"
                  class="text-xl"
                />
              </UiButton>
              <UiButton
                variant="outline"
                size="icon"
                :class="stageBtn"
                :title="view3d ? $t('studio.stage.exitFullscreen') : $t('studio.stage.fullscreen')"
                :aria-label="view3d ? $t('studio.stage.exitFullscreen') : $t('studio.stage.fullscreen')"
                :aria-pressed="view3d"
                @click="view3d = !view3d"
              >
                <Icon
                  :name="view3d ? 'lucide:minimize-2' : 'lucide:maximize-2'"
                  class="text-xl"
                />
              </UiButton>
            </div>

            <!-- Bottom right: the flat / 3D toggle, on its own. -->
            <div class="absolute bottom-3 right-3 z-20">
              <UiButton
                variant="outline"
                size="icon"
                :class="[stageBtn, flat ? '' : 'text-primary']"
                :title="flat ? $t('studio.stage.view3d') : $t('studio.stage.flat')"
                :aria-label="flat ? $t('studio.stage.view3d') : $t('studio.stage.flat')"
                :aria-pressed="!flat"
                @click="flat = !flat"
              >
                <Icon
                  :name="flat ? 'lucide:box' : 'lucide:square'"
                  class="text-xl"
                />
              </UiButton>
            </div>
          </div>

          <!-- The selected element's quick actions, floating under the press. -->
          <div
            v-if="layer && layer.area === selectedArea && !linkedFrom && !pressing"
            class="fixed z-40 flex w-fit max-w-[calc(100vw-1rem)] -translate-x-1/2 items-center gap-0.5 overflow-x-auto rounded-full border border-border bg-card p-1 shadow-lg"
            :style="toolbarStyle"
            role="toolbar"
            :aria-label="$t('studio.stage.element')"
          >
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :title="$t('studio.stage.adjust')"
              :aria-label="$t('studio.stage.adjust')"
              @click="tool = 'options'"
            >
              <Icon name="lucide:sliders-horizontal" />
            </UiButton>
            <UiButton
              v-if="!layer.dial"
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :title="$t('studio.layer.duplicate')"
              :aria-label="$t('studio.layer.duplicate')"
              @click="duplicate(layer.id)"
            >
              <Icon name="lucide:copy" />
            </UiButton>
            <span class="mx-0.5 h-5 w-px shrink-0 bg-border" />
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :title="$t('studio.stage.centerX')"
              :aria-label="$t('studio.stage.centerX')"
              :disabled="isLocked(layer)"
              @click="centerLayer('x')"
            >
              <Icon name="lucide:align-center-vertical" />
            </UiButton>
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :title="$t('studio.stage.centerY')"
              :aria-label="$t('studio.stage.centerY')"
              :disabled="isLocked(layer)"
              @click="centerLayer('y')"
            >
              <Icon name="lucide:align-center-horizontal" />
            </UiButton>
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :title="$t('studio.stage.bringForward')"
              :aria-label="$t('studio.stage.bringForward')"
              :disabled="!canMove(layer.id, 1)"
              @click="moveLayer(layer.id, 1)"
            >
              <Icon name="lucide:bring-to-front" />
            </UiButton>
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :title="$t('studio.stage.sendBackward')"
              :aria-label="$t('studio.stage.sendBackward')"
              :disabled="!canMove(layer.id, -1)"
              @click="moveLayer(layer.id, -1)"
            >
              <Icon name="lucide:send-to-back" />
            </UiButton>
            <span class="mx-0.5 h-5 w-px shrink-0 bg-border" />
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full"
              :class="isLocked(layer) ? 'text-primary' : ''"
              :disabled="layer.locked === 'system' || isBackgroundLayer(layer)"
              :title="layer.locked === 'system' || isBackgroundLayer(layer) ? $t('studio.layer.lockedInPlace') : layer.locked ? $t('studio.layer.unlock') : $t('studio.layer.lock')"
              :aria-label="isLocked(layer) ? $t('studio.layer.unlock') : $t('studio.layer.lock')"
              :aria-pressed="isLocked(layer)"
              @click="setLocked(layer.id, !layer.locked)"
            >
              <Icon :name="isLocked(layer) ? 'lucide:lock' : 'lucide:lock-open'" />
            </UiButton>
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="rounded-full text-destructive hover:bg-destructive/10 hover:text-destructive"
              :title="$t('studio.layer.delete')"
              :aria-label="$t('studio.layer.delete')"
              @click="removeLayer(layer.id)"
            >
              <Icon name="lucide:trash-2" />
            </UiButton>
          </div>

          <!-- The product's types: one row, scrolled sideways. -->
          <section
            v-if="product.variants.length > 1"
            aria-labelledby="other-types"
          >
            <h2
              id="other-types"
              class="mb-2 px-1 text-[13px] font-semibold text-foreground"
            >
              {{ $t('studio.variants.title') }}
            </h2>
            <!-- Sideways only: the row is as tall as its longest name. -->
            <div class="scrollbar-none -mx-1 flex snap-x snap-mandatory items-start gap-2.5 overflow-x-auto overflow-y-hidden scroll-px-1 p-1">
              <UiButton
                v-for="v in product.variants"
                :key="v.id"
                variant="ghost"
                class="group h-auto w-24 shrink-0 snap-start flex-col items-stretch justify-start gap-1.5 self-start p-0 hover:bg-transparent sm:w-28"
                :title="v.name"
                :aria-pressed="v.id === variantId"
                @click="v.id !== variantId && chooseVariant(v.id, null)"
              >
                <span
                  class="relative block aspect-square overflow-hidden rounded-xl border-2 bg-white transition"
                  :class="v.id === variantId ? 'border-primary' : 'border-border/70 group-hover:border-slate-300'"
                >
                  <img
                    v-if="variantPhoto(v)"
                    :src="variantPhoto(v)!"
                    :alt="v.name"
                    loading="lazy"
                    class="h-full w-full object-cover"
                  >
                  <span
                    v-else
                    class="block h-full w-full"
                    :style="{ background: v.colors[0]?.hex ?? '#eee' }"
                  />
                  <span
                    v-if="v.id === variantId"
                    class="absolute right-1.5 top-1.5 flex size-5 items-center justify-center rounded-full bg-primary text-xs text-primary-foreground"
                  >
                    <Icon name="lucide:check" />
                  </span>
                </span>
                <span
                  class="whitespace-normal break-words text-center text-xs leading-tight"
                  :class="v.id === variantId ? 'font-semibold text-primary' : 'font-medium text-foreground'"
                >{{ v.name }}</span>
              </UiButton>
            </div>
          </section>

          <StudioSidebar
            v-model:quantity="quantity"
            @add-to-cart="onAddToCart"
          />
        </main>
      </div>

      <Transition
        enter-active-class="transition duration-200"
        enter-from-class="translate-y-2 opacity-0"
        leave-active-class="transition duration-150"
        leave-to-class="opacity-0"
      >
        <p
          v-if="toast"
          class="fixed bottom-20 left-1/2 z-50 -translate-x-1/2 rounded-full bg-slate-900 px-4 py-2 text-xs font-semibold text-white shadow-lg lg:bottom-6"
          role="status"
        >
          {{ toast }}
        </p>
      </Transition>

      <!-- "Rasmga olish": the five-view set, or the stage as it stands. -->
      <UiDialog
        :open="shotOpen"
        @update:open="(open: boolean) => shotOpen = open"
      >
        <UiDialogContent class="sm:max-w-2xl">
          <UiDialogHeader>
            <UiDialogTitle>{{ $t('studio.shots.title') }}</UiDialogTitle>
          </UiDialogHeader>
          <div class="grid gap-3 sm:grid-cols-2">
            <button
              type="button"
              class="group flex cursor-pointer flex-col gap-3 rounded-xl border border-border bg-card p-3 text-left transition hover:border-primary/60 hover:bg-muted/40 disabled:cursor-default disabled:opacity-60"
              :disabled="shooting"
              @click="downloadShots()"
            >
              <div class="grid aspect-[4/3] grid-cols-2 grid-rows-2 gap-1 overflow-hidden rounded-lg bg-[#e9ebef] p-1">
                <template v-if="shotPreviews.set.length">
                  <img
                    v-for="(src, i) in shotPreviews.set.slice(0, 4)"
                    :key="i"
                    :src="src"
                    alt=""
                    class="h-full w-full rounded object-cover"
                  >
                </template>
                <template v-else>
                  <UiSkeleton
                    v-for="n in 4"
                    :key="`s${n}`"
                    class="h-full w-full rounded"
                  />
                </template>
              </div>
              <div class="flex items-center gap-2">
                <Icon
                  name="lucide:images"
                  class="text-lg text-primary"
                />
                <span class="text-sm font-semibold text-foreground">{{ $t('studio.shots.set') }}</span>
                <span class="ml-auto text-xs text-muted-foreground">ZIP</span>
              </div>
            </button>

            <button
              type="button"
              class="group flex cursor-pointer flex-col gap-3 rounded-xl border border-border bg-card p-3 text-left transition hover:border-primary/60 hover:bg-muted/40 disabled:cursor-default disabled:opacity-60"
              :disabled="shooting"
              @click="downloadView()"
            >
              <div class="aspect-[4/3] overflow-hidden rounded-lg bg-[#e9ebef] p-1">
                <img
                  v-if="shotPreviews.view"
                  :src="shotPreviews.view"
                  alt=""
                  class="h-full w-full object-contain"
                >
                <UiSkeleton
                  v-else
                  class="h-full w-full rounded"
                />
              </div>
              <div class="flex items-center gap-2">
                <Icon
                  name="lucide:image"
                  class="text-lg text-primary"
                />
                <span class="text-sm font-semibold text-foreground">{{ $t('studio.shots.current') }}</span>
                <span class="ml-auto text-xs text-muted-foreground">PNG</span>
              </div>
            </button>
          </div>
          <p
            v-if="shooting"
            class="flex items-center gap-2 text-xs text-muted-foreground"
          >
            <Icon
              name="lucide:loader-circle"
              class="animate-spin text-base"
            />
            {{ $t('studio.common.preparing') }}
          </p>
        </UiDialogContent>
      </UiDialog>

      <StudioSyncDialog
        v-model:open="syncOpen"
        :source="area"
        :options="syncOptions"
        :selected="syncedTo"
        @save="(targets: string[]) => area && setSync(area.key, targets)"
      />

      <StudioTemplateSave
        v-if="templateMode"
        v-model:open="templateSaveOpen"
        :editing="editingTemplate"
        :variants="product.variants"
        :variant-id="variantId"
        :busy="templateBusy"
        :error="templateError"
        @save="saveTemplate"
      />

      <UiDialog
        :open="doneDialog !== null"
        @update:open="(open: boolean) => { if (!open) doneDialog = null; }"
      >
        <UiDialogContent class="sm:max-w-md">
          <UiDialogHeader class="items-center text-center">
            <span class="mb-1 flex size-12 items-center justify-center rounded-full bg-emerald-50 text-2xl text-emerald-600">
              <Icon :name="doneDialog === 'cart' ? 'lucide:shopping-cart' : 'lucide:check'" />
            </span>
            <UiDialogTitle>
              {{ doneDialog === 'cart' ? $t('studio.done.added') : $t('studio.done.saved') }}
            </UiDialogTitle>
          </UiDialogHeader>
          <UiDialogFooter class="gap-2 sm:justify-center">
            <UiButton
              variant="outline"
              @click="doneDialog = null"
            >
              <Icon name="lucide:arrow-left" />
              {{ $t('studio.done.back') }}
            </UiButton>
            <UiButton
              v-if="doneDialog === 'cart'"
              as-child
            >
              <NuxtLink :to="localePath('/user/cart')">
                <Icon name="lucide:shopping-cart" />
                {{ $t('studio.done.toCart') }}
              </NuxtLink>
            </UiButton>
            <UiButton
              v-else
              :disabled="placedCount === 0"
              @click="addFromDialog"
            >
              <Icon name="lucide:shopping-cart" />
              {{ $t('studio.cart.add') }}
            </UiButton>
          </UiDialogFooter>
        </UiDialogContent>
      </UiDialog>

      <UiDialog
        :open="Boolean(pendingVariant)"
        @update:open="(open: boolean) => { if (!open) pendingVariant = null; }"
      >
        <UiDialogContent class="sm:max-w-md">
          <UiDialogHeader>
            <UiDialogTitle>{{ $t('studio.variants.switchTitle') }}</UiDialogTitle>
          </UiDialogHeader>
          <p class="text-sm text-muted-foreground">
            {{ $t('studio.variants.switchText', pendingVariant?.lost ?? 0) }}
            {{ $t('studio.variants.switchUndo') }}
          </p>
          <UiDialogFooter>
            <UiButton
              variant="outline"
              @click="pendingVariant = null"
            >
              {{ $t('studio.common.cancel') }}
            </UiButton>
            <UiButton @click="confirmVariant">
              {{ $t('studio.variants.switch') }}
            </UiButton>
          </UiDialogFooter>
        </UiDialogContent>
      </UiDialog>
    </template>
  </div>
</template>
