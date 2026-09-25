<script setup lang="ts">
// Ranked or ordered categories as thin horizontal bars: the label on the
// left, the value at the right (an optional second figure muted before it),
// the bar underneath. Hovering a row lifts its bar and shows its share.
interface BarDatum {
  label: string;
  value: number;
  valueLabel?: string;
  /** A second, quieter figure (e.g. revenue next to units). */
  hint?: string;
}

const props = withDefaults(defineProps<{
  data: BarDatum[];
  emptyMessage?: string;
  emptyIcon?: string;
}>(), {
  emptyMessage: undefined,
  emptyIcon: 'lucide:chart-bar',
});

const { t } = useI18n();
const hoverIndex = ref<number | null>(null);
const maxValue = computed(() => Math.max(...props.data.map(item => item.value), 1));
const total = computed(() => props.data.reduce((sum, item) => sum + item.value, 0));

function widthPct(value: number) {
  return value > 0 ? Math.max((value / maxValue.value) * 100, 2) : 0;
}
function share(value: number) {
  return total.value ? `${Math.round((value / total.value) * 100)}%` : '0%';
}
</script>

<template>
  <EmptyState
    v-if="data.length === 0"
    :title="emptyMessage ?? t('admin.dashboard.noData')"
    :icon="emptyIcon"
    class="border-0 bg-transparent py-8"
  />
  <ul
    v-else
    class="space-y-3.5"
  >
    <li
      v-for="(item, index) in data"
      :key="item.label"
      class="group"
      @pointerenter="hoverIndex = index"
      @pointerleave="hoverIndex = null"
    >
      <div class="mb-1.5 flex items-baseline justify-between gap-3 text-sm">
        <span class="min-w-0 truncate text-foreground">{{ item.label }}</span>
        <span class="flex shrink-0 items-baseline gap-2 tabular-nums">
          <span
            v-if="hoverIndex === index"
            class="text-xs text-muted-foreground"
          >{{ share(item.value) }}</span>
          <span
            v-else-if="item.hint"
            class="hidden text-xs text-muted-foreground sm:inline"
          >{{ item.hint }}</span>
          <span class="font-semibold text-foreground">{{ item.valueLabel ?? item.value.toLocaleString('ru-RU') }}</span>
        </span>
      </div>
      <div class="h-2 w-full rounded-e-[4px] bg-muted/70">
        <div
          class="h-full rounded-e-[4px] bg-primary transition-opacity duration-150"
          :class="hoverIndex === null || hoverIndex === index ? 'opacity-100' : 'opacity-50'"
          :style="{ width: `${widthPct(item.value)}%` }"
        />
      </div>
    </li>
  </ul>
</template>
