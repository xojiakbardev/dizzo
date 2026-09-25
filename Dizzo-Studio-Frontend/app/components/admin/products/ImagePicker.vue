<script setup lang="ts">
// Ordered image list for a product / variant / colour. Uploads go straight
// to R2 (purpose "catalog"); the parent persists the new order of media ids.
import { getApiErrorMessage } from '~/composables/useApi';
import { MEDIA_IMAGE_TYPES, useMediaUpload } from '~/composables/useMediaUpload';
import type { CatalogImage } from '~/types/catalog';

const props = withDefaults(defineProps<{
  images: CatalogImage[];
  max?: number;
  disabled?: boolean;
  /** Tile size: sm 80px (variants, colours), md 112px (a gallery), lg 224–256px, xl 288–320px (a cover). */
  size?: 'sm' | 'md' | 'lg' | 'xl';
  /** One row that scrolls sideways (snapping) instead of wrapping. */
  scroll?: boolean;
  /** A list with no main picture (a colour's gallery) hides the star. */
  starrable?: boolean;
}>(), { max: 12, disabled: false, size: 'sm', scroll: false, starrable: true });

const TILE = { sm: 'size-20', md: 'size-28', lg: 'size-56 sm:size-64', xl: 'size-72 sm:size-80' } as const;

const emit = defineEmits<{ change: [mediaIds: string[]] }>();

const { t } = useI18n();
const { upload } = useMediaUpload();
const uploading = ref(false);
const error = ref<string | null>(null);

const ids = computed(() => props.images.map(i => i.media_id));

async function onFiles(files: File[]) {
  if (!files.length) return;
  error.value = null;
  uploading.value = true;
  try {
    const room = props.max - props.images.length;
    const added: string[] = [];
    for (const file of files.slice(0, room)) {
      const blob = await resizeImageToBlob(file, 1600, 0.88, 'image/webp');
      added.push((await upload(blob, 'catalog')).id);
    }
    emit('change', [...ids.value, ...added]);
  }
  catch (err) {
    error.value = getApiErrorMessage(err, err instanceof Error ? err.message : t('admin.images.uploadFailed'));
  }
  finally {
    uploading.value = false;
  }
}

/** The star: this picture becomes the main one (first). */
function makeMain(index: number) {
  if (index === 0) return;
  const next = [...ids.value];
  const [item] = next.splice(index, 1);
  emit('change', [item!, ...next]);
}

function remove(index: number) {
  emit('change', ids.value.filter((_, i) => i !== index));
}
</script>

<template>
  <div class="min-w-0 space-y-2">
    <div
      class="flex gap-2"
      :class="scroll ? 'scrollbar-none snap-x snap-mandatory overflow-x-auto pb-1' : 'flex-wrap'"
    >
      <div
        v-for="(image, index) in images"
        :key="image.media_id"
        class="group relative shrink-0 snap-start"
        :class="TILE[size]"
      >
        <MediaThumb
          :src="image.url"
          class="size-full border border-border"
        />
        <UiButton
          v-if="starrable && max > 1 && !disabled"
          type="button"
          variant="ghost"
          size="icon-xs"
          class="absolute right-1 top-1 rounded-full shadow-xs"
          :class="index === 0 ? 'bg-amber-400 text-white hover:bg-amber-400 hover:text-white' : 'bg-white/90 text-slate-500 opacity-0 transition hover:bg-white hover:text-amber-500 group-hover:opacity-100 group-focus-within:opacity-100 pointer-coarse:opacity-100'"
          :aria-label="index === 0 ? t('admin.images.main') : t('admin.images.makeMain')"
          :title="index === 0 ? t('admin.images.main') : t('admin.images.makeMain')"
          :aria-pressed="index === 0"
          @click="makeMain(index)"
        >
          <Icon
            name="lucide:star"
            class="text-sm"
          />
        </UiButton>
        <div
          v-if="!disabled"
          class="absolute inset-x-0 bottom-0 flex justify-center rounded-b-xl bg-foreground/70 px-0.5 opacity-0 transition group-hover:opacity-100 group-focus-within:opacity-100 pointer-coarse:opacity-100"
        >
          <UiButton
            type="button"
            variant="ghost"
            size="icon-sm"
            class="h-6 w-6 text-rose-200 hover:bg-white/15"
            :aria-label="t('admin.common.delete')"
            @click="remove(index)"
          >
            <Icon
              name="lucide:trash-2"
              class="h-3.5 w-3.5"
            />
          </UiButton>
        </div>
      </div>
      <UiFileInput
        v-if="!disabled && images.length < max"
        :multiple="max > 1"
        :accept="MEDIA_IMAGE_TYPES.join(',')"
        :disabled="uploading"
        class="shrink-0 snap-start flex-col px-0 py-0 font-medium"
        :class="[TILE[size], size === 'lg' || size === 'xl' ? 'gap-2 text-sm' : 'gap-1 text-[11px]']"
        @select="onFiles"
      >
        <Icon
          :name="uploading ? 'lucide:loader-2' : 'lucide:image-plus'"
          :class="[size === 'lg' || size === 'xl' ? 'text-3xl' : 'text-xl', uploading ? 'animate-spin' : '']"
        />
        {{ uploading ? t('admin.images.uploading') : max === 1 && images.length === 0 ? t('admin.images.upload') : t('admin.common.add') }}
      </UiFileInput>
    </div>
    <UiAlert
      v-if="error"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ error }}
    </UiAlert>
  </div>
</template>
