<script setup lang="ts">
// The product's tab row (inside a UiTabs), with room at its right end for
// the open tab's buttons.
import { PRODUCT_TABS, productTabCount, productTabLabel } from '~/lib/admin/productTabs';
import type { AdminCatalogProduct } from '~/types/catalog';

defineProps<{ product: AdminCatalogProduct | null }>();
</script>

<template>
  <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
    <div class="-mx-3 min-w-0 max-w-[calc(100%+1.5rem)] overflow-x-auto px-3 scrollbar-none sm:mx-0 sm:max-w-full sm:px-0">
      <UiTabsList class="h-11 w-max gap-1 rounded-xl border border-border bg-card p-1 shadow-2xs group-data-horizontal/tabs:h-11">
        <UiTabsTrigger
          v-for="t in PRODUCT_TABS"
          :key="t.id"
          :value="t.id"
          class="h-full flex-none rounded-lg px-3 text-muted-foreground hover:bg-primary/10 hover:text-primary data-active:bg-primary data-active:text-primary-foreground data-active:shadow-xs data-active:hover:bg-primary data-active:hover:text-primary-foreground"
        >
          <Icon
            :name="t.icon"
            class="text-base"
          />
          {{ productTabLabel(t.id) }}
          <span
            v-if="productTabCount(product, t.id) !== null"
            class="rounded-md bg-foreground/10 px-1.5 text-[11px] font-semibold tabular-nums"
          >{{ productTabCount(product, t.id) }}</span>
        </UiTabsTrigger>
      </UiTabsList>
    </div>
    <div class="ml-auto flex shrink-0 items-center gap-2">
      <slot />
    </div>
  </div>
</template>
