<script setup lang="ts">
// "Galereya": the mockups of designs that customers actually ordered and
// received (GET /api/gallery/ — completed orders only, never drafts), then
// the designs the admin put up. Laid out like the catalog, without search:
// the catalog shelves as a row of chips under the title, "Dizayn yaratish"
// beside the title, and the pieces loaded as the page scrolls. A tap opens
// a piece large (GalleryViewer) and puts it in the link (?p=), so a shared
// link opens that piece and its preview shows it (useSiteSeo). The first
// page is rendered on the server for search engines.
import { galleryKey } from '~/composables/queries/useGallery';
import type { GalleryItem } from '~/composables/queries/useGallery';
import type { ProductCategory, ShelfOption } from '~/types/catalog';

const SKELETONS = 12;
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { start: startDesign } = useProductPicker();

const isSlug = (v: unknown): v is string => typeof v === 'string' && /^[a-z0-9-]{1,40}$/.test(v);
const category = ref<ProductCategory | null>(isSlug(route.query.c) ? route.query.c : null);
const pieceId = ref<string | null>(isSlug(route.query.p) ? route.query.p : null);
const piece = useGalleryItem(pieceId);

const feed = useGalleryFeed(category);
const results = computed<GalleryItem[]>(() => feed.data.value?.pages.flat() ?? []);

// The shelves that have work, in the admin's order, with their counts.
const shelfCounts = useGalleryShelves();
const total = computed(() => shelfCounts.data.value?.total ?? 0);
const counts = computed(() => shelfCounts.data.value?.counts ?? {});
const shelves = useCategories();
const categories = computed<ShelfOption[]>(() => (shelves.data.value ?? [])
  .filter(c => (counts.value[c.slug] ?? 0) > 0)
  .map(c => ({ value: c.slug, label: c.name, icon_svg: c.icon_svg, image_url: c.image_url })));
const hasShelves = computed(() => categories.value.length > 1);
if (import.meta.server) {
  await Promise.all([
    feed.suspense(), shelfCounts.suspense(), shelves.suspense(),
    ...(pieceId.value ? [piece.suspense()] : []),
  ]).catch(() => {});
}

// The next page loads when the end of the grid comes near.
const sentinel = ref<HTMLElement | null>(null);
function loadMore() {
  if (feed.hasNextPage.value && !feed.isFetchingNextPage.value) void feed.fetchNextPage();
}
useIntersectionObserver(sentinel, (entries) => {
  if (entries.some(e => e.isIntersecting)) loadMore();
}, { rootMargin: '600px 0px' });

function reset() {
  category.value = null;
}
watch(category, () => {
  pieceId.value = null;
});

// ── The viewer: steps through every piece the shelf shows ──
const open = ref(false);
const viewing = ref(0);
// A linked piece further down than the loaded pages leads the list.
const viewerItems = computed(() => {
  const it = piece.data.value;
  return it && pieceId.value === it.id && !results.value.some(r => r.id === it.id) ? [it, ...results.value] : results.value;
});

const heading = (item: GalleryItem) => item.title || item.product_name;

function openAt(index: number) {
  viewing.value = index;
  open.value = true;
}
watch(viewing, (i) => {
  if (i >= viewerItems.value.length - 2) loadMore();
});

// The link follows the shelf and the open piece.
watch([open, viewing, () => viewerItems.value.length], () => {
  if (!open.value) pieceId.value = null;
  else pieceId.value = viewerItems.value[viewing.value]?.id ?? pieceId.value;
});
watch([category, pieceId], () => {
  void router.replace({ query: {
    ...(category.value ? { c: category.value } : {}),
    ...(pieceId.value ? { p: pieceId.value } : {}),
  } });
});
// A shared piece opens once it is known.
onMounted(() => {
  const start = () => {
    const i = viewerItems.value.findIndex(r => r.id === pieceId.value);
    if (i >= 0) openAt(i);
    return i >= 0;
  };
  if (!pieceId.value || start()) return;
  const stop = watch(viewerItems, () => {
    if (start() || piece.isError.value) stop();
  });
});
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 pb-14 pt-6 sm:px-6 sm:pt-8 lg:px-8">
    <div class="flex items-center justify-between gap-3">
      <h1 class="text-[1.75rem] font-extrabold tracking-[-0.02em] text-ink sm:text-3xl">
        {{ t('storefront.gallery.title') }}
      </h1>
      <UiButton @click="startDesign()">
        <Icon name="lucide:sparkles" />
        {{ t('storefront.common.createDesign') }}
      </UiButton>
    </div>

    <div
      v-if="hasShelves"
      class="mt-4"
    >
      <ShelfChips
        v-model="category"
        :categories="categories"
        :counts="counts"
        :total="total"
      />
    </div>
    <div
      v-else-if="shelfCounts.isLoading.value"
      class="mt-4 flex gap-2 overflow-hidden"
    >
      <UiSkeleton
        v-for="i in 5"
        :key="i"
        class="h-10 w-28 shrink-0 rounded-full bg-plate"
      />
    </div>

    <div class="mt-5">
      <!-- loading: a full page of work in grey -->
      <div
        v-if="feed.isLoading.value"
        aria-busy="true"
      >
        <ul class="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:gap-5 lg:grid-cols-4">
          <li
            v-for="i in SKELETONS"
            :key="i"
          >
            <UiSkeleton class="aspect-square rounded-2xl bg-plate" />
            <div class="mt-2 flex h-lh items-center text-[15px]">
              <UiSkeleton class="h-[0.9em] w-2/3 bg-plate" />
            </div>
            <div class="flex h-lh items-center text-xs">
              <UiSkeleton class="h-[0.9em] w-1/2 bg-plate" />
            </div>
          </li>
        </ul>
      </div>

      <EmptyState
        v-else-if="feed.isError.value"
        icon="lucide:wifi-off"
        tone="destructive"
        :title="t('storefront.gallery.loadError')"
      >
        <UiButton
          variant="outline"
          @click="feed.refetch()"
        >
          <Icon name="lucide:rotate-cw" />
          {{ t('storefront.common.retry') }}
        </UiButton>
      </EmptyState>

      <EmptyState
        v-else-if="!results.length && !category"
        icon="lucide:images"
        :title="t('storefront.gallery.empty')"
      />

      <EmptyState
        v-else-if="!results.length"
        icon="lucide:search-x"
        :title="t('storefront.gallery.notFound')"
      >
        <UiButton
          variant="outline"
          @click="reset"
        >
          {{ t('storefront.common.showAll') }}
        </UiButton>
      </EmptyState>

      <template v-else>
        <ul class="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:gap-5 lg:grid-cols-4">
          <li
            v-for="(item, i) in results"
            :key="galleryKey(item)"
          >
            <button
              type="button"
              class="group block w-full cursor-pointer text-left"
              :aria-label="t('storefront.gallery.enlarge', { name: heading(item) })"
              @click="openAt(i)"
            >
              <span class="block overflow-hidden rounded-2xl border border-line bg-white">
                <img
                  v-bind="thumbAttrs(item.preview_image_url, '(min-width: 1024px) 25vw, 50vw')"
                  :alt="heading(item)"
                  class="aspect-square w-full object-cover transition duration-300 group-hover:scale-[1.03]"
                  loading="lazy"
                >
              </span>
              <span class="mt-2 block truncate text-[15px] font-semibold text-ink">{{ heading(item) }}</span>
              <span class="block truncate text-xs text-slate-600">{{ item.title ? item.product_name : formatDate(item.created_at) }}</span>
            </button>
          </li>
        </ul>

        <div
          ref="sentinel"
          class="flex h-16 items-center justify-center"
          aria-hidden="true"
        >
          <Icon
            v-if="feed.isFetchingNextPage.value"
            name="lucide:loader-circle"
            class="animate-spin text-2xl text-slate-400"
          />
        </div>
      </template>
    </div>

    <GalleryViewer
      v-model:open="open"
      v-model:index="viewing"
      :items="viewerItems"
    />
  </div>
</template>
