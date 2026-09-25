<script setup lang="ts">
// A picture in a tile: product covers, type and colour photos, template
// previews, order mockups, review photos. A skeleton while it loads; the
// fallback slot (an image icon by default) when there is no picture or it
// fails to load. The URL is used as the backend gives it (absolute R2 /
// storage links), relative media paths are resolved with useMediaUrl.
import { cn } from '~/lib/utils';
import type { ThumbWidth } from '~/utils/thumb';

const props = withDefaults(defineProps<{
  src?: string | null;
  alt?: string;
  /** `contain` for product cutouts, `cover` for photos. */
  fit?: 'cover' | 'contain';
  class?: string;
  imgClass?: string;
  /** Which copy of a catalog picture: 480 (tiles) or 960 (large). */
  width?: ThumbWidth;
}>(), { src: null, alt: '', fit: 'cover', class: '', imgClass: '', width: 480 });

const { getMediaUrl } = useMediaUrl();
const original = computed(() => (props.src ? getMediaUrl(props.src) : ''));
// The small copy until it fails, then the original.
const useOriginal = ref(false);
const url = computed(() => (useOriginal.value ? original.value : thumbUrl(original.value, props.width)));
const status = ref<'loading' | 'loaded' | 'error'>(url.value ? 'loading' : 'error');
watch(original, (next) => {
  useOriginal.value = false;
  status.value = next ? 'loading' : 'error';
});
function onError() {
  if (!useOriginal.value && url.value !== original.value) useOriginal.value = true;
  else status.value = 'error';
}

const img = ref<HTMLImageElement | null>(null);
// An image already in the cache can finish before the listeners are attached.
onMounted(() => {
  if (img.value?.complete && img.value.naturalWidth > 0) status.value = 'loaded';
});
</script>

<template>
  <div
    data-slot="media-thumb"
    :class="cn('relative flex shrink-0 items-center justify-center overflow-hidden rounded-xl bg-muted text-muted-foreground/60', props.class)"
  >
    <img
      v-if="url && status !== 'error'"
      ref="img"
      :src="url"
      :alt="alt"
      loading="lazy"
      decoding="async"
      :class="cn(
        'absolute inset-0 size-full transition-opacity duration-200',
        fit === 'contain' ? 'object-contain' : 'object-cover',
        status === 'loaded' ? 'opacity-100' : 'opacity-0',
        imgClass,
      )"
      @load="status = 'loaded'"
      @error="onError"
    >
    <UiSkeleton
      v-if="url && status === 'loading'"
      class="absolute inset-0 size-full rounded-none"
    />
    <slot
      v-if="status === 'error'"
      name="fallback"
    >
      <Icon
        name="lucide:image"
        class="size-1/3 max-h-8 max-w-8"
      />
    </slot>
  </div>
</template>
