<script setup lang="ts">
// What a product tab looks like while it loads: the same grid, cards and
// sizes as the tab itself (ProductInfoTab, ShapesTab, VariantsTab, PricesTab,
// GalleryTab), so nothing jumps when the data arrives. Keep in step with
// those files when their layout changes.
import type { CatalogMethod } from '~/types/catalog';
import { METHOD_LABELS } from '~/types/catalog';

export type ProductTab = 'info' | 'shapes' | 'variants' | 'images' | 'prices' | 'templates';

defineProps<{ tab: ProductTab }>();
const methods = Object.keys(METHOD_LABELS) as CatalogMethod[];
</script>

<template>
  <div aria-hidden="true">
    <!-- Asosiy: the cover card on the left, the fields card on the right. -->
    <template v-if="tab === 'info'">
      <div class="grid items-start gap-5 lg:grid-cols-[auto_minmax(0,1fr)]">
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-20" />
            </div>
          </UiCardHeader>
          <UiCardContent class="flex justify-center py-5">
            <UiSkeleton class="size-72 rounded-xl sm:size-80" />
          </UiCardContent>
        </UiCard>
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-40" />
            </div>
          </UiCardHeader>
          <UiCardContent class="space-y-4 py-5">
            <div class="grid gap-4 sm:grid-cols-2">
              <!-- The name: its label row carries the UZ/RU/EN tabs. -->
              <div class="grid gap-1.5">
                <div class="flex min-h-7 items-center justify-between gap-2">
                  <UiSkeleton class="h-3 w-24" />
                  <UiSkeleton class="h-7 w-[5.5rem] rounded-lg" />
                </div>
                <UiSkeleton class="h-10 rounded-xl" />
              </div>
              <div class="grid gap-1.5">
                <UiSkeleton class="h-3 w-24" />
                <UiSkeleton class="h-10 rounded-xl" />
              </div>
            </div>
            <div class="grid gap-3 sm:grid-cols-2">
              <UiSkeleton
                v-for="n in 2"
                :key="n"
                class="h-[3.25rem] rounded-xl"
              />
            </div>
          </UiCardContent>
        </UiCard>
      </div>
    </template>

    <!-- Shakllar: square picture with its two badges, name, three buttons. -->
    <div
      v-else-if="tab === 'shapes'"
      class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"
    >
      <UiCard
        v-for="n in 3"
        :key="n"
        class="gap-0 py-0"
      >
        <div class="relative">
          <UiSkeleton class="aspect-square w-full rounded-none" />
          <UiSkeleton class="absolute left-2 top-2 h-6 w-16 rounded-lg" />
          <UiSkeleton class="absolute right-2 top-2 h-6 w-24 rounded-lg" />
        </div>
        <UiCardContent class="flex flex-1 flex-col gap-3 border-t py-4">
          <div class="flex h-6 items-center">
            <UiSkeleton class="h-4 w-1/2" />
          </div>
          <div class="flex gap-2">
            <UiSkeleton class="h-8.5 flex-1 rounded-lg" />
            <UiSkeleton class="h-8.5 w-20 rounded-lg" />
            <UiSkeleton class="size-8.5 rounded-lg" />
          </div>
        </UiCardContent>
      </UiCard>
    </div>

    <!-- Variantlar: picture (method badges top-right), name and price, shape, colours, footer. -->
    <div
      v-else-if="tab === 'variants'"
      class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"
    >
      <UiCard
        v-for="n in 4"
        :key="n"
        class="gap-3 p-3"
      >
        <div class="relative">
          <UiSkeleton class="aspect-square w-full rounded-xl" />
          <UiSkeleton class="absolute right-2 top-2 h-5 w-20 rounded-md" />
        </div>
        <div class="space-y-1">
          <div class="flex h-5 items-center justify-between gap-2">
            <UiSkeleton class="h-3.5 w-1/2" />
            <UiSkeleton class="h-3.5 w-16" />
          </div>
          <div class="flex h-4 items-center">
            <UiSkeleton class="h-3 w-1/3" />
          </div>
        </div>
        <div class="flex min-h-4 items-center gap-1">
          <UiSkeleton
            v-for="c in 3"
            :key="c"
            class="size-4 rounded-full"
          />
        </div>
        <div class="mt-auto flex items-center gap-2 border-t pt-3">
          <UiSkeleton class="h-[1.15rem] w-8 rounded-full" />
          <UiSkeleton class="h-3 w-12" />
          <UiSkeleton class="ml-auto h-8.5 w-24 rounded-lg" />
        </div>
      </UiCard>
    </div>

    <!-- Rasmlar: the tray and the type cards beside the preview. -->
    <div
      v-else-if="tab === 'images'"
      class="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]"
    >
      <div class="space-y-4">
        <UiSkeleton class="h-32 w-full rounded-xl" />
        <UiCard
          v-for="n in 2"
          :key="n"
          class="gap-3 p-4"
        >
          <UiSkeleton class="h-5 w-1/3" />
          <div
            v-for="r in 3"
            :key="r"
            class="flex items-center gap-3"
          >
            <UiSkeleton class="h-8 w-40" />
            <UiSkeleton class="h-24 flex-1 rounded-xl" />
          </div>
        </UiCard>
      </div>
      <UiSkeleton class="aspect-[3/4] w-full rounded-xl" />
    </div>

    <!-- Narxlar: one card per print method. -->
    <div
      v-else-if="tab === 'prices'"
      class="grid items-start gap-5 lg:grid-cols-2"
    >
      <UiCard
        v-for="m in methods"
        :key="m"
        class="gap-0 py-0"
      >
        <UiCardHeader class="flex items-center justify-between gap-3 border-b py-4">
          <div class="flex min-w-0 flex-1 items-center gap-2.5">
            <UiSkeleton class="size-9 shrink-0 rounded-xl" />
            <div class="min-w-0 flex-1">
              <div class="flex h-[1.375rem] items-center">
                <UiSkeleton class="h-4 w-28" />
              </div>
              <div class="flex h-4 items-center">
                <UiSkeleton class="h-3 w-44 max-w-full" />
              </div>
            </div>
          </div>
          <UiSkeleton class="h-6 w-24 rounded-full" />
        </UiCardHeader>
        <UiCardContent class="space-y-3 py-4">
          <div class="space-y-1">
            <UiSkeleton class="h-3 w-full" />
            <UiSkeleton class="h-3 w-11/12" />
            <UiSkeleton class="h-3 w-1/2" />
          </div>
          <div class="hidden h-4 grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2.25rem] items-center gap-2 px-2 sm:grid">
            <UiSkeleton class="h-3 w-16" />
            <UiSkeleton class="h-3 w-20" />
          </div>
          <UiSkeleton
            v-for="r in 2"
            :key="r"
            class="h-24 rounded-xl sm:h-13"
          />
        </UiCardContent>
        <div class="flex items-center justify-between gap-2 rounded-b-xl border-t bg-muted/50 p-4">
          <UiSkeleton class="h-8.5 w-32 rounded-lg" />
          <UiSkeleton class="h-8.5 w-24 rounded-lg" />
        </div>
      </UiCard>
    </div>

    <!-- Galereya: the search row, then the designs' rows. -->
    <div
      v-else
      class="space-y-4"
    >
      <div class="flex items-center gap-3">
        <UiSkeleton class="h-10 flex-1 rounded-xl sm:max-w-md" />
        <UiSkeleton class="ml-auto size-10 rounded-xl" />
        <UiSkeleton class="h-10 w-36 rounded-xl" />
      </div>
      <div class="space-y-3">
        <div
          v-for="n in 4"
          :key="n"
          class="flex items-center gap-3 rounded-2xl border border-border bg-card p-3"
        >
          <UiSkeleton class="h-10 w-6 rounded-md" />
          <UiSkeleton class="size-16 rounded-xl" />
          <div class="flex-1 space-y-2">
            <UiSkeleton class="h-4 w-1/3" />
            <UiSkeleton class="h-3 w-1/4" />
          </div>
          <UiSkeleton class="h-5 w-24 rounded-full" />
        </div>
      </div>
    </div>
  </div>
</template>
