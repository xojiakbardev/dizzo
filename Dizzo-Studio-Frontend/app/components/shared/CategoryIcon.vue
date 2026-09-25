<script setup lang="ts">
// A shelf's icon: its picture if it has one, else its SVG drawn in the
// text colour (as a mask, so an admin's SVG never runs as markup).
const props = defineProps<{ svg?: string | null; image?: string | null }>();

const mask = computed(() => {
  if (props.image || !props.svg?.trim()) return null;
  const url = `url("data:image/svg+xml;charset=utf-8,${encodeURIComponent(props.svg)}")`;
  return { maskImage: url, WebkitMaskImage: url };
});
</script>

<template>
  <img
    v-if="image"
    v-bind="thumbSmall(image)"
    alt=""
    class="size-[1.25em] shrink-0 rounded object-cover"
    loading="lazy"
  >
  <span
    v-else-if="mask"
    class="inline-block size-[1.25em] shrink-0 bg-current [mask-position:center] [mask-repeat:no-repeat] [mask-size:contain]"
    :style="mask"
    aria-hidden="true"
  />
</template>
