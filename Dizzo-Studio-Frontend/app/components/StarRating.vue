<script setup lang="ts">
// Five stars, filled up to `value`; with v-model it becomes a picker.
// Inline SVG, since icon-font stars can't be filled.
const props = defineProps<{ value?: number; class?: string }>();
const model = defineModel<number>();
const shown = computed(() => model.value ?? props.value ?? 0);
const interactive = computed(() => model.value !== undefined);
const STAR = 'M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3l-5.9 3.3 1.3-6.6-4.9-4.6 6.6-.8z';
</script>

<template>
  <div
    class="flex gap-0.5"
    :role="interactive ? 'radiogroup' : 'img'"
    :aria-label="$t('user.review.ratingAria', { value: shown })"
  >
    <component
      :is="interactive ? 'button' : 'span'"
      v-for="s in 5"
      :key="s"
      :type="interactive ? 'button' : undefined"
      :role="interactive ? 'radio' : undefined"
      :aria-checked="interactive ? s === shown : undefined"
      :aria-label="interactive ? $t('user.review.stars', s) : undefined"
      :class="interactive ? 'rounded transition hover:scale-110' : ''"
      @click="interactive && (model = s)"
    >
      <svg
        viewBox="0 0 24 24"
        :class="[props.class, s <= shown ? 'text-amber-400' : 'text-slate-200']"
        aria-hidden="true"
      >
        <path
          :d="STAR"
          fill="currentColor"
        />
      </svg>
    </component>
  </div>
</template>
