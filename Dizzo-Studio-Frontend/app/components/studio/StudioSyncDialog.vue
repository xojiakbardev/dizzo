<script setup lang="ts">
// "Sinxronlash": which other areas show the open area's design. Only areas
// of the same size (or the admin's mirrored pair) can; a synced area has no
// design of its own and is edited through its source.
import type { PrintArea } from '~/types/catalog';

export interface SyncOption {
  area: PrintArea;
  mirror: boolean; // an admin-made mirrored pair: placed as a mirror image
  own: number; // layers it has now (they are set aside when synced)
  blocked: string | null; // why it can't be picked
}

const props = defineProps<{
  open: boolean;
  source: PrintArea | null;
  options: SyncOption[];
  selected: string[];
}>();
const emit = defineEmits<{ 'update:open': [open: boolean]; 'save': [targets: string[]] }>();

const { t } = useI18n();
const picked = ref<string[]>([]);
watch(() => props.open, (open) => {
  if (open) picked.value = [...props.selected];
});

function toggle(key: string) {
  picked.value = picked.value.includes(key) ? picked.value.filter(k => k !== key) : [...picked.value, key];
}
const parked = computed(() => props.options
  .filter(o => picked.value.includes(o.area.key) && !props.selected.includes(o.area.key) && o.own > 0));
</script>

<template>
  <UiDialog :open="open" @update:open="(v: boolean) => emit('update:open', v)">
    <UiDialogContent class="sm:max-w-md">
      <UiDialogHeader>
        <UiDialogTitle>{{ $t('studio.sync.title') }}</UiDialogTitle>
      </UiDialogHeader>
      <div class="space-y-2">
        <label
          v-for="o in options"
          :key="o.area.key"
          class="flex items-center gap-3 rounded-xl border px-3 py-2.5 text-sm"
          :class="o.blocked ? 'border-slate-100 text-slate-400' : picked.includes(o.area.key) ? 'border-secondary-400 bg-secondary-50/60' : 'border-slate-200'"
        >
          <input
            type="checkbox"
            class="h-4 w-4 accent-secondary-600"
            :checked="picked.includes(o.area.key)"
            :disabled="Boolean(o.blocked)"
            @change="toggle(o.area.key)"
          >
          <span class="min-w-0 flex-1">
            <span class="block font-semibold text-slate-900">{{ o.area.name }}</span>
            <span class="block text-[11px] text-brand-muted">
              {{ Number(o.area.width_mm) }} × {{ Number(o.area.height_mm) }} {{ $t('studio.common.mm') }}<template v-if="o.mirror"> · {{ $t('studio.sync.mirrored') }}</template>
            </span>
          </span>
          <span
            v-if="o.blocked"
            class="text-right text-[11px]"
          >{{ o.blocked }}</span>
        </label>
        <p
          v-if="!options.length"
          class="rounded-xl bg-brand-surface-low px-3 py-4 text-center text-xs text-brand-muted"
        >
          {{ $t('studio.sync.none') }}
        </p>
        <p
          v-if="parked.length"
          class="rounded-xl bg-amber-50 px-3 py-2 text-[11px] text-amber-900"
        >
          {{ $t('studio.sync.parked', { list: parked.map(o => t('studio.sync.parkedItem', { name: o.area.name, count: o.own }, o.own)).join(', ') }) }}
        </p>
        <p class="text-[11px] text-brand-muted">
          {{ $t('studio.sync.hint', { name: source?.name ?? '' }) }}
        </p>
      </div>
      <div class="mt-4 flex justify-end gap-2">
        <button
          type="button"
          class="h-10 rounded-xl border border-slate-200 px-4 text-sm font-semibold"
          @click="emit('update:open', false)"
        >
          {{ $t('studio.common.cancel') }}
        </button>
        <button
          type="button"
          class="h-10 rounded-xl bg-secondary-600 px-4 text-sm font-bold text-white"
          @click="emit('save', picked); emit('update:open', false)"
        >
          {{ $t('studio.common.save') }}
        </button>
      </div>
    </UiDialogContent>
  </UiDialog>
</template>
