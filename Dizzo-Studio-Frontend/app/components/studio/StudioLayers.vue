<script setup lang="ts">
// "Qatlamlar": layers of the open area (top first) — each shown as itself
// (the picture, the sticker, the shape in its colour, the text in its
// font), dragged by its grip to a new place in the stack, locked or
// deleted — then layers of other areas, and "not placed" ones (their area
// doesn't exist on the current variant's shape).
import GraphicThumb from '~/components/studio/panels/GraphicThumb.vue';
import type { Layer } from '~/lib/design/document';
import { isBackgroundLayer, layerLabel } from '~/lib/design/document';
import { graphicLabel, resolveGraphic } from '~/lib/design/graphics';
import { imageDpi, LOW_DPI } from '~/lib/design/render';
import { ensureStickers, loadStickerIndex, packVersion, stickerUrl } from '~/lib/design/stickers';
import { isDialArea } from '~/lib/design/dial';
import type { PrintArea } from '~/types/catalog';

const props = defineProps<{
  layers: Layer[];
  areas: PrintArea[];
  selectedArea: string | null;
  selectedId: string | null;
  problems: Record<string, string[]>;
  linkedFrom: string | null; // the open area is synced from this area
}>();
const emit = defineEmits<{
  select: [id: string];
  reorder: [id: string, aboveId: string | null];
  lock: [id: string, on: boolean];
  remove: [id: string];
  place: [id: string];
  addDial: [areaKey: string];
}>();

// A graphic is called by its own name ("Qizil yurak", "Yulduz"), not its kind.
const { t, locale } = useI18n();
const stickerNames = ref<Map<string, string>>(new Map());
async function loadNames() {
  try {
    stickerNames.value = new Map((await loadStickerIndex()).items.map(i => [i.n, i.l]));
  }
  catch {
    // the kind's name stays
  }
}
onMounted(loadNames);
watch(locale, loadNames);
function label(l: Layer): string {
  if (isBackgroundLayer(l)) return t('studio.layer.background');
  if (l.dial) return t('studio.layer.dial');
  if (l.graphic?.library === 'sticker') return stickerNames.value.get(l.graphic.name) ?? l.graphic.name.replace(/-/g, ' ');
  if (l.graphic) return graphicLabel(l.graphic) ?? layerLabel(l);
  if (l.text) return l.text.content.split('\n').join(' ') || t('studio.layer.text');
  return layerLabel(l);
}
const areaName = (key: string | null) => props.areas.find(a => a.key === key)?.name ?? '';
const here = computed(() => props.layers.filter(l => l.area === props.selectedArea));
const top = computed(() => [...here.value].reverse()); // as listed: top first
const currentArea = computed(() => props.areas.find(a => a.key === props.selectedArea) ?? null);
const isClockArea = computed(() => Boolean(currentArea.value && isDialArea(currentArea.value)));
const hasDial = computed(() => here.value.some(l => Boolean(l.dial)));
const elsewhere = computed(() => props.layers.filter(l => l.area !== null && l.area !== props.selectedArea));
const unplaced = computed(() => props.layers.filter(l => l.area === null));
watch(() => props.layers, ls => void ensureStickers(ls.flatMap(l => (l.graphic?.library === 'sticker' ? [l.graphic.name] : []))).catch(() => {}), { immediate: true });
function thumb(l: Layer): string | null {
  void packVersion.value;
  if (l.image) return l.image.url;
  if (l.graphic?.library === 'sticker') return stickerUrl(l.graphic.name);
  return null;
}

const lowDpi = (l: Layer) => {
  const dpi = imageDpi(l);
  return dpi !== null && dpi < LOW_DPI;
};
const locked = (l: Layer) => Boolean(l.locked) || isBackgroundLayer(l);
const systemLocked = (l: Layer) => l.locked === 'system' || isBackgroundLayer(l);

// ── Dragging a row by its grip (mouse and touch alike) ──
const listRef = ref<HTMLElement | null>(null);
const dragging = ref<string | null>(null);
const dropIndex = ref<number | null>(null); // gap before this row of `top`
const dragY = ref(0);
let rows: DOMRect[] = [];

function startDrag(event: PointerEvent, id: string) {
  if (event.button !== 0) return;
  event.preventDefault();
  dragging.value = id;
  rows = [...(listRef.value?.querySelectorAll('[data-row]') ?? [])].map(el => el.getBoundingClientRect());
  dragY.value = event.clientY;
  dropIndex.value = top.value.findIndex(l => l.id === id);
  (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
}
function moveDrag(event: PointerEvent) {
  if (!dragging.value) return;
  dragY.value = event.clientY;
  let i = rows.findIndex(r => event.clientY < r.top + r.height / 2);
  if (i < 0) i = rows.length;
  dropIndex.value = i;
}
function endDrag() {
  const id = dragging.value;
  const i = dropIndex.value;
  dragging.value = null;
  dropIndex.value = null;
  if (!id || i === null) return;
  const from = top.value.findIndex(l => l.id === id);
  if (i === from || i === from + 1) return;
  // Dropped in the gap before row i (the list is top first): it goes right
  // above the layer listed after that gap (none: to the bottom).
  const listed = top.value.filter(l => l.id !== id);
  const at = i > from ? i - 1 : i;
  const below = listed[at] ?? null; // the layer that ends up right under it
  emit('reorder', id, below ? below.id : null);
}
</script>

<template>
  <div class="space-y-4">
    <section>
      <p
        v-if="linkedFrom"
        class="rounded-lg bg-secondary-50 px-3 py-2 text-xs text-secondary-900"
      >
        {{ $t('studio.layers.linked', { name: linkedFrom }) }}
      </p>
      <p
        v-else-if="!here.length"
        class="rounded-lg bg-brand-surface-low px-3 py-2 text-xs text-brand-muted"
      >
        {{ $t('studio.layers.empty') }}
      </p>
      <ul
        ref="listRef"
        class="space-y-1"
      >
        <li
          v-for="(l, i) in top"
          :key="l.id"
          data-row
          class="relative flex items-center gap-2 rounded-xl border px-1.5 py-1.5 text-sm transition-colors"
          :class="[
            l.id === selectedId ? 'border-secondary-400 bg-secondary-50' : 'border-transparent hover:bg-brand-surface-low',
            dragging === l.id ? 'opacity-40' : '',
          ]"
        >
          <span
            v-if="dragging && dropIndex === i"
            class="pointer-events-none absolute inset-x-1 -top-[3px] h-0.5 rounded bg-primary"
          />
          <span
            v-if="dragging && dropIndex === top.length && i === top.length - 1"
            class="pointer-events-none absolute inset-x-1 -bottom-[3px] h-0.5 rounded bg-primary"
          />
          <button
            type="button"
            class="flex h-10 w-6 shrink-0 cursor-grab touch-none items-center justify-center rounded-md text-base text-brand-muted hover:bg-white active:cursor-grabbing"
            :aria-label="$t('studio.layers.dragLabel')"
            :title="$t('studio.layers.dragHint')"
            @pointerdown="startDrag($event, l.id)"
            @pointermove="moveDrag"
            @pointerup="endDrag"
            @pointercancel="endDrag"
          >
            <Icon name="lucide:grip-vertical" />
          </button>
          <button
            type="button"
            class="flex min-w-0 flex-1 items-center gap-2.5 text-left"
            @click="emit('select', l.id)"
          >
            <span class="flex size-10 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-border bg-white">
              <img
                v-if="thumb(l)"
                :src="thumb(l)!"
                alt=""
                class="max-h-full max-w-full object-contain"
              >
              <span
                v-else-if="isBackgroundLayer(l)"
                class="size-7 rounded-md border border-black/10"
                :style="{ background: l.graphic?.color }"
              />
              <span
                v-else-if="l.graphic && resolveGraphic(l.graphic)"
                class="flex size-7 items-center justify-center"
                :style="{ color: l.graphic.color }"
              >
                <GraphicThumb :def="resolveGraphic(l.graphic)!" />
              </span>
              <span
                v-else-if="l.text"
                class="text-[17px] leading-none"
                :style="{ fontFamily: `'${l.text.font}'`, color: l.text.color === '#ffffff' ? '#94a3b8' : l.text.color, fontWeight: l.text.bold ? 700 : 400 }"
              >Aa</span>
              <Icon
                v-else-if="l.dial"
                name="lucide:clock-3"
                class="text-xl text-slate-600"
              />
              <UiSkeleton
                v-else
                class="size-7"
              />
            </span>
            <span class="truncate font-medium text-slate-800">{{ label(l) }}</span>
            <Icon
              v-if="problems[l.id]"
              name="lucide:triangle-alert"
              class="shrink-0 text-amber-600"
            />
            <Icon
              v-else-if="lowDpi(l)"
              name="lucide:image-off"
              class="shrink-0 text-amber-600"
            />
          </button>
          <UiButton
            variant="ghost"
            size="icon-sm"
            :class="locked(l) ? 'text-primary' : 'text-brand-muted'"
            :disabled="systemLocked(l)"
            :aria-label="systemLocked(l) ? $t('studio.layer.lockedInPlace') : locked(l) ? $t('studio.layer.unlock') : $t('studio.layer.lock')"
            :aria-pressed="locked(l)"
            @click="emit('lock', l.id, !l.locked)"
          >
            <Icon :name="locked(l) ? 'lucide:lock' : 'lucide:lock-open'" />
          </UiButton>
          <UiButton
            variant="ghost"
            size="icon-sm"
            class="text-rose-600 hover:bg-rose-50 hover:text-rose-700"
            :aria-label="$t('studio.layer.delete')"
            @click="emit('remove', l.id)"
          >
            <Icon name="lucide:trash-2" />
          </UiButton>
        </li>
      </ul>
      <div
        v-if="isClockArea && !hasDial"
        class="mt-2.5 rounded-xl border border-dashed border-primary/40 bg-primary/5 p-3.5 text-center"
      >
        <div class="flex items-center justify-center gap-2 text-xs font-semibold text-foreground">
          <Icon name="lucide:clock-3" class="size-4 text-primary" />
          <span>{{ $t('studio.layers.clockDial') }}</span>
        </div>
        <p class="mt-1 text-[11px] text-muted-foreground">
          {{ $t('studio.layers.clockDialDeleted') }}
        </p>
        <UiButton
          size="sm"
          variant="outline"
          class="mt-2.5 h-8 gap-1.5 text-xs bg-white hover:bg-primary hover:text-white"
          @click="emit('addDial', selectedArea!)"
        >
          <Icon name="lucide:plus" class="size-3.5" />
          {{ $t('studio.layers.addDial') }}
        </UiButton>
      </div>
    </section>

    <section v-if="elsewhere.length">
      <p class="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-brand-muted">
        {{ $t('studio.layers.elsewhere') }}
      </p>
      <ul class="space-y-1">
        <li
          v-for="l in elsewhere"
          :key="l.id"
        >
          <button
            type="button"
            class="flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2 text-left text-sm hover:bg-brand-surface-low"
            @click="emit('select', l.id)"
          >
            <span class="truncate text-slate-700">{{ label(l) }}</span>
            <span class="ml-auto shrink-0 text-[10px] text-brand-muted">{{ areaName(l.area) }}</span>
          </button>
        </li>
      </ul>
    </section>

    <section
      v-if="unplaced.length"
      class="rounded-xl border border-amber-200 bg-amber-50/60 p-2.5"
    >
      <p class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-amber-800">
        {{ $t('studio.layers.unplaced') }}
      </p>
      <ul class="space-y-1">
        <li
          v-for="l in unplaced"
          :key="l.id"
          class="flex items-center gap-2 text-xs"
        >
          <span class="min-w-0 flex-1 truncate text-slate-800">{{ label(l) }}</span>
          <UiButton
            variant="outline"
            size="xs"
            :disabled="!selectedArea"
            @click="emit('place', l.id)"
          >
            {{ $t('studio.layers.placeHere') }}
          </UiButton>
          <UiButton
            variant="ghost"
            size="icon-xs"
            class="text-rose-600"
            :aria-label="$t('studio.layer.delete')"
            @click="emit('remove', l.id)"
          >
            <Icon name="lucide:trash-2" />
          </UiButton>
        </li>
      </ul>
    </section>
  </div>
</template>
