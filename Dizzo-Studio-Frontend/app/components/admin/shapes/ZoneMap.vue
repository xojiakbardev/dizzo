<script setup lang="ts">
// A flat drawing of an area (its real proportions, 1 cm grid) with its
// method zones. The active zone moves and resizes by dragging; an engrave
// zone shows its laser strip where the preview has it.
import type { CatalogMethod } from '~/types/catalog';
import type { DraftArea, Phase, ZoneRect } from '~/lib/admin/shapeDraft';
import { ZONE_COLOURS } from '~/lib/admin/shapeDraft';

const props = defineProps<{ area: DraftArea; method: CatalogMethod; stripAt: number | null; round?: boolean; cornerMm?: number }>();
const emit = defineEmits<{ zone: [rect: ZoneRect, phase: Phase] }>();

const { t } = useI18n();
const svgRef = ref<SVGSVGElement | null>(null);
const W = computed(() => Math.max(1, props.area.w));
const H = computed(() => Math.max(1, props.area.h));
// Lines and handles keep their size on screen whatever the area's size.
const unit = computed(() => Math.max(W.value, H.value) / 240);
const zone = computed(() => props.area.methods.find(m => m.method === props.method) ?? null);
const others = computed(() => props.area.methods.filter(m => m.method !== props.method));
const gridX = computed(() => Array.from({ length: Math.floor(W.value / 10) + 1 }, (_, i) => i * 10));
const gridY = computed(() => Array.from({ length: Math.floor(H.value / 10) + 1 }, (_, i) => i * 10));
const strip = computed(() => {
  const z = zone.value;
  if (!z || z.method !== 'engrave' || !z.strip || z.strip >= z.w || props.stripAt === null) return null;
  return { x: z.x + (z.w - z.strip) * props.stripAt, w: z.strip };
});

const HANDLES: Array<[number, number, string]> = [
  [-1, -1, 'nwse-resize'], [0, -1, 'ns-resize'], [1, -1, 'nesw-resize'], [1, 0, 'ew-resize'],
  [1, 1, 'nwse-resize'], [0, 1, 'ns-resize'], [-1, 1, 'nesw-resize'], [-1, 0, 'ew-resize'],
];

let drag: { sx: number; sy: number; start: { x: number; y: number }; rect0: ZoneRect; last: ZoneRect | null } | null = null;

function toArea(event: PointerEvent) {
  const svg = svgRef.value!;
  const point = svg.createSVGPoint();
  point.x = event.clientX;
  point.y = event.clientY;
  const p = point.matrixTransform(svg.getScreenCTM()!.inverse());
  return { x: p.x, y: p.y };
}

function start(event: PointerEvent, sx: number, sy: number) {
  const z = zone.value;
  if (!z || event.button !== 0) return;
  event.preventDefault();
  (event.currentTarget as Element).setPointerCapture(event.pointerId);
  drag = { sx, sy, start: toArea(event), rect0: { x: z.x, y: z.y, w: z.w, h: z.h }, last: null };
}

function move(event: PointerEvent) {
  if (!drag) return;
  const p = toArea(event);
  const r = drag.rect0;
  const snap = (v: number) => Math.round(v * 2) / 2; // half millimetres
  let next: ZoneRect;
  if (!drag.sx && !drag.sy) {
    next = {
      ...r,
      x: Math.min(Math.max(0, snap(r.x + p.x - drag.start.x)), Math.max(0, W.value - r.w)),
      y: Math.min(Math.max(0, snap(r.y + p.y - drag.start.y)), Math.max(0, H.value - r.h)),
    };
  }
  else {
    let left = r.x;
    let right = r.x + r.w;
    let top = r.y;
    let bottom = r.y + r.h;
    if (drag.sx < 0) left = Math.min(Math.max(0, snap(p.x)), right - 1);
    if (drag.sx > 0) right = Math.max(Math.min(W.value, snap(p.x)), left + 1);
    if (drag.sy < 0) top = Math.min(Math.max(0, snap(p.y)), bottom - 1);
    if (drag.sy > 0) bottom = Math.max(Math.min(H.value, snap(p.y)), top + 1);
    next = { x: left, y: top, w: right - left, h: bottom - top };
  }
  drag.last = next;
  emit('zone', next, 'live');
}

function end() {
  if (drag?.last) emit('zone', drag.last, 'commit');
  drag = null;
}

const colour = computed(() => ZONE_COLOURS[props.method]);
const cornerR = computed(() => (props.round ? 0 : Math.min(props.cornerMm ?? 0, W.value / 2, H.value / 2)));
</script>

<template>
  <div class="rounded-xl border border-border bg-muted/50 p-3">
    <svg
      ref="svgRef"
      :viewBox="`${-unit * 8} ${-unit * 8} ${W + unit * 16} ${H + unit * 16}`"
      class="mx-auto block max-h-56 w-full touch-none select-none"
      :style="{ aspectRatio: `${W + unit * 16} / ${H + unit * 16}` }"
      role="img"
      :aria-label="t('admin.shapeParts.zoneMap', { name: area.name })"
      data-testid="zone-map"
    >
      <defs>
        <clipPath :id="`face-${area.uid}`">
          <ellipse
            v-if="round"
            :cx="W / 2"
            :cy="H / 2"
            :rx="W / 2"
            :ry="H / 2"
          />
          <rect
            v-else
            :width="W"
            :height="H"
            :rx="cornerR"
          />
        </clipPath>
      </defs>
      <g :clip-path="`url(#face-${area.uid})`">
        <rect
          :width="W"
          :height="H"
          fill="white"
        />
        <line
          v-for="x in gridX"
          :key="`x${x}`"
          :x1="x"
          :x2="x"
          :y2="H"
          :stroke="x % 50 === 0 ? 'rgb(15 23 42 / 0.3)' : 'rgb(15 23 42 / 0.1)'"
          :stroke-width="unit * 0.6"
        />
        <line
          v-for="y in gridY"
          :key="`y${y}`"
          :y1="y"
          :y2="y"
          :x2="W"
          :stroke="y % 50 === 0 ? 'rgb(15 23 42 / 0.3)' : 'rgb(15 23 42 / 0.1)'"
          :stroke-width="unit * 0.6"
        />
        <rect
          v-for="m in others"
          :key="m.method"
          :x="m.x"
          :y="m.y"
          :width="m.w"
          :height="m.h"
          :fill="ZONE_COLOURS[m.method].fill"
          :stroke="ZONE_COLOURS[m.method].line"
          :stroke-width="unit"
          :stroke-dasharray="m.method === 'engrave' ? `${unit * 4} ${unit * 2}` : undefined"
          opacity="0.45"
        />
      </g>
      <rect
        :width="W"
        :height="H"
        :rx="round ? undefined : cornerR"
        fill="none"
        stroke="#e11d48"
        :stroke-width="unit * 1.4"
      />
      <ellipse
        v-if="round"
        :cx="W / 2"
        :cy="H / 2"
        :rx="W / 2"
        :ry="H / 2"
        fill="none"
        stroke="#e11d48"
        :stroke-width="unit"
        stroke-dasharray="4 3"
      />
      <template v-if="zone">
        <rect
          :x="zone.x"
          :y="zone.y"
          :width="zone.w"
          :height="zone.h"
          :fill="colour.strong"
          :stroke="colour.line"
          :stroke-width="unit * 1.6"
          :stroke-dasharray="method === 'engrave' ? `${unit * 5} ${unit * 3}` : undefined"
          class="cursor-move"
          data-testid="zone-rect"
          @pointerdown="start($event, 0, 0)"
          @pointermove="move"
          @pointerup="end"
          @pointercancel="end"
        />
        <rect
          v-if="strip"
          :x="strip.x"
          :y="zone.y"
          :width="strip.w"
          :height="zone.h"
          fill="rgb(234 88 12 / 0.3)"
          stroke="#ea580c"
          :stroke-width="unit * 1.2"
          pointer-events="none"
          data-testid="laser-strip"
        />
        <rect
          v-for="[sx, sy, cursor] in HANDLES"
          :key="`${sx}${sy}`"
          :x="zone.x + (zone.w * (sx + 1)) / 2 - unit * 4"
          :y="zone.y + (zone.h * (sy + 1)) / 2 - unit * 4"
          :width="unit * 8"
          :height="unit * 8"
          :rx="unit * 1.5"
          fill="white"
          :stroke="colour.line"
          :stroke-width="unit * 1.4"
          :style="{ cursor }"
          @pointerdown="start($event, sx, sy)"
          @pointermove="move"
          @pointerup="end"
          @pointercancel="end"
        />
      </template>
    </svg>
  </div>
</template>
