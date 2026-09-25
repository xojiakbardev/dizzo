<script setup lang="ts">
// A product's "Galereya" tab: the gallery's list, only this product's designs.
import GalleryDesigns from '~/components/admin/GalleryDesigns.vue';
import type { AdminCatalogProduct } from '~/types/catalog';

defineProps<{ product: AdminCatalogProduct }>();
</script>

<template>
  <GalleryDesigns :product="{ id: product.id, slug: product.slug }" />
</template>
