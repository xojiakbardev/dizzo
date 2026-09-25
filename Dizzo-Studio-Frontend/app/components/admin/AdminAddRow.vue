<script setup lang="ts">
// The "add" row under an admin list: the new item's fields and one button,
// in a dashed frame. Enter in a field adds too. Not a <form>, so it can sit
// inside one.
defineProps<{ label: string; disabled?: boolean }>();
const emit = defineEmits<{ add: [] }>();
</script>

<template>
  <div
    role="group"
    :aria-label="label"
    class="flex flex-wrap items-center gap-2 rounded-xl border border-dashed border-border p-3"
    @keydown.enter.prevent="!disabled && emit('add')"
  >
    <slot />
    <UiButton
      type="button"
      size="sm"
      class="h-9"
      :class="$slots.default ? '' : 'flex-1'"
      :variant="$slots.default ? 'default' : 'ghost'"
      :disabled="disabled"
      @click="emit('add')"
    >
      <Icon
        name="lucide:plus"
        class="h-4 w-4"
      />
      {{ label }}
    </UiButton>
  </div>
</template>
