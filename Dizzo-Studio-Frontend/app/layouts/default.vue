<script setup lang="ts">
const route = useRoute();
const getRouteBaseName = useRouteBaseName();
const isHome = computed(() => getRouteBaseName(route) === 'index');
</script>

<template>
  <div class="flex min-h-screen flex-col">
    <AppNavbar />
    <main
      id="main-content"
      class="flex-1"
    >
      <slot />
    </main>
    <!-- Only the home page has a footer; the other pages are the customer's cabinet. -->
    <AppFooter v-if="isHome" />
    <!-- "Dizayn yaratishni boshlash" from any storefront page (useProductPicker) -->
    <ProductPicker />
  </div>
</template>
