<script setup lang="ts">
// "3D" on the product page: the variant's body in its material and colour,
// turned by dragging. three.js is loaded only when the dialog opens.
import type { StudioScene } from '~/lib/three/studioScene';
import type { Material, PublicShape } from '~/types/catalog';

const props = defineProps<{ shape: PublicShape; material: Material; colorHex: string | null; title: string }>();
const open = defineModel<boolean>('open', { default: false });
const { t } = useI18n();

const canvasRef = ref<HTMLCanvasElement | null>(null);
const wrapRef = ref<HTMLElement | null>(null);
const state = ref<'loading' | 'ready' | 'error'>('loading');
let scene: StudioScene | null = null;
let observer: ResizeObserver | null = null;

async function build() {
  if (!scene) return;
  state.value = 'loading';
  try {
    const current = await scene.setShape(props.shape, props.material, props.colorHex ?? '#ffffff');
    if (!current) return;
    scene.viewer.frameAll();
    await scene.viewer.nextFrame(); // the loader stays until the model is drawn
    if (scene) state.value = 'ready';
  }
  catch {
    state.value = 'error';
  }
}

async function start() {
  await nextTick();
  const { StudioScene } = await import('~/lib/three/studioScene');
  if (!open.value || !canvasRef.value || !wrapRef.value) return;
  scene = new StudioScene(canvasRef.value);
  scene.viewer.controls.enableZoom = true; // nothing to scroll inside the dialog
  observer = new ResizeObserver(() => {
    const rect = wrapRef.value?.getBoundingClientRect();
    if (rect?.width) scene?.viewer.resize(rect.width, rect.height);
  });
  observer.observe(wrapRef.value);
  await build();
}

function stop() {
  observer?.disconnect();
  observer = null;
  scene?.dispose();
  scene = null;
}

watch(open, on => (on ? void start() : stop()));
watch(() => props.shape, () => void build());
watch(() => [props.material, props.colorHex] as const, ([material, hex]) => scene?.setAppearance(material, hex ?? '#ffffff'));
onBeforeUnmount(stop);
</script>

<template>
  <UiDialog v-model:open="open">
    <UiDialogContent class="h-[min(85dvh,44rem)] max-w-[calc(100%-1rem)] grid-rows-[auto_minmax(0,1fr)] gap-3 p-3 sm:max-w-3xl">
      <div class="flex min-h-8.5 items-center gap-2 pl-1 pr-10">
        <UiDialogTitle class="truncate text-sm font-semibold">
          {{ title }} — 3D
        </UiDialogTitle>
      </div>
      <UiDialogDescription class="sr-only">
        {{ t('storefront.product.model3dDescription') }}
      </UiDialogDescription>
      <div
        ref="wrapRef"
        class="relative min-h-0 overflow-hidden rounded-lg bg-white"
      >
        <canvas
          ref="canvasRef"
          class="block size-full touch-none"
        />
        <StageLoader
          class="!bg-white"
          :show="state === 'loading'"
          :text="t('storefront.product.model3dLoading')"
        />
        <div
          v-if="state === 'error'"
          class="absolute inset-0 flex items-center justify-center bg-white text-sm text-muted-foreground"
        >
          {{ t('storefront.product.model3dError') }}
        </div>
        <p
          v-else-if="state === 'ready'"
          class="pointer-events-none absolute inset-x-0 bottom-3 text-center text-xs text-muted-foreground"
        >
          {{ t('storefront.product.model3dHint') }}
        </p>
      </div>
    </UiDialogContent>
  </UiDialog>
</template>
