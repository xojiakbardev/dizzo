<script setup lang="ts">
// "Matn": plain text from the main button, ready-made headings, or a
// sample in every font. Every text starts at the same size (the page
// decides it); the customer changes it afterwards.
import type { Font } from '~/lib/design/document';
import { FONTS } from '~/lib/design/document';

export interface TextPreset { content: string; font: Font; bold: boolean; italic: boolean }

defineProps<{ disabled: boolean }>();
const emit = defineEmits<{ add: [preset: TextPreset] }>();

const { t } = useI18n();

// The sample texts are in the page's language: they go onto the design as they are.
const plain = computed<TextPreset>(() => ({ content: t('studio.text.plain'), font: 'Open Sans', bold: false, italic: false }));

const HEADINGS: Array<Omit<TextPreset, 'content'> & { key: string; cls: string }> = [
  { key: 'heading', font: 'Montserrat', bold: true, italic: false, cls: 'text-2xl font-extrabold' },
  { key: 'subheading', font: 'Montserrat', bold: true, italic: false, cls: 'text-base font-bold' },
  { key: 'bigHeading', font: 'Oswald', bold: true, italic: false, cls: 'text-xl font-bold tracking-wide' },
  { key: 'birthday', font: 'Rubik', bold: true, italic: false, cls: 'text-lg font-bold' },
  { key: 'elegant', font: 'Playfair Display', bold: true, italic: true, cls: 'text-xl font-bold italic' },
  { key: 'congrats', font: 'Lobster', bold: false, italic: false, cls: 'text-xl' },
  { key: 'goodDays', font: 'Pacifico', bold: false, italic: false, cls: 'text-lg' },
  { key: 'bestDad', font: 'Caveat', bold: true, italic: false, cls: 'text-2xl font-bold' },
  { key: 'withLove', font: 'Comfortaa', bold: true, italic: false, cls: 'text-lg font-bold' },
];
const headings = computed(() => HEADINGS.map(({ key, cls, ...h }) => ({ key, cls, preset: { ...h, content: t(`studio.text.presets.${key}`) } })));
</script>

<template>
  <div class="space-y-5">
    <UiButton
      class="h-11 w-full font-semibold"
      :disabled="disabled"
      @click="emit('add', plain)"
    >
      <Icon
        name="lucide:plus"
        class="text-lg"
      />
      {{ $t('studio.text.add') }}
    </UiButton>

    <section class="space-y-2">
      <UiButton
        v-for="h in headings"
        :key="h.key"
        variant="outline"
        class="h-auto w-full justify-start whitespace-normal px-3.5 py-2.5 text-left leading-tight text-foreground hover:border-primary/60 hover:bg-primary/5"
        :class="h.cls"
        :style="{ fontFamily: `'${h.preset.font}'` }"
        :disabled="disabled"
        @click="emit('add', h.preset)"
      >
        {{ h.preset.content }}
      </UiButton>
    </section>

    <section>
      <p class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
        {{ $t('studio.text.fonts') }}
      </p>
      <div class="grid grid-cols-2 gap-2">
        <UiButton
          v-for="f in FONTS"
          :key="f"
          variant="outline"
          class="h-auto flex-col items-start gap-0 px-3 py-2.5 text-left hover:border-primary/60 hover:bg-primary/5"
          :disabled="disabled"
          @click="emit('add', { content: $t('studio.text.sample'), font: f, bold: false, italic: false })"
        >
          <span
            class="text-lg font-normal leading-7 text-foreground"
            :style="{ fontFamily: `'${f}'` }"
          >{{ $t('studio.text.sample') }}</span>
          <span class="text-[10px] font-normal text-muted-foreground">{{ f }}</span>
        </UiButton>
      </div>
    </section>
  </div>
</template>
