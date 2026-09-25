<script setup lang="ts">
// Mockups from completed orders, then the admin's samples (GET /api/gallery/). The
// landing shows it once there are at least three pieces (see index.vue),
// and in grey while they load. The row is full width: four across (two on
// phones), two rows when there are eight, else one.
import type { GalleryItem } from '~/composables/queries/useGallery';
import { galleryKey } from '~/composables/queries/useGallery';

const props = defineProps<{ items: GalleryItem[]; loading?: boolean }>();
const { t } = useI18n();
const localePath = useLocalePath();

const shown = computed(() => props.items.slice(0, props.items.length >= 8 ? 8 : 4));

// A tile opens the piece large right here, like on /gallery.
const open = ref(false);
const viewing = ref(0);
function openAt(index: number) {
  viewing.value = index;
  open.value = true;
}
</script>

<template>
  <section
    id="gallery"
    aria-labelledby="gallery-title"
    class="scroll-mt-20"
  >
    <div class="flex items-center justify-between gap-4">
      <h2
        id="gallery-title"
        class="text-2xl font-extrabold tracking-[-0.02em] text-ink sm:text-[1.75rem]"
      >
        {{ t('storefront.gallery.title') }}
      </h2>
      <UiButton
        as-child
        variant="outline"
        size="lg"
        class="shrink-0 rounded-xl max-sm:size-10 max-sm:px-0"
      >
        <NuxtLink :to="localePath('/gallery')">
          <span class="max-sm:sr-only">{{ t('storefront.landing.seeAll') }}</span>
          <Icon name="lucide:arrow-right" />
        </NuxtLink>
      </UiButton>
    </div>
    <ul
      v-if="loading"
      class="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4 lg:gap-5"
      aria-busy="true"
    >
      <li
        v-for="i in 4"
        :key="i"
        class="overflow-hidden rounded-2xl border border-line"
      >
        <UiSkeleton class="aspect-square rounded-none bg-plate" />
      </li>
    </ul>
    <ul
      v-else
      class="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4 lg:gap-5"
    >
      <li
        v-for="(item, i) in shown"
        :key="galleryKey(item)"
        :class="{ 'max-sm:hidden': i >= 6 }"
      >
        <button
          type="button"
          class="block w-full cursor-pointer overflow-hidden rounded-2xl border border-line bg-plate"
          :aria-label="t('storefront.gallery.enlarge', { name: item.title || item.product_name })"
          @click="openAt(i)"
        >
          <img
            v-bind="thumbAttrs(item.preview_image_url, '(min-width: 1024px) 25vw, 50vw')"
            :alt="item.title || item.product_name"
            width="480"
            height="480"
            class="aspect-square w-full object-cover transition duration-300 hover:scale-[1.03]"
            loading="lazy"
            decoding="async"
          >
        </button>
      </li>
    </ul>

    <GalleryViewer
      v-model:open="open"
      v-model:index="viewing"
      :items="shown"
    />
  </section>
</template>
