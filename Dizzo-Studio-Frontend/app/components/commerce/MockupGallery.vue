<script setup lang="ts">
// A cart or order item's pictures: the Studio takes five views of the
// product (the design's front, either side, the back, from above); older
// items have one to three. `auto`: on phones a row of equal tiles, from
// `sm` the first picture large with the others under it (hovering one shows
// it large); `stacked`: that at every width ("Dizaynlarim"'s cards); `row`:
// small tiles only (the checkout summary); `swipe`: one picture at a time,
// swiped sideways with dots under it (the order page). Any picture
// opens large in a dialog, with arrows and the others under it. With
// `skeleton` it draws its own placeholder at the same size.
import { cn } from '~/lib/utils';

const props = withDefaults(defineProps<{
  images?: string[];
  alt?: string;
  layout?: 'auto' | 'stacked' | 'row' | 'swipe';
  /** `row` tiles' size. */
  tileClass?: string;
  skeleton?: boolean;
  /** How many pictures the skeleton stands for. */
  count?: number;
  class?: string;
}>(), { images: () => [], alt: '', layout: 'auto', tileClass: 'size-12', skeleton: false, count: 5, class: '' });

const active = ref(0);
const viewing = ref(0);
const open = ref(false);
const total = computed(() => (props.skeleton ? props.count : props.images.length));
const stacked = computed(() => props.layout === 'stacked');
watch(() => props.images, () => {
  active.value = 0;
});

const strip = ref<HTMLElement | null>(null);
function onSwipe() {
  const el = strip.value;
  if (el?.clientWidth) active.value = Math.round(el.scrollLeft / el.clientWidth);
}
function swipeTo(index: number) {
  strip.value?.scrollTo({ left: index * strip.value.clientWidth, behavior: 'smooth' });
}

function openAt(index: number) {
  viewing.value = index;
  open.value = true;
}
function step(by: number) {
  const n = props.images.length;
  if (n > 1) viewing.value = (viewing.value + by + n) % n;
}
</script>

<template>
  <!-- row: small tiles only -->
  <div
    v-if="layout === 'row'"
    :class="cn('flex flex-wrap gap-1.5', props.class)"
  >
    <template v-if="skeleton">
      <UiSkeleton
        v-for="i in count"
        :key="i"
        :class="cn('rounded-lg', tileClass)"
      />
    </template>
    <template v-else>
      <button
        v-for="(src, i) in images"
        :key="i"
        type="button"
        class="rounded-lg outline-none transition hover:opacity-85 focus-visible:ring-3 focus-visible:ring-ring/50"
        :aria-label="$t('user.gallery.enlargeView', { alt, n: i + 1 })"
        @click="openAt(i)"
      >
        <MediaThumb
          :src="src"
          :alt="$t('user.gallery.viewOf', { alt, n: i + 1 })"
          :class="cn('rounded-lg ring-1 ring-inset ring-foreground/10', tileClass)"
        />
      </button>
    </template>
  </div>

  <!-- swipe: one picture at a time, dots under it -->
  <div
    v-else-if="layout === 'swipe'"
    :class="cn('min-w-0', props.class)"
  >
    <UiSkeleton
      v-if="skeleton"
      class="aspect-square w-full rounded-xl"
    />
    <MediaThumb
      v-else-if="!images.length"
      class="aspect-square w-full rounded-xl"
    />
    <template v-else>
      <div
        ref="strip"
        class="flex aspect-square w-full snap-x snap-mandatory overflow-x-auto overscroll-x-contain rounded-xl [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        @scroll.passive="onSwipe"
      >
        <button
          v-for="(src, i) in images"
          :key="i"
          type="button"
          class="aspect-square w-full shrink-0 snap-center outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
          :aria-label="$t('user.gallery.enlargeView', { alt, n: i + 1 })"
          @click="openAt(i)"
        >
          <MediaThumb
            :src="src"
            :alt="$t('user.gallery.viewOf', { alt, n: i + 1 })"
            class="size-full rounded-xl ring-1 ring-inset ring-foreground/10"
          />
        </button>
      </div>
      <div
        v-if="images.length > 1"
        class="mt-1.5 flex justify-center gap-1"
      >
        <button
          v-for="(_, i) in images"
          :key="i"
          type="button"
          class="h-1.5 rounded-full transition-all"
          :class="i === active ? 'w-3 bg-primary' : 'w-1.5 bg-foreground/20 hover:bg-foreground/40'"
          :aria-label="$t('user.gallery.view', { n: i + 1 })"
          :aria-pressed="i === active"
          @click="swipeTo(i)"
        />
      </div>
    </template>
  </div>

  <!-- auto: tiles on phones, the main picture and its thumbnails from sm;
       stacked: the main picture and its thumbnails -->
  <div
    v-else
    :class="cn('min-w-0', props.class)"
  >
    <template v-if="skeleton">
      <UiSkeleton
        class="aspect-square w-full rounded-xl"
        :class="stacked ? '' : count > 1 ? 'hidden sm:block' : 'w-24 sm:w-full'"
      />
      <div
        v-if="count > 1"
        class="grid grid-cols-5"
        :class="stacked ? 'mt-2 gap-1.5' : 'gap-2 sm:mt-2 sm:gap-1.5'"
      >
        <UiSkeleton
          v-for="i in count"
          :key="i"
          class="aspect-square w-full rounded-lg"
        />
      </div>
    </template>

    <template v-else-if="total">
      <button
        type="button"
        class="group relative block aspect-square overflow-hidden rounded-xl outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
        :class="stacked ? 'w-full' : total > 1 ? 'hidden w-full sm:block' : 'w-24 sm:w-full'"
        :aria-label="$t('user.gallery.enlarge', { alt })"
        @click="openAt(active)"
      >
        <MediaThumb
          :src="images[active]"
          :alt="$t('user.gallery.viewOf', { alt, n: active + 1 })"
          class="size-full rounded-xl ring-1 ring-inset ring-foreground/10"
        />
        <span class="pointer-events-none absolute right-2 top-2 flex size-7 items-center justify-center rounded-lg bg-background/90 text-foreground opacity-0 shadow-xs backdrop-blur transition group-hover:opacity-100 group-focus-visible:opacity-100">
          <Icon
            name="lucide:maximize-2"
            class="text-sm"
          />
        </span>
      </button>
      <div
        v-if="total > 1"
        class="grid grid-cols-5"
        :class="stacked ? 'mt-2 gap-1.5' : 'gap-2 sm:mt-2 sm:gap-1.5'"
      >
        <button
          v-for="(src, i) in images"
          :key="i"
          type="button"
          class="rounded-lg outline-none transition focus-visible:ring-3 focus-visible:ring-ring/50"
          :class="stacked
            ? (i === active ? 'ring-2 ring-primary' : 'opacity-75 hover:opacity-100')
            : (i === active ? 'sm:ring-2 sm:ring-primary' : 'sm:opacity-75 sm:hover:opacity-100')"
          :aria-label="$t('user.gallery.viewOfLabel', { alt, n: i + 1 })"
          @mouseenter="active = i"
          @focus="active = i"
          @click="openAt(i)"
        >
          <MediaThumb
            :src="src"
            alt=""
            class="aspect-square w-full rounded-lg ring-1 ring-inset ring-foreground/10"
          />
        </button>
      </div>
    </template>

    <MediaThumb
      v-else
      class="aspect-square rounded-xl"
      :class="stacked ? 'w-full' : 'w-24 sm:w-full'"
    />
  </div>

  <UiDialog
    v-if="!skeleton && images.length"
    v-model:open="open"
  >
    <UiDialogContent
      class="gap-3 p-3 sm:max-w-2xl"
      @keydown.left.prevent="step(-1)"
      @keydown.right.prevent="step(1)"
    >
      <div class="flex min-h-8.5 items-center gap-2 pr-10 pl-1">
        <UiDialogTitle class="truncate text-sm font-semibold">
          {{ alt }}
        </UiDialogTitle>
        <UiBadge
          v-if="images.length > 1"
          variant="secondary"
          class="tabular-nums"
        >
          {{ viewing + 1 }} / {{ images.length }}
        </UiBadge>
      </div>
      <UiDialogDescription class="sr-only">
        {{ $t('user.gallery.description') }}
      </UiDialogDescription>

      <div class="relative mx-auto aspect-square w-full max-w-[min(100%,70dvh)]">
        <MediaThumb
          :src="images[viewing]"
          :alt="$t('user.gallery.viewOf', { alt, n: viewing + 1 })"
          class="size-full rounded-lg"
        />
        <template v-if="images.length > 1">
          <UiButton
            type="button"
            variant="outline"
            size="icon-sm"
            class="absolute top-1/2 left-2 -translate-y-1/2 bg-background/90 backdrop-blur"
            :aria-label="$t('user.gallery.prev')"
            @click="step(-1)"
          >
            <Icon
              name="lucide:chevron-left"
              class="text-lg"
            />
          </UiButton>
          <UiButton
            type="button"
            variant="outline"
            size="icon-sm"
            class="absolute top-1/2 right-2 -translate-y-1/2 bg-background/90 backdrop-blur"
            :aria-label="$t('user.gallery.next')"
            @click="step(1)"
          >
            <Icon
              name="lucide:chevron-right"
              class="text-lg"
            />
          </UiButton>
        </template>
      </div>

      <div
        v-if="images.length > 1"
        class="flex justify-center gap-1.5"
      >
        <button
          v-for="(src, i) in images"
          :key="i"
          type="button"
          class="rounded-lg outline-none transition focus-visible:ring-3 focus-visible:ring-ring/50"
          :class="i === viewing ? 'ring-2 ring-primary' : 'opacity-70 hover:opacity-100'"
          :aria-label="$t('user.gallery.view', { n: i + 1 })"
          :aria-pressed="i === viewing"
          @click="viewing = i"
        >
          <MediaThumb
            :src="src"
            alt=""
            class="size-12 rounded-lg sm:size-14"
          />
        </button>
      </div>
    </UiDialogContent>
  </UiDialog>
</template>
