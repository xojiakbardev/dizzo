<script setup lang="ts">
// Previous / next pages on the left, "page / pages · total N" on the right.
const props = withDefaults(
  defineProps<{
    totalPages: number;
    totalCount?: number;
    perPage?: number;
  }>(),
  {
    totalCount: undefined,
    perPage: 20,
  },
);

const page = defineModel<number>('page', { default: 1 });
const pages = computed(() => Math.max(1, props.totalPages || 1));
</script>

<template>
  <div class="flex flex-wrap items-center justify-between gap-3 pt-2 text-sm">
    <div class="flex items-center gap-2">
      <UiButton
        variant="outline"
        size="sm"
        :disabled="page <= 1"
        :aria-label="$t('common.ui.pagination.previousPage')"
        @click="page = Math.max(1, page - 1)"
      >
        <Icon
          name="lucide:chevron-left"
          class="text-base"
        />
        {{ $t('common.ui.pagination.previous') }}
      </UiButton>
      <UiButton
        variant="outline"
        size="sm"
        :disabled="page >= pages"
        :aria-label="$t('common.ui.pagination.nextPage')"
        @click="page = Math.min(pages, page + 1)"
      >
        {{ $t('common.ui.pagination.next') }}
        <Icon
          name="lucide:chevron-right"
          class="text-base"
        />
      </UiButton>
    </div>
    <span class="ml-auto text-sm text-muted-foreground tabular-nums">
      <i18n-t
        keypath="common.ui.pagination.pageOf"
        tag="span"
        scope="global"
      >
        <template #page><span class="font-semibold text-foreground">{{ page }}</span></template>
        <template #pages>{{ pages }}</template>
      </i18n-t>
      <template v-if="totalCount !== undefined"> · {{ $t('common.ui.pagination.total', { count: totalCount }) }}</template>
    </span>
  </div>
</template>
