<script setup lang="ts">
// The Studio's engine alone, for the mobile app: its editor is native, but
// the 3D view, the mockups and the print files come from here (in a
// WebView), so they are the web's to the pixel. No chrome, no sign-in; the
// host drives it with window.dizzoEngine.call() and hears back through the
// bridge (lib/embed/bridge.ts). The protocol is docs/EMBED_ENGINE.md; a
// desktop harness is /embed/harness.
import { createBridge, DEFAULT_CHUNK_CHARS } from '~/lib/embed/bridge';
import type { EmbedEngine, Params } from '~/lib/embed/engine';
import type { PublicProductDetail } from '~/types/catalog';

interface EngineCall { id?: unknown; method?: unknown; params?: unknown }
interface EngineResponse { id: unknown; ok: boolean; result?: unknown; error?: string }

declare global {
  interface Window {
    dizzoEngine?: { version: number; call: (request: string | EngineCall) => Promise<EngineResponse> };
  }
}

const PROTOCOL_VERSION = 1;

definePageMeta({ layout: false, pageTransition: false });

const route = useRoute();

// The app passes its language (?lang=uz|ru|en): texts, problems and the
// catalog's names (Accept-Language) follow it. Switched in place — setLocale()
// would navigate to /ru/embed/engine and remount the engine under the host.
const { locale, locales, loadLocaleMessages } = useI18n();
async function applyHostLanguage() {
  const lang = typeof route.query.lang === 'string' ? route.query.lang : null;
  const known = locales.value.map(l => (typeof l === 'string' ? l : l.code)) as string[];
  if (!lang || lang === locale.value || !known.includes(lang)) return;
  await loadLocaleMessages(lang as typeof locale.value);
  locale.value = lang as typeof locale.value;
}
await applyHostLanguage();

const transparent = ref(route.query.transparent === '1');
const background = computed(() => (transparent.value ? 'transparent' : '#e9ebef'));
useHead({
  title: 'Dizzo engine',
  meta: [
    { name: 'robots', content: 'noindex, nofollow' },
    // The host's pinch zooms the product, not the page.
    { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no' },
  ],
  htmlAttrs: { style: computed(() => `background:${background.value}`) },
  bodyAttrs: { style: computed(() => `background:${background.value};overflow:hidden;overscroll-behavior:none`) },
});

const api = useApi();
const bridge = createBridge(Number(route.query.chunk) || DEFAULT_CHUNK_CHARS);
const wrapRef = ref<HTMLDivElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);
let engine: EmbedEngine | null = null;
let observer: ResizeObserver | null = null;

const errorText = (err: unknown) => (err instanceof Error ? err.message : String(err));

// Calls run one at a time, in the order they came; until the engine is up
// they wait for it.
let startEngine!: (e: EmbedEngine) => void;
let failEngine!: (err: unknown) => void;
const engineReady = new Promise<EmbedEngine>((resolve, reject) => {
  startEngine = resolve;
  failEngine = reject;
});
engineReady.catch(() => {}); // reported as an event; each call reports it again
let queue: Promise<unknown> = Promise.resolve();

type Handler = (e: EmbedEngine, params: Params) => unknown;
const METHODS: Record<string, Handler> = {
  load: (e, p) => e.load(p).then((state) => {
    bridge.send({ event: 'loaded', productSlug: state.productSlug, variantId: state.variantId, colorId: state.colorId, shapeId: state.shapeId });
    return state;
  }),
  setDocument: (e, p) => e.setDocument(p),
  setAppearance: (e, p) => e.setAppearance(p),
  setSize: (e, p) => e.setSize(p),
  showArea: (e, p) => e.showArea(p),
  resetView: e => e.resetView(),
  viewPreset: (e, p) => e.viewPreset(p),
  captureFrames: (e, p) => e.captureFrames(p),
  captureView: (e, p) => e.captureView(p),
  renderPrintFiles: e => e.renderPrintFiles(),
  measure: e => e.measure(),
  setBackground: (e, p) => {
    const result = e.setBackground(p);
    transparent.value = result.transparent;
    return result;
  },
  ping: () => ({ version: PROTOCOL_VERSION, chunkChars: bridge.chunkChars }),
};

function call(request: string | EngineCall): Promise<EngineResponse> {
  let req: EngineCall;
  try {
    req = typeof request === 'string' ? JSON.parse(request) as EngineCall : request;
    if (!req || typeof req !== 'object') throw new Error('not an object');
  }
  catch (err) {
    const response = { id: null, ok: false, error: `bad request: ${errorText(err)}` };
    bridge.send(response);
    return Promise.resolve(response);
  }
  const id = req.id ?? null;
  const run = async () => {
    const handler = typeof req.method === 'string' ? METHODS[req.method] : undefined;
    if (!handler) throw Object.assign(new Error(`unknown method: ${String(req.method)}`), { name: 'EngineError' });
    const params = req.params && typeof req.params === 'object' ? req.params as Params : {};
    return handler(await engineReady, params);
  };
  const done = queue.then(run);
  queue = done.catch(() => {});
  return done.then(
    (result) => {
      const response = { id, ok: true, result: result ?? null };
      bridge.send(response);
      return response;
    },
    (err) => {
      if (!(err instanceof Error && err.name === 'EngineError')) console.error('[dizzo-engine]', err);
      const response = { id, ok: false, error: errorText(err) };
      bridge.send(response);
      return response;
    },
  );
}

// Before anything else loads: the host may call right away (calls wait).
if (import.meta.client) window.dizzoEngine = { version: PROTOCOL_VERSION, call };

function onError(event: ErrorEvent) {
  bridge.send({ event: 'error', message: errorText(event.error ?? event.message), fatal: false });
}
function onRejection(event: PromiseRejectionEvent) {
  bridge.send({ event: 'error', message: errorText(event.reason), fatal: false });
}

onMounted(async () => {
  window.addEventListener('error', onError);
  window.addEventListener('unhandledrejection', onRejection);
  try {
    const { EmbedEngine } = await import('~/lib/embed/engine');
    if (!canvasRef.value || !wrapRef.value) return;
    engine = new EmbedEngine(canvasRef.value, slug => api.get<PublicProductDetail>(`/catalog/products/${encodeURIComponent(slug)}/`));
    const e = engine;
    e.setBackground({ transparent: transparent.value });
    e.onUserView(phase => bridge.send({ event: 'view', phase, zoom: e.zoom(), area: e.shownArea }));
    observer = new ResizeObserver(() => {
      const rect = wrapRef.value!.getBoundingClientRect();
      e.resize(rect.width, rect.height);
    });
    observer.observe(wrapRef.value);
    const rect = wrapRef.value.getBoundingClientRect();
    e.resize(rect.width, rect.height);
    startEngine(e);
    bridge.send({ event: 'ready', version: PROTOCOL_VERSION, chunkChars: bridge.chunkChars });
  }
  catch (err) {
    // No WebGL, or the engine's code didn't load.
    failEngine(err);
    bridge.send({ event: 'error', message: `engine failed to start: ${errorText(err)}`, fatal: true });
  }
});

onBeforeUnmount(() => {
  window.removeEventListener('error', onError);
  window.removeEventListener('unhandledrejection', onRejection);
  observer?.disconnect();
  engine?.dispose();
  engine = null;
  if (window.dizzoEngine?.call === call) delete window.dizzoEngine;
});
</script>

<template>
  <div
    ref="wrapRef"
    class="fixed inset-0 overflow-hidden"
  >
    <canvas
      ref="canvasRef"
      class="absolute inset-0 h-full w-full touch-none select-none"
      :aria-label="$t('studio.preview.view3d')"
    />
  </div>
</template>
