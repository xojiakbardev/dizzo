<script setup lang="ts">
// "Video darsliklar": short videos on using the site, as a masonry wall of
// covers (each keeps its own shape). A tile with a video opens it in a
// lightbox (YouTube / Telegram embed, an MP4 in <video>, else a new tab);
// one without says "Tez orada". The landing hides the section when the
// admin has published nothing (index.vue).
import { tutorialPlayer, type Tutorial } from '~/composables/queries/useTutorials';

const props = defineProps<{ items: Tutorial[] }>();
const { t } = useI18n();

// The wall is at most this long; more would bury the sections below.
const shown = computed(() => props.items.slice(0, 12));

const playing = ref<Tutorial | null>(null);
// The loader stays over a Telegram frame or an MP4 until it can play.
const mediaReady = ref(false);
watch(playing, () => {
  mediaReady.value = false;
});
const player = computed(() => (playing.value?.video_url ? tutorialPlayer(playing.value.video_url) : null));
const open = computed({
  get: () => playing.value !== null,
  set: (value: boolean) => {
    if (!value) playing.value = null;
  },
});

function play(item: Tutorial) {
  if (!item.video_url) return;
  const p = tutorialPlayer(item.video_url);
  if (p.kind === 'link') window.open(p.src, '_blank', 'noopener');
  else playing.value = item;
}

const ratio = (item: Tutorial) =>
  item.cover_width && item.cover_height ? `${item.cover_width} / ${item.cover_height}` : undefined;
</script>

<template>
  <section
    id="tutorials"
    aria-labelledby="tutorials-title"
    class="scroll-mt-20"
  >
    <h2
      id="tutorials-title"
      class="text-2xl font-extrabold tracking-[-0.02em] text-ink sm:text-[1.75rem]"
    >
      {{ t('storefront.nav.tutorials') }}
    </h2>

    <ul class="mt-5 columns-2 gap-3 sm:columns-3 sm:gap-4 lg:columns-4 lg:gap-5">
      <li
        v-for="item in shown"
        :key="item.id"
        class="mb-3 break-inside-avoid sm:mb-4 lg:mb-5"
      >
        <component
          :is="item.video_url ? 'button' : 'div'"
          :type="item.video_url ? 'button' : undefined"
          class="group relative block w-full overflow-hidden rounded-2xl border border-line bg-white text-left shadow-xs transition duration-300 hover:-translate-y-1 hover:shadow-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
          :class="item.video_url ? 'cursor-pointer' : 'cursor-default'"
          :aria-label="item.video_url ? t('storefront.tutorials.watch', { title: item.title }) : undefined"
          @click="play(item)"
        >
          <span class="relative block overflow-hidden bg-plate">
            <img
              v-bind="thumbAttrs(item.cover_url, '(min-width: 1024px) 25vw, 50vw')"
              :alt="item.title"
              :width="item.cover_width ?? undefined"
              :height="item.cover_height ?? undefined"
              :style="{ aspectRatio: ratio(item) }"
              class="block h-auto w-full object-cover transition duration-500 group-hover:scale-[1.03]"
              loading="lazy"
            >
            <span
              class="absolute right-2.5 top-2.5 flex size-10 items-center justify-center rounded-full shadow-md backdrop-blur-sm transition duration-300 group-hover:scale-110 sm:size-11"
              :class="item.video_url ? 'bg-cta text-white' : 'bg-white/85 text-ink/70'"
              aria-hidden="true"
            >
              <Icon
                name="lucide:play"
                class="ml-0.5 size-4 fill-current sm:size-5"
              />
            </span>
          </span>
          <span class="flex items-start justify-between gap-2 px-3 py-2.5 sm:px-4 sm:py-3">
            <span class="text-sm font-bold leading-snug text-ink sm:text-[15px]">{{ item.title }}</span>
            <span
              v-if="!item.video_url"
              class="mt-px shrink-0 rounded-full bg-plate px-2 py-0.5 text-[11px] font-semibold text-slate-600"
            >{{ t('storefront.tutorials.soon') }}</span>
          </span>
        </component>
      </li>
    </ul>

    <UiDialog v-model:open="open">
      <UiDialogContent class="gap-3 p-3 sm:max-w-4xl sm:p-4">
        <UiDialogHeader>
          <UiDialogTitle class="pr-8">
            {{ playing?.title }}
          </UiDialogTitle>
        </UiDialogHeader>
        <div class="relative overflow-hidden rounded-xl bg-black">
          <YoutubePlayer
            v-if="player?.kind === 'youtube'"
            :key="player.id"
            :video-id="player.id"
            :title="playing?.title"
            :poster="playing?.cover_url"
          />
          <template v-else-if="player?.kind === 'iframe'">
            <iframe
              :src="player.src"
              :title="playing?.title"
              class="aspect-video w-full"
              allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
              allowfullscreen
              @load="mediaReady = true"
            />
            <StageLoader
              :show="!mediaReady"
              immediate
              :text="t('common.video.loading')"
            />
          </template>
          <template v-else-if="player?.kind === 'video'">
            <video
              :src="player.src"
              :poster="playing?.cover_url"
              class="aspect-video w-full"
              controls
              autoplay
              playsinline
              controlslist="nodownload"
              @playing="mediaReady = true"
              @canplay="mediaReady = true"
            />
            <StageLoader
              :show="!mediaReady"
              immediate
              :text="t('common.video.loading')"
            />
          </template>
        </div>
      </UiDialogContent>
    </UiDialog>
  </section>
</template>
