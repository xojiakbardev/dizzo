<script setup lang="ts">
// The product page's pictures: one large picture that crossfades when the
// set or the picture changes, a strip of thumbnails laid over its bottom
// edge, arrows / keyboard /
// swipe to step, and a full-screen viewer (click to zoom, drag to look
// around). `preload`: pictures the customer is likely to open next
// (the other colours and variants), fetched while the browser is idle.
// The pictures are cut-outs with nothing behind them, so everything here
// sits on the warm plate rather than on white.
const props = withDefaults(defineProps<{ images: string[]; alt: string; preload?: string[] }>(), { preload: () => [] });

const { t } = useI18n();
const active = ref(0);
const open = ref(false);
const zoomed = ref(false);
const origin = ref('50% 50%');
const current = computed(() => props.images[active.value] ?? props.images[0] ?? '');
const strip = ref<HTMLElement | null>(null);

// Keep the active thumbnail in view inside the strip.
watch(active, (i) => {
  const box = strip.value;
  const thumb = box?.querySelectorAll<HTMLElement>('[data-thumb]')[i];
  if (!box || !thumb) return;
  // Only the strip scrolls (scrollIntoView could move the page too).
  const left = thumb.offsetLeft - box.offsetLeft;
  if (left < box.scrollLeft || left + thumb.offsetWidth > box.scrollLeft + box.clientWidth) {
    box.scrollTo({ left: left - (box.clientWidth - thumb.offsetWidth) / 2, behavior: 'smooth' });
  }
});

// A new set (another colour or variant) starts from its first picture.
watch(() => props.images.join('|'), () => {
  active.value = 0;
  zoomed.value = false;
});

function step(by: number) {
  const n = props.images.length;
  if (n > 1) active.value = (active.value + by + n) % n;
  zoomed.value = false;
}

// Swipe on the large picture (touch and pen; a mouse click opens the viewer).
let startX: number | null = null;
function onPointerDown(event: PointerEvent) {
  startX = event.pointerType === 'mouse' ? null : event.clientX;
}
function onPointerUp(event: PointerEvent) {
  if (startX === null) return;
  const dx = event.clientX - startX;
  startX = null;
  if (Math.abs(dx) > 40) step(dx < 0 ? 1 : -1);
}

// The dialog's content forwards listeners to more than one element, so one
// key press can arrive twice: the first handler marks it as handled.
function onViewerKey(event: KeyboardEvent) {
  if (event.defaultPrevented || (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight')) return;
  event.preventDefault();
  step(event.key === 'ArrowLeft' ? -1 : 1);
}

function openViewer() {
  zoomed.value = false;
  open.value = true;
}
function toggleZoom(event: MouseEvent) {
  moveZoom(event);
  zoomed.value = !zoomed.value;
}
function moveZoom(event: MouseEvent | PointerEvent) {
  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
  origin.value = `${((event.clientX - rect.left) / rect.width) * 100}% ${((event.clientY - rect.top) / rect.height) * 100}%`;
}

// Warm the browser cache for the next pictures, a few at a time when idle.
const loaded = new Set<string>();
function warm(urls: string[]) {
  if (!import.meta.client) return;
  const todo = urls.filter(u => u && !loaded.has(u));
  if (!todo.length) return;
  const run = () => todo.forEach((u) => {
    loaded.add(u);
    const img = new Image();
    img.decoding = 'async';
    img.src = u;
  });
  if ('requestIdleCallback' in window) window.requestIdleCallback(run, { timeout: 1500 });
  else setTimeout(run, 300);
}
onMounted(() => {
  warm(props.images);
  watch(() => [...props.images, ...props.preload], warm, { immediate: true });
});
</script>

<template>
  <div
    class="outline-none"
    tabindex="0"
    :aria-roledescription="t('storefront.product.imagesRole')"
    :aria-label="alt"
    @keydown.left.prevent="step(-1)"
    @keydown.right.prevent="step(1)"
  >
    <!-- The warm plate, not white: the pictures are cut out (transparent
         PNGs), so a white mug needs something to stand on. -->
    <div
      class="group relative aspect-square touch-pan-y overflow-hidden rounded-2xl border border-line bg-plate"
      @pointerdown="onPointerDown"
      @pointerup="onPointerUp"
    >
      <Transition
        enter-active-class="transition-opacity duration-300 ease-out"
        enter-from-class="opacity-0"
        leave-active-class="transition-opacity duration-300 ease-in"
        leave-to-class="opacity-0"
      >
        <button
          v-if="current"
          :key="current"
          type="button"
          class="absolute inset-0 flex cursor-zoom-in items-center justify-center"
          :aria-label="t('storefront.gallery.enlarge', { name: alt })"
          @click="openViewer"
        >
          <img
            v-bind="thumbAttrs(current, '(min-width: 1024px) 50vw, 100vw')"
            :alt="t('storefront.product.imageAlt', { name: alt, n: active + 1 })"
            class="object-contain"
            :class="images.length > 1 ? 'mb-14 h-[78%] w-[82%] sm:mb-16' : 'h-[88%] w-[88%]'"
            draggable="false"
          >
        </button>
        <span
          v-else
          class="absolute inset-0 flex items-center justify-center"
        >
          <Icon
            name="lucide:package"
            class="text-5xl text-slate-400"
          />
        </span>
      </Transition>

      <template v-if="images.length > 1">
        <UiButton
          type="button"
          variant="outline"
          size="icon-sm"
          class="absolute left-3 top-1/2 -translate-y-1/2 rounded-full bg-white/90 shadow-xs sm:opacity-0 sm:group-hover:opacity-100 sm:focus-visible:opacity-100"
          :aria-label="t('storefront.product.prevImage')"
          @click="step(-1)"
        >
          <Icon name="lucide:chevron-left" />
        </UiButton>
        <UiButton
          type="button"
          variant="outline"
          size="icon-sm"
          class="absolute right-3 top-1/2 -translate-y-1/2 rounded-full bg-white/90 shadow-xs sm:opacity-0 sm:group-hover:opacity-100 sm:focus-visible:opacity-100"
          :aria-label="t('storefront.product.nextImage')"
          @click="step(1)"
        >
          <Icon name="lucide:chevron-right" />
        </UiButton>

        <!-- thumbnails over the bottom edge; a long set scrolls sideways -->
        <div
          class="absolute inset-x-0 bottom-0 flex justify-center px-3 pb-3"
          @pointerdown.stop
          @pointerup.stop
        >
          <div
            ref="strip"
            class="scrollbar-none flex max-w-full snap-x snap-mandatory scroll-px-1.5 gap-1.5 overflow-x-auto rounded-xl bg-white/75 p-1.5 shadow-xs backdrop-blur-sm"
          >
            <button
              v-for="(src, i) in images"
              :key="src + i"
              data-thumb
              type="button"
              class="size-11 shrink-0 snap-start overflow-hidden rounded-lg bg-plate outline-none transition focus-visible:ring-3 focus-visible:ring-ring/50 sm:size-12"
              :class="i === active ? 'ring-2 ring-primary' : 'opacity-70 hover:opacity-100'"
              :aria-label="t('storefront.product.imageN', { n: i + 1 })"
              :aria-current="i === active"
              @click="active = i"
            >
              <img
                v-bind="thumbSmall(src)"
                alt=""
                loading="lazy"
                class="h-full w-full object-contain"
              >
            </button>
          </div>
        </div>
      </template>

      <div class="absolute right-3 top-3 flex gap-2">
        <slot name="actions" />
      </div>
    </div>
  </div>

  <UiDialog v-model:open="open">
    <UiDialogContent
      class="h-[calc(100dvh-1rem)] max-w-[calc(100%-1rem)] grid-rows-[auto_minmax(0,1fr)_auto] gap-3 p-3 sm:max-w-[calc(100%-2rem)] lg:max-w-6xl"
      @keydown="onViewerKey"
    >
      <div class="flex min-h-8.5 items-center gap-2 pl-1 pr-10">
        <UiDialogTitle class="truncate text-sm font-semibold">
          {{ alt }}
        </UiDialogTitle>
        <UiBadge
          v-if="images.length > 1"
          variant="secondary"
          class="tabular-nums"
        >
          {{ active + 1 }} / {{ images.length }}
        </UiBadge>
      </div>
      <UiDialogDescription class="sr-only">
        {{ t('storefront.product.zoomHint') }}
      </UiDialogDescription>

      <div
        class="relative min-h-0 touch-pan-y overflow-hidden rounded-lg bg-plate"
        @pointerdown="onPointerDown"
        @pointerup="onPointerUp"
      >
        <img
          v-bind="thumbAttrs(current, '100vw')"
          :alt="t('storefront.product.imageAlt', { name: alt, n: active + 1 })"
          class="size-full object-contain transition-transform duration-200"
          :class="zoomed ? 'scale-[2.2] cursor-zoom-out' : 'cursor-zoom-in'"
          :style="{ transformOrigin: origin }"
          draggable="false"
          @click="toggleZoom"
          @mousemove="zoomed && moveZoom($event)"
        >
        <template v-if="images.length > 1">
          <UiButton
            type="button"
            variant="outline"
            size="icon-sm"
            class="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-white/90"
            :aria-label="t('storefront.product.prevImage')"
            @click="step(-1)"
          >
            <Icon name="lucide:chevron-left" />
          </UiButton>
          <UiButton
            type="button"
            variant="outline"
            size="icon-sm"
            class="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-white/90"
            :aria-label="t('storefront.product.nextImage')"
            @click="step(1)"
          >
            <Icon name="lucide:chevron-right" />
          </UiButton>
        </template>
      </div>

      <div
        v-if="images.length > 1"
        class="scrollbar-none flex justify-center gap-2 overflow-x-auto"
      >
        <button
          v-for="(src, i) in images"
          :key="src + i"
          type="button"
          class="size-12 shrink-0 overflow-hidden rounded-lg border-2 bg-plate"
          :class="i === active ? 'border-primary' : 'border-border/70'"
          :aria-label="t('storefront.product.imageN', { n: i + 1 })"
          @click="active = i; zoomed = false"
        >
          <img
            v-bind="thumbSmall(src)"
            alt=""
            class="h-full w-full object-contain"
          >
        </button>
      </div>
    </UiDialogContent>
  </UiDialog>
</template>
