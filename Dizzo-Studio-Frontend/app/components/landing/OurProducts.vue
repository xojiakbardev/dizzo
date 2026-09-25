<script setup lang="ts">
// "Mahsulot tanlang": the heart of the landing. Two rows of the products
// most likely to sell (the backend's best sellers, then the newest); the
// whole catalog, with its search and shelves, is one click away.
const query = usePopularProducts();
const { t } = useI18n();
const localePath = useLocalePath();
const shown = computed(() => (query.data.value ?? []).slice(0, 8));
</script>

<template>
  <section
    id="products"
    aria-labelledby="products-title"
    class="scroll-mt-20 border-t border-line bg-white"
  >
    <div class="mx-auto max-w-7xl px-4 py-10 sm:px-6 sm:py-12 lg:px-8 lg:py-14">
      <div class="flex items-center justify-between gap-4">
        <h2
          id="products-title"
          class="text-[1.75rem] font-extrabold tracking-[-0.02em] text-ink sm:text-3xl"
        >
          {{ t('storefront.landing.productsTitle') }}
        </h2>
        <UiButton
          as-child
          variant="outline"
          size="lg"
          class="shrink-0 rounded-xl max-sm:size-10 max-sm:px-0"
        >
          <NuxtLink :to="localePath('/catalog')">
            <span class="max-sm:sr-only">{{ t('storefront.landing.seeAll') }}</span>
            <Icon name="lucide:arrow-right" />
          </NuxtLink>
        </UiButton>
      </div>

      <!-- loading: the two rows of cards in grey, so the section keeps its
           size when products arrive -->
      <ul
        v-if="query.isLoading.value"
        class="mt-6 grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4 lg:gap-5"
        aria-busy="true"
      >
        <li
          v-for="i in 8"
          :key="i"
        >
          <ProductCardSkeleton />
        </li>
      </ul>

      <div
        v-else-if="query.isError.value"
        class="mt-6 flex flex-col items-start gap-3 rounded-2xl bg-plate p-6 text-base text-slate-700 sm:flex-row sm:items-center sm:justify-between"
      >
        {{ t('storefront.landing.productsError') }}
        <UiButton
          variant="outline"
          class="shrink-0"
          @click="query.refetch()"
        >
          {{ t('storefront.common.retry') }}
        </UiButton>
      </div>

      <p
        v-else-if="!shown.length"
        class="mt-6 rounded-2xl bg-plate p-6 text-base text-slate-700"
      >
        {{ t('storefront.landing.productsEmpty') }}
      </p>

      <ul
        v-else
        class="mt-6 grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4 lg:gap-5"
      >
        <li
          v-for="product in shown"
          :key="product.slug"
        >
          <ProductCard :product="product" />
        </li>
      </ul>
    </div>
  </section>
</template>
