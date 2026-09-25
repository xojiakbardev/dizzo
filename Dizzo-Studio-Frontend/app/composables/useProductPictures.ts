// State of the admin "Rasmlar" tab. Every change is shown at once and saved
// right away; saves run one after another (each answer is the whole product,
// so the last one holds every change), and a failed save falls back to what
// the server has.
import type { InjectionKey } from 'vue';
import { getApiErrorMessage } from '~/composables/useApi';
import { useMediaUpload, dataUrlToBlob } from '~/composables/useMediaUpload';
import { cellsOf, saveRequest, type Cell } from '~/lib/catalogPictures';
import type { AdminCatalogProduct, CatalogImage } from '~/types/catalog';
import { i18nT } from '~/lib/i18n';

export const PICTURE_DRAG = 'application/x-dizzo-picture';

/** A picture being dragged: from a list (`from` its key) or the tray (`from` "tray"). */
export interface DraggedPicture { mediaId: string; url: string; from: string }

export interface PendingUpload { id: string; preview: string }

export interface TrayItem {
  id: string;
  name: string;
  preview: string;
  status: 'uploading' | 'ready' | 'error';
  media: CatalogImage | null;
  error?: string;
}

export interface GenerateJob {
  cellKey: string;
  status: 'rendering' | 'ready' | 'saving' | 'error';
  done: number;
  total: number;
  frames: string[];
  chosen: boolean[];
  error?: string;
}

/** One list of a batch: drawn, uploaded and saved without anyone choosing
 * frames — a whole type's colours are far too many to sit through. */
export interface BatchStep {
  cellKey: string;
  status: 'waiting' | 'rendering' | 'saving' | 'done' | 'error';
  error?: string;
}

export interface BatchJob {
  steps: BatchStep[];
  index: number; // the list being worked on
  done: number; // progress inside it
  total: number;
  running: boolean;
  stopped: boolean;
}

let localSeq = 0;
const localId = () => `local-${++localSeq}`;

/** Runs at most `limit` of the tasks at once; results in order. */
async function pool<T, R>(items: T[], limit: number, work: (item: T) => Promise<R>): Promise<PromiseSettledResult<R>[]> {
  const out: PromiseSettledResult<R>[] = Array.from({ length: items.length });
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      try {
        out[i] = { status: 'fulfilled', value: await work(items[i]!) };
      }
      catch (reason) {
        out[i] = { status: 'rejected', reason };
      }
    }
  }));
  return out;
}

async function prepare(file: Blob): Promise<Blob> {
  // WebP keeps a cut-out's transparency; large photos are brought down to 1600px.
  return resizeImageToBlob(file, 1600, 0.9, 'image/webp');
}

export function useProductPictures(product: Ref<AdminCatalogProduct>, options: {
  /** Draws a cell's pictures from its shape (null: the cell can't). */
  render: (cellKey: string, onProgress: (done: number, total: number) => void) => Promise<string[]> | null;
}) {
  const { run } = useCatalogAdminActions();
  const { upload: uploadMedia } = useMediaUpload();

  const server = computed(() => cellsOf(product.value));
  const overrides = reactive(new Map<string, CatalogImage[]>());
  const pending = reactive(new Map<string, number>());
  const errors = reactive(new Map<string, string>());
  const uploading = reactive(new Map<string, PendingUpload[]>());
  const tray = ref<TrayItem[]>([]);
  const job = ref<GenerateJob | null>(null);
  const batch = ref<BatchJob | null>(null);
  let chain: Promise<unknown> = Promise.resolve();
  const errorTimers = new Map<string, ReturnType<typeof setTimeout>>();

  const images = (key: string): CatalogImage[] => overrides.get(key) ?? server.value.get(key)?.images ?? [];
  const cell = (key: string): Cell | undefined => server.value.get(key);

  function fail(key: string, message: string) {
    errors.set(key, message);
    clearTimeout(errorTimers.get(key));
    errorTimers.set(key, setTimeout(() => errors.delete(key), 8000));
  }

  /** Shows `next` at once and saves it. */
  function set(key: string, next: CatalogImage[]): Promise<boolean> {
    const target = cell(key);
    if (!target) return Promise.resolve(false);
    const list = next.slice(0, target.max);
    const req = saveRequest(target, list.map(i => i.media_id));
    overrides.set(key, list);
    pending.set(key, (pending.get(key) ?? 0) + 1);
    errors.delete(key);
    const work = chain.then(() => run(req.verb, req.path, req.body));
    chain = work.catch(() => undefined);
    return work.then(
      () => true,
      (err) => {
        fail(key, getApiErrorMessage(err, i18nT('common.errors.saveFailed')));
        return false;
      },
    ).finally(() => {
      const left = (pending.get(key) ?? 1) - 1;
      if (left > 0) {
        pending.set(key, left);
      }
      else {
        // Nothing more on its way: show the server's list (the saved one, or
        // after a failure the one from before).
        pending.delete(key);
        overrides.delete(key);
      }
    });
  }

  /** Adds pictures to the end of a list (or at `at`), skipping ones it already has. */
  function add(key: string, pictures: CatalogImage[], at?: number) {
    const current = images(key);
    const fresh = pictures.filter(p => !current.some(c => c.media_id === p.media_id));
    const target = cell(key);
    if (!target || !fresh.length) return Promise.resolve(false);
    if (target.max === 1) return set(key, fresh.slice(0, 1)); // the cover: replaced
    const next = [...current];
    next.splice(at ?? next.length, 0, ...fresh);
    if (next.length > target.max) fail(key, i18nT('common.pictures.maxCount', { count: target.max }, target.max));
    return set(key, next);
  }

  /** A dragged picture dropped on a list at `at`: reordered, moved or added. */
  function place(picture: DraggedPicture, key: string, at: number) {
    const img: CatalogImage = { media_id: picture.mediaId, url: picture.url };
    if (picture.from === key) {
      const list = [...images(key)];
      const from = list.findIndex(i => i.media_id === picture.mediaId);
      if (from < 0) return;
      list.splice(from, 1);
      list.splice(from < at ? at - 1 : at, 0, img);
      if (list.some((x, i) => x.media_id !== images(key)[i]?.media_id)) set(key, list);
      return;
    }
    if (images(key).some(i => i.media_id === picture.mediaId)) return;
    if (picture.from === 'tray') {
      tray.value = tray.value.filter(t => t.media?.media_id !== picture.mediaId);
      add(key, [img], at);
      return;
    }
    // From another list: moved (the cover keeps its picture — it is copied).
    add(key, [img], at).then((ok) => {
      if (ok && picture.from !== 'cover') set(picture.from, images(picture.from).filter(i => i.media_id !== picture.mediaId));
    });
  }

  /** Files dropped on (or picked for) a list: uploaded, then added in their order. */
  async function upload(key: string, files: File[]) {
    const target = cell(key);
    if (!target || !files.length) return;
    const room = Math.max(0, target.max - images(key).length) || (target.max === 1 ? 1 : 0);
    const chosen = files.slice(0, room);
    if (chosen.length < files.length) fail(key, i18nT('common.pictures.maxCount', { count: target.max }, target.max));
    const shown = chosen.map(f => ({ id: localId(), preview: URL.createObjectURL(f) }));
    uploading.set(key, [...(uploading.get(key) ?? []), ...shown]);
    const results = await pool(chosen, 3, async f => uploadMedia(await prepare(f), 'catalog'));
    uploading.set(key, (uploading.get(key) ?? []).filter(u => !shown.includes(u)));
    shown.forEach(u => URL.revokeObjectURL(u.preview));
    const done = results.flatMap(r => (r.status === 'fulfilled' ? [{ media_id: r.value.id, url: r.value.url }] : []));
    const failed = results.find(r => r.status === 'rejected') as PromiseRejectedResult | undefined;
    if (done.length) await add(key, done);
    if (failed) fail(key, getApiErrorMessage(failed.reason, i18nT('common.pictures.uploadOneFailed')));
  }

  /** Files for the tray: uploaded now, placed later (by dragging or by name). */
  async function uploadToTray(files: File[]) {
    const items: TrayItem[] = files.map(f => ({ id: localId(), name: f.name, preview: URL.createObjectURL(f), status: 'uploading', media: null }));
    tray.value = [...tray.value, ...items];
    await pool(files, 3, async (f) => {
      const id = items[files.indexOf(f)]!.id;
      const patch = (p: Partial<TrayItem>) => {
        tray.value = tray.value.map(t => (t.id === id ? { ...t, ...p } : t));
      };
      try {
        const media = await uploadMedia(await prepare(f), 'catalog');
        patch({ status: 'ready', media: { media_id: media.id, url: media.url } });
      }
      catch (err) {
        patch({ status: 'error', error: getApiErrorMessage(err, i18nT('common.errors.uploadFailed')) });
      }
    });
  }

  function removeFromTray(id: string) {
    const item = tray.value.find(t => t.id === id);
    if (item) URL.revokeObjectURL(item.preview);
    tray.value = tray.value.filter(t => t.id !== id);
  }

  /** Tray pictures to their lists, each list in the given order. */
  async function assign(pairs: Array<{ trayId: string; cellKey: string }>) {
    const byCell = new Map<string, CatalogImage[]>();
    for (const { trayId, cellKey } of pairs) {
      const media = tray.value.find(t => t.id === trayId)?.media;
      if (media) byCell.set(cellKey, [...(byCell.get(cellKey) ?? []), media]);
    }
    const ids = new Set(pairs.map(p => p.trayId));
    tray.value = tray.value.filter(t => !ids.has(t.id));
    await Promise.all([...byCell].map(([key, list]) => add(key, list)));
  }

  /** Uploads data URLs (drawn frames) and gives back their media. */
  async function uploadFrames(frames: string[], onDone?: () => void): Promise<CatalogImage[]> {
    const results = await pool(frames, 3, async (frame) => {
      const media = await uploadMedia(await prepare(await dataUrlToBlob(frame)), 'catalog');
      onDone?.();
      return { media_id: media.id, url: media.url };
    });
    const done = results.flatMap(r => (r.status === 'fulfilled' ? [r.value] : []));
    if (!done.length) throw (results[0] as PromiseRejectedResult).reason;
    return done;
  }

  /** A fresh render takes the place of the older drawn pictures; photographs
   * an admin uploaded (source "manual") keep their place at the front.
   * Until the API sends `source` nothing is known to be a photograph, and a
   * regenerate replaces the whole list rather than filling it up. */
  function replaceRendered(key: string, fresh: CatalogImage[]) {
    const current = images(key);
    const kept = current.some(i => i.source) ? current.filter(i => i.source !== 'render') : [];
    return set(key, [...kept, ...fresh]);
  }

  // ── "Rasm yaratish": pictures drawn from the 3D shape, one list at a time ──
  async function generate(key: string) {
    if (job.value && job.value.status !== 'error' && job.value.status !== 'ready') return;
    job.value = { cellKey: key, status: 'rendering', done: 0, total: 0, frames: [], chosen: [] };
    try {
      const frames = await options.render(key, (done, total) => {
        if (job.value?.cellKey === key) Object.assign(job.value, { done, total });
      });
      if (!frames?.length) throw new Error(i18nT('common.pictures.renderEmpty'));
      if (job.value?.cellKey !== key) return;
      Object.assign(job.value, { status: 'ready', frames, chosen: frames.map(() => true) });
    }
    catch (err) {
      if (job.value?.cellKey === key) Object.assign(job.value, { status: 'error', error: err instanceof Error ? err.message : i18nT('common.pictures.renderFailed') });
    }
  }

  async function attachGenerated() {
    const j = job.value;
    if (!j || j.status !== 'ready') return;
    const picked = j.frames.filter((_, i) => j.chosen[i]);
    if (!picked.length) return;
    j.status = 'saving';
    j.done = 0;
    j.total = picked.length;
    try {
      await add(j.cellKey, await uploadFrames(picked, () => j.done++));
      job.value = null;
    }
    catch (err) {
      Object.assign(j, { status: 'error', error: getApiErrorMessage(err, i18nT('common.pictures.uploadManyFailed')) });
    }
  }

  // ── The same, for every colour of a type at once: each list is drawn,
  // uploaded and saved in turn, and a list that fails does not stop the rest.
  async function generateBatch(keys: string[]) {
    if (!keys.length || batch.value?.running) return;
    if (job.value && job.value.status !== 'error' && job.value.status !== 'ready') return;
    const state: BatchJob = {
      steps: keys.map(cellKey => ({ cellKey, status: 'waiting' })),
      index: 0, done: 0, total: 0, running: true, stopped: false,
    };
    batch.value = state;
    for (const [i, key] of keys.entries()) {
      if (state.stopped) break;
      const step = state.steps[i]!;
      Object.assign(state, { index: i, done: 0, total: 0 });
      step.status = 'rendering';
      try {
        const frames = await options.render(key, (done, total) => {
          if (batch.value === state) Object.assign(state, { done, total });
        });
        if (!frames?.length) throw new Error(i18nT('common.pictures.renderEmpty'));
        if (state.stopped) break;
        step.status = 'saving';
        const room = cell(key)?.max ?? 1;
        await replaceRendered(key, await uploadFrames(frames.slice(0, room)));
        step.status = 'done';
      }
      catch (err) {
        Object.assign(step, { status: 'error', error: getApiErrorMessage(err, i18nT('common.pictures.renderFailed')) });
      }
    }
    state.running = false;
  }

  onBeforeUnmount(() => {
    if (batch.value) batch.value.stopped = true; // the page is gone; stop after this list
    tray.value.forEach(t => URL.revokeObjectURL(t.preview));
    errorTimers.forEach(t => clearTimeout(t));
  });

  return {
    images,
    cell,
    maxOf: (key: string) => cell(key)?.max ?? 0,
    uploadsOf: (key: string) => uploading.get(key) ?? [],
    isSaving: (key: string) => (pending.get(key) ?? 0) > 0 || Boolean(uploading.get(key)?.length),
    errorOf: (key: string) => errors.get(key) ?? null,
    set,
    add,
    place,
    upload,
    tray,
    uploadToTray,
    removeFromTray,
    assign,
    job,
    generate,
    attachGenerated,
    closeJob: () => {
      job.value = null;
    },
    batch,
    generateBatch,
    stopBatch: () => {
      if (batch.value) batch.value.stopped = true;
    },
    closeBatch: () => {
      if (!batch.value?.running) batch.value = null;
    },
  };
}

export type ProductPictures = ReturnType<typeof useProductPictures>;
export const PICTURES_KEY: InjectionKey<ProductPictures> = Symbol('product-pictures');
