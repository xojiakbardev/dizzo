<script setup lang="ts">
// A design on its product in 3D, turned by dragging (gallery viewers). It
// fills its parent; three.js loads when it mounts, the Dizzo loader shows
// until the model and the design are drawn.
import type { StudioScene } from '~/lib/three/studioScene';
import type { DesignDocument } from '~/lib/design/document';
import type { Material, PublicShape } from '~/types/catalog';

const props = defineProps<{
  shape: PublicShape;
  material: Material;
  colorHex: string | null;
  document: DesignDocument | null;
}>();

const { t } = useI18n();
const canvasRef = ref<HTMLCanvasElement | null>(null);
const wrapRef = ref<HTMLElement | null>(null);
const state = ref<'loading' | 'ready' | 'error'>('loading');
let scene: StudioScene | null = null;
let observer: ResizeObserver | null = null;
const canvases = new Map<string, HTMLCanvasElement>();

async function paint() {
  if (!scene || !props.document) return;
  const [{ effectiveLayers }, render, { ENGRAVE_TINT }] = await Promise.all([
    import('~/lib/design/document'),
    import('~/lib/design/render'),
    import('~/lib/three/materials'),
  ]);
  const layers = effectiveLayers(props.document, props.shape.areas);
  await render.prepareAssets(layers);
  for (const area of props.shape.areas) {
    let canvas = canvases.get(area.key);
    if (!canvas) {
      canvas = render.previewCanvas(area);
      canvases.set(area.key, canvas);
    }
    await render.paintPreview(canvas, area, layers, ENGRAVE_TINT[props.material], props.document.strips);
    scene?.setAreaTexture(area.key, canvas);
  }
}

async function build() {
  if (!scene) return;
  state.value = 'loading';
  try {
    const current = await scene.setShape(props.shape, props.material, props.colorHex ?? '#ffffff');
    if (!current) return;
    canvases.clear();
    await paint();
    scene?.viewer.frameAll();
    await scene?.viewer.nextFrame(); // the loader stays until it is drawn
    if (scene) state.value = 'ready';
  }
  catch {
    state.value = 'error';
  }
}

onMounted(async () => {
  const { StudioScene } = await import('~/lib/three/studioScene');
  if (!canvasRef.value || !wrapRef.value) return;
  scene = new StudioScene(canvasRef.value);
  scene.viewer.controls.enableZoom = true;
  observer = new ResizeObserver(() => {
    const rect = wrapRef.value?.getBoundingClientRect();
    if (rect?.width) scene?.viewer.resize(rect.width, rect.height);
  });
  observer.observe(wrapRef.value);
  await build();
});

onBeforeUnmount(() => {
  observer?.disconnect();
  scene?.dispose();
  scene = null;
});

watch(() => props.shape, () => void build());
watch(() => props.document, () => void paint());
watch(() => [props.material, props.colorHex] as const, ([material, hex]) => scene?.setAppearance(material, hex ?? '#ffffff'));
</script>

<template>
  <div
    ref="wrapRef"
    class="relative size-full overflow-hidden"
  >
    <canvas
      ref="canvasRef"
      class="block size-full touch-none"
    />
    <StageLoader
      :show="state === 'loading'"
      immediate
      :text="t('storefront.product.view3dLoading')"
    />
    <div
      v-if="state === 'error'"
      class="absolute inset-0 flex items-center justify-center text-sm text-muted-foreground"
    >
      {{ t('storefront.product.model3dError') }}
    </div>
  </div>
</template>
