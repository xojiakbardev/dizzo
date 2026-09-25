<script setup lang="ts">
// "Qaysi mahsulot uchun dizayn yaratasiz?" — opened by useProductPicker().start()
// when there is more than one product to choose from. Mounted once in the
// default and cabinet layouts. Each product goes to its Studio, where the type and colour
// are picked next.
const { open, choose } = useProductPicker();
const { t } = useI18n();
const { query, list } = useStorefrontProducts();
const { search, results } = useProductSearch(list);
watch(open, (isOpen) => { if (isOpen) search.value = ''; });

// On touch screens, focusing the search on open would pop the keyboard
// over the products; there the dialog keeps focus instead.
function onOpenAutoFocus(event: Event) {
  if (window.matchMedia('(pointer: coarse)').matches) event.preventDefault();
}

// A long catalog gets a search box and a denser grid.
const many = computed(() => list.value.length > 8);
const width = computed(() => {
  if (list.value.length === 2) return 'sm:max-w-xl';
  return many.value ? 'sm:max-w-4xl' : 'sm:max-w-3xl';
});
const columns = computed(() => {
  if (list.value.length === 2) return 'sm:grid-cols-2';
  return many.value ? 'sm:grid-cols-3 md:grid-cols-4' : 'sm:grid-cols-3';
});
</script>

<template>
  <UiDialog v-model:open="open">
    <UiDialogContent
      class="max-h-[calc(100dvh-2rem)] gap-0 overflow-hidden rounded-3xl p-0"
      :class="width"
      @open-auto-focus="onOpenAutoFocus"
    >
      <UiDialogHeader class="px-5 pb-4 pt-6 text-left sm:px-7 sm:pt-7">
        <UiDialogTitle class="pr-8 text-xl font-bold tracking-tight text-ink sm:text-2xl">
          {{ t('storefront.picker.title') }}
        </UiDialogTitle>
        <label
          v-if="many"
          class="relative mt-3 block"
        >
          <span class="sr-only">{{ t('storefront.picker.search') }}</span>
          <Icon
            name="lucide:search"
            class="pointer-events-none absolute left-4 top-1/2 h-[18px] w-[18px] -translate-y-1/2 text-slate-400"
          />
          <input
            v-model="search"
            type="search"
            :placeholder="t('storefront.picker.search')"
            class="h-11 w-full rounded-full bg-plate pl-11 pr-4 text-[15px] text-ink outline-none ring-cta transition placeholder:text-slate-500 focus:ring-2"
          >
        </label>
      </UiDialogHeader>

      <div class="overflow-y-auto px-5 pb-6 sm:px-7 sm:pb-7">
        <!-- loading: the product buttons below, in grey -->
        <ul
          v-if="query.isLoading.value"
          class="grid gap-3 p-0.5 sm:grid-cols-3 sm:gap-4"
          aria-busy="true"
        >
          <li
            v-for="i in 3"
            :key="i"
            class="flex items-center gap-4 rounded-2xl p-2 ring-1 ring-line sm:flex-col sm:items-stretch sm:p-3"
          >
            <UiSkeleton class="size-20 shrink-0 rounded-xl bg-plate sm:aspect-square sm:size-auto sm:w-full" />
            <span class="min-w-0 flex-1 sm:px-1 sm:pb-1">
              <span class="flex h-lh items-center">
                <UiSkeleton class="h-4 w-2/3 bg-plate" />
              </span>
              <span class="mt-0.5 flex h-lh items-center text-sm">
                <UiSkeleton class="h-3.5 w-1/3 bg-plate" />
              </span>
            </span>
          </li>
        </ul>

        <div
          v-else-if="query.isError.value"
          class="flex flex-col items-start gap-3 rounded-2xl bg-plate p-5 text-sm text-slate-700"
        >
          {{ t('storefront.landing.productsError') }}
          <UiButton
            variant="outline"
            @click="query.refetch()"
          >
            {{ t('storefront.common.retry') }}
          </UiButton>
        </div>

        <p
          v-else-if="!list.length"
          class="rounded-2xl bg-plate p-5 text-sm text-slate-700"
        >
          {{ t('storefront.landing.productsEmpty') }}
        </p>

        <p
          v-else-if="!results.length"
          class="rounded-2xl bg-plate p-5 text-sm text-slate-700"
        >
          {{ t('storefront.picker.notFound', { query: search }) }}
        </p>

        <ul
          v-else
          class="grid gap-3 p-0.5 sm:gap-4"
          :class="columns"
        >
          <li
            v-for="product in results"
            :key="product.slug"
          >
            <button
              type="button"
              class="group flex w-full cursor-pointer items-center gap-4 rounded-2xl p-2 text-left ring-1 ring-line transition hover:ring-slate-300 focus-visible:outline-2 focus-visible:outline-cta sm:flex-col sm:items-stretch sm:p-3"
              @click="choose(product.slug)"
            >
              <span class="flex size-20 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-plate sm:aspect-square sm:size-auto sm:w-full">
                <img
                  v-if="product.cover_url"
                  v-bind="thumbSmall(product.cover_url)"
                  :alt="product.name"
                  class="h-full w-full object-cover transition duration-500 group-hover:scale-[1.04]"
                  loading="lazy"
                >
                <Icon
                  v-else
                  name="lucide:package"
                  class="h-8 w-8 text-slate-400"
                />
              </span>
              <span class="flex min-w-0 flex-1 items-center justify-between gap-3 sm:px-1 sm:pb-1">
                <span class="min-w-0">
                  <span class="block truncate font-semibold text-ink">{{ product.name }}</span>
                  <i18n-t
                    keypath="storefront.picker.fromPrice"
                    tag="span"
                    scope="global"
                    class="mt-0.5 block text-sm text-slate-600"
                  >
                    <template #price>
                      <span class="font-semibold text-ink">{{ formatMoney(product.from_price) }}</span>
                    </template>
                  </i18n-t>
                </span>
                <Icon
                  name="lucide:arrow-right"
                  class="h-5 w-5 shrink-0 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-cta"
                />
              </span>
            </button>
          </li>
        </ul>
      </div>
    </UiDialogContent>
  </UiDialog>
</template>
