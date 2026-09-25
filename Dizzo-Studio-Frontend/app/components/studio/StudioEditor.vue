<script lang="ts">
/** CSS px left round the area on every side (the Studio sizes its stage with it). */
export const FLAT_PAD = 16;
</script>

<script setup lang="ts">
// Flat editor of one print area. The canvas shows the area in the
// product's colour with the layers drawn by the same renderer as the print
// files; an SVG overlay in millimetres carries the zones, the selection and
// the handles. Moving and resizing keep a layer inside its method's zone.
// The area always fits the view (no zoom).
// Dragging snaps like Figma (lib/design/snap.ts): pink guides to the zone,
// the centre and other layers, equal gaps; Ctrl (⌘) held turns it off.
// Corners resize; just outside a corner (or the top knob) rotates, with the
// angle shown and a short hold at every 45°.
import * as renderModule from '~/lib/design/render';
import type { Layer, StripPosition } from '~/lib/design/document';
import { isLocked, printZone, zoneBox } from '~/lib/design/document';
import { faceOf } from '~/lib/design/dial';
import type { Drag } from '~/lib/design/gestures';
import { cornersOf, dragTo, hitLayer, nudge, rotateSpots, startDrag } from '~/lib/design/gestures';
import type { GapMark, Guide } from '~/lib/design/snap';
import type { CatalogMethod, PrintArea } from '~/types/catalog';

const props = defineProps<{
  area: PrintArea;
  layers: Layer[];
  strips: StripPosition[] | undefined; // the document's
  selectedId: string | null;
  methods: CatalogMethod[];
  colorHex: string;
  engraveTint: string;
  problems: Record<string, string[]>;
  // A synced area shows its source's layers but can't be edited.
  readonly?: boolean;
}>();
const emit = defineEmits<{
  select: [id: string | null];
  begin: [];
  patch: [id: string, patch: Partial<Layer>];
  remove: [id: string];
  editText: [id: string];
}>();

const wrapRef = ref<HTMLDivElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);
const svgRef = ref<SVGSVGElement | null>(null);
const s = ref(1); // CSS pixels per mm
const PAD = FLAT_PAD;
const areaW = computed(() => Number(props.area.width_mm));
const areaH = computed(() => Number(props.area.height_mm));
const own = computed(() => props.layers.filter(l => l.area === props.area.key));
const selected = computed(() => own.value.find(l => l.id === props.selectedId) ?? null);
// A zone with a strip shows faintly (where the strip may travel), the strip
// itself as a zone — from the same document the canvas is drawn from.
const zones = computed(() => props.area.methods
  .filter(m => props.methods.includes(m.method))
  .flatMap((m) => {
    const zone = { key: m.method, method: m.method, box: zoneBox(m), faint: false };
    if (!m.strip_width_mm) return [zone];
    return [{ ...zone, key: `${m.method}-zone`, faint: true }, { ...zone, box: printZone(props.area, m, own.value, props.strips) }];
  }));
const handle = computed(() => 7 / s.value); // handle size in mm (7 CSS px)
// A round face (a clock's dial) or rounded corners: the area is shown that shape.
const faceRadius = computed(() => {
  const f = faceOf(props.area);
  return f.face === 'round' ? '50%' : `${f.corner_radius_mm * s.value}px`;
});

// ── Drawing ──
const render = renderModule;
let drawToken = 0;
let frame = 0;

function scheduleDraw() {
  cancelAnimationFrame(frame);
  frame = requestAnimationFrame(() => void draw());
}

async function draw() {
  const canvas = canvasRef.value;
  if (!canvas || !render) return;
  const token = ++drawToken;
  const layers = own.value;
  const strips = props.strips;
  await render.prepareAssets(layers);
  if (token !== drawToken) return; // a newer draw started meanwhile
  // From here on at once: the canvas never shows half a paint.
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const width = Math.round(areaW.value * s.value * dpr);
  const height = Math.round(areaH.value * s.value * dpr);
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
  }
  const ctx = canvas.getContext('2d')!;
  ctx.fillStyle = props.colorHex;
  ctx.fillRect(0, 0, width, height);
  // 10 mm grid, faint, for orientation.
  const px = s.value * dpr;
  ctx.strokeStyle = 'rgba(100, 116, 139, 0.14)';
  ctx.lineWidth = 1;
  for (let x = 10; x < areaW.value; x += 10) {
    ctx.beginPath();
    ctx.moveTo(x * px, 0);
    ctx.lineTo(x * px, height);
    ctx.stroke();
  }
  for (let y = 10; y < areaH.value; y += 10) {
    ctx.beginPath();
    ctx.moveTo(0, y * px);
    ctx.lineTo(width, y * px);
    ctx.stroke();
  }
  render.drawAreaNow(ctx, props.area, layers, { s: px, strips, tints: { engrave: props.engraveTint }, ghost: 0.28 });
}

let observer: ResizeObserver | null = null;
function fit() {
  const el = wrapRef.value;
  if (!el) return;
  // Floored a pixel short, so the fitted area never overflows the view.
  const fitS = Math.min((el.clientWidth - 2 * PAD - 1) / areaW.value, (el.clientHeight - 2 * PAD - 1) / areaH.value);
  s.value = Math.max(0.1, fitS);
}

onMounted(() => {
  observer = new ResizeObserver(() => {
    fit();
    scheduleDraw();
  });
  if (wrapRef.value) observer.observe(wrapRef.value);
  fit();
  scheduleDraw();
});
onBeforeUnmount(() => {
  observer?.disconnect();
  cancelAnimationFrame(frame);
});
watch(() => [own.value, props.strips, props.colorHex, props.engraveTint, props.area], () => {
  fit();
  scheduleDraw();
});

// ── Geometry helpers ──
function toMm(event: PointerEvent) {
  const rect = svgRef.value!.getBoundingClientRect();
  return { x: (event.clientX - rect.left) / s.value, y: (event.clientY - rect.top) / s.value };
}

const corners = (layer: Layer) => cornersOf(layer, handle.value);
const polygon = (layer: Layer) => corners(layer).points.map(p => `${p.x},${p.y}`).join(' ');
const ROTATE_ICON = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke-linecap="round" stroke-linejoin="round">'
  + '<path d="M5 13a7 7 0 0 1 12.5-4.3M18.5 4v4.8h-4.8" stroke="#fff" stroke-width="4.5"/>'
  + '<path d="M5 13a7 7 0 0 1 12.5-4.3M18.5 4v4.8h-4.8" stroke="#111827" stroke-width="2"/></svg>';
const ROTATE_CURSOR = `url("data:image/svg+xml,${encodeURIComponent(ROTATE_ICON)}") 12 12, grab`;

// ── Snapping feedback ──
const SNAP_PX = 6; // how close (CSS px) before an edge sticks
const guides = ref<Guide[]>([]);
const gaps = ref<GapMark[]>([]);
// The angle while rotating (above the pointer), the size while resizing.
const badge = ref<{ x: number; y: number; text: string; above: boolean } | null>(null);
const fmt = (mm: number) => (Math.round(mm * 10) / 10).toString();

// ── Interaction (lib/design/gestures.ts does the geometry) ──
let drag: Drag | null = null;

function onPointerDown(event: PointerEvent) {
  if (event.button !== 0 || props.readonly) return;
  const p = toMm(event);
  const target = (event.target as Element).getAttribute('data-handle');
  const current = selected.value;
  if (current && !isLocked(current) && (target === 'rotate' || target === 'scale')) {
    drag = startDrag(target, current, p);
  }
  else {
    const layer = hitLayer(own.value, p);
    emit('select', layer?.id ?? null);
    if (!layer || isLocked(layer)) return;
    drag = startDrag('move', layer, p);
  }
  emit('begin');
  svgRef.value?.setPointerCapture(event.pointerId);
}

function onPointerMove(event: PointerEvent) {
  if (!drag) return;
  const p = toMm(event);
  const snapping = !event.ctrlKey && !event.metaKey;
  const result = dragTo(drag, p, { area: props.area, layers: own.value, strips: props.strips, threshold: SNAP_PX / s.value, snapping, fineAngle: event.shiftKey });
  emit('patch', drag.id, result.patch);
  guides.value = result.guides;
  gaps.value = result.gaps;
  badge.value = result.badge ? { x: p.x * s.value, y: p.y * s.value, text: result.badge, above: drag.kind === 'rotate' } : null;
}

function onPointerUp(event: PointerEvent) {
  if (!drag) return;
  drag = null;
  guides.value = [];
  gaps.value = [];
  badge.value = null;
  svgRef.value?.releasePointerCapture(event.pointerId);
}

/** A press on the grey beside the area belongs to no element: it clears
 * the selection, the same as a press on the area's empty background. */
function onOutsideDown(event: PointerEvent) {
  if (event.button === 0 && !svgRef.value?.contains(event.target as Node)) emit('select', null);
}

function onDoubleClick(event: MouseEvent) {
  if (props.readonly) return;
  const layer = hitLayer(own.value, toMm(event as PointerEvent));
  if (layer?.text) emit('editText', layer.id);
}

function onKey(event: KeyboardEvent) {
  const layer = selected.value;
  if (!layer || props.readonly) return;
  if (event.key === 'Delete' || event.key === 'Backspace') {
    event.preventDefault();
    emit('remove', layer.id);
    return;
  }
  const patch = nudge(props.area, layer, event.key, event.shiftKey, own.value);
  if (!patch) return;
  event.preventDefault();
  emit('begin');
  emit('patch', layer.id, patch);
}
</script>

<template>
  <div
    ref="wrapRef"
    class="relative h-full min-h-0 w-full overflow-hidden outline-none"
    tabindex="0"
    :aria-label="$t('studio.editor.label')"
    @keydown="onKey"
    @pointerdown="onOutsideDown"
  >
    <div
      class="flex min-h-full w-max min-w-full items-center justify-center"
      :style="{ padding: `${PAD}px` }"
    >
      <div
        class="relative shrink-0 shadow-[0_8px_30px_rgba(15,23,42,0.12)] ring-1 ring-slate-300/60"
        :style="{ width: `${areaW * s}px`, height: `${areaH * s}px`, borderRadius: faceRadius }"
      >
        <canvas
          ref="canvasRef"
          class="absolute inset-0 h-full w-full"
          :style="{ borderRadius: faceRadius }"
        />
        <svg
          ref="svgRef"
          class="absolute inset-0 h-full w-full touch-none select-none overflow-visible"
          :viewBox="`0 0 ${areaW} ${areaH}`"
          preserveAspectRatio="none"
          @pointerdown="onPointerDown"
          @pointermove="onPointerMove"
          @pointerup="onPointerUp"
          @pointercancel="onPointerUp"
          @dblclick="onDoubleClick"
        >
          <rect
            v-for="z in zones"
            :key="z.key"
            :x="z.box.x0"
            :y="z.box.y0"
            :width="z.box.x1 - z.box.x0"
            :height="z.box.y1 - z.box.y0"
            fill="none"
            :stroke="z.method === 'uv' ? '#0b7ea3' : '#b7791f'"
            :stroke-opacity="z.faint ? 0.35 : undefined"
            stroke-dasharray="4 3"
            vector-effect="non-scaling-stroke"
            pointer-events="none"
          />
          <polygon
            v-for="l in own"
            :key="l.id"
            :points="polygon(l)"
            :fill="l.id === selectedId && !isLocked(l) ? 'rgba(225, 29, 72, 0.04)' : 'transparent'"
            :stroke="problems[l.id] ? '#e11d48' : l.id === selectedId ? '#e11d48' : 'transparent'"
            :stroke-dasharray="(problems[l.id] && l.id !== selectedId) || isLocked(l) ? '3 2' : undefined"
            stroke-width="1.5"
            vector-effect="non-scaling-stroke"
            :class="readonly ? '' : 'cursor-move'"
          />
          <template v-if="selected && !readonly && !isLocked(selected)">
            <circle
              v-for="(p, i) in rotateSpots(selected, handle)"
              :key="`r${i}`"
              :cx="p.x"
              :cy="p.y"
              :r="handle * 0.95"
              fill="transparent"
              data-handle="rotate"
              :style="{ cursor: ROTATE_CURSOR }"
            >
              <title>{{ $t('studio.editor.rotate') }}</title>
            </circle>
            <line
              :x1="corners(selected).top.x"
              :y1="corners(selected).top.y"
              :x2="corners(selected).rotate.x"
              :y2="corners(selected).rotate.y"
              stroke="#e11d48"
              stroke-width="1.2"
              vector-effect="non-scaling-stroke"
              pointer-events="none"
            />
            <circle
              :cx="corners(selected).rotate.x"
              :cy="corners(selected).rotate.y"
              :r="handle * 0.6"
              fill="#fff"
              stroke="#e11d48"
              stroke-width="1.5"
              vector-effect="non-scaling-stroke"
              data-handle="rotate"
              :style="{ cursor: ROTATE_CURSOR }"
            >
              <title>{{ $t('studio.editor.rotate') }}</title>
            </circle>
            <rect
              v-for="(p, i) in corners(selected).points"
              :key="i"
              :x="p.x - handle / 2"
              :y="p.y - handle / 2"
              :width="handle"
              :height="handle"
              fill="#fff"
              stroke="#e11d48"
              stroke-width="1.5"
              vector-effect="non-scaling-stroke"
              data-handle="scale"
              class="cursor-nwse-resize"
            >
              <title>{{ $t('studio.editor.resize') }}</title>
            </rect>
          </template>
          <g pointer-events="none">
            <line
              v-for="(g, i) in guides"
              :key="`g${i}`"
              :x1="g.axis === 'x' ? g.at : g.from"
              :y1="g.axis === 'x' ? g.from : g.at"
              :x2="g.axis === 'x' ? g.at : g.to"
              :y2="g.axis === 'x' ? g.to : g.at"
              stroke="#ec4899"
              stroke-width="1"
              vector-effect="non-scaling-stroke"
            />
            <g
              v-for="(m, i) in gaps"
              :key="`m${i}`"
              stroke="#ec4899"
              stroke-width="1"
            >
              <line
                :x1="m.axis === 'x' ? m.from : m.at"
                :y1="m.axis === 'x' ? m.at : m.from"
                :x2="m.axis === 'x' ? m.to : m.at"
                :y2="m.axis === 'x' ? m.at : m.to"
                vector-effect="non-scaling-stroke"
              />
              <line
                v-for="end in [m.from, m.to]"
                :key="end"
                :x1="m.axis === 'x' ? end : m.at - handle / 3"
                :y1="m.axis === 'x' ? m.at - handle / 3 : end"
                :x2="m.axis === 'x' ? end : m.at + handle / 3"
                :y2="m.axis === 'x' ? m.at + handle / 3 : end"
                vector-effect="non-scaling-stroke"
              />
            </g>
          </g>
        </svg>
        <span
          v-for="(m, i) in gaps"
          :key="`l${i}`"
          class="pointer-events-none absolute -translate-x-1/2 -translate-y-1/2 rounded bg-pink-500 px-1 py-px text-[10px] font-semibold leading-3 text-white"
          :style="m.axis === 'x'
            ? { left: `${((m.from + m.to) / 2) * s}px`, top: `${m.at * s}px` }
            : { left: `${m.at * s}px`, top: `${((m.from + m.to) / 2) * s}px` }"
        >{{ fmt(m.mm) }}</span>
        <span
          v-if="badge"
          class="pointer-events-none absolute z-10 whitespace-nowrap rounded-lg bg-slate-900 px-2 py-1 text-[12px] font-bold tabular-nums text-white shadow-lg"
          :class="badge.above ? '-translate-x-1/2 -translate-y-[140%]' : 'translate-x-3 translate-y-3'"
          :style="{ left: `${badge.x}px`, top: `${badge.y}px` }"
          role="status"
        >{{ badge.text }}</span>
      </div>
    </div>
  </div>
</template>
