<script setup lang="ts">
// The product page's shape in grey while the product loads.
const { t } = useI18n();
</script>

<template>
  <div
    class="lg:grid lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)] lg:gap-10"
    aria-busy="true"
    :aria-label="t('storefront.common.loading')"
  >
    <!-- One square with the thumbnail strip laid over its bottom edge, as
         ProductGallery draws it. -->
    <div class="relative aspect-square w-full overflow-hidden rounded-2xl border border-line bg-plate">
      <div class="absolute inset-x-0 bottom-0 flex justify-center px-3 pb-3">
        <div class="flex gap-1.5 rounded-xl bg-white/75 p-1.5">
          <UiSkeleton
            v-for="i in 4"
            :key="i"
            class="size-11 rounded-lg bg-plate sm:size-12"
          />
        </div>
      </div>
    </div>
    <div class="mt-6 space-y-5 lg:mt-0">
      <UiSkeleton class="h-4 w-24 rounded bg-plate" />
      <UiSkeleton class="h-9 w-2/3 rounded-lg bg-plate" />
      <UiSkeleton class="h-7 w-40 rounded-lg bg-plate" />
      <div class="flex gap-2.5">
        <UiSkeleton
          v-for="i in 3"
          :key="i"
          class="size-24 rounded-xl bg-plate sm:size-28"
        />
      </div>
      <div class="flex gap-2">
        <UiSkeleton
          v-for="i in 5"
          :key="i"
          class="size-8 rounded-full bg-plate"
        />
      </div>
      <UiSkeleton class="h-12 w-full rounded-xl bg-plate" />
      <UiSkeleton class="h-24 w-full rounded-xl bg-plate" />
    </div>
  </div>
</template>
