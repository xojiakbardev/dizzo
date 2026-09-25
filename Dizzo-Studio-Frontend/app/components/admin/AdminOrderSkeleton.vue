<script setup lang="ts">
// What the order page looks like while it loads: the same header row, grid,
// cards and sizes as pages/admin/orders/[id].vue and AdminOrderItem, so
// nothing jumps when the data arrives. Keep in step with those files.
import type { DataTableColumn } from '~/components/ui/DataTable.vue';

const { t } = useI18n();

// AdminOrderItem's "Bosma fayllar" columns.
const FILE_COLUMNS = computed<DataTableColumn[]>(() => [
  { key: 'area_name', header: t('admin.orders.item.col.area') },
  { key: 'method', header: t('admin.orders.item.col.method') },
  { key: 'size', header: t('admin.orders.item.col.size'), className: 'hidden sm:table-cell' },
  { key: 'dpi', header: 'DPI', className: 'hidden md:table-cell' },
  { key: 'painted', header: t('admin.orders.item.col.painted'), className: 'hidden md:table-cell' },
  { key: 'download', header: '', className: 'text-right' },
]);
</script>

<template>
  <div
    class="space-y-4"
    aria-hidden="true"
  >
    <!-- Number, status, date; refresh and the next step. -->
    <div class="flex flex-wrap items-center gap-3">
      <div class="flex h-7 items-center">
        <UiSkeleton class="h-5 w-28" />
      </div>
      <UiSkeleton class="h-6 w-24 rounded-full" />
      <div class="flex h-5 items-center">
        <UiSkeleton class="h-3.5 w-40" />
      </div>
      <div class="ml-auto flex items-center gap-2">
        <UiSkeleton class="size-10 rounded-xl" />
        <UiSkeleton class="h-10 w-56 rounded-xl" />
      </div>
    </div>

    <div class="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_20rem] xl:grid-cols-[minmax(0,1fr)_24rem]">
      <!-- One order line: header, frames beside the details, the print files. -->
      <div class="min-w-0 space-y-4">
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="flex flex-wrap items-center justify-between gap-3 border-b py-4">
            <div class="min-w-0">
              <div class="flex h-[1.375rem] items-center">
                <UiSkeleton class="h-4 w-40" />
              </div>
              <div class="flex h-5 items-center">
                <UiSkeleton class="h-3.5 w-24" />
              </div>
            </div>
            <UiSkeleton class="h-8.5 w-40 rounded-lg" />
          </UiCardHeader>
          <UiCardContent class="space-y-5 py-5">
            <div class="grid gap-5 md:grid-cols-[16rem_minmax(0,1fr)]">
              <div class="mx-auto w-full max-w-xs space-y-2 md:max-w-none">
                <UiSkeleton class="aspect-square w-full rounded-xl" />
                <div class="grid grid-cols-5 gap-2">
                  <UiSkeleton
                    v-for="n in 5"
                    :key="n"
                    class="aspect-square w-full rounded-lg"
                  />
                </div>
              </div>
              <div class="min-w-0">
                <div class="space-y-2.5">
                  <div
                    v-for="n in 4"
                    :key="n"
                    class="flex h-5 items-center justify-between gap-3"
                  >
                    <UiSkeleton class="h-3.5 w-16" />
                    <UiSkeleton class="h-3.5 w-24" />
                  </div>
                </div>
                <UiSeparator class="my-4" />
                <div class="space-y-2.5">
                  <div
                    v-for="n in 3"
                    :key="n"
                    class="flex h-5 items-center justify-between gap-3"
                  >
                    <UiSkeleton class="h-3.5 w-24" />
                    <UiSkeleton class="h-3.5 w-20" />
                  </div>
                  <div class="flex h-6 items-center justify-between gap-3">
                    <UiSkeleton class="h-4 w-24" />
                    <UiSkeleton class="h-4 w-28" />
                  </div>
                </div>
              </div>
            </div>
            <section>
              <div class="mb-2 flex h-5 items-center">
                <UiSkeleton class="h-3.5 w-24" />
              </div>
              <UiDataTable
                :columns="FILE_COLUMNS"
                :data="[]"
                is-loading
                :skeleton-rows="2"
              />
            </section>
          </UiCardContent>
        </UiCard>
      </div>

      <div class="min-w-0 space-y-4">
        <!-- Mijoz -->
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-16" />
            </div>
          </UiCardHeader>
          <UiCardContent class="space-y-2.5 py-4">
            <div
              v-for="n in 3"
              :key="n"
              class="flex h-5 items-center justify-between gap-3"
            >
              <UiSkeleton class="h-3.5 w-14" />
              <UiSkeleton class="h-3.5 w-32" />
            </div>
          </UiCardContent>
        </UiCard>

        <!-- Yetkazib berish -->
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-32" />
            </div>
          </UiCardHeader>
          <UiCardContent class="space-y-3 py-4">
            <div class="flex gap-2.5">
              <UiSkeleton class="mt-0.5 size-4 shrink-0 rounded-full" />
              <div class="min-w-0 flex-1 space-y-0.5">
                <div class="flex h-5 items-center">
                  <UiSkeleton class="h-3.5 w-4/5" />
                </div>
                <div class="flex h-5 items-center">
                  <UiSkeleton class="h-3.5 w-1/2" />
                </div>
              </div>
            </div>
            <UiSkeleton class="h-8.5 w-full rounded-lg" />
          </UiCardContent>
        </UiCard>

        <!-- To‘lov -->
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-16" />
            </div>
          </UiCardHeader>
          <UiCardContent class="py-4">
            <div class="space-y-2.5">
              <div
                v-for="n in 2"
                :key="n"
                class="flex h-5 items-center justify-between gap-3"
              >
                <UiSkeleton class="h-3.5 w-28" />
                <UiSkeleton class="h-3.5 w-20" />
              </div>
            </div>
            <UiSeparator class="my-3" />
            <div class="flex h-6 items-center justify-between gap-3">
              <UiSkeleton class="h-4 w-12" />
              <UiSkeleton class="h-4 w-28" />
            </div>
          </UiCardContent>
        </UiCard>

        <!-- Jarayon -->
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-20" />
            </div>
          </UiCardHeader>
          <UiCardContent class="space-y-4 py-4">
            <div>
              <div
                v-for="n in 7"
                :key="n"
                class="flex items-center gap-3 pb-4 last:pb-0"
              >
                <UiSkeleton class="size-6 shrink-0 rounded-full" />
                <UiSkeleton class="h-3.5 w-36" />
              </div>
            </div>
            <div class="flex items-center justify-between gap-3 border-t pt-4">
              <div class="flex h-4 items-center">
                <UiSkeleton class="h-3 w-24" />
              </div>
              <UiSkeleton class="h-3 w-32" />
            </div>
          </UiCardContent>
        </UiCard>

        <!-- Ichki izoh va kuryer -->
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-4">
            <div class="flex h-[1.375rem] items-center">
              <UiSkeleton class="h-4 w-36" />
            </div>
          </UiCardHeader>
          <UiCardContent class="space-y-3 py-4">
            <div class="grid gap-1.5">
              <UiSkeleton class="h-3 w-20" />
              <UiSkeleton class="h-24 rounded-xl" />
            </div>
            <div
              v-for="n in 2"
              :key="n"
              class="grid gap-1.5"
            >
              <UiSkeleton class="h-3 w-24" />
              <UiSkeleton class="h-10 rounded-xl" />
            </div>
            <UiSkeleton class="h-10 w-full rounded-xl" />
          </UiCardContent>
        </UiCard>
      </div>
    </div>
  </div>
</template>
