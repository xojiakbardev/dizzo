<script setup lang="ts">
// One measure over days: a line with a light wash (money) or columns
// (counts). Drawn in pixels at the container's real width, so labels stay
// crisp at any size. Hovering a day shows a crosshair (line) or lifts the
// column, with a tooltip for that day; a screen-reader table carries every
// value.
import { useElementSize } from '@vueuse/core';

export interface TrendPoint {
  /** "YYYY-MM-DD" */
  date: string;
  value: number;
}

const props = withDefaults(defineProps<{
  points: TrendPoint[];
  kind?: 'line' | 'bar';
  /** The measure's name, for the tooltip and the table. */
  label: string;
  format?: (value: number) => string;
  /** Short axis ticks: 1.2M, 350K. */
  compact?: boolean;
  /** Other figures of the hovered day, shown under the main one. */
  details?: (index: number) => Array<{ label: string; value: string }>;
  height?: number;
}>(), {
  kind: 'line',
  format: (value: number) => value.toLocaleString('ru-RU'),
  compact: false,
  details: undefined,
  height: 260,
});

const PAD = { top: 16, right: 12, bottom: 28 };
const MIN_LABEL_GAP = 84;

const box = ref<HTMLElement | null>(null);
const { width } = useElementSize(box);
const hover = ref<number | null>(null);

function compactNumber(value: number) {
  const abs = Math.abs(value);
  const trim = (n: number) => String(Number(n.toFixed(1)));
  if (abs >= 1_000_000_000) return `${trim(value / 1_000_000_000)}B`;
  if (abs >= 1_000_000) return `${trim(value / 1_000_000)}M`;
  if (abs >= 1_000) return `${trim(value / 1_000)}K`;
  return String(Math.round(value));
}
const tickLabel = (value: number) => (props.compact ? compactNumber(value) : value.toLocaleString('ru-RU'));

/** 0 … a round top, in 4 steps (counts keep whole steps). */
const scale = computed(() => {
  const max = Math.max(0, ...props.points.map(p => p.value));
  if (max <= 0) return { top: 4, step: 1 };
  const raw = max / 4;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const norm = raw / mag;
  let step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10) * mag;
  if (props.kind === 'bar') step = Math.max(1, Math.ceil(step));
  return { top: step * Math.ceil(max / step), step };
});
const ticks = computed(() => {
  const out: number[] = [];
  for (let v = 0; v <= scale.value.top + 1e-9; v += scale.value.step) out.push(v);
  return out;
});

const padLeft = computed(() => Math.max(28, ...ticks.value.map(t => tickLabel(t).length * 6.5 + 12)));
const plotW = computed(() => Math.max(0, width.value - padLeft.value - PAD.right));
const plotH = computed(() => props.height - PAD.top - PAD.bottom);
const baseY = computed(() => PAD.top + plotH.value);
const band = computed(() => (props.points.length ? plotW.value / props.points.length : 0));
const yOf = (v: number) => PAD.top + plotH.value - (v / scale.value.top) * plotH.value;
const xOf = (i: number) => padLeft.value + band.value * (i + 0.5);

const barW = computed(() => Math.max(2, Math.min(24, band.value - 2)));
function barPath(i: number, v: number) {
  const x = xOf(i) - barW.value / 2;
  const y = yOf(v);
  const h = baseY.value - y;
  if (h <= 0) return '';
  const r = Math.min(4, h, barW.value / 2);
  const w = barW.value;
  return `M${x},${baseY.value} V${y + r} Q${x},${y} ${x + r},${y} H${x + w - r} Q${x + w},${y} ${x + w},${y + r} V${baseY.value} Z`;
}

const linePath = computed(() => props.points.map((p, i) => `${i ? 'L' : 'M'}${xOf(i).toFixed(1)},${yOf(p.value).toFixed(1)}`).join(' '));
const areaPath = computed(() => {
  const n = props.points.length;
  if (!n) return '';
  return `${linePath.value} L${xOf(n - 1).toFixed(1)},${baseY.value} L${xOf(0).toFixed(1)},${baseY.value} Z`;
});

/** Every k-th day, counted back from the last so "today" is always labelled. */
const labelEvery = computed(() => Math.max(1, Math.ceil(MIN_LABEL_GAP / Math.max(band.value, 1))));
const xLabels = computed(() => props.points
  .map((p, i) => ({ i, text: formatDayMonth(p.date) }))
  .filter(({ i }) => (props.points.length - 1 - i) % labelEvery.value === 0)
  .map(({ i, text }) => {
    // The edge labels hug the plot's ends instead of spilling past them.
    const x = xOf(i);
    const half = text.length * 3.2;
    if (x + half > width.value - PAD.right) return { i, text, x: Math.min(x + band.value / 2, width.value - PAD.right), anchor: 'end' };
    if (x - half < padLeft.value) return { i, text, x: Math.max(x - band.value / 2, padLeft.value), anchor: 'start' };
    return { i, text, x, anchor: 'middle' };
  }));

function onMove(event: PointerEvent) {
  if (!props.points.length || !band.value) return;
  const rect = (event.currentTarget as SVGElement).getBoundingClientRect();
  const x = event.clientX - rect.left - padLeft.value;
  hover.value = Math.min(props.points.length - 1, Math.max(0, Math.floor(x / band.value)));
}

const hovered = computed(() => (hover.value === null ? null : props.points[hover.value] ?? null));
const tooltipStyle = computed(() => {
  if (hover.value === null) return {};
  const x = xOf(hover.value);
  const flip = x > width.value * 0.6;
  return {
    left: `${x}px`,
    top: `${PAD.top}px`,
    transform: flip ? 'translateX(calc(-100% - 12px))' : 'translateX(12px)',
  };
});
const total = computed(() => props.points.reduce((sum, p) => sum + p.value, 0));
</script>

<template>
  <div
    ref="box"
    class="relative w-full select-none"
    :style="{ height: `${height}px` }"
  >
    <svg
      v-if="width > 0"
      :width="width"
      :height="height"
      class="block overflow-visible text-primary"
      role="img"
      :aria-label="$t('admin.dashboard.chartTotal', { label, total: format(total) })"
      @pointermove="onMove"
      @pointerleave="hover = null"
    >
      <g>
        <template
          v-for="t in ticks"
          :key="t"
        >
          <line
            :x1="padLeft"
            :x2="width - PAD.right"
            :y1="yOf(t)"
            :y2="yOf(t)"
            class="stroke-border"
            stroke-width="1"
          />
          <text
            :x="padLeft - 8"
            :y="yOf(t)"
            text-anchor="end"
            dominant-baseline="middle"
            class="fill-muted-foreground tabular-nums"
            font-size="11"
          >{{ tickLabel(t) }}</text>
        </template>
      </g>

      <text
        v-for="l in xLabels"
        :key="l.i"
        :x="l.x"
        :y="height - 8"
        :text-anchor="l.anchor"
        class="fill-muted-foreground tabular-nums"
        font-size="11"
      >{{ l.text }}</text>

      <template v-if="kind === 'bar'">
        <path
          v-for="(p, i) in points"
          :key="p.date"
          :d="barPath(i, p.value)"
          fill="currentColor"
          :fill-opacity="hover === null || hover === i ? 1 : 0.45"
          class="transition-[fill-opacity] duration-150"
        />
      </template>
      <template v-else>
        <path
          :d="areaPath"
          fill="currentColor"
          fill-opacity="0.1"
        />
        <path
          :d="linePath"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <line
          v-if="hovered && hover !== null"
          :x1="xOf(hover)"
          :x2="xOf(hover)"
          :y1="PAD.top"
          :y2="baseY"
          class="stroke-muted-foreground/50"
          stroke-width="1"
        />
        <circle
          v-if="hovered && hover !== null"
          :cx="xOf(hover)"
          :cy="yOf(hovered.value)"
          r="4.5"
          fill="currentColor"
          class="stroke-card"
          stroke-width="2"
        />
      </template>

      <!-- The whole plot is the hover target, not just the thin marks. -->
      <rect
        :x="padLeft"
        :y="PAD.top"
        :width="plotW"
        :height="plotH"
        fill="transparent"
      />
    </svg>

    <div
      v-if="hovered"
      class="pointer-events-none absolute z-10 min-w-36 rounded-lg border border-border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-lg"
      :style="tooltipStyle"
    >
      <p class="text-muted-foreground">
        {{ formatDayMonth(hovered.date) }}
      </p>
      <p class="mt-0.5 flex items-center justify-between gap-4">
        <span class="flex items-center gap-1.5 text-muted-foreground">
          <span class="size-2 rounded-full bg-primary" />{{ label }}
        </span>
        <span class="font-semibold text-foreground tabular-nums">{{ format(hovered.value) }}</span>
      </p>
      <p
        v-for="row in details?.(hover ?? 0) ?? []"
        :key="row.label"
        class="mt-0.5 flex items-center justify-between gap-4"
      >
        <span class="text-muted-foreground">{{ row.label }}</span>
        <span class="font-medium text-foreground tabular-nums">{{ row.value }}</span>
      </p>
    </div>

    <table class="sr-only">
      <caption>{{ label }}</caption>
      <tbody>
        <tr
          v-for="p in points"
          :key="p.date"
        >
          <th scope="row">
            {{ formatDayMonth(p.date) }}
          </th>
          <td>{{ format(p.value) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
