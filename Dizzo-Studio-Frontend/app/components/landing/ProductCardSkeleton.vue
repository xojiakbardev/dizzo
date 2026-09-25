<script setup lang="ts">
// ProductCard's shape in grey while the catalog loads (landing and catalog):
// the same border, photo ratio and line heights, so nothing moves when the
// real cards arrive.
</script>

<template>
  <div class="flex h-full flex-col overflow-hidden rounded-2xl border border-line bg-white">
    <UiSkeleton class="aspect-[5/4] rounded-none bg-plate" />
    <div class="flex flex-1 flex-col border-t border-line px-3.5 pb-3.5 pt-3 sm:px-4 sm:pb-4">
      <div class="flex h-lh items-center text-[15px] leading-snug sm:text-base">
        <UiSkeleton class="h-[0.9em] w-3/4 bg-plate" />
      </div>
      <div class="mt-auto flex h-lh items-center justify-between pt-1.5 text-[15px]">
        <UiSkeleton class="h-[0.9em] w-1/2 bg-plate" />
        <UiSkeleton class="h-[0.9em] w-12 bg-plate" />
      </div>
    </div>
  </div>
</template>
