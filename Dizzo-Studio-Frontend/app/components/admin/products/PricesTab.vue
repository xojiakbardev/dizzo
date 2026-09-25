<script setup lang="ts">
import type { AdminCatalogProduct, CatalogMethod } from '~/types/catalog';
import { METHOD_LABELS } from '~/types/catalog';
import PriceTiers from '~/components/admin/products/PriceTiers.vue';

const props = defineProps<{ product: AdminCatalogProduct }>();
const tiersFor = (method: CatalogMethod) => props.product.price_tiers.filter(t => t.method === method);
</script>

<template>
  <div class="grid items-start gap-5 lg:grid-cols-2">
    <PriceTiers
      v-for="method in (Object.keys(METHOD_LABELS) as CatalogMethod[])"
      :key="`${method}-${product.price_tiers.length}`"
      :product-id="product.id"
      :method="method"
      :tiers="tiersFor(method)"
    />
  </div>
</template>
