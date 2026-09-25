<script setup lang="ts">
// One print method of an area: where in the area it may go (the zone,
// dragged on the mini-map or on the model), and its limits. For the laser,
// the zone is where its strip may travel; the strip itself previews as a
// band sliding across it.
import type { DraftArea, DraftMethod, Phase, ZoneRect } from '~/lib/admin/shapeDraft';
import { DPI_CHOICES, methodProblems, ZONE_COLOURS } from '~/lib/admin/shapeDraft';
import { METHOD_LABELS } from '~/types/catalog';
import MmField from '~/components/admin/shapes/MmField.vue';
import ZoneMap from '~/components/admin/shapes/ZoneMap.vue';

const props = defineProps<{
  area: DraftArea;
  method: DraftMethod;
  editing: boolean; // the zone's handles are on the model
  open: boolean;
  stripAt: number | null;
  playing: boolean;
  removable: boolean;
  round?: boolean;
  cornerMm?: number;
}>();
const emit = defineEmits<{
  patch: [patch: Partial<DraftMethod>, group?: string];
  zone: [rect: ZoneRect, phase: Phase];
  toggleEdit: [];
  toggleOpen: [];
  stripAt: [value: number];
  play: [];
  remove: [];
}>();

const { t } = useI18n();
const engrave = computed(() => props.method.method === 'engrave');
const errors = computed(() => {
  const out: Record<string, string> = {};
  for (const p of methodProblems(props.method, props.area.w, props.area.h)) out[p.field] ??= p.text;
  return out;
});
const whole = computed(() => props.method.x === 0 && props.method.y === 0 && props.method.w === props.area.w && props.method.h === props.area.h);
const set = (key: keyof DraftMethod) => (value: number | null) => emit('patch', { [key]: value } as Partial<DraftMethod>, key);
function setZone(key: 'x' | 'y' | 'w' | 'h', value: number | null) {
  if (value === null) return;
  emit('patch', { [key]: value } as Partial<DraftMethod>, key);
}
const hasStrip = computed(() => engrave.value && props.method.strip !== null && props.method.strip < props.method.w);
const dpiText = ref('');
watch(() => props.method.dpi, (v) => {
  dpiText.value = String(v);
}, { immediate: true });
function commitDpi() {
  const v = Math.round(Number(dpiText.value));
  if (Number.isFinite(v) && v > 0 && v !== props.method.dpi) emit('patch', { dpi: v }, 'dpi');
  else dpiText.value = String(props.method.dpi);
}
const colour = computed(() => ZONE_COLOURS[props.method.method]);
</script>

<template>
  <section
    class="overflow-hidden rounded-xl border bg-card"
    :class="editing ? 'border-primary/60 ring-2 ring-primary/15' : 'border-border'"
    :data-method="method.method"
  >
    <header class="flex items-center gap-2 px-3 py-2">
      <button
        type="button"
        class="flex min-w-0 flex-1 items-center gap-2 text-left"
        :aria-expanded="open"
        @click="emit('toggleOpen')"
      >
        <span
          class="size-2.5 shrink-0 rounded-sm"
          :style="{ background: colour.line }"
        />
        <span class="truncate text-sm font-semibold">{{ METHOD_LABELS[method.method] }}</span>
        <span
          v-if="Object.keys(errors).length"
          class="size-1.5 shrink-0 rounded-full bg-rose-500"
        />
        <Icon
          name="lucide:chevron-down"
          class="ml-auto size-4 shrink-0 text-muted-foreground transition-transform"
          :class="open ? 'rotate-180' : ''"
        />
      </button>
      <UiTooltip v-if="removable">
        <UiTooltipTrigger as-child>
          <UiButton
            variant="ghost"
            size="icon-xs"
            class="text-muted-foreground hover:text-destructive"
            :aria-label="t('admin.shapeParts.removeMethodNamed', { method: METHOD_LABELS[method.method] })"
            @click="emit('remove')"
          >
            <Icon
              name="lucide:x"
              class="size-3.5"
            />
          </UiButton>
        </UiTooltipTrigger>
        <UiTooltipContent>{{ t('admin.shapeParts.removeMethod') }}</UiTooltipContent>
      </UiTooltip>
    </header>

    <div
      v-if="open"
      class="space-y-3 border-t border-border px-3 pb-3 pt-3"
    >
      <div class="flex items-center justify-between gap-2">
        <p class="text-xs font-semibold text-foreground">
          {{ engrave ? t('admin.shapeParts.laserZone') : t('admin.shapeParts.printZone') }}
        </p>
        <div class="flex gap-1">
          <UiButton
            variant="ghost"
            size="xs"
            :disabled="whole"
            @click="emit('patch', { x: 0, y: 0, w: area.w, h: area.h })"
          >
            {{ t('admin.shapeParts.wholeArea') }}
          </UiButton>
          <UiButton
            :variant="editing ? 'default' : 'outline'"
            size="xs"
            :aria-pressed="editing"
            data-testid="zone-edit"
            @click="emit('toggleEdit')"
          >
            <Icon
              :name="editing ? 'lucide:check' : 'lucide:move'"
              class="size-3.5"
            />
            {{ editing ? t('admin.shapeParts.done') : t('admin.shapeParts.onModel') }}
          </UiButton>
        </div>
      </div>

      <ZoneMap
        :area="area"
        :method="method.method"
        :strip-at="hasStrip ? stripAt : null"
        :round="round"
        :corner-mm="cornerMm"
        @zone="(rect, phase) => emit('zone', rect, phase)"
      />

      <div class="grid grid-cols-4 gap-2">
        <MmField
          label="X"
          :model-value="method.x"
          hide-cm
          :error="errors.x ? ' ' : null"
          @update:model-value="setZone('x', $event)"
        />
        <MmField
          label="Y"
          :model-value="method.y"
          hide-cm
          :error="errors.y ? ' ' : null"
          @update:model-value="setZone('y', $event)"
        />
        <MmField
          :label="t('admin.shapeParts.width')"
          :model-value="method.w"
          :min="0.1"
          hide-cm
          :error="errors.w ? ' ' : null"
          @update:model-value="setZone('w', $event)"
        />
        <MmField
          :label="t('admin.shapeParts.height')"
          :model-value="method.h"
          :min="0.1"
          hide-cm
          :error="errors.h ? ' ' : null"
          @update:model-value="setZone('h', $event)"
        />
      </div>
      <p
        v-if="errors.x || errors.y || errors.w || errors.h"
        class="-mt-1 text-[11px] text-destructive"
      >
        {{ errors.w || errors.h || errors.x || errors.y }}
      </p>

      <div
        v-if="engrave"
        class="space-y-2 rounded-lg bg-orange-50 p-2.5 dark:bg-orange-950/30"
      >
        <MmField
          :label="t('admin.shapeParts.laserWidth')"
          :model-value="method.strip"
          nullable
          :min="0.1"
          :placeholder="t('admin.shapeParts.wholeZone')"
          :error="errors.strip"
          @update:model-value="set('strip')($event)"
        />
        <div
          v-if="hasStrip"
          class="flex items-center gap-2"
        >
          <UiButton
            variant="outline"
            size="icon-xs"
            :aria-label="playing ? t('admin.shapeParts.stop') : t('admin.shapeParts.playMotion')"
            data-testid="strip-play"
            @click="emit('play')"
          >
            <Icon
              :name="playing ? 'lucide:pause' : 'lucide:play'"
              class="size-3.5"
            />
          </UiButton>
          <input
            type="range"
            min="0"
            max="1"
            step="0.01"
            class="h-1.5 flex-1 accent-orange-600"
            :aria-label="t('admin.shapeParts.stripPosition')"
            :value="stripAt ?? 0.5"
            @input="emit('stripAt', Number(($event.target as HTMLInputElement).value))"
          >
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <MmField
          :label="t('admin.shapeParts.maxWidth')"
          :model-value="method.maxW"
          nullable
          :min="0.1"
          :placeholder="t('admin.shapeParts.unlimited')"
          :error="errors.maxW"
          @update:model-value="set('maxW')($event)"
        />
        <MmField
          :label="t('admin.shapeParts.maxHeight')"
          :model-value="method.maxH"
          nullable
          :min="0.1"
          :placeholder="t('admin.shapeParts.unlimited')"
          :error="errors.maxH"
          @update:model-value="set('maxH')($event)"
        />
        <MmField
          v-if="engrave"
          :label="t('admin.shapeParts.minFont')"
          :model-value="method.minFont"
          nullable
          :min="0.1"
          :max="100"
          hide-cm
          :error="errors.minFont"
          @update:model-value="set('minFont')($event)"
        />
        <div
          v-else
          class="grid gap-1"
        >
          <span class="text-xs font-medium text-muted-foreground">{{ t('admin.shapeParts.colors') }}</span>
          <UiLabel class="flex h-9 cursor-pointer items-center gap-2 rounded-lg border border-input px-2.5 text-sm font-normal">
            <UiSwitch
              size="sm"
              :model-value="method.colors"
              @update:model-value="(on: boolean) => emit('patch', { colors: on })"
            />
            {{ method.colors ? t('admin.shapeParts.colorful') : t('admin.shapeParts.oneColor') }}
          </UiLabel>
        </div>
      </div>

      <div class="grid gap-1">
        <span class="text-xs font-medium text-muted-foreground">DPI</span>
        <div class="flex items-center gap-2">
          <UiToggleGroup
            type="single"
            :model-value="String(method.dpi)"
            class="flex-1"
            aria-label="DPI"
            @update:model-value="(v) => v && emit('patch', { dpi: Number(v) })"
          >
            <UiToggleGroupItem
              v-for="d in DPI_CHOICES"
              :key="d"
              :value="String(d)"
              class="h-7 flex-1 px-1.5 text-xs tabular-nums"
            >
              {{ d }}
            </UiToggleGroupItem>
          </UiToggleGroup>
          <input
            v-model="dpiText"
            inputmode="numeric"
            class="h-9 w-16 rounded-lg border bg-background px-2 text-center text-sm tabular-nums outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
            :class="errors.dpi ? 'border-destructive' : 'border-input'"
            :aria-label="t('admin.shapeParts.dpiValue')"
            @blur="commitDpi"
            @keydown.enter.prevent="commitDpi"
          >
        </div>
        <p
          v-if="errors.dpi"
          class="text-[11px] text-destructive"
        >
          {{ errors.dpi }}
        </p>
      </div>
    </div>
  </section>
</template>
