<script setup lang="ts">
import type { DialSource, Font, Layer } from '~/lib/design/document';
import { FONTS } from '~/lib/design/document';
import type { PrintArea } from '~/types/catalog';
import { fontString } from '~/lib/design/render';

const props = defineProps<{
  dialLayer: Layer | null;
  area: PrintArea | null;
  colorHex?: string;
  surfaceHex?: string;
}>();

const emit = defineEmits<{
  add: [];
  update: [changes: Partial<DialSource>];
  remove: [];
}>();

const { t } = useI18n();

const PALETTE = [
  '#000000', '#ffffff', '#dc2626', '#2563eb', '#16a34a', '#ca8a04', '#9333ea', '#ea580c', '#475569', '#d4af37',
];

const dial = computed(() => props.dialLayer?.dial ?? null);

const minSize = 6;
const maxSize = computed(() => {
  if (!props.dialLayer) return 36;
  return Math.max(minSize, Math.round(Math.min(props.dialLayer.w_mm, props.dialLayer.h_mm) * 0.16));
});

async function setDial(changes: Partial<DialSource>) {
  if (!dial.value) return;
  const next = { ...dial.value, ...changes };
  await document.fonts.load(fontString(next, 64), '0123456789XIV');
  emit('update', changes);
}
</script>

<template>
  <div class="space-y-4 text-xs">
    <!-- If no dial exists, show a prominent Add Dial button -->
    <div
      v-if="!dial"
      class="rounded-2xl border-2 border-dashed border-primary/40 bg-primary/5 p-5 text-center space-y-3"
    >
      <div class="mx-auto flex size-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
        <Icon name="lucide:clock-3" class="size-7" />
      </div>
      <div>
        <h3 class="text-sm font-bold text-foreground">
          {{ $t('studio.layers.clockDial') }}
        </h3>
        <p class="mt-1 text-xs text-muted-foreground">
          {{ $t('studio.layers.clockDialDeleted') }}
        </p>
      </div>
      <UiButton
        class="h-11 w-full font-semibold shadow-sm"
        @click="emit('add')"
      >
        <Icon name="lucide:plus" class="text-lg mr-1" />
        {{ $t('studio.layers.restoreDial') }}
      </UiButton>
    </div>

    <!-- If dial exists, show full controls -->
    <template v-else>
      <!-- Numerals style selection -->
      <section class="space-y-1.5">
        <span class="block text-[11px] font-semibold text-muted-foreground">
          {{ $t('studio.layer.dial') }}
        </span>
        <UiTabs
          :model-value="dial.numerals"
          @update:model-value="(v: string | number) => setDial({ numerals: v as DialSource['numerals'] })"
        >
          <UiTabsList class="grid w-full grid-cols-3">
            <UiTabsTrigger value="arabic" class="font-bold">
              12 3 6
            </UiTabsTrigger>
            <UiTabsTrigger value="roman" class="font-serif font-bold">
              XII III
            </UiTabsTrigger>
            <UiTabsTrigger value="none">
              {{ $t('studio.layer.noNumerals') }}
            </UiTabsTrigger>
          </UiTabsList>
        </UiTabs>
      </section>

      <!-- Font selection (only if numerals !== 'none') -->
      <section v-if="dial.numerals !== 'none'" class="space-y-1.5">
        <span class="block text-[11px] font-semibold text-muted-foreground">
          {{ $t('studio.layer.font') }}
        </span>
        <UiSelect
          :model-value="dial.font"
          @update:model-value="(v: unknown) => setDial({ font: v as Font })"
        >
          <UiSelectTrigger
            class="w-full"
            :aria-label="$t('studio.layer.font')"
            :style="{ fontFamily: `'${dial.font}'` }"
          >
            <UiSelectValue />
          </UiSelectTrigger>
          <UiSelectContent>
            <UiSelectItem
              v-for="f in FONTS"
              :key="f"
              :value="f"
              :style="{ fontFamily: `'${f}'` }"
            >
              {{ f }}
            </UiSelectItem>
          </UiSelectContent>
        </UiSelect>
      </section>

      <!-- Size and styling -->
      <section v-if="dial.numerals !== 'none'" class="grid grid-cols-[1fr_auto] items-end gap-2">
        <label class="block">
          <span class="mb-1 block text-[11px] font-semibold text-muted-foreground">
            {{ $t('studio.layer.numeralSize') }}
          </span>
          <UiInput
            type="number"
            :min="minSize"
            :max="maxSize"
            step="1"
            :model-value="Math.round(dial.size_mm)"
            @change="setDial({ size_mm: Math.min(maxSize, Math.max(minSize, Math.round(Number(($event.target as HTMLInputElement).value)) || minSize)) })"
          />
        </label>
        <div class="flex gap-1">
          <UiButton
            variant="outline"
            size="icon"
            class="font-bold"
            :class="dial.bold ? 'border-primary bg-primary/10 text-primary' : ''"
            :aria-pressed="dial.bold"
            :aria-label="$t('studio.layer.bold')"
            @click="setDial({ bold: !dial.bold })"
          >
            B
          </UiButton>
          <UiButton
            variant="outline"
            size="icon"
            class="italic font-serif"
            :class="dial.italic ? 'border-primary bg-primary/10 text-primary' : ''"
            :aria-pressed="dial.italic"
            :aria-label="$t('studio.layer.italic')"
            @click="setDial({ italic: !dial.italic })"
          >
            I
          </UiButton>
        </div>
      </section>

      <!-- Minute ticks toggle -->
      <UiLabel class="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-border px-3.5 py-3 text-[13px] font-medium bg-card hover:bg-accent/5 transition-colors">
        <div class="flex items-center gap-2">
          <Icon name="lucide:timer" class="size-4 text-muted-foreground" />
          <span>{{ $t('studio.layer.ticks') }}</span>
        </div>
        <UiSwitch
          :model-value="dial.ticks"
          @update:model-value="(on: boolean) => setDial({ ticks: on })"
        />
      </UiLabel>

      <!-- Dial Color -->
      <section class="space-y-2">
        <span class="block text-[11px] font-semibold text-muted-foreground">
          {{ $t('studio.layer.color') }}
        </span>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="hex in PALETTE"
            :key="hex"
            type="button"
            class="size-7 rounded-full border border-black/15 shadow-xs transition-transform hover:scale-110 active:scale-95 flex items-center justify-center"
            :style="{ background: hex }"
            :class="dial.color.toLowerCase() === hex.toLowerCase() ? 'ring-2 ring-primary ring-offset-2 scale-105' : ''"
            @click="setDial({ color: hex })"
          >
            <Icon
              v-if="dial.color.toLowerCase() === hex.toLowerCase()"
              name="lucide:check"
              class="size-3.5"
              :class="hex.toLowerCase() === '#ffffff' ? 'text-black' : 'text-white'"
            />
          </button>
          <!-- Custom color input -->
          <label
            class="relative size-7 cursor-pointer overflow-hidden rounded-full border border-border bg-card shadow-xs transition-transform hover:scale-110 flex items-center justify-center"
            :title="$t('studio.layer.customColor')"
          >
            <Icon name="lucide:pipette" class="size-3.5 text-muted-foreground" />
            <input
              type="color"
              :value="dial.color"
              class="absolute inset-0 cursor-pointer opacity-0"
              @input="setDial({ color: ($event.target as HTMLInputElement).value })"
            >
          </label>
        </div>
      </section>

      <!-- Delete dial button -->
      <div class="pt-2 border-t border-border">
        <UiButton
          variant="outline"
          class="w-full text-rose-600 border-rose-200 hover:bg-rose-50 hover:text-rose-700 hover:border-rose-300 font-medium"
          @click="emit('remove')"
        >
          <Icon name="lucide:trash-2" class="size-4 mr-1.5" />
          {{ $t('studio.layer.delete') }}
        </UiButton>
      </div>
    </template>
  </div>
</template>
