<script setup lang="ts">
// A dashboard figure: title, value and — when there's a period to compare
// with — the change against the period before (the earlier value in its
// tooltip). No description line: the title says what it is.
import { NuxtLink } from '#components';

const { t } = useI18n();

const props = withDefaults(defineProps<{
  title: string;
  value?: string | number;
  icon: string;
  /** Change in percent against the previous period; null hides it. */
  delta?: number | null;
  /** The previous period's value, shown in the change's tooltip. */
  previous?: string;
  /** A rise is bad news (e.g. cancellations). */
  invert?: boolean;
  /** A small chip instead of the change (e.g. "3 / 8"). */
  chip?: string;
  chipTitle?: string;
  to?: string;
  loading?: boolean;
}>(), {
  value: undefined,
  delta: null,
  previous: undefined,
  invert: false,
  chip: undefined,
  chipTitle: undefined,
  to: undefined,
  loading: false,
});

const deltaView = computed(() => {
  const d = props.delta;
  if (d === null || !Number.isFinite(d)) return null;
  const rounded = Math.round(d);
  const good = props.invert ? rounded < 0 : rounded > 0;
  const bad = props.invert ? rounded > 0 : rounded < 0;
  return {
    text: `${rounded > 0 ? '+' : ''}${rounded}%`,
    icon: rounded > 0 ? 'lucide:trending-up' : rounded < 0 ? 'lucide:trending-down' : 'lucide:minus',
    tone: good ? 'bg-emerald-50 text-emerald-700' : bad ? 'bg-rose-50 text-rose-700' : 'bg-muted text-muted-foreground',
  };
});
</script>

<template>
  <component
    :is="to ? NuxtLink : 'div'"
    :to="to"
    :class="['block rounded-xl outline-none focus-visible:ring-3 focus-visible:ring-ring/50', to ? 'group' : '']"
  >
    <UiCard :class="['h-full gap-0 py-0 shadow-xs', to ? 'transition-shadow group-hover:shadow-md' : '']">
      <UiCardContent class="flex h-full flex-col gap-3 p-4">
        <div class="flex items-center justify-between gap-2">
          <span class="truncate text-xs font-medium text-muted-foreground">{{ title }}</span>
          <Icon
            :name="icon"
            class="shrink-0 text-base text-muted-foreground"
          />
        </div>
        <UiSkeleton
          v-if="loading"
          class="h-7 w-2/3 rounded-md"
        />
        <div
          v-else
          class="flex flex-wrap items-center gap-x-2 gap-y-1"
        >
          <span class="truncate text-xl font-bold leading-none tracking-tight text-foreground sm:text-2xl">{{ value }}</span>
          <UiTooltip v-if="deltaView">
            <UiTooltipTrigger as-child>
              <span
                :class="['inline-flex h-5 items-center gap-1 rounded-md px-1.5 text-[11px] font-semibold tabular-nums', deltaView.tone]"
                tabindex="0"
              >
                <Icon
                  :name="deltaView.icon"
                  class="text-xs"
                />
                {{ deltaView.text }}
              </span>
            </UiTooltipTrigger>
            <UiTooltipContent v-if="previous !== undefined">
              {{ t('admin.dashboard.previousPeriod', { value: previous }) }}
            </UiTooltipContent>
          </UiTooltip>
          <UiTooltip v-else-if="chip">
            <UiTooltipTrigger as-child>
              <span
                class="inline-flex h-5 items-center rounded-md bg-muted px-1.5 text-[11px] font-semibold text-muted-foreground tabular-nums"
                tabindex="0"
              >{{ chip }}</span>
            </UiTooltipTrigger>
            <UiTooltipContent v-if="chipTitle">
              {{ chipTitle }}
            </UiTooltipContent>
          </UiTooltip>
        </div>
      </UiCardContent>
    </UiCard>
  </component>
</template>
