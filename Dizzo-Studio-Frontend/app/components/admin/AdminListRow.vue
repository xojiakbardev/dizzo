<script setup lang="ts">
// One row of an admin list (colours, sizes, specs, price ranges): the same
// card look everywhere.
</script>

<template>
  <div class="flex flex-wrap items-center gap-2 rounded-xl border border-border bg-card p-3">
    <slot />
  </div>
</template>
