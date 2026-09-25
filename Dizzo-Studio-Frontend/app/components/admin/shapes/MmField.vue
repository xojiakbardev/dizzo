<script setup lang="ts">
// A length in millimetres: typed freely, taken on Enter or when the field
// is left (arrow keys step at once, Shift ×10); the centimetres show beside
// it. Empty is allowed when `nullable` (then the placeholder says what it means).
import { cmHint, round2 } from '~/lib/admin/shapeDraft';

const props = withDefaults(defineProps<{
  label?: string;
  modelValue: number | null;
  id?: string;
  min?: number;
  max?: number;
  step?: number;
  nullable?: boolean;
  placeholder?: string;
  unit?: string;
  hideCm?: boolean;
  error?: string | null;
  disabled?: boolean;
}>(), { min: 0, max: 5000, step: 1, unit: 'mm', label: undefined, id: undefined, placeholder: undefined, error: null });
const emit = defineEmits<{ 'update:modelValue': [value: number | null] }>();

const text = ref('');
const focused = ref(false);
const show = (v: number | null) => (v === null || Number.isNaN(v) ? '' : String(round2(v)));
watch(() => props.modelValue, (v) => {
  if (!focused.value) text.value = show(v);
}, { immediate: true });

function parse(raw: string): number | null | undefined {
  const t = raw.trim().replace(',', '.');
  if (!t) return props.nullable ? null : undefined;
  const v = Number(t);
  if (!Number.isFinite(v)) return undefined;
  return Math.min(props.max, Math.max(props.min, round2(v)));
}

function commit() {
  const v = parse(text.value);
  if (v === undefined) {
    text.value = show(props.modelValue);
    return;
  }
  text.value = show(v);
  if (v !== props.modelValue) emit('update:modelValue', v);
}

function step(event: KeyboardEvent, sign: number) {
  event.preventDefault();
  const base = parse(text.value) ?? props.modelValue ?? 0;
  text.value = show(Math.min(props.max, Math.max(props.min, round2(base + sign * props.step * (event.shiftKey ? 10 : 1)))));
  commit();
}

const hint = computed(() => (props.unit === 'mm' && !props.hideCm ? cmHint(parse(text.value) ?? null) : ''));
const autoId = useId();
const { t } = useI18n();
const unitText = computed(() => (props.unit === 'mm' ? t('admin.shapeParts.mm') : props.unit));
const inputId = computed(() => props.id ?? autoId);
</script>

<template>
  <div class="grid min-w-0 grid-cols-[minmax(0,1fr)] gap-1">
    <UiLabel
      v-if="label"
      :for="inputId"
      class="truncate text-xs font-medium text-muted-foreground"
    >
      {{ label }}
    </UiLabel>
    <div
      class="flex h-9 w-full min-w-0 items-center rounded-lg border bg-background pr-2 transition-colors focus-within:border-ring focus-within:ring-3 focus-within:ring-ring/50"
      :class="[error ? 'border-destructive' : 'border-input', disabled ? 'opacity-50' : '']"
    >
      <input
        :id="inputId"
        v-model="text"
        inputmode="decimal"
        autocomplete="off"
        class="h-full w-0 min-w-0 flex-1 bg-transparent px-2.5 text-sm tabular-nums outline-none placeholder:text-muted-foreground"
        :placeholder="placeholder"
        :disabled="disabled"
        :aria-invalid="error ? true : undefined"
        @focus="focused = true"
        @blur="focused = false; commit()"
        @keydown.enter.prevent="commit()"
        @keydown.up="step($event, 1)"
        @keydown.down="step($event, -1)"
      >
      <span class="shrink-0 text-xs text-muted-foreground">{{ unitText }}</span>
    </div>
    <p
      v-if="error && error.trim()"
      class="text-[11px] leading-tight text-destructive"
    >
      {{ error }}
    </p>
    <p
      v-else-if="hint && !error"
      class="text-[11px] leading-tight text-muted-foreground tabular-nums"
    >
      {{ hint }}
    </p>
  </div>
</template>
