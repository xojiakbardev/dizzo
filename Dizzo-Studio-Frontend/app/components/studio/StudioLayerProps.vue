<script setup lang="ts">
// "Sozlamalar": properties of the selected layer. Mono methods (engraving)
// have no colour picker at all; text can't go below the method's minimum
// size. The print method itself is chosen in the right-hand panel.
import type { DialSource, Layer, TextSource } from '~/lib/design/document';
import { areaMethod, clampIntoZone, FONTS, layerBox, layerLabel, placeInZone, stripWidth } from '~/lib/design/document';
import { useStudioContext } from '~/composables/useStudio';
import { graphicLabel } from '~/lib/design/graphics';
import { fontString, imageDpi, layoutText, LOW_DPI } from '~/lib/design/render';
import { loadFontFace } from '~/lib/design/fonts';
import { isMonoSticker, loadStickerIndex } from '~/lib/design/stickers';
import type { PrintArea } from '~/types/catalog';

const props = defineProps<{
  layer: Layer;
  area: PrintArea | null;
  problems: string[];
  canForward: boolean;
  canBackward: boolean;
}>();
const emit = defineEmits<{
  begin: [];
  patch: [patch: Partial<Layer>];
  update: [patch: Partial<Layer>];
  remove: [];
  duplicate: [];
  move: [step: -1 | 1];
  lock: [on: boolean];
}>();

const textRef = ref<{ $el: HTMLTextAreaElement } | null>(null);
const method = computed(() => (props.area ? areaMethod(props.area, props.layer.method) : undefined));
const mono = computed(() => method.value ? !method.value.colors_allowed : false);
const minFont = computed(() => Math.ceil(method.value?.min_font_mm ? Number(method.value.min_font_mm) : 1));
const dpi = computed(() => imageDpi(props.layer));
const { t, locale } = useI18n();
const stickerName = ref<string | null>(null);
watch([() => props.layer.graphic, locale], async ([g]) => {
  stickerName.value = null;
  if (g?.library !== 'sticker') return;
  const item = (await loadStickerIndex().catch(() => null))?.items.find(i => i.n === g.name);
  stickerName.value = item?.l ?? g.name.replace(/-/g, ' ');
}, { immediate: true });
const title = computed(() => (props.layer.graphic
  ? stickerName.value ?? graphicLabel(props.layer.graphic) ?? layerLabel(props.layer)
  : props.layer.text ? t('studio.layer.text') : props.layer.dial ? t('studio.layer.dial') : t('studio.layer.image')));
const systemLocked = computed(() => props.layer.locked === 'system' || props.layer.id.startsWith('bg-'));
// Stickers are many-coloured: nothing to recolour.
const color = computed(() => {
  const g = props.layer.graphic;
  if (props.layer.text) return props.layer.text.color;
  if (props.layer.dial) return props.layer.dial.color;
  // Many-coloured stickers keep their own colours; single-colour icons don't.
  return g && (g.library !== 'sticker' || isMonoSticker(g.name)) ? g.color : null;
});
const SWATCHES = ['#111827', '#ffffff', '#b91c1c', '#ea580c', '#ca8a04', '#15803d', '#0369a1', '#6d28d9', '#be185d', '#8d4b00'];

const { layers: allLayers } = useStudioContext();

/** A text change re-measures the box around the same centre (once the
 * font — and its subset for these characters — has loaded). With a strip
 * the text never gets wider than it (the size steps down, not below the
 * minimum) and stays in it with the area's other layers. */
async function textPatch(changes: Partial<TextSource>): Promise<Partial<Layer>> {
  let text = { ...props.layer.text!, ...changes };
  await loadFontFace(fontString(text, 64), text.content);
  let layout = layoutText(text);
  const m = method.value;
  const width = m ? stripWidth(m) : null;
  const boxWidth = () => {
    const b = layerBox({ ...props.layer, w_mm: layout.w_mm, h_mm: layout.h_mm });
    return b.x1 - b.x0;
  };
  for (let i = 0; width !== null && i < 4 && boxWidth() > width && text.size_mm > minFont.value; i++) {
    text = { ...text, size_mm: Math.max(minFont.value, Math.floor((text.size_mm * width) / boxWidth() * 10) / 10) };
    layout = layoutText(text);
  }
  const next = { ...props.layer, text, w_mm: layout.w_mm, h_mm: layout.h_mm };
  const own = allLayers.value.filter(l => l.area === props.layer.area);
  const placed = m ? (width === null ? clampIntoZone(next, m) : placeInZone(next, m, own)) : next;
  return { text, w_mm: layout.w_mm, h_mm: layout.h_mm, x_mm: placed.x_mm, y_mm: placed.y_mm };
}

async function setText(changes: Partial<TextSource>) {
  emit('update', await textPatch(changes));
}

async function typeText(content: string) {
  emit('patch', await textPatch({ content: content || ' ' }));
}

/** Clock numerals: the font and look change; the layout follows the face. */
async function setDial(changes: Partial<DialSource>) {
  const dial = { ...props.layer.dial!, ...changes };
  await loadFontFace(fontString(dial, 64), '0123456789XIV');
  emit('update', { dial });
}
const maxDialSize = computed(() => Math.max(minFont.value, Math.round(Math.min(props.layer.w_mm, props.layer.h_mm) * 0.16)));

function setColor(value: string) {
  if (props.layer.dial) void setDial({ color: value });
  else if (props.layer.text) void setText({ color: value });
  else if (props.layer.graphic) emit('update', { graphic: { ...props.layer.graphic, color: value } });
}

defineExpose({
  focusText() {
    textRef.value?.$el.focus();
    textRef.value?.$el.select();
  },
});
</script>

<template>
  <div class="space-y-4 text-xs">
    <div class="flex items-center justify-between gap-2">
      <p class="min-w-0 truncate text-sm font-bold text-foreground">
        {{ title }}
      </p>
      <div class="flex shrink-0 gap-0.5">
        <UiButton
          variant="ghost"
          size="icon-sm"
          :class="layer.locked || systemLocked ? 'text-primary' : ''"
          :disabled="systemLocked"
          :title="systemLocked ? $t('studio.layer.lockedInPlace') : layer.locked ? $t('studio.layer.unlock') : $t('studio.layer.lock')"
          :aria-label="systemLocked ? $t('studio.layer.lockedInPlace') : layer.locked ? $t('studio.layer.unlock') : $t('studio.layer.lock')"
          :aria-pressed="Boolean(layer.locked) || systemLocked"
          @click="emit('lock', !layer.locked)"
        >
          <Icon :name="layer.locked || systemLocked ? 'lucide:lock' : 'lucide:lock-open'" />
        </UiButton>
        <UiButton
          v-if="!layer.dial"
          variant="ghost"
          size="icon-sm"
          :title="$t('studio.layer.duplicate')"
          :aria-label="$t('studio.layer.duplicate')"
          @click="emit('duplicate')"
        >
          <Icon name="lucide:copy" />
        </UiButton>
        <UiButton
          variant="ghost"
          size="icon-sm"
          class="text-destructive hover:bg-destructive/10 hover:text-destructive"
          :title="$t('studio.layer.delete')"
          :aria-label="$t('studio.layer.delete')"
          @click="emit('remove')"
        >
          <Icon name="lucide:trash-2" />
        </UiButton>
      </div>
    </div>

    <ul
      v-if="problems.length"
      class="space-y-0.5 rounded-xl border border-destructive/30 bg-destructive/10 px-3 py-2 text-destructive"
    >
      <li
        v-for="p in problems"
        :key="p"
      >
        • {{ p }}
      </li>
    </ul>

    <template v-if="layer.dial">
      <UiTabs
        :model-value="layer.dial.numerals"
        @update:model-value="(v: string | number) => setDial({ numerals: v as DialSource['numerals'] })"
      >
        <UiTabsList class="grid w-full grid-cols-3">
          <UiTabsTrigger value="arabic">
            12 3 6
          </UiTabsTrigger>
          <UiTabsTrigger value="roman">
            XII III
          </UiTabsTrigger>
          <UiTabsTrigger value="none">
            {{ $t('studio.layer.noNumerals') }}
          </UiTabsTrigger>
        </UiTabsList>
      </UiTabs>
      <UiSelect
        :model-value="layer.dial.font"
        @update:model-value="(v: unknown) => setDial({ font: v as DialSource['font'] })"
      >
        <UiSelectTrigger
          class="w-full"
          :aria-label="$t('studio.layer.font')"
          :style="{ fontFamily: `'${layer.dial.font}'` }"
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
      <div class="grid grid-cols-[1fr_auto] items-end gap-2">
        <label class="block">
          <span class="mb-1 block text-[11px] font-semibold text-muted-foreground">{{ $t('studio.layer.numeralSize') }}</span>
          <UiInput
            type="number"
            :min="minFont"
            :max="maxDialSize"
            step="1"
            :model-value="Math.round(layer.dial.size_mm)"
            @change="setDial({ size_mm: Math.min(maxDialSize, Math.max(minFont, Math.round(Number(($event.target as HTMLInputElement).value)) || minFont)) })"
          />
        </label>
        <div class="flex gap-1">
          <UiButton
            variant="outline"
            size="icon"
            class="font-bold"
            :class="layer.dial.bold ? 'border-primary bg-primary/10' : ''"
            :aria-pressed="layer.dial.bold"
            :aria-label="$t('studio.layer.bold')"
            @click="setDial({ bold: !layer.dial.bold })"
          >
            B
          </UiButton>
          <UiButton
            variant="outline"
            size="icon"
            class="italic"
            :class="layer.dial.italic ? 'border-primary bg-primary/10' : ''"
            :aria-pressed="layer.dial.italic"
            :aria-label="$t('studio.layer.italic')"
            @click="setDial({ italic: !layer.dial.italic })"
          >
            I
          </UiButton>
        </div>
      </div>
      <UiLabel class="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-border px-3 py-2.5 text-[13px] font-medium">
        {{ $t('studio.layer.ticks') }}
        <UiSwitch
          :model-value="layer.dial.ticks"
          @update:model-value="(on: boolean) => setDial({ ticks: on })"
        />
      </UiLabel>
    </template>

    <template v-if="layer.text">
      <UiTextarea
        ref="textRef"
        :model-value="layer.text.content"
        rows="2"
        maxlength="500"
        class="min-h-16 resize-y"
        :aria-label="$t('studio.layer.text')"
        @focus="emit('begin')"
        @update:model-value="(v: string | number) => typeText(String(v))"
      />
      <UiSelect
        :model-value="layer.text.font"
        @update:model-value="(v: unknown) => setText({ font: v as TextSource['font'] })"
      >
        <UiSelectTrigger
          class="w-full"
          :aria-label="$t('studio.layer.font')"
          :style="{ fontFamily: `'${layer.text.font}'` }"
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
      <div class="grid grid-cols-[1fr_auto] items-end gap-2">
        <label class="block">
          <span class="mb-1 block text-[11px] font-semibold text-muted-foreground">{{ $t('studio.layer.size') }}</span>
          <UiInput
            type="number"
            :min="minFont"
            max="300"
            step="1"
            :model-value="Math.round(layer.text.size_mm)"
            @change="setText({ size_mm: Math.max(minFont, Math.round(Number(($event.target as HTMLInputElement).value)) || minFont) })"
          />
        </label>
        <div class="flex gap-1">
          <UiButton
            variant="outline"
            size="icon"
            class="font-bold"
            :class="layer.text.bold ? 'border-primary bg-primary/10' : ''"
            :aria-pressed="layer.text.bold"
            :aria-label="$t('studio.layer.bold')"
            @click="setText({ bold: !layer.text.bold })"
          >
            B
          </UiButton>
          <UiButton
            variant="outline"
            size="icon"
            class="italic"
            :class="layer.text.italic ? 'border-primary bg-primary/10' : ''"
            :aria-pressed="layer.text.italic"
            :aria-label="$t('studio.layer.italic')"
            @click="setText({ italic: !layer.text.italic })"
          >
            I
          </UiButton>
        </div>
      </div>
      <UiTabs
        :model-value="layer.text.align"
        @update:model-value="(v: string | number) => setText({ align: v as TextSource['align'] })"
      >
        <UiTabsList class="grid w-full grid-cols-3">
          <UiTabsTrigger
            v-for="a in (['left', 'center', 'right'] as const)"
            :key="a"
            :value="a"
            :aria-label="$t(`studio.layer.align.${a}`)"
          >
            <Icon :name="`lucide:align-${a}`" />
          </UiTabsTrigger>
        </UiTabsList>
      </UiTabs>
    </template>

    <div v-if="color !== null && !mono">
      <span class="mb-1.5 block text-[11px] font-semibold text-muted-foreground">{{ $t('studio.layer.color') }}</span>
      <div class="flex flex-wrap items-center gap-1.5">
        <UiButton
          v-for="c in SWATCHES"
          :key="c"
          variant="outline"
          size="icon-xs"
          class="rounded-full"
          :class="color.toLowerCase() === c ? 'ring-2 ring-primary ring-offset-1' : ''"
          :style="{ background: c }"
          :aria-label="c"
          :aria-pressed="color.toLowerCase() === c"
          @click="setColor(c)"
        />
        <input
          type="color"
          :value="color"
          class="h-7 w-9 cursor-pointer rounded-md border border-input"
          :aria-label="$t('studio.layer.customColor')"
          @change="setColor(($event.target as HTMLInputElement).value)"
        >
      </div>
    </div>

    <p
      v-if="layer.image && dpi !== null && dpi < 100"
      class="rounded-xl bg-red-50 px-3 py-2 text-[11px] font-medium text-red-900"
    >
      {{ $t('studio.layer.lowDpiBlocked', { dpi: Math.round(dpi) }) }}
    </p>
    <p
      v-else-if="layer.image && dpi !== null && dpi < LOW_DPI"
      class="rounded-xl bg-amber-50 px-3 py-2 text-[11px] text-amber-900"
    >
      {{ $t('studio.layer.lowDpi', { dpi: Math.round(dpi) }) }}
    </p>

    <div class="grid grid-cols-2 gap-2">
      <UiButton
        variant="outline"
        :disabled="!canForward"
        @click="emit('move', 1)"
      >
        <Icon name="lucide:bring-to-front" />
        {{ $t('studio.layer.forward') }}
      </UiButton>
      <UiButton
        variant="outline"
        :disabled="!canBackward"
        @click="emit('move', -1)"
      >
        <Icon name="lucide:send-to-back" />
        {{ $t('studio.layer.backward') }}
      </UiButton>
    </div>
  </div>
</template>
