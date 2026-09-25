<script setup lang="ts">
// The product in 3D with the design on it, and the place the design is
// edited: each area is re-rendered into its own canvas (same renderer as the
// print files) and shown as a texture on the product's surface. With
// `editable`, pressing on an area selects it and the layer under the
// pointer; dragging moves the layer across the surface, its corners resize
// it, the knob or just outside a corner rotates it, all with the same snap
// guides as the flat editor (lib/design/gestures.ts). Dragging anywhere else
// turns the product. The frame, handles and zones drawn while editing are
// removed before any mockup or picture is taken (flush / captureFrames).
import type { Layer, StripPosition } from '~/lib/design/document';
import type { Drag, Point } from '~/lib/design/gestures';
import { isLocked } from '~/lib/design/document';
import { dragTo, handleAt, hitLayer, nudge, startDrag } from '~/lib/design/gestures';
import { drawOverlay } from '~/lib/design/overlay';
import type { GapMark, Guide } from '~/lib/design/snap';
import type { StudioScene } from '~/lib/three/studioScene';
import type { CatalogMethod, Material, PublicShape } from '~/types/catalog';
import * as renderModule from '~/lib/design/render';

const { t } = useI18n();
const props = defineProps<{
  shape: PublicShape;
  material: Material;
  colorHex: string;
  layers: Layer[];
  strips: StripPosition[] | undefined; // the document's
  selectedArea: string | null;
  // Editing on the surface (all optional: without them it only shows).
  editable?: boolean;
  selectedId?: string | null;
  methods?: CatalogMethod[];
  problems?: Record<string, string[]>;
  lockedArea?: string | null; // a synced area: shown, not edited
  whiteUnderbase?: boolean;
}>();
const emit = defineEmits<{
  surface: [colors: Record<string, string>]; // the colour under each area (StudioScene.surfaceColors)
  selectArea: [key: string];
  select: [id: string | null];
  begin: [];
  patch: [id: string, patch: Partial<Layer>];
  remove: [id: string];
  editText: [id: string];
  zoom: [percent: number]; // 100 = the product framed
}>();

const wrapRef = ref<HTMLDivElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);
const state = ref<'loading' | 'ready' | 'error'>('loading');
const error = ref<string | null>(null);
let scene: StudioScene | null = null;
const render = renderModule;
let tints: typeof import('~/lib/three/materials').ENGRAVE_TINT | null = null;
let observer: ResizeObserver | null = null;
const canvases = new Map<string, HTMLCanvasElement>();
// Until the customer turns the model, it is re-framed whenever the view
// changes size or another area is chosen.
const turned = ref(false);

function frame() {
  turned.value = false;
  if (props.selectedArea) scene?.viewArea(props.selectedArea);
}
// The loader stays until the model has been drawn once (not just loaded).
const drawn = ref(false);
const drawnOnce = ref(false);
let builds = 0;
async function buildShape() {
  if (!scene) return;
  const build = ++builds;
  drawn.value = false;
  state.value = 'loading';
  error.value = null;
  try {
    const current = await scene.setShape(props.shape, props.material, props.colorHex);
    if (!current) return;
    if (props.whiteUnderbase !== undefined) scene.setWhiteUnderbase(props.whiteUnderbase);
  }
  catch (err) {
    state.value = 'error';
    error.value = t('studio.preview.loadFailed', { reason: err instanceof Error ? err.message : String(err) });
    return;
  }
  canvases.clear();
  state.value = 'ready';
  emit('surface', scene.surfaceColors());
  await paintAll();
  frame();
  await scene?.viewer.nextFrame();
  if (build === builds) drawn.value = drawnOnce.value = true;
}

/** Runs `take` with the design painted alone (no frame or handles). */
async function withCleanPaint<T>(take: () => T): Promise<T> {
  cleanHolds++;
  let result: T;
  try {
    await paintAll();
    stale = false;
    result = take();
  }
  finally {
    cleanHolds--;
  }
  if (props.editable && !cleanHolds) await paintAll(); // the frame and handles come back
  return result;
}
// ── Editing state drawn over the design ──
const guides = ref<Guide[]>([]);
const gaps = ref<GapMark[]>([]);
const badge = ref<{ x: number; y: number; text: string } | null>(null);
// The design alone (no frame, handles or zones) while a picture is taken:
// every taker holds it (pictures may overlap), and flush() holds it until
// the cart's mockups are taken.
let cleanHolds = 0;
let flushed = false;
const isEditing = () => Boolean(props.editable) && cleanHolds === 0 && !flushed;
// An area chosen by pressing on it in 3D is already in view: no re-framing.
let pickedArea: string | null = null;
const areaByKey = (key: string) => props.shape.areas.find(a => a.key === key) ?? null;
const areaLayers = (key: string) => props.layers.filter(l => l.area === key);
/** Handles 8 screen pixels wide at the current view, whatever the size
 * of the element. */
const HANDLE_PX = 8;
function handleMm(key: string): number {
  const px = scene?.screenPxPerMm(key);
  const area = areaByKey(key);
  const fallback = area ? Math.max(Number(area.width_mm), Number(area.height_mm)) * 0.02 : 3;
  return Math.min(12, Math.max(1, px ? HANDLE_PX / px : fallback));
}

let paintTimer: ReturnType<typeof setTimeout> | null = null;
// While the flat editor covers the view, the product's textures aren't
// redrawn on every change — only once it shows again (or for its pictures).
let stale = false;
function schedulePaint() {
  if (paintTimer) clearTimeout(paintTimer);
  if (!props.editable) {
    stale = true;
    return;
  }
  paintTimer = setTimeout(() => void paintAll(), 90);
}
watch(() => props.editable, (on) => {
  if (on && stale) {
    stale = false;
    void paintAll();
  }
});

// The latest paint of each area: an older one still loading its assets
// leaves the texture to it (and waits for it), so a slow paint never lands
// over a newer one.
const paintSeq = new Map<string, number>();
const latestPaint = new Map<string, Promise<void>>();

function paintArea(key: string): Promise<void> {
  const seq = (paintSeq.get(key) ?? 0) + 1;
  paintSeq.set(key, seq);
  const run = paintAreaNow(key, seq);
  latestPaint.set(key, run);
  return run;
}

async function paintAreaNow(key: string, seq: number): Promise<void> {
  const area = areaByKey(key);
  if (!scene || !render || !area || state.value !== 'ready') return;
  // The design and its strips as they are now: the texture and the zones
  // drawn over it always show the same document.
  const layers = props.layers;
  const strips = props.strips;
  await render.prepareAssets(layers.filter(l => l.area === key));
  if (paintSeq.get(key) !== seq) return latestPaint.get(key);
  if (!scene || state.value !== 'ready') return;
  const w = Number(area.width_mm);
  let canvas = canvases.get(area.key);
  if (!canvas) {
    canvas = render.previewCanvas(area);
    canvases.set(area.key, canvas);
  }
  const ctx = render.paintPreviewNow(canvas, area, layers, tints![props.material], strips);
  if (isEditing() && area.key === props.selectedArea) {
    drawOverlay(ctx, area, layers, {
      strips,
      selectedId: props.selectedId ?? null, methods: props.methods ?? area.methods.map(m => m.method),
      problems: props.problems ?? {}, guides: guides.value, gaps: gaps.value, handle: handleMm(area.key),
      readonly: area.key === props.lockedArea,
    }, canvas.width / w);
  }
  scene.setAreaTexture(area.key, canvas);
}

// Paints run one after another, so a picture never catches half of an
// earlier paint with the editing marks.
let painting: Promise<void> = Promise.resolve();
function paintAll(): Promise<void> {
  painting = painting.then(paintAllNow, paintAllNow);
  return painting;
}
async function paintAllNow() {
  if (!scene || !render || state.value !== 'ready') return;
  await render.prepareAssets(props.layers);
  for (const area of props.shape.areas) await paintArea(area.key);
}

// While dragging, the dragged area is repainted every frame instead.
let dragFrame = 0;
function paintNow(key: string) {
  cancelAnimationFrame(dragFrame);
  dragFrame = requestAnimationFrame(() => void paintArea(key));
}

// ── Pointer ──
let drag: (Drag & { area: string }) | null = null;
const SNAP_PX = 7;
const cursor = ref('grab');

function pick(event: PointerEvent | MouseEvent, only?: string): (Point & { key: string }) | null {
  return scene?.pickArea(event.clientX, event.clientY, only) ?? null;
}

/** Takes the press when it lands on an area; otherwise the product turns. */
function onPointerDown(event: PointerEvent) {
  if (!props.editable || event.button !== 0 || !scene || state.value !== 'ready' || event.target !== canvasRef.value) return;
  const hit = pick(event);
  // Beside the product, or on a part of it nothing is printed on: the
  // press belongs to no element, so nothing stays selected.
  if (!hit) {
    emit('select', null);
    return;
  }
  if (hit.key !== props.selectedArea) {
    pickedArea = hit.key;
    emit('selectArea', hit.key);
  }
  if (hit.key === props.lockedArea) return;
  const own = areaLayers(hit.key);
  const current = own.find(l => l.id === props.selectedId) ?? null;
  const handle = current && !isLocked(current) ? handleAt(current, hit, handleMm(hit.key)) : null;
  const layer = handle ? current : hitLayer(own, hit);
  if (!layer) {
    emit('select', null);
    return; // empty surface: turn the product
  }
  if (isLocked(layer)) {
    emit('select', layer.id); // its settings open; dragging still turns the product
    return;
  }
  emit('select', layer.id); // also when already selected: its settings open
  drag = { ...startDrag(handle ?? 'move', layer, hit), area: hit.key };
  emit('begin');
  event.stopPropagation(); // keep the orbit controls out of it
  event.preventDefault();
  scene.setTurning(false);
  wrapRef.value?.setPointerCapture(event.pointerId);
  wrapRef.value?.focus({ preventScroll: true });
}

function onPointerMove(event: PointerEvent) {
  if (!scene || !props.editable) return;
  if (!drag) {
    hover(event);
    return;
  }
  const area = areaByKey(drag.area);
  const p = pick(event, drag.area);
  if (!area || !p) return;
  const px = scene.screenPxPerMm(drag.area) ?? 4;
  const result = dragTo(drag, p, {
    area, layers: areaLayers(drag.area), strips: props.strips, threshold: SNAP_PX / px,
    snapping: !event.ctrlKey && !event.metaKey, fineAngle: event.shiftKey,
  });
  emit('patch', drag.id, result.patch);
  guides.value = result.guides;
  gaps.value = result.gaps;
  const rect = wrapRef.value!.getBoundingClientRect();
  badge.value = result.badge ? { x: event.clientX - rect.left, y: event.clientY - rect.top, text: result.badge } : null;
  paintNow(drag.area);
}

function onPointerUp(event: PointerEvent) {
  if (!drag) return;
  const key = drag.area;
  drag = null;
  guides.value = [];
  gaps.value = [];
  badge.value = null;
  scene?.setTurning(true);
  wrapRef.value?.releasePointerCapture(event.pointerId);
  paintNow(key);
}

// The cursor says what a press would do (throttled to a frame).
let hoverFrame = 0;
function hover(event: PointerEvent) {
  if (event.pointerType !== 'mouse') return;
  cancelAnimationFrame(hoverFrame);
  hoverFrame = requestAnimationFrame(() => {
    const hit = pick(event);
    if (!hit || hit.key === props.lockedArea) {
      cursor.value = 'grab';
      return;
    }
    const own = areaLayers(hit.key);
    const current = own.find(l => l.id === props.selectedId && !isLocked(l));
    const handle = current && hit.key === props.selectedArea ? handleAt(current, hit, handleMm(hit.key)) : null;
    const under = hitLayer(own, hit);
    cursor.value = handle === 'scale' ? 'nwse-resize' : handle === 'rotate' ? 'alias' : under && !isLocked(under) ? 'move' : 'pointer';
  });
}

function onDoubleClick(event: MouseEvent) {
  if (!props.editable) return;
  const hit = pick(event);
  if (!hit || hit.key === props.lockedArea) return;
  const layer = hitLayer(areaLayers(hit.key), hit);
  if (layer?.text) emit('editText', layer.id);
}

function onKey(event: KeyboardEvent) {
  if (!props.editable || !props.selectedArea || props.selectedArea === props.lockedArea) return;
  const area = areaByKey(props.selectedArea);
  const layer = props.layers.find(l => l.id === props.selectedId && l.area === props.selectedArea);
  if (!area || !layer) return;
  if (event.key === 'Delete' || event.key === 'Backspace') {
    event.preventDefault();
    emit('remove', layer.id);
    return;
  }
  const patch = nudge(area, layer, event.key, event.shiftKey, areaLayers(area.key));
  if (!patch) return;
  event.preventDefault();
  emit('begin');
  emit('patch', layer.id, patch);
}

onMounted(async () => {
  const [studio, materials] = await Promise.all([
    import('~/lib/three/studioScene'), import('~/lib/three/materials'),
  ]);
  if (!canvasRef.value || !wrapRef.value) return;
  tints = materials.ENGRAVE_TINT;
  scene = new studio.StudioScene(canvasRef.value);
  scene.onUserTurn(() => (turned.value = true));
  scene.onViewChange(() => {
    if (scene?.baseDistance) emit('zoom', Math.round((scene.baseDistance / Math.max(scene.viewDistance(), 1e-6)) * 100));
  });
  observer = new ResizeObserver(() => {
    const rect = wrapRef.value!.getBoundingClientRect();
    scene?.viewer.resize(rect.width, rect.height, () => {
      if (!turned.value && state.value === 'ready') frame();
    });
  });
  observer.observe(wrapRef.value);
  await buildShape();
});

onBeforeUnmount(() => {
  observer?.disconnect();
  if (paintTimer) clearTimeout(paintTimer);
  cancelAnimationFrame(dragFrame);
  cancelAnimationFrame(hoverFrame);
  scene?.dispose();
  scene = null;
});

watch(() => props.shape, () => void buildShape());
watch(() => props.whiteUnderbase, (val) => {
  if (scene && val !== undefined) {
    scene.setWhiteUnderbase(val);
    schedulePaint();
  }
});
watch(() => [props.material, props.colorHex] as const, ([material, hex]) => {
  scene?.setAppearance(material, hex);
  if (scene) emit('surface', scene.surfaceColors());
  schedulePaint(); // engraving tint depends on the material
});
watch(() => [props.layers, props.strips], () => {
  if (!drag) schedulePaint();
});
watch(() => [props.selectedId, props.editable, props.problems, props.lockedArea], schedulePaint);
watch(() => props.selectedArea, (key) => {
  if (key !== pickedArea) frame();
  pickedArea = null;
  schedulePaint();
});

defineExpose({
  /** The cart's mockups: five views of the product, the first straight at
   * the used areas (JPEG data URLs, 900 px unless `size` says otherwise),
   * drawn with the latest layers and no editing marks — call flush()
   * first; the marks come back right after. */
  captureFrames(areas: string[], size?: number): string[] {
    const frames = scene?.captureFrames(areas, size) ?? [];
    flushed = false;
    schedulePaint();
    return frames;
  },
  /** The gallery's pictures: the same views as captureFrames, but each one
   * fitted and cut out (transparent PNGs), so they sit on any background
   * instead of on the editor's grey backdrop. */
  async captureCutouts(areas: string[], size = 1600, margin = 160): Promise<string[]> {
    if (!scene || state.value !== 'ready') return [];
    if (paintTimer) clearTimeout(paintTimer);
    return withCleanPaint(() => scene!.captureFittedFrames(areas, size, margin));
  },
  /** The product as it is seen now, centred in a square picture, without
   * editing marks — same grey backdrop as the multi-view set. */
  async captureView(): Promise<string | null> {
    if (!scene || state.value !== 'ready') return null;
    if (paintTimer) clearTimeout(paintTimer);
    // A tenth of the picture free on each side.
    return withCleanPaint(() => scene!.captureFitted(1600, 160, { transparent: false }));
  },
  /** Back to the chosen area's framing. */
  resetView() {
    frame();
  },
  zoomBy(factor: number) {
    scene?.viewer.zoomBy(factor);
  },
  /** Paints the latest layers now, without editing marks (a mockup follows). */
  async flush() {
    if (paintTimer) clearTimeout(paintTimer);
    flushed = true;
    await paintAll();
  },
});
</script>

<template>
  <div
    ref="wrapRef"
    class="relative h-full w-full overflow-hidden rounded-2xl bg-[#e9ebef] outline-none"
    :tabindex="editable ? 0 : undefined"
    :aria-label="editable ? $t('studio.preview.editor') : undefined"
    @pointerdown.capture="onPointerDown"
    @pointermove="onPointerMove"
    @pointerup="onPointerUp"
    @pointercancel="onPointerUp"
    @dblclick="onDoubleClick"
    @keydown="onKey"
  >
    <canvas
      ref="canvasRef"
      class="absolute inset-0 h-full w-full touch-none"
      :style="{ cursor: editable ? cursor : 'grab' }"
      :aria-label="$t('studio.preview.view3d')"
    />
    <StageLoader
      :show="state !== 'error' && !drawn"
      :text="$t('studio.preview.loading')"
      :immediate="!drawnOnce"
    />
    <div
      v-if="state === 'error'"
      class="absolute inset-0 grid place-items-center p-6 text-center text-xs text-rose-700"
    >
      {{ error }}
    </div>
    <span
      v-if="badge"
      class="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-[160%] whitespace-nowrap rounded-lg bg-slate-900 px-2 py-1 text-[12px] font-bold tabular-nums text-white shadow-lg"
      :style="{ left: `${badge.x}px`, top: `${badge.y}px` }"
      role="status"
    >{{ badge.text }}</span>
  </div>
</template>
