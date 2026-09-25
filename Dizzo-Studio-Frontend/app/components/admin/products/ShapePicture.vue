<script setup lang="ts">
// A shape drawn in 3D with its print areas, as a still picture (see
// lib/three/thumbnails.ts). Skeleton while it is drawn.
import type { PublicShape } from '~/types/catalog';
import { cn } from '~/lib/utils';

const props = withDefaults(defineProps<{ shape: PublicShape; size?: number; class?: string }>(), { size: 480, class: '' });
const src = ref<string | null>(null);
const failed = ref(false);

watch(() => props.shape, async (shape) => {
  failed.value = false;
  try {
    const { shapePicture } = await import('~/lib/three/thumbnails');
    src.value = await shapePicture(shape, props.size);
  }
  catch {
    // A model that doesn't load shows the box icon instead.
    failed.value = true;
  }
}, { immediate: true });
</script>

<template>
  <MediaThumb
    :src="failed ? null : src"
    :class="cn('aspect-square w-full', props.class)"
  >
    <template #fallback>
      <Icon
        v-if="failed"
        name="lucide:box"
        class="h-8 w-8 text-muted-foreground/60"
      />
      <UiSkeleton
        v-else
        class="absolute inset-0 size-full rounded-none"
      />
    </template>
  </MediaThumb>
</template>
