<script setup lang="ts">
// A detail page's top row, as on the shape editor: back and the title on the
// left (the default slot adds badges after it); delete / cancel / save on
// the right (#actions).
defineProps<{ back: string; backLabel: string; title: string }>();
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <UiButton
      as-child
      variant="ghost"
      size="icon-sm"
    >
      <NuxtLinkLocale
        :to="back"
        :aria-label="backLabel"
      >
        <Icon
          name="lucide:arrow-left"
          class="size-4"
        />
      </NuxtLinkLocale>
    </UiButton>
    <h1 class="min-w-0 truncate text-xl font-bold leading-7 text-foreground">
      {{ title }}
    </h1>
    <slot />
    <div class="ml-auto flex shrink-0 flex-wrap items-center gap-2">
      <slot name="actions" />
    </div>
  </div>
</template>
