<script setup lang="ts">
// The catalog's search box. One line, 44px tall, so it fits beside the
// shelves button in the phone's sticky bar.
const props = defineProps<{ placeholder?: string }>();
const { t } = useI18n();
const label = computed(() => props.placeholder ?? t('storefront.catalog.search'));
const model = defineModel<string>({ required: true });
</script>

<template>
  <label class="relative block">
    <span class="sr-only">{{ label }}</span>
    <Icon
      name="lucide:search"
      class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-lg text-slate-500"
    />
    <input
      v-model="model"
      type="search"
      :placeholder="label"
      class="h-11 w-full rounded-xl border border-line bg-white pl-11 pr-3 text-base text-ink outline-none transition placeholder:text-slate-500 focus:border-cta focus:ring-2 focus:ring-cta/20"
    >
  </label>
</template>
