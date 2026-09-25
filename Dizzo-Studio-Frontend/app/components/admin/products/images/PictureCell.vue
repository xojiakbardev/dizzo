<script setup lang="ts">
// One picture list (the cover, the product's, a type's base shot, a colour's
// card or its gallery) as a strip: drop files or pictures from the tray /
// another list onto it, drag to reorder, star to make main where a list has
// a main one, delete. Every change saves at once.
import { MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import { PICTURE_DRAG, PICTURES_KEY, type DraggedPicture } from '~/composables/useProductPictures';

const props = withDefaults(defineProps<{
  cellKey: string;
  /** The generate button (types and colours with a 3D shape). */
  canGenerate?: boolean;
  /** What that button says, when "Rasm yaratish" is not the right words. */
  generateLabel?: string;
  /** A colour's gallery has no main picture — the type's base shot and the
   * colour's card are their own lists now — so it hides the star. */
  starrable?: boolean;
  size?: 'sm' | 'md';
}>(), { canGenerate: false, generateLabel: undefined, starrable: true, size: 'sm' });

const { t } = useI18n();
const store = inject(PICTURES_KEY)!;
const images = computed(() => store.images(props.cellKey));
const max = computed(() => store.maxOf(props.cellKey));
const uploads = computed(() => store.uploadsOf(props.cellKey));
const saving = computed(() => store.isSaving(props.cellKey));
const error = computed(() => store.errorOf(props.cellKey));
// The cover (one picture) is replaced by a new one, never "full".
const full = computed(() => max.value > 1 && images.value.length >= max.value);
const tile = computed(() => (props.size === 'md' ? 'size-24' : 'size-20'));

const over = ref(false); // something is dragged over the strip
const overIndex = ref<number | null>(null); // … over this tile
let depth = 0;

function dragged(event: DragEvent): DraggedPicture | null {
  const raw = event.dataTransfer?.getData(PICTURE_DRAG);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as DraggedPicture;
  }
  catch {
    return null;
  }
}

const accepts = (event: DragEvent) => {
  const types = event.dataTransfer?.types ?? [];
  return types.includes(PICTURE_DRAG) || types.includes('Files');
};

function onEnter(event: DragEvent) {
  if (!accepts(event)) return;
  depth++;
  over.value = true;
}
function onLeave() {
  depth = Math.max(0, depth - 1);
  if (!depth) {
    over.value = false;
    overIndex.value = null;
  }
}
function onOver(event: DragEvent) {
  if (!accepts(event)) return;
  event.preventDefault();
  if (event.dataTransfer) event.dataTransfer.dropEffect = event.dataTransfer.types.includes('Files') ? 'copy' : 'move';
}

function onDrop(event: DragEvent, index: number | null = null) {
  // Files dropped on the "Qo‘shish" tile are taken by the tile itself.
  const handled = event.defaultPrevented;
  event.preventDefault();
  event.stopPropagation();
  const at = index ?? overIndex.value ?? images.value.length;
  depth = 0;
  over.value = false;
  overIndex.value = null;
  const picture = dragged(event);
  if (picture) {
    store.place(picture, props.cellKey, at);
    return;
  }
  if (handled) return;
  const files = Array.from(event.dataTransfer?.files ?? []).filter(f => MEDIA_IMAGE_TYPES.includes(f.type));
  if (files.length) store.upload(props.cellKey, files);
}

function onDragStart(event: DragEvent, index: number) {
  const img = images.value[index]!;
  const payload: DraggedPicture = { mediaId: img.media_id, url: img.url, from: props.cellKey };
  event.dataTransfer?.setData(PICTURE_DRAG, JSON.stringify(payload));
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move';
}

function makeMain(index: number) {
  if (index === 0) return;
  const next = [...images.value];
  const [item] = next.splice(index, 1);
  store.set(props.cellKey, [item!, ...next]);
}

function remove(index: number) {
  store.set(props.cellKey, images.value.filter((_, i) => i !== index));
}
</script>

<template>
  <div
    class="relative min-w-0 rounded-xl border p-2 transition-colors"
    :class="[
      over ? 'border-primary bg-primary/5 ring-2 ring-primary/30' : images.length || uploads.length ? 'border-border bg-card' : 'border-dashed border-amber-400/70 bg-amber-50/60 dark:bg-amber-400/5',
    ]"
    :data-cell="cellKey"
    @dragenter="onEnter"
    @dragleave="onLeave"
    @dragover="onOver"
    @drop="onDrop($event)"
  >
    <div class="flex items-center gap-2 overflow-x-auto pb-0.5 scrollbar-none">
      <div
        v-for="(image, index) in images"
        :key="image.media_id"
        class="group relative shrink-0 cursor-grab active:cursor-grabbing"
        :class="[tile, overIndex === index ? 'before:absolute before:-left-1.5 before:inset-y-1 before:w-1 before:rounded-full before:bg-primary' : '']"
        draggable="true"
        @dragstart="onDragStart($event, index)"
        @dragover="overIndex = index"
        @drop="onDrop($event, index)"
      >
        <MediaThumb
          :src="image.url"
          fit="contain"
          class="size-full border border-border bg-[repeating-conic-gradient(var(--color-muted)_0_25%,transparent_0_50%)] bg-size-[16px_16px]"
        />
        <span
          v-if="starrable && index === 0 && images.length > 1"
          class="pointer-events-none absolute left-1 top-1 rounded-md bg-amber-400 px-1 text-[10px] font-semibold text-white"
        >{{ t('admin.images.mainBadge') }}</span>
        <UiButton
          v-if="starrable && index > 0"
          type="button"
          variant="ghost"
          size="icon-xs"
          class="absolute right-1 top-1 rounded-full bg-white/90 text-slate-500 opacity-0 shadow-xs transition hover:bg-white hover:text-amber-500 group-hover:opacity-100 group-focus-within:opacity-100 pointer-coarse:opacity-100"
          :aria-label="t('admin.images.makeMain')"
          :title="t('admin.images.makeMain')"
          @click="makeMain(index)"
        >
          <Icon
            name="lucide:star"
            class="text-sm"
          />
        </UiButton>
        <UiButton
          type="button"
          variant="ghost"
          size="icon-xs"
          class="absolute bottom-1 right-1 rounded-full bg-foreground/70 text-rose-200 opacity-0 transition hover:bg-foreground/85 hover:text-rose-100 group-hover:opacity-100 group-focus-within:opacity-100 pointer-coarse:opacity-100"
          :aria-label="t('admin.common.delete')"
          :title="t('admin.common.delete')"
          @click="remove(index)"
        >
          <Icon
            name="lucide:trash-2"
            class="text-sm"
          />
        </UiButton>
      </div>

      <!-- Files on their way up: their local previews, dimmed. -->
      <div
        v-for="u in uploads"
        :key="u.id"
        class="relative shrink-0"
        :class="tile"
      >
        <img
          :src="u.preview"
          alt=""
          class="size-full rounded-xl border border-border object-contain opacity-50"
        >
        <Icon
          name="lucide:loader-2"
          class="absolute inset-0 m-auto animate-spin text-xl text-primary"
        />
      </div>

      <p
        v-if="!images.length && !uploads.length"
        class="flex h-20 shrink-0 items-center gap-1.5 px-2 text-sm font-medium text-amber-700 dark:text-amber-400"
      >
        <Icon
          name="lucide:image-off"
          class="text-base"
        />
        {{ t('admin.images.noPicture') }}
      </p>

      <UiFileInput
        v-if="!full"
        multiple
        :accept="MEDIA_IMAGE_TYPES.join(',')"
        class="shrink-0 flex-col gap-1 px-0 py-0 text-[11px] font-medium"
        :class="tile"
        @select="files => store.upload(cellKey, files)"
      >
        <Icon
          name="lucide:image-plus"
          class="text-xl"
        />
        {{ t('admin.common.add') }}
      </UiFileInput>

      <UiButton
        v-if="canGenerate && !full"
        type="button"
        variant="outline"
        class="h-20 shrink-0 flex-col gap-1 rounded-xl px-2 text-[11px] font-medium"
        :class="size === 'md' ? 'h-24' : ''"
        @click="store.generate(cellKey)"
      >
        <Icon
          name="lucide:wand-sparkles"
          class="text-xl"
        />
        {{ generateLabel ?? t('admin.images.generate') }}
      </UiButton>

      <slot name="actions" />
    </div>

    <div class="mt-1 flex items-center gap-2 px-0.5 text-[11px] text-muted-foreground">
      <span class="tabular-nums">{{ images.length }} / {{ max }}</span>
      <span
        v-if="saving"
        class="inline-flex items-center gap-1 text-primary"
      >
        <Icon
          name="lucide:loader-2"
          class="animate-spin"
        />
        {{ t('admin.images.saving') }}
      </span>
      <span
        v-if="error"
        class="inline-flex min-w-0 items-center gap-1 truncate text-destructive"
      >
        <Icon name="lucide:circle-alert" />
        {{ error }}
      </span>
    </div>
  </div>
</template>
