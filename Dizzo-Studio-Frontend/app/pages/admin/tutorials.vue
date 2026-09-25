<script setup lang="ts">
definePageMeta({
  layout: 'admin',
  middleware: [
    () => navigateTo('/admin/gallery?tab=tutorials', { replace: true }),
  ],
});
</script>

<template>
  <div />
</template>
