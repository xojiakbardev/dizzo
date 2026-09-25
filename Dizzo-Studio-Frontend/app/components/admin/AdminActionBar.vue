<script setup lang="ts">
// The page's own "Bekor qilish" / "Saqlash" row: the last thing on an edit
// page, stuck to the bottom of the admin's scrolling <main> while the page
// is longer than the screen. It bleeds over <main>'s padding (p-3 sm:p-4)
// so it runs edge to edge. Buttons go in the default slot (right side);
// anything for the left (a destructive action, a note) in #start.
</script>

<template>
  <div
    data-slot="admin-action-bar"
    class="sticky -bottom-3 z-20 -mx-3 -mb-3 mt-5 border-t border-border bg-card/95 px-3 pt-3 pb-[calc(0.75rem+env(safe-area-inset-bottom,0px))] shadow-[0_-6px_16px_-10px_rgb(15_23_42/0.18)] backdrop-blur-sm sm:-bottom-4 sm:-mx-4 sm:-mb-4 sm:px-4"
  >
    <div class="flex flex-wrap items-center justify-end gap-2">
      <div
        v-if="$slots.start"
        class="mr-auto flex min-w-0 items-center gap-2"
      >
        <slot name="start" />
      </div>
      <slot />
    </div>
  </div>
</template>
