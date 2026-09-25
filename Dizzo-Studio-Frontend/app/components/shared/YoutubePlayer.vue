<script setup lang="ts">
// A YouTube video with our own controls and none of YouTube's: the frame
// is three times as tall as the box (the video sits in its middle band), so
// the title bar and the logo fall outside; a layer over it keeps YouTube's
// hover UI from appearing; on pause or at the end our cover shows instead
// of "More videos". The Dizzo loader stays until the video really plays.
const props = defineProps<{ videoId: string; title?: string; poster?: string | null }>();
const { t } = useI18n();

interface YtPlayer {
  playVideo(): void;
  pauseVideo(): void;
  seekTo(seconds: number, allowSeekAhead: boolean): void;
  mute(): void;
  unMute(): void;
  isMuted(): boolean;
  getCurrentTime(): number;
  getDuration(): number;
  destroy(): void;
}
interface YtNamespace {
  Player: new (el: HTMLElement, options: Record<string, unknown>) => YtPlayer;
  PlayerState: { ENDED: number; PLAYING: number; PAUSED: number; BUFFERING: number };
}
type YtWindow = Window & { YT?: YtNamespace; onYouTubeIframeAPIReady?: () => void };

let apiPromise: Promise<YtNamespace> | null = null;
function loadApi(): Promise<YtNamespace> {
  const w = window as YtWindow;
  if (w.YT?.Player) return Promise.resolve(w.YT);
  apiPromise ??= new Promise((resolve, reject) => {
    const previous = w.onYouTubeIframeAPIReady;
    w.onYouTubeIframeAPIReady = () => {
      previous?.();
      resolve(w.YT!);
    };
    const script = document.createElement('script');
    script.src = 'https://www.youtube.com/iframe_api';
    script.async = true;
    script.onerror = () => {
      apiPromise = null;
      reject(new Error('youtube'));
    };
    document.head.appendChild(script);
  });
  return apiPromise;
}

const box = ref<HTMLElement | null>(null);
const mount = ref<HTMLElement | null>(null);
const state = ref<'loading' | 'playing' | 'paused' | 'ended' | 'error'>('loading');
const started = ref(false);
const muted = ref(false);
const current = ref(0);
const duration = ref(0);
let player: YtPlayer | null = null;
let ticker: ReturnType<typeof setInterval> | undefined;
let autoplayCheck: ReturnType<typeof setTimeout> | undefined;

onMounted(async () => {
  try {
    const YT = await loadApi();
    if (!mount.value) return;
    player = new YT.Player(mount.value, {
      host: 'https://www.youtube-nocookie.com',
      videoId: props.videoId,
      playerVars: {
        autoplay: 1, controls: 0, rel: 0, modestbranding: 1, iv_load_policy: 3, playsinline: 1,
        disablekb: 1, fs: 0, cc_load_policy: 0, origin: window.location.origin,
      },
      events: {
        onReady: () => {
          duration.value = player?.getDuration() ?? 0;
          player?.playVideo();
          // Autoplay with sound can be refused: then the play button shows.
          autoplayCheck = setTimeout(() => {
            if (!started.value) state.value = 'paused';
          }, 2500);
        },
        onStateChange: (event: { data: number }) => {
          if (event.data === YT.PlayerState.PLAYING) {
            started.value = true;
            state.value = 'playing';
            duration.value = player?.getDuration() ?? duration.value;
          }
          else if (event.data === YT.PlayerState.PAUSED) state.value = 'paused';
          else if (event.data === YT.PlayerState.ENDED) state.value = 'ended';
        },
        onError: () => {
          state.value = 'error';
        },
      },
    });
    ticker = setInterval(() => {
      if (player && state.value === 'playing') current.value = player.getCurrentTime();
    }, 250);
  }
  catch {
    state.value = 'error';
  }
});

onBeforeUnmount(() => {
  clearInterval(ticker);
  clearTimeout(autoplayCheck);
  player?.destroy();
  player = null;
});

function toggle() {
  if (!player) return;
  if (state.value === 'playing') player.pauseVideo();
  else {
    if (state.value === 'ended') player.seekTo(0, true);
    player.playVideo();
  }
}
function seek(event: Event) {
  const value = Number((event.target as HTMLInputElement).value);
  current.value = value;
  player?.seekTo(value, true);
}
function toggleMute() {
  if (!player) return;
  if (player.isMuted()) player.unMute();
  else player.mute();
  muted.value = !muted.value;
}
function fullscreen() {
  const el = box.value;
  if (!el) return;
  if (document.fullscreenElement) void document.exitFullscreen();
  else void el.requestFullscreen?.();
}
const clock = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
</script>

<template>
  <div
    ref="box"
    class="group relative aspect-video w-full overflow-hidden bg-black"
  >
    <!-- the frame, three boxes tall: only the video's band is visible -->
    <div class="pointer-events-none absolute inset-x-0 top-1/2 h-[300%] -translate-y-1/2">
      <div
        ref="mount"
        class="size-full"
      />
    </div>

    <!-- our layer: a tap plays or pauses; YouTube never sees the pointer -->
    <button
      type="button"
      class="absolute inset-0 cursor-pointer"
      :aria-label="state === 'playing' ? t('common.video.pause') : t('common.video.play')"
      @click="toggle"
    />

    <!-- before it plays, on pause and at the end: the cover and a big button -->
    <div
      v-if="state === 'paused' || state === 'ended' || (state === 'loading' && !started)"
      class="pointer-events-none absolute inset-0 flex items-center justify-center bg-black"
    >
      <img
        v-if="poster"
        v-bind="thumbAttrs(poster, '100vw')"
        alt=""
        class="absolute inset-0 size-full object-cover opacity-60"
      >
      <span
        v-if="state !== 'loading'"
        class="relative flex size-16 items-center justify-center rounded-full bg-white/95 text-ink shadow-lg sm:size-20"
      >
        <Icon
          :name="state === 'ended' ? 'lucide:rotate-ccw' : 'lucide:play'"
          class="ml-0.5 text-3xl sm:text-4xl"
        />
      </span>
    </div>

    <StageLoader
      :show="state === 'loading'"
      immediate
      :text="t('common.video.loading')"
    />

    <div
      v-if="state === 'error'"
      class="absolute inset-0 flex items-center justify-center bg-black p-6 text-center text-sm text-white/80"
    >
      {{ t('common.video.error') }}
    </div>

    <!-- controls: always on phones, on hover on computers -->
    <div
      v-if="started && state !== 'error'"
      class="absolute inset-x-0 bottom-0 flex items-center gap-2 bg-gradient-to-t from-black/70 to-transparent px-3 pb-2 pt-6 text-white transition-opacity sm:opacity-0 sm:group-hover:opacity-100"
      :class="{ 'sm:opacity-100': state !== 'playing' }"
    >
      <button
        type="button"
        class="flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-full hover:bg-white/15"
        :aria-label="state === 'playing' ? t('common.video.pause') : t('common.video.play')"
        @click="toggle"
      >
        <Icon
          :name="state === 'playing' ? 'lucide:pause' : 'lucide:play'"
          class="text-xl"
        />
      </button>
      <span class="shrink-0 text-xs tabular-nums">{{ clock(current) }}</span>
      <input
        type="range"
        min="0"
        :max="duration || 0"
        step="0.1"
        :value="current"
        class="h-1 min-w-0 flex-1 cursor-pointer accent-[#ed5123]"
        :aria-label="t('common.video.seek')"
        @input="seek"
      >
      <span class="shrink-0 text-xs tabular-nums">{{ clock(duration) }}</span>
      <button
        type="button"
        class="flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-full hover:bg-white/15"
        :aria-label="muted ? t('common.video.unmute') : t('common.video.mute')"
        @click="toggleMute"
      >
        <Icon
          :name="muted ? 'lucide:volume-x' : 'lucide:volume-2'"
          class="text-xl"
        />
      </button>
      <button
        type="button"
        class="flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-full hover:bg-white/15"
        :aria-label="t('common.video.fullscreen')"
        @click="fullscreen"
      >
        <Icon
          name="lucide:maximize"
          class="text-xl"
        />
      </button>
    </div>
  </div>
</template>
