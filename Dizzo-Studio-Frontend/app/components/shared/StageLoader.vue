<script setup lang="ts">
// The loading overlay of a 3D stage (the model coming in, the cart's long
// "Savatga qo‘shish"): the Dizzo loader in the middle, no box, a short step
// text under it that crossfades as the real work moves on, and a thin bar
// when the share done is known. Short waits never show it (`delay`), and
// once shown it stays a moment (`minShow`) so it doesn't flash.
const props = withDefaults(defineProps<{
  show: boolean;
  text?: string | null;
  progress?: number | null; // 0..1, null: unknown
  veil?: 'solid' | 'soft'; // solid: nothing to see yet; soft: the design stays faintly visible
  immediate?: boolean; // shown at once (a loader was already on screen)
  delay?: number;
  minShow?: number;
}>(), { text: null, progress: null, veil: 'solid', immediate: false, delay: 250, minShow: 600 });

const { t } = useI18n();
const visible = ref(false);
let shownAt = 0;
let timer: ReturnType<typeof setTimeout> | undefined;

function reveal() {
  visible.value = true;
  shownAt = performance.now();
}

watch(() => props.show, (on) => {
  clearTimeout(timer);
  if (on) {
    if (visible.value) return;
    if (props.immediate) reveal(); // on the server too: the same first paint
    else if (import.meta.client) timer = setTimeout(reveal, props.delay);
    return;
  }
  const left = props.minShow - (performance.now() - shownAt);
  if (visible.value && left > 0) timer = setTimeout(() => (visible.value = false), left);
  else visible.value = false;
}, { immediate: true });
onBeforeUnmount(() => clearTimeout(timer));

// Only a new step crossfades; a counter ("3/11") changes in place.
const textKey = computed(() => (props.text ?? '').replace(/\d+\s*\/\s*\d+/g, '#'));
const bar = computed(() => (props.progress == null ? null : Math.min(1, Math.max(0, props.progress))));
</script>

<template>
  <Transition
    enter-active-class="transition-opacity duration-300 ease-out"
    leave-active-class="transition-opacity duration-300 ease-in"
    enter-from-class="opacity-0"
    leave-to-class="opacity-0"
  >
    <div
      v-if="visible"
      class="absolute inset-0 grid place-items-center"
      :class="veil === 'solid' ? 'bg-[#e9ebef]' : 'bg-[#e9ebef]/85'"
      role="status"
      aria-live="polite"
      :aria-label="text || t('storefront.common.loading')"
    >
      <div class="flex w-56 max-w-[80%] flex-col items-center">
        <BrandLoader size="clamp(3.5rem, 12vmin, 5.5rem)" />
        <div
          v-if="text"
          class="mt-4 grid w-full text-center text-[13px] font-medium text-slate-600"
        >
          <Transition
            enter-active-class="transition duration-200 ease-out"
            leave-active-class="transition duration-150 ease-in"
            enter-from-class="opacity-0 translate-y-1"
            leave-to-class="opacity-0 -translate-y-1"
          >
            <span
              :key="textKey"
              class="[grid-area:1/1] truncate tabular-nums"
            >{{ text }}</span>
          </Transition>
        </div>
        <div
          v-if="bar !== null"
          class="mt-2.5 h-[3px] w-24 overflow-hidden rounded-full bg-slate-900/10"
        >
          <div
            class="h-full w-full origin-left rounded-full bg-[#ED5124] transition-transform duration-300 ease-out"
            :style="{ transform: `scaleX(${bar})` }"
          />
        </div>
      </div>
    </div>
  </Transition>
</template>
