<script setup lang="ts">
// Everything on sale, the admin's featured products first: search, shelves
// and the products loaded as the page scrolls — the server filters and
// pages them, so the catalog stays quick however long it grows. The search
// and shelf live in the URL (?q=&c=), so links and the back button land in
// place. The search sits beside the title; the shelves are a sticky row of
// chips on a phone and a sticky side column from lg.
import type { PublicProductCard, ProductCategory, ShelfOption } from '~/types/catalog';

const SKELETONS = 12;
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const isCategory = (v: unknown): v is ProductCategory => typeof v === 'string' && /^[a-z0-9-]{1,40}$/.test(v);
const search = ref(typeof route.query.q === 'string' ? route.query.q : '');
const category = ref<ProductCategory | null>(isCategory(route.query.c) ? route.query.c : null);
// The server searches once typing pauses.
const query = refDebounced(search, 300);

const feed = useProductFeed(category, query);
const results = computed<PublicProductCard[]>(() => feed.data.value?.pages.flat() ?? []);
const shelfCounts = useProductShelves();
const shelves = useCategories();
if (import.meta.server) await Promise.all([feed.suspense(), shelfCounts.suspense(), shelves.suspense()]).catch(() => {});

const total = computed(() => shelfCounts.data.value?.total ?? 0);
const counts = computed(() => shelfCounts.data.value?.counts ?? {});
const categories = computed<ShelfOption[]>(() => (shelves.data.value ?? [])
  .filter(c => (counts.value[c.slug] ?? 0) > 0)
  .map(c => ({ value: c.slug, label: c.name, icon_svg: c.icon_svg, image_url: c.image_url })));
const hasShelves = computed(() => categories.value.length > 1);
const loading = computed(() => feed.isLoading.value);

watch([query, category], () => {
  void router.replace({ query: {
    ...(query.value.trim() ? { q: query.value.trim() } : {}),
    ...(category.value ? { c: category.value } : {}),
  } });
});

// The next page loads when the end of the grid comes near.
const sentinel = ref<HTMLElement | null>(null);
useIntersectionObserver(sentinel, (entries) => {
  if (entries.some(e => e.isIntersecting) && feed.hasNextPage.value && !feed.isFetchingNextPage.value) {
    void feed.fetchNextPage();
  }
}, { rootMargin: '600px 0px' });

function reset() {
  search.value = '';
  category.value = null;
}
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 pb-14 pt-6 sm:px-6 sm:pt-8 lg:px-8">
    <div class="flex items-center justify-between gap-3">
      <h1 class="shrink-0 text-[1.75rem] font-extrabold tracking-[-0.02em] text-ink sm:text-3xl">
        {{ t('storefront.catalog.title') }}
      </h1>
      <ProductSearchField
        v-model="search"
        class="w-full min-w-0 max-w-xs"
      />
    </div>

    <!-- phones: the shelves in one sideways row, kept in reach under the navbar -->
    <div
      v-if="hasShelves"
      class="sticky top-16 z-30 -mx-4 mt-4 border-b border-line bg-white px-4 py-3 sm:-mx-6 sm:px-6 lg:hidden"
    >
      <ShelfChips
        v-model="category"
        :categories="categories"
        :counts="counts"
        :total="total"
      />
    </div>

    <div class="mt-5 lg:mt-6 lg:grid lg:grid-cols-[15rem_minmax(0,1fr)] lg:gap-8">
      <!-- wide screens: the shelves in a sticky side column -->
      <aside class="hidden lg:block">
        <div class="sticky top-20">
          <ShelfList
            v-if="hasShelves"
            v-model="category"
            :categories="categories"
            :counts="counts"
            :total="total"
          />
          <div
            v-else-if="shelfCounts.isLoading.value"
            class="space-y-1"
          >
            <UiSkeleton
              v-for="i in 5"
              :key="i"
              class="h-12 rounded-xl bg-plate"
            />
          </div>
        </div>
      </aside>

      <div>
        <!-- loading: a full page of cards in grey -->
        <div
          v-if="loading"
          aria-busy="true"
        >
          <ul class="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:gap-5">
            <li
              v-for="i in SKELETONS"
              :key="i"
            >
              <ProductCardSkeleton />
            </li>
          </ul>
        </div>

        <EmptyState
          v-else-if="feed.isError.value"
          icon="lucide:wifi-off"
          tone="destructive"
          :title="t('storefront.catalog.loadError')"
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
          v-else-if="!results.length && !query.trim() && !category"
          icon="lucide:package-open"
          :title="t('storefront.catalog.empty')"
        />

        <EmptyState
          v-else-if="!results.length"
          icon="lucide:search-x"
          :title="t('storefront.catalog.notFound')"
        >
          <UiButton
            variant="outline"
            @click="reset"
          >
            {{ t('storefront.common.showAll') }}
          </UiButton>
        </EmptyState>

        <template v-else>
          <ul class="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:gap-5">
            <li
              v-for="product in results"
              :key="product.slug"
            >
              <ProductCard :product="product" />
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
    </div>
  </div>
</template>
