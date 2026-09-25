<script setup lang="ts">
// The shape's parts on the left: the model itself, then every area with
// its side, methods and a dot for how it stands. Horizontal chips on
// narrow screens.
import type { AreaMeasure, DraftArea, Problem, ShapeDraft } from '~/lib/admin/shapeDraft';
import { SIDE_LABELS } from '~/lib/admin/shapeDraft';

const props = defineProps<{
  draft: ShapeDraft;
  selected: string | null;
  measures: Record<string, AreaMeasure>;
  problems: Problem[];
  locked: boolean; // the model has no size yet: areas wait
  placing: boolean;
  compact?: boolean;
}>();
const emit = defineEmits<{ select: [uid: string | null]; add: [] }>();

const { t } = useI18n();

function tone(area: DraftArea): 'bad' | 'warn' | 'ok' {
  const mine = props.problems.filter(p => p.uid === area.uid);
  if (mine.some(p => p.blocking)) return 'bad';
  return mine.length ? 'warn' : 'ok';
}
const DOT = { bad: 'bg-rose-500', warn: 'bg-amber-500', ok: 'bg-emerald-500' };
const shapeTone = computed(() => (props.problems.some(p => p.uid === null && p.blocking) ? 'bad' : props.problems.some(p => p.uid === null) ? 'warn' : 'ok'));
const sideOf = (area: DraftArea) => {
  const side = props.measures[area.uid]?.side;
  return side ? SIDE_LABELS[side] : t('admin.shapeParts.notPlaced');
};
const bodyLabel = computed(() => (props.draft.kind === 'model' ? t('admin.shapeParts.model3d') : t('admin.shapeParts.shapeSize')));
</script>

<template>
  <!-- Narrow: one row of chips. -->
  <div
    v-if="compact"
    class="flex items-center gap-1.5 overflow-x-auto scrollbar-none"
  >
    <button
      type="button"
      class="flex h-9 shrink-0 items-center gap-1.5 rounded-lg border px-2.5 text-sm font-medium transition-colors"
      :class="selected === null ? 'border-primary bg-primary/10 text-primary' : 'border-border bg-card text-muted-foreground hover:text-foreground'"
      @click="emit('select', null)"
    >
      <Icon
        name="lucide:box"
        class="size-4"
      />
      {{ bodyLabel }}
      <span
        class="size-1.5 rounded-full"
        :class="DOT[shapeTone]"
      />
    </button>
    <button
      v-for="area in draft.areas"
      :key="area.uid"
      type="button"
      class="flex h-9 max-w-44 shrink-0 items-center gap-1.5 rounded-lg border px-2.5 text-sm font-medium transition-colors"
      :class="selected === area.uid ? 'border-primary bg-primary/10 text-primary' : 'border-border bg-card text-foreground hover:bg-muted'"
      :data-area="area.key"
      @click="emit('select', area.uid)"
    >
      <span
        class="size-1.5 shrink-0 rounded-full"
        :class="DOT[tone(area)]"
      />
      <span class="truncate">{{ area.name || area.key }}</span>
    </button>
    <UiButton
      size="sm"
      :variant="placing ? 'default' : 'outline'"
      class="h-9 shrink-0"
      :disabled="locked"
      data-testid="add-area"
      @click="emit('add')"
    >
      <Icon
        name="lucide:plus"
        class="size-4"
      />
      {{ t('admin.shapeParts.area') }}
    </UiButton>
  </div>

  <div
    v-else
    class="flex h-full min-h-0 flex-col"
  >
    <div class="flex items-center justify-between gap-2 px-3 pb-2 pt-3">
      <h2 class="text-sm font-semibold">
        {{ t('admin.shapeParts.areas') }}
      </h2>
      <UiTooltip>
        <UiTooltipTrigger as-child>
          <UiButton
            size="icon-sm"
            :variant="placing ? 'default' : 'outline'"
            :disabled="locked"
            :aria-label="t('admin.shapeParts.addArea')"
            data-testid="add-area"
            @click="emit('add')"
          >
            <Icon
              name="lucide:plus"
              class="size-4"
            />
          </UiButton>
        </UiTooltipTrigger>
        <UiTooltipContent>{{ locked ? t('admin.shapeParts.enterModelSizeFirst') : t('admin.shapeParts.addAreaKey') }}</UiTooltipContent>
      </UiTooltip>
    </div>
    <div class="min-h-0 flex-1 space-y-1 overflow-y-auto px-2 pb-3">
      <button
        type="button"
        class="flex w-full items-center gap-2.5 rounded-lg px-2 py-2 text-left transition-colors"
        :class="selected === null ? 'bg-primary/10 text-primary' : 'hover:bg-muted'"
        @click="emit('select', null)"
      >
        <span class="flex size-8 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground">
          <Icon
            name="lucide:box"
            class="size-4"
          />
        </span>
        <span class="min-w-0 flex-1">
          <span class="block truncate text-sm font-medium">{{ bodyLabel }}</span>
          <span class="block truncate text-xs text-muted-foreground">{{ t('admin.shapeParts.sizeFile') }}</span>
        </span>
        <span
          class="size-2 shrink-0 rounded-full"
          :class="DOT[shapeTone]"
        />
      </button>
      <div class="mx-2 my-1 h-px bg-border" />
      <p
        v-if="!draft.areas.length"
        class="px-2 py-3 text-xs text-muted-foreground"
      >
        {{ locked ? t('admin.shapeParts.areasAfterSize') : t('admin.shapeParts.noAreas') }}
      </p>
      <button
        v-for="area in draft.areas"
        :key="area.uid"
        type="button"
        class="flex w-full items-start gap-2.5 rounded-lg px-2 py-2 text-left transition-colors"
        :class="selected === area.uid ? 'bg-primary/10' : 'hover:bg-muted'"
        :data-area="area.key"
        @click="emit('select', area.uid)"
      >
        <span
          class="mt-1.5 size-2 shrink-0 rounded-full"
          :class="DOT[tone(area)]"
        />
        <span class="min-w-0 flex-1">
          <span
            class="flex items-center gap-1 text-sm font-medium"
            :class="selected === area.uid ? 'text-primary' : 'text-foreground'"
          >
            <span class="truncate">{{ area.name || area.key }}</span>
            <Icon
              v-if="area.pairKey"
              name="lucide:link-2"
              class="size-3.5 shrink-0 text-muted-foreground"
            />
          </span>
          <span class="block truncate text-xs text-muted-foreground tabular-nums">
            {{ sideOf(area) }} · {{ Math.round(area.w) }}×{{ Math.round(area.h) }} {{ t('admin.shapeParts.mm') }}
          </span>
          <span class="mt-1 flex gap-1">
            <span
              v-for="m in area.methods"
              :key="m.method"
              class="rounded px-1.5 py-px text-[10px] font-semibold"
              :class="m.method === 'uv' ? 'bg-sky-100 text-sky-800 dark:bg-sky-950 dark:text-sky-200' : 'bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200'"
            >{{ m.method === 'uv' ? t('admin.shapeParts.chipColor') : t('admin.shapeParts.chipLaser') }}</span>
          </span>
        </span>
      </button>
    </div>
  </div>
</template>
