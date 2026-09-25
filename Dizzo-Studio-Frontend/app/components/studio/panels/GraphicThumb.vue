<script setup lang="ts">
// A library graphic drawn as inline SVG (panel thumbnails).
import type { GraphicDef } from '~/lib/design/graphics';

defineProps<{ def: GraphicDef }>();
</script>

<template>
  <svg
    :viewBox="`0 0 ${def.width} ${def.height}`"
    class="max-h-full max-w-full"
    aria-hidden="true"
  >
    <path
      v-for="(p, i) in def.paths"
      :key="i"
      :d="p.d"
      :fill-rule="p.evenOdd ? 'evenodd' : undefined"
      fill="currentColor"
    />
  </svg>
</template>
