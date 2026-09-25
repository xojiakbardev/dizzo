<script setup lang="ts">
// A list page's top row, as on "Buyurtmalar": the search and filters on the
// left; refresh (an icon) and the page's add button on the right. No title —
// the navbar says where you are.
// @refresh is a prop, so the button shows only on pages that listen.
const props = defineProps<{ placeholder?: string; refreshing?: boolean; onRefresh?: () => void }>();
const search = defineModel<string>('search');
</script>

<template>
  <div class="flex flex-wrap items-center gap-3">
    <div
      v-if="search !== undefined"
      class="relative w-full min-w-0 sm:w-auto sm:min-w-[240px] sm:flex-1"
    >
      <Icon
        name="lucide:search"
        class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
      />
      <UiInput
        v-model="search"
        :placeholder="placeholder"
        class="bg-card pl-10"
        :aria-label="$t('admin.common.search')"
      />
    </div>
    <slot />
    <div class="ml-auto flex items-center gap-2">
      <slot name="actions" />
    </div>
  </div>
</template>
