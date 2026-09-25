<script setup lang="ts">
// A shape to look at: its body with the areas' test prints, turned by
// dragging. Nothing here edits it.
import type { Material, PublicShape } from '~/types/catalog';
import type { StudioScene } from '~/lib/three/studioScene';

const props = defineProps<{ shape: PublicShape }>();

const LOOK: Record<PublicShape['kind'], Material> = { model: 'fabric', cylinder: 'ceramic_glossy', plane: 'paper', disc: 'plastic' };
const wrapRef = ref<HTMLDivElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);
const { t } = useI18n();
const state = ref<'loading' | 'ready' | 'error'>('loading');
let scene: StudioScene | null = null;
let observer: ResizeObserver | null = null;

onMounted(async () => {
  const [{ StudioScene }, { testPatternCanvas }] = await Promise.all([import('~/lib/three/studioScene'), import('~/lib/three/testPattern')]);
  if (!canvasRef.value || !wrapRef.value) return;
  scene = new StudioScene(canvasRef.value);
  scene.viewer.controls.enableZoom = true;
  observer = new ResizeObserver(() => {
    const rect = wrapRef.value!.getBoundingClientRect();
    scene?.viewer.resize(rect.width, rect.height);
  });
  observer.observe(wrapRef.value);
  try {
    await scene.setShape(props.shape, LOOK[props.shape.kind], props.shape.kind === 'model' ? null : '#ffffff');
    for (const area of props.shape.areas) scene.setAreaTexture(area.key, testPatternCanvas(area, true));
    scene.viewer.frameAll();
    await scene.viewer.nextFrame();
    state.value = 'ready';
  }
  catch {
    state.value = 'error';
  }
});

onBeforeUnmount(() => {
  observer?.disconnect();
  scene?.viewer.dispose();
  scene = null;
});

function viewFrom(deg: number) {
  scene?.viewer.viewFrom(deg);
}

const SIDES = computed(() => [
  { label: t('admin.shapeParts.side.front'), deg: 0 }, { label: t('admin.shapeParts.side.left'), deg: 90 },
  { label: t('admin.shapeParts.side.back'), deg: 180 }, { label: t('admin.shapeParts.side.right'), deg: -90 },
]);
</script>

<template>
  <div
    ref="wrapRef"
    class="relative h-[60dvh] max-h-[560px] min-h-[320px] overflow-hidden rounded-xl bg-muted"
  >
    <canvas
      ref="canvasRef"
      class="absolute inset-0 size-full touch-none"
      :aria-label="t('admin.shapeParts.view3d')"
    />
    <StageLoader
      class="!bg-muted"
      :show="state === 'loading'"
    />
    <div
      v-if="state === 'error'"
      class="absolute inset-0 grid place-items-center text-sm text-muted-foreground"
    >
      {{ t('admin.shapeParts.modelOpenFailed') }}
    </div>
    <div
      v-if="state === 'ready'"
      class="absolute bottom-3 left-1/2 flex -translate-x-1/2 gap-0.5 rounded-xl border border-border bg-card/95 p-1 shadow-sm"
    >
      <UiButton
        v-for="s in SIDES"
        :key="s.deg"
        variant="ghost"
        size="sm"
        class="h-8 px-2.5"
        @click="viewFrom(s.deg)"
      >
        {{ s.label }}
      </UiButton>
    </div>
  </div>
</template>
