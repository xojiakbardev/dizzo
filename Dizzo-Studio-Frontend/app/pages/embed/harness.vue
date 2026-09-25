<script setup lang="ts">
// A desktop stand-in for the mobile app: /embed/engine in a phone-sized
// frame, driven through window.dizzoEngine exactly as the app drives it,
// with its answers (chunks joined) logged and its pictures shown. For
// developers only (docs/EMBED_ENGINE.md).
definePageMeta({ layout: false });
useHead({ title: 'Dizzo engine harness', meta: [{ name: 'robots', content: 'noindex, nofollow' }] });

interface LoadedArea { key: string; methods: Array<{ method: string; available: boolean; zone: { xMm: number; yMm: number; wMm: number; hMm: number } }> }

const route = useRoute();
const frameRef = ref<HTMLIFrameElement | null>(null);
const chunk = typeof route.query.chunk === 'string' ? `&chunk=${encodeURIComponent(route.query.chunk)}` : '';
const lang = typeof route.query.lang === 'string' ? `&lang=${encodeURIComponent(route.query.lang)}` : '';
const src = `/embed/engine?harness=1${chunk}${lang}`;
const slug = ref(typeof route.query.slug === 'string' ? route.query.slug : '');
const variantId = ref('');
const colorId = ref('');
const size = ref(900);
const docText = ref('{"version":1,"layers":[],"links":[]}');
const log = ref<string[]>([]);
const images = ref<Array<{ label: string; url: string }>>([]);
const ready = ref(false);
let areas: LoadedArea[] = [];
let nextId = 1;
const pieces = new Map<number, string[]>();

const short = (value: unknown) => JSON.stringify(value, (_, v: unknown) =>
  typeof v === 'string' && v.length > 120 ? `${v.slice(0, 48)}… (${v.length} chars)` : v, 1);

function received(message: Record<string, unknown>) {
  if (message.event === 'ready') ready.value = true;
  log.value.unshift(`← ${short(message)}`);
  const result = message.result as Record<string, unknown> | undefined;
  if (!result) return;
  if (Array.isArray(result.areas) && result.areas[0] && typeof result.areas[0] === 'object') areas = result.areas as LoadedArea[];
  const shots: Array<{ label: string; url: string }> = [];
  (result.frames as string[] | undefined)?.forEach((url, i) => shots.push({ label: `frame ${i + 1}`, url }));
  if (typeof result.image === 'string') shots.push({ label: 'view', url: result.image });
  (result.files as Array<{ area: string; method: string; width: number; height: number; dataUrl: string }> | undefined)
    ?.forEach(f => shots.push({ label: `${f.area} · ${f.method} · ${f.width}×${f.height}`, url: f.dataUrl }));
  if (shots.length) images.value = shots;
}

function onMessage(event: MessageEvent) {
  if (event.source !== frameRef.value?.contentWindow || typeof event.data !== 'string') return;
  const message = JSON.parse(event.data) as Record<string, unknown>;
  const part = message.chunk as { id: number; index: number; count: number } | undefined;
  if (!part) return received(message);
  const list = pieces.get(part.id) ?? [];
  list[part.index] = message.data as string;
  pieces.set(part.id, list);
  log.value.unshift(`← chunk ${part.index + 1}/${part.count} of message ${part.id}`);
  if (list.filter(p => p !== undefined).length === part.count) {
    pieces.delete(part.id);
    received(JSON.parse(list.join('')) as Record<string, unknown>);
  }
}

function send(method: string, params: Record<string, unknown> = {}) {
  const engine = frameRef.value?.contentWindow?.dizzoEngine;
  if (!engine) {
    log.value.unshift('× the engine page has not loaded yet');
    return;
  }
  const request = JSON.stringify({ id: String(nextId++), method, params });
  log.value.unshift(`→ ${short(JSON.parse(request))}`);
  void engine.call(request);
}

const optionalId = (v: string) => (v.trim() ? Number(v) : undefined);

function load() {
  send('load', { productSlug: slug.value.trim(), variantId: optionalId(variantId.value), colorId: optionalId(colorId.value) });
}

function setDocument() {
  try {
    send('setDocument', { document: JSON.parse(docText.value) });
  }
  catch (err) {
    log.value.unshift(`× document JSON: ${err instanceof Error ? err.message : String(err)}`);
  }
}

/** A text in the middle of the first area's first method. */
function sampleDocument() {
  const area = areas[0];
  const method = area?.methods.find(m => m.available) ?? area?.methods[0];
  if (!area || !method) {
    log.value.unshift('× load a product first');
    return;
  }
  const z = method.zone;
  const text = { content: 'Dizzo', font: 'Montserrat', size_mm: Math.max(6, z.hMm / 5), color: '#d24419', align: 'center', bold: true, italic: false };
  const layer = {
    id: 'sample', area: area.key, method: method.method, kind: 'text', x_mm: z.xMm + z.wMm / 2, y_mm: z.yMm + z.hMm / 2,
    w_mm: text.size_mm * 3.4, h_mm: text.size_mm * 1.4, rotation: 0, text,
  };
  docText.value = JSON.stringify({ version: 1, layers: [layer], links: [] }, null, 2);
}

onMounted(() => window.addEventListener('message', onMessage));
onBeforeUnmount(() => window.removeEventListener('message', onMessage));

const btn = 'rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white hover:bg-slate-700 disabled:opacity-40';
const field = 'rounded-lg border border-slate-300 px-2 py-1 text-xs';
</script>

<template>
  <div class="flex min-h-dvh flex-wrap gap-4 bg-slate-100 p-4 text-slate-900">
    <iframe
      ref="frameRef"
      :src="src"
      title="Dizzo engine"
      class="h-[520px] w-[320px] shrink-0 rounded-2xl border border-slate-300 bg-white"
    />
    <div class="flex min-w-0 flex-1 flex-col gap-3">
      <p class="text-xs text-slate-500">
        {{ ready ? 'Engine ready.' : 'Waiting for the engine…' }} Protocol: docs/EMBED_ENGINE.md
      </p>
      <div class="flex flex-wrap items-center gap-2">
        <input v-model="slug" :class="field" placeholder="product slug" aria-label="Product slug">
        <input v-model="variantId" :class="[field, 'w-24']" placeholder="variant id" aria-label="Variant id">
        <input v-model="colorId" :class="[field, 'w-24']" placeholder="colour id" aria-label="Colour id">
        <button :class="btn" :disabled="!slug.trim()" @click="load">load</button>
        <button :class="btn" @click="send('setAppearance', { variantId: optionalId(variantId), colorId: optionalId(colorId) })">setAppearance</button>
      </div>
      <textarea v-model="docText" :class="[field, 'h-32 font-mono']" aria-label="Design document JSON" />
      <div class="flex flex-wrap items-center gap-2">
        <button :class="btn" @click="sampleDocument">sample document</button>
        <button :class="btn" @click="setDocument">setDocument</button>
        <button :class="btn" @click="send('resetView')">resetView</button>
        <button v-for="i in 4" :key="i" :class="btn" @click="send('viewPreset', { index: i - 1 })">preset {{ i - 1 }}</button>
        <button :class="btn" @click="send('showArea', { key: areas[1]?.key ?? areas[0]?.key })">showArea (2nd)</button>
        <button :class="btn" @click="send('setBackground', { transparent: true })">transparent</button>
        <button :class="btn" @click="send('setBackground', { transparent: false })">backdrop</button>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <input v-model.number="size" type="number" :class="[field, 'w-20']" aria-label="Picture size">
        <button :class="btn" @click="send('captureFrames', { size })">captureFrames</button>
        <button :class="btn" @click="send('captureView', { size })">captureView</button>
        <button :class="btn" @click="send('renderPrintFiles')">renderPrintFiles</button>
        <button :class="btn" @click="send('measure')">measure</button>
      </div>
      <div v-if="images.length" class="flex flex-wrap gap-2">
        <figure v-for="img in images" :key="img.label" class="w-40">
          <img :src="img.url" :alt="img.label" class="aspect-square w-full rounded-lg border border-slate-300 bg-[repeating-conic-gradient(#e2e8f0_0_25%,#fff_0_50%)] bg-[length:16px_16px] object-contain">
          <figcaption class="truncate text-[11px] text-slate-500">{{ img.label }}</figcaption>
        </figure>
      </div>
      <pre class="max-h-[50vh] overflow-auto rounded-lg bg-white p-2 text-[11px] leading-snug">{{ log.join('\n') }}</pre>
    </div>
  </div>
</template>
