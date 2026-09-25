<script setup lang="ts">
// The shape editor: one screen with the areas on the left, the 3D view in
// the middle and the inspector on the right (a sheet at the bottom on
// narrow screens). Every change goes to a local draft first — with undo —
// and the draft is saved as a whole a moment later. "Save" makes the
// shape ready once the checks pass.
import { getApiErrorMessage } from '~/composables/useApi';
import type { AreaAnchor, CatalogMethod, Shape } from '~/types/catalog';
import { isPlacedModelAnchor } from '~/types/catalog';
import type { AreaMeasure, DraftArea, DraftMethod, ModelInfo, Phase, Problem, ShapeDraft, ZoneRect } from '~/lib/admin/shapeDraft';
import {
  cloneDraft, draftFromShape, DraftHistory, draftProblems, emptyAreaTr, keyFromName, layoutBody, METHODS, missingNameText, namedTr,
  newMethod, newUid, nextName, partnerMethod, resizeMethods, round1, syncPartner,
} from '~/lib/admin/shapeDraft';
import type { ContentLang, TextTranslations } from '~/lib/admin/translations';
import { missingLangs, TRANSLATION_LANGS } from '~/lib/admin/translations';
import { saveLayout } from '~/lib/admin/shapeSave';
import type { AreaOps } from '~/components/admin/shapes/ops';
import AreaInspector from '~/components/admin/shapes/AreaInspector.vue';
import AreaList from '~/components/admin/shapes/AreaList.vue';
import ShapePanel from '~/components/admin/shapes/ShapePanel.vue';
import ShapeViewport from '~/components/admin/shapes/ShapeViewport.vue';

const props = defineProps<{ shape: Shape; productId: number; revision: boolean }>();
const emit = defineEmits<{ leave: [] }>();
const { t } = useI18n();
const { run, busy } = useCatalogAdminActions();
const { upload } = useMediaUpload();

// ── The draft and its history ───────────────────────────────────────────
const draft = reactive<ShapeDraft>(draftFromShape(props.shape));
const initial = cloneDraft(draft);
const history = new DraftHistory(draft);
const historyTick = ref(0);
const canUndo = computed(() => historyTick.value >= 0 && history.canUndo);
const canRedo = computed(() => historyTick.value >= 0 && history.canRedo);
const known = new Set(props.shape.areas.map(a => a.id));
const knownTick = ref(0);

const selected = ref<string | null>(draft.areas[0]?.uid ?? null);
const selectedArea = computed(() => draft.areas.find(a => a.uid === selected.value) ?? null);
const activeMethod = ref<CatalogMethod | null>(null);
const openMethods = ref<CatalogMethod[]>(['uv', 'engrave']);
const stripAt = ref(0.5);
const playing = ref(false);
const placing = ref<{ uid: string | null } | null>(null);
const measures = ref<Record<string, AreaMeasure>>({});
const info = shallowRef<ModelInfo | null>(null);
const sizeDone = ref(draft.kind !== 'model' || Boolean(draft.model.mmPerUnit && draft.areas.length));
const viewport = ref<InstanceType<typeof ShapeViewport> | null>(null);
const rotation = ref<number | null>(null);

const guided = computed(() => draft.kind === 'model' && (!draft.model.url || !draft.model.mmPerUnit || !sizeDone.value));
const problems = computed(() => draftProblems(draft, measures.value));
const blocking = computed(() => problems.value.filter(p => p.blocking));

let live: { uid: string; area: DraftArea } | null = null;

function commit(group?: string) {
  if (history.commit(draft, group)) historyTick.value++;
  scheduleSave();
}

function edit(fn: (d: ShapeDraft) => void, group?: string) {
  fn(draft);
  commit(group);
}

function replaceDraft(next: ShapeDraft) {
  Object.assign(draft, next);
  if (selected.value && !draft.areas.some(a => a.uid === selected.value)) selected.value = null;
  activeMethod.value = null;
  historyTick.value++;
  scheduleSave();
}
function undo() {
  const d = history.undo();
  if (d) replaceDraft(d);
}
function redo() {
  const d = history.redo();
  if (d) replaceDraft(d);
}

const areaOf = (uid: string) => draft.areas.find(a => a.uid === uid) ?? null;

watch(selected, (uid) => {
  activeMethod.value = null;
  playing.value = false;
  if (placing.value?.uid && placing.value.uid !== uid) placing.value = null;
  refreshRotation();
});
function refreshRotation() {
  rotation.value = selected.value && viewport.value ? viewport.value.rotation(selected.value) : null;
}

// ── Saving ──────────────────────────────────────────────────────────────
type SaveState = 'saved' | 'pending' | 'saving' | 'error' | 'invalid';
const saveState = ref<SaveState>('saved');
const saveError = ref<string | null>(null);
const bodyJson = computed(() => knownTick.value >= 0 && JSON.stringify(layoutBody(draft, known)));
let lastSaved = JSON.stringify(layoutBody(draft, known));
let saveTimer: ReturnType<typeof setTimeout> | undefined;
let saving: Promise<boolean> | null = null;
const lastSavedRef = ref(lastSaved);
const dirty = computed(() => bodyJson.value !== lastSavedRef.value);

function scheduleSave() {
  clearTimeout(saveTimer);
  if (live) return;
  if (bodyJson.value === lastSaved) {
    if (!saving) saveState.value = 'saved';
    return;
  }
  if (blocking.value.length) {
    saveState.value = 'invalid';
    return;
  }
  if (!saving) saveState.value = 'pending';
  saveTimer = setTimeout(() => void save(), 900);
}
watch(bodyJson, scheduleSave);

async function save(): Promise<boolean> {
  clearTimeout(saveTimer);
  if (saving) await saving;
  if (live) return false;
  if (bodyJson.value === lastSaved) {
    saveState.value = 'saved';
    return true;
  }
  if (blocking.value.length) {
    saveState.value = 'invalid';
    return false;
  }
  const snapshot = cloneDraft(draft);
  const body = layoutBody(snapshot, known);
  saveState.value = 'saving';
  saving = (async () => {
    try {
      const product = await saveLayout(run, props.shape.id, body);
      const shape = product.shapes.find(s => s.id === props.shape.id)!;
      const ids = new Map<string, number>();
      for (const a of snapshot.areas) {
        const saved = shape.areas.find(x => x.key === a.key);
        if (saved) ids.set(a.uid, saved.id);
      }
      known.clear();
      shape.areas.forEach(a => known.add(a.id));
      for (const a of snapshot.areas) a.id = ids.get(a.uid) ?? null;
      for (const a of draft.areas) {
        const id = ids.get(a.uid);
        if (id !== undefined && a.id !== id) a.id = id;
      }
      history.assignIds(ids);
      if (shape.model_media_id && !draft.model.mediaId) draft.model.mediaId = shape.model_media_id;
      if (shape.model_media_id) snapshot.model.mediaId = shape.model_media_id;
      lastSaved = JSON.stringify(layoutBody(snapshot, known));
      lastSavedRef.value = lastSaved;
      knownTick.value++;
      saveError.value = null;
      return true;
    }
    catch (err) {
      saveError.value = getApiErrorMessage(err, t('admin.shapes.editor.saveFailed'));
      saveState.value = 'error';
      return false;
    }
  })();
  const ok = await saving;
  saving = null;
  if (ok) {
    if (bodyJson.value === lastSaved) saveState.value = 'saved';
    else scheduleSave();
  }
  return ok;
}

// ── The body: model file, orientation, size ─────────────────────────────
const uploading = ref(false);
const uploadError = ref<string | null>(null);

function setWidth(mm: number) {
  const scale = viewport.value?.scaleFor(mm);
  if (!scale) return;
  const dist = Math.hypot(scale.a[0] - scale.b[0], scale.a[1] - scale.b[1], scale.a[2] - scale.b[2]);
  edit((d) => {
    d.model.scale = scale;
    d.model.mmPerUnit = dist > 0 ? scale.mm / dist : null;
  });
}

function orient(upAxis: 'y' | 'z', yawDeg: 0 | 90 | 180 | 270) {
  // The real size stays: the scale is measured again on the turned model.
  const mm = info.value && draft.model.mmPerUnit ? info.value.widthUnits * draft.model.mmPerUnit : null;
  edit((d) => {
    d.model.upAxis = upAxis;
    d.model.yawDeg = yawDeg;
  });
  if (mm) pendingWidth = mm;
}
let pendingWidth: number | null = null;
function onModel(next: ModelInfo | null) {
  info.value = next;
  if (pendingWidth && next) {
    const mm = pendingWidth;
    pendingWidth = null;
    const scale = viewport.value?.scaleFor(mm);
    if (scale) {
      const dist = Math.hypot(scale.a[0] - scale.b[0], scale.a[1] - scale.b[1], scale.a[2] - scale.b[2]);
      draft.model.scale = scale;
      draft.model.mmPerUnit = scale.mm / dist;
      commit('orient');
    }
  }
  refreshRotation();
}

async function replaceModel(file: File) {
  uploadError.value = null;
  uploading.value = true;
  try {
    const kit = await import('~/lib/three/kit');
    const inspected = await kit.inspectGlbFile(file);
    if ('error' in inspected) {
      uploadError.value = inspected.error;
      return;
    }
    const media = await upload(new Blob([file], { type: kit.GLB_CONTENT_TYPE }), 'model');
    if (!viewport.value) return;
    const hadModel = Boolean(draft.model.url);
    const moved = hadModel ? await viewport.value.replaceModel(media.url) : null;
    edit((d) => {
      d.model.mediaId = media.id;
      d.model.url = media.url;
      if (moved) {
        d.model.scale = moved.scale;
        d.model.mmPerUnit = moved.mmPerUnit;
        for (const a of d.areas) {
          const anchor = moved.anchors[a.uid];
          if (anchor) a.anchor = anchor;
          else if (d.kind === 'model') a.anchor = {} as AreaAnchor;
        }
      }
      else {
        d.model.scale = null;
        d.model.mmPerUnit = null;
      }
    });
    if (moved?.info) info.value = moved.info;
    if (!draft.model.mmPerUnit) sizeDone.value = false;
  }
  catch (err) {
    uploadError.value = getApiErrorMessage(err, err instanceof Error ? err.message : t('admin.shapes.editor.modelUploadFailed'));
  }
  finally {
    uploading.value = false;
  }
}

const bodySize = computed(() => (draft.kind !== 'model' && viewport.value && JSON.stringify(draft.dims) ? viewport.value.bodySize() : null));
function setDims(dims: Record<string, unknown>, group?: string) {
  const anchors = viewport.value?.anchorsForDims(dims) ?? {};
  edit((d) => {
    d.dims = dims;
    for (const a of d.areas) if (anchors[a.uid]) a.anchor = anchors[a.uid]!;
  }, group);
}
function setBodySize(width: number, height: number) {
  const dims = viewport.value?.resizedDims(width, height);
  if (dims) setDims(dims);
}

// ── Areas ───────────────────────────────────────────────────────────────
function defaultSize(): { w: number; h: number } {
  const m = draft.model.mmPerUnit;
  const i = info.value;
  const body = draft.kind === 'model' ? (i && m ? { width: i.widthUnits * m, height: i.heightUnits * m } : null) : viewport.value?.bodySize();
  if (!body) return { w: 100, h: 100 };
  if (!draft.areas.length) {
    const w = Math.max(20, Math.round((body.width * 0.6) / 10) * 10);
    return { w, h: Math.min(w, Math.max(20, Math.round((body.height * 0.45) / 10) * 10)) };
  }
  const side = Math.max(10, Math.min(200, Math.round(Math.min(body.width, body.height) / 30) * 10));
  return { w: side, h: side };
}

function startPlacing(uid: string | null = null) {
  if (guided.value) return;
  placing.value = placing.value && placing.value.uid === uid ? null : { uid };
  activeMethod.value = null;
}

function onPlace(make: (w: number, h: number) => AreaAnchor | null) {
  const target = placing.value;
  placing.value = null;
  if (!target) return;
  if (target.uid) {
    const area = areaOf(target.uid);
    const anchor = area && make(area.w, area.h);
    if (area && anchor) edit(() => {
      area.anchor = keepFace(area.anchor, anchor);
    });
    return;
  }
  const { w, h } = defaultSize();
  const anchor = make(w, h);
  if (!anchor) return;
  const named = draft.areas.length ? nextName(draft) : { name: t('admin.shapes.frontSide', {}, { locale: 'uz' }), tr: namedTr('admin.shapes.frontSide') };
  const key = keyFromName(draft.areas.length ? named.name : 'front', new Set(draft.areas.map(a => a.key)));
  const area: DraftArea = {
    uid: newUid(), id: null, key, name: named.name, w, h, anchor, camera: null, note: '', pairKey: null, pairMirror: true,
    methods: METHODS.map(m => newMethod(m, w, h)), tr: named.tr,
  };
  edit(d => d.areas.push(area));
  selected.value = area.uid;
}

/** A model anchor keeps the face (round, corners, dial) it had. */
function keepFace(old: AreaAnchor, next: AreaAnchor): AreaAnchor {
  if (!isPlacedModelAnchor(next) || !isPlacedModelAnchor(old)) return next;
  const face: Record<string, unknown> = {};
  if (old.round) face.round = true;
  if (old.corner_radius_mm) face.corner_radius_mm = old.corner_radius_mm;
  if (old.dial) face.dial = true;
  return { ...next, ...face } as AreaAnchor;
}

// Changes from the 3D view: live while dragging, one undo step at the end.
function onArea(uid: string, patch: Partial<Pick<DraftArea, 'w' | 'h' | 'anchor'>>, phase: Phase) {
  const area = areaOf(uid);
  if (!area) return;
  if (!live || live.uid !== uid) live = { uid, area: JSON.parse(JSON.stringify(area)) };
  const base = live.area;
  if (patch.anchor) area.anchor = patch.anchor;
  if (patch.w !== undefined && patch.h !== undefined) {
    area.w = patch.w;
    area.h = patch.h;
    area.methods = resizeMethods(base.methods, base.w, base.h, patch.w, patch.h);
    syncPartner(draft, uid);
  }
  if (phase === 'commit') {
    live = null;
    commit();
    refreshRotation();
  }
}

function onZone(uid: string, method: CatalogMethod, rect: ZoneRect, phase: Phase) {
  const area = areaOf(uid);
  const m = area?.methods.find(x => x.method === method);
  if (!area || !m) return;
  if (!live || live.uid !== uid) live = { uid, area: JSON.parse(JSON.stringify(area)) };
  Object.assign(m, rect);
  clampLimits(m);
  syncPartner(draft, uid);
  if (phase === 'commit') {
    live = null;
    commit();
  }
}

function clampLimits(m: DraftMethod) {
  if (m.maxW !== null) m.maxW = Math.min(m.maxW, m.w);
  if (m.maxH !== null) m.maxH = Math.min(m.maxH, m.h);
  if (m.strip !== null) m.strip = Math.min(m.strip, m.w);
}

function withAnchor(uid: string, anchor: AreaAnchor | null | undefined, group?: string) {
  const area = areaOf(uid);
  if (!area || !anchor) return;
  edit(() => {
    area.anchor = anchor;
  }, group);
  refreshRotation();
}

const ops: AreaOps = {
  patch(uid, patch, group) {
    const area = areaOf(uid);
    if (!area) return;
    edit(() => {
      if (patch.key !== undefined && patch.key !== area.key) {
        // The partner follows a renamed key.
        const partner = draft.areas.find(a => a.pairKey === area.key && a.uid !== uid);
        if (partner) partner.pairKey = patch.key;
        area.key = patch.key;
      }
      if (patch.name !== undefined) area.name = patch.name;
      if (patch.note !== undefined) area.note = patch.note;
      if (patch.tr !== undefined) area.tr = patch.tr;
    }, group);
  },
  resize(uid, w, h) {
    const area = areaOf(uid);
    if (!area || (w === area.w && h === area.h)) return;
    const anchor = viewport.value?.resized(uid, w, h);
    edit(() => {
      area.methods = resizeMethods(area.methods, area.w, area.h, w, h);
      area.w = w;
      area.h = h;
      if (anchor) area.anchor = anchor;
      syncPartner(draft, uid);
    });
  },
  face(uid, face) {
    const area = areaOf(uid);
    if (!area || !isPlacedModelAnchor(area.anchor)) return;
    const anchor: Record<string, unknown> = { ...area.anchor };
    if (face.round !== undefined) anchor.round = face.round;
    if (face.corner !== undefined) anchor.corner_radius_mm = face.corner ? String(round1(face.corner)) : null;
    if (face.dial !== undefined) anchor.dial = face.dial;
    for (const key of ['round', 'dial'] as const) if (!anchor[key]) delete anchor[key];
    if (!anchor.corner_radius_mm) delete anchor.corner_radius_mm;
    edit(() => {
      area.anchor = anchor as unknown as AreaAnchor;
    }, face.corner !== undefined ? 'corner' : undefined);
  },
  align: (uid, how) => withAnchor(uid, viewport.value?.align(uid, how)),
  nudge: (uid, dx, dy) => withAnchor(uid, viewport.value?.nudge(uid, dx, dy), `nudge-${uid}`),
  rotate: (uid, deg) => withAnchor(uid, viewport.value?.rotate(uid, deg), `rotate-${uid}`),
  place: uid => startPlacing(uid),
  lookAt: uid => viewport.value?.lookAt(uid),
  saveCamera(uid) {
    const camera = viewport.value?.currentCamera();
    const area = areaOf(uid);
    if (area && camera) edit(() => {
      area.camera = camera;
    });
  },
  clearCamera(uid) {
    const area = areaOf(uid);
    if (area) edit(() => {
      area.camera = null;
    });
  },
  duplicate(uid) {
    const area = areaOf(uid);
    if (!area) return;
    const anchor = viewport.value?.besideCopy(uid) ?? area.anchor;
    addCopy(area, anchor, 'admin.shapes.copyName', false);
  },
  mirrorCopy(uid, across) {
    const area = areaOf(uid);
    const anchor = viewport.value?.opposite(uid, across);
    if (!area) return;
    if (!anchor) {
      flash(t('admin.shapes.editor.noOpposite'));
      return;
    }
    addCopy(area, keepFace(area.anchor, anchor), across === 'side' ? 'admin.shapes.pairName' : 'admin.shapes.backName', true);
  },
  remove(uid) {
    const area = areaOf(uid);
    if (!area) return;
    const index = draft.areas.indexOf(area);
    edit((d) => {
      d.areas.splice(index, 1);
      for (const a of d.areas) if (a.pairKey === area.key) a.pairKey = null;
    });
    selected.value = draft.areas[Math.min(index, draft.areas.length - 1)]?.uid ?? null;
    removed = area.uid;
    flash(t('admin.shapes.editor.areaRemoved', { name: area.name }), true);
  },
  pair(uid, partnerKey, mirror) {
    const area = areaOf(uid);
    if (!area) return;
    edit((d) => {
      // Whoever either side was paired with before is released.
      for (const a of d.areas) {
        if (a.uid !== uid && (a.pairKey === area.key || (partnerKey && a.key !== partnerKey && a.pairKey === partnerKey))) a.pairKey = null;
      }
      const partner = partnerKey ? d.areas.find(a => a.key === partnerKey) : null;
      if (partner) {
        const old = partner.pairKey ? d.areas.find(a => a.key === partner.pairKey && a.uid !== uid) : null;
        if (old) old.pairKey = null;
      }
      area.pairKey = partner ? partner.key : null;
      area.pairMirror = mirror;
      if (partner) {
        partner.pairKey = area.key;
        syncPartner(d, uid);
      }
    });
  },
  toggleMethod(uid, method) {
    const area = areaOf(uid);
    if (!area) return;
    const has = area.methods.some(m => m.method === method);
    if (has && area.methods.length === 1) return;
    edit(() => {
      area.methods = has
        ? area.methods.filter(m => m.method !== method)
        : METHODS.filter(m => m === method || area.methods.some(x => x.method === m))
            .map(m => area.methods.find(x => x.method === m) ?? newMethod(m, area.w, area.h));
      syncPartner(draft, uid);
    });
    if (has && activeMethod.value === method) activeMethod.value = null;
    if (!has && !openMethods.value.includes(method)) openMethods.value = [...openMethods.value, method];
  },
  method(uid, method, patch, group) {
    const area = areaOf(uid);
    const m = area?.methods.find(x => x.method === method);
    if (!area || !m) return;
    edit(() => {
      Object.assign(m, patch);
      if ('w' in patch || 'h' in patch || 'x' in patch || 'y' in patch) clampLimits(m);
      syncPartner(draft, uid);
    }, group ? `${uid}-${method}-${group}` : undefined);
  },
  zone: onZone,
};

/** `label`: the message naming the copy ("{name} (nusxa)"), in every language. */
function addCopy(area: DraftArea, anchor: AreaAnchor, label: string, pair: boolean) {
  const taken = new Set(draft.areas.map(a => a.key));
  const key = keyFromName(pair ? `${area.key}_juft` : `${area.key}_nusxa`, taken);
  const tr: TextTranslations = JSON.parse(JSON.stringify(area.tr ?? emptyAreaTr()));
  for (const lang of TRANSLATION_LANGS) {
    const own = tr[lang].name?.trim();
    tr[lang].name = own ? t(label, { name: own }, { locale: lang }) : '';
  }
  const copy: DraftArea = {
    ...JSON.parse(JSON.stringify(area)), uid: newUid(), id: null, key, anchor, camera: null,
    name: t(label, { name: area.name }, { locale: 'uz' }), tr, pairKey: pair ? area.key : null, pairMirror: true,
  };
  edit((d) => {
    if (pair) {
      const old = area.pairKey ? d.areas.find(a => a.key === area.pairKey) : null;
      if (old) old.pairKey = null;
      area.pairKey = key;
      area.pairMirror = true;
      copy.methods = area.methods.map(m => partnerMethod(m, area.w, true));
    }
    d.areas.splice(d.areas.indexOf(area) + 1, 0, copy);
  });
  selected.value = copy.uid;
}

// ── Laser strip preview ─────────────────────────────────────────────────
let playFrame = 0;
function togglePlay() {
  playing.value = !playing.value;
}
watch(playing, (on) => {
  cancelAnimationFrame(playFrame);
  if (!on) return;
  const started = performance.now() - Math.acos(1 - 2 * stripAt.value) * 700;
  const tick = (now: number) => {
    stripAt.value = (1 - Math.cos((now - started) / 700)) / 2;
    if (playing.value) playFrame = requestAnimationFrame(tick);
  };
  playFrame = requestAnimationFrame(tick);
});
function editZone(method: CatalogMethod | null) {
  activeMethod.value = method;
  placing.value = null;
  if (method && selected.value) viewport.value?.lookAt(selected.value);
}
function toggleOpen(method: CatalogMethod) {
  openMethods.value = openMethods.value.includes(method) ? openMethods.value.filter(m => m !== method) : [...openMethods.value, method];
}

let removed: string | null = null;
function undoRemove() {
  undo();
  toast.value = null;
  if (removed && draft.areas.some(a => a.uid === removed)) selected.value = removed;
  removed = null;
}

// ── Messages ────────────────────────────────────────────────────────────
const toast = ref<{ text: string; undo: boolean } | null>(null);
let toastTimer: ReturnType<typeof setTimeout> | undefined;
function flash(text: string, withUndo = false) {
  clearTimeout(toastTimer);
  toast.value = { text, undo: withUndo };
  toastTimer = setTimeout(() => {
    toast.value = null;
  }, 6000);
}

// ── Ready, cancel, leaving ──────────────────────────────────────────────
const problemsOpen = ref(false);
const serverProblem = ref<string | null>(null);
const readyProblems = ref<Problem[]>([]);
const publishing = ref(false);

async function publish() {
  placing.value = null;
  activeMethod.value = null;
  serverProblem.value = null;
  publishing.value = true;
  try {
    const saved = await save();
    readyProblems.value = draftProblems(draft, measures.value);
    if (!saved || readyProblems.value.length) {
      if (!saved && saveError.value) serverProblem.value = saveError.value;
      problemsOpen.value = true;
      return;
    }
    const checks = draft.kind === 'model'
      ? Object.fromEntries(draft.areas.filter(a => a.id !== null).map((a) => {
          const m = measures.value[a.uid] ?? { coverage: 0, stretched: 0 };
          return [a.id, { coverage: Number(m.coverage.toFixed(4)), stretched_share: Number(m.stretched.toFixed(4)) }];
        }))
      : {};
    await run('post', `/admin/catalog/shapes/${props.shape.id}/ready/`, { checks });
    leaving = true;
    emit('leave');
  }
  catch (err) {
    serverProblem.value = getApiErrorMessage(err, t('admin.shapes.editor.readyFailed'));
    problemsOpen.value = true;
  }
  finally {
    publishing.value = false;
  }
}

function showProblem(p: Problem) {
  problemsOpen.value = false;
  selected.value = p.uid;
  if (p.method) {
    if (!openMethods.value.includes(p.method)) openMethods.value = [...openMethods.value, p.method];
  }
  if (p.uid) nextTick(() => viewport.value?.lookAt(p.uid!));
}

const cancelOpen = ref(false);
const cancelling = ref(false);
async function cancel() {
  cancelling.value = true;
  try {
    clearTimeout(saveTimer);
    if (saving) await saving;
    if (props.revision) {
      await run('delete', `/admin/catalog/shapes/${props.shape.id}/`);
    }
    else {
      replaceDraft(cloneDraft(initial));
      clearTimeout(saveTimer);
      if (!(await save())) {
        cancelOpen.value = false;
        return;
      }
    }
    leaving = true;
    emit('leave');
  }
  catch (err) {
    saveError.value = getApiErrorMessage(err, t('admin.shapes.editor.cancelFailed'));
    saveState.value = 'error';
  }
  finally {
    cancelling.value = false;
    cancelOpen.value = false;
  }
}

let leaving = false;
/** Before the page is left: saves what is left; false if it couldn't. */
async function flush(): Promise<boolean> {
  if (leaving) return true;
  if (!dirty.value && !saving) return true;
  return save();
}
defineExpose({ flush, dirty });

function onBeforeUnload(event: BeforeUnloadEvent) {
  if (!leaving && (dirty.value || saving)) {
    void save();
    event.preventDefault();
  }
}

function onSaveState() {
  if (saveState.value === 'error') void save();
  else if (saveState.value === 'invalid') {
    serverProblem.value = null;
    readyProblems.value = problems.value;
    problemsOpen.value = true;
  }
}

function finishSize() {
  sizeDone.value = true;
  if (!draft.areas.length) startPlacing();
}

// ── Name ────────────────────────────────────────────────────────────────
// The name and the short description in the language picked on their tabs.
const nameLang = ref<ContentLang>('uz');
const nameValue = computed(() => (nameLang.value === 'uz' ? draft.name : draft.tr[nameLang.value].name ?? ''));
const descriptionValue = computed(() => (nameLang.value === 'uz' ? draft.description ?? '' : draft.tr[nameLang.value].description ?? ''));
const nameMissing = computed<ContentLang[]>(() => (draft.name.trim() ? missingLangs(draft.tr, 'name') : []));
const nameError = computed(() => (!draft.name.trim() ? t('admin.shapes.problem.shapeName') : missingNameText(draft.tr)));
const langSuffix = computed(() => (nameLang.value === 'uz' ? '' : ` (${nameLang.value.toUpperCase()})`));
function setName(value: string | number) {
  const lang = nameLang.value;
  edit((d) => {
    if (lang === 'uz') d.name = String(value);
    else d.tr[lang].name = String(value);
  }, `shape-name-${lang}`);
}
function setDescription(value: string) {
  const lang = nameLang.value;
  edit((d) => {
    if (lang === 'uz') d.description = value;
    else d.tr[lang].description = value;
  }, `shape-description-${lang}`);
}

// ── Keyboard ────────────────────────────────────────────────────────────
function onKey(event: KeyboardEvent) {
  const target = event.target as HTMLElement | null;
  const typing = Boolean(target?.closest('input, textarea, select, [contenteditable], [role="combobox"]'));
  const mod = event.ctrlKey || event.metaKey;
  if (mod && event.key.toLowerCase() === 'z' && !typing) {
    event.preventDefault();
    if (event.shiftKey) redo();
    else undo();
    return;
  }
  if (mod && event.key.toLowerCase() === 'y' && !typing) {
    event.preventDefault();
    redo();
    return;
  }
  if (mod && event.key.toLowerCase() === 's') {
    event.preventDefault();
    void save();
    return;
  }
  if (typing) return;
  if (event.key === 'Escape') {
    if (placing.value) placing.value = null;
    else if (activeMethod.value) activeMethod.value = null;
    return;
  }
  if (event.key.toLowerCase() === 'a' && !mod) {
    startPlacing();
    return;
  }
  const uid = selected.value;
  if (!uid) return;
  if (event.key === 'Delete' || event.key === 'Backspace') {
    event.preventDefault();
    ops.remove(uid);
    return;
  }
  const step = event.shiftKey ? 10 : 1;
  const arrows: Record<string, [number, number]> = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, step], ArrowDown: [0, -step] };
  const d = arrows[event.key];
  if (!d) return;
  event.preventDefault();
  if (activeMethod.value) {
    const area = areaOf(uid);
    const m = area?.methods.find(x => x.method === activeMethod.value);
    if (area && m) {
      ops.method(uid, m.method, {
        x: Math.min(Math.max(0, m.x + d[0]), area.w - m.w),
        y: Math.min(Math.max(0, m.y - d[1]), area.h - m.h),
      }, 'nudge');
    }
    return;
  }
  ops.nudge(uid, d[0], d[1]);
}

onMounted(() => {
  window.addEventListener('keydown', onKey);
  window.addEventListener('beforeunload', onBeforeUnload);
});
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKey);
  window.removeEventListener('beforeunload', onBeforeUnload);
  cancelAnimationFrame(playFrame);
  clearTimeout(toastTimer);
});

// ── Layout ──────────────────────────────────────────────────────────────
const sheetOpen = ref(true);
const status = computed(() => (props.revision
  ? { text: t('admin.shapes.status.revision'), tone: 'info' as const }
  : props.shape.status === 'ready'
    ? { text: t('admin.shapes.status.ready'), tone: 'success' as const }
    : { text: t('admin.shapes.status.draft'), tone: 'warn' as const }));
const SAVE_LABEL: Record<SaveState, { icon: string; tone: string }> = {
  saved: { icon: 'lucide:cloud-check', tone: 'text-muted-foreground' },
  pending: { icon: 'lucide:cloud', tone: 'text-muted-foreground' },
  saving: { icon: 'lucide:loader-2', tone: 'text-muted-foreground' },
  error: { icon: 'lucide:cloud-alert', tone: 'text-destructive' },
  invalid: { icon: 'lucide:circle-alert', tone: 'text-destructive' },
};
const rulerProp = computed(() => (guided.value || (selected.value === null && draft.kind === 'model') ? { mmPerUnit: draft.model.mmPerUnit } : null));
const selectedProblems = computed(() => problems.value.filter(p => p.uid === selected.value));
</script>

<template>
  <div
    class="flex h-full min-h-0 flex-col overflow-hidden rounded-xl border border-border bg-card shadow-2xs"
    data-testid="shape-editor"
  >
    <!-- Top bar -->
    <div class="flex flex-wrap items-center gap-2 border-b border-border px-3 py-2">
      <UiButton
        variant="ghost"
        size="icon-sm"
        :aria-label="t('admin.shapes.editor.backToShapes')"
        @click="emit('leave')"
      >
        <Icon
          name="lucide:arrow-left"
          class="size-4"
        />
      </UiButton>
      <AdminLangTabs
        v-model="nameLang"
        :missing="nameMissing"
        required
      />
      <input
        :value="nameValue"
        :lang="nameLang"
        class="h-9 min-w-0 max-w-64 flex-1 rounded-lg border border-transparent bg-transparent px-2 text-base font-semibold outline-none transition-colors hover:border-input focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
        :class="nameError && (nameLang === 'uz' ? !draft.name.trim() : nameMissing.includes(nameLang)) ? 'border-destructive' : ''"
        :title="nameError ?? undefined"
        :aria-label="t('admin.shapes.editor.name') + langSuffix"
        :aria-invalid="nameError ? true : undefined"
        :placeholder="nameLang === 'uz' ? t('admin.shapes.editor.name') : draft.name || t('admin.shapes.editor.name')"
        data-testid="shape-name"
        @input="setName(($event.target as HTMLInputElement).value)"
      >
      <input
        v-if="draft.description !== null"
        :value="descriptionValue"
        :lang="nameLang"
        maxlength="200"
        class="h-9 min-w-0 max-w-72 flex-1 rounded-lg border border-transparent bg-transparent px-2 text-sm text-muted-foreground outline-none transition-colors hover:border-input focus-visible:border-ring focus-visible:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50"
        :aria-label="t('admin.shapes.editor.description') + langSuffix"
        :placeholder="nameLang === 'uz' ? t('admin.shapes.editor.description') : draft.description || t('admin.shapes.editor.description')"
        data-testid="shape-description"
        @input="setDescription(($event.target as HTMLInputElement).value)"
      >
      <UiStatusBadge :tone="status.tone">
        {{ status.text }}
      </UiStatusBadge>
      <button
        type="button"
        class="flex items-center gap-1.5 rounded-md px-1.5 py-1 text-xs"
        :class="SAVE_LABEL[saveState].tone"
        :title="saveError ?? undefined"
        data-testid="save-state"
        :data-state="saveState"
        @click="onSaveState"
      >
        <Icon
          :name="SAVE_LABEL[saveState].icon"
          class="size-4"
          :class="saveState === 'saving' ? 'animate-spin' : ''"
        />
        <span class="hidden sm:inline">{{ t(`admin.shapes.saveState.${saveState}`) }}</span>
        <span
          v-if="saveState === 'error'"
          class="underline"
        >{{ t('admin.shapes.editor.retry') }}</span>
      </button>
      <div class="ml-auto flex items-center gap-1">
        <UiTooltip>
          <UiTooltipTrigger as-child>
            <UiButton
              variant="ghost"
              size="icon-sm"
              :disabled="!canUndo"
              :aria-label="t('admin.shapes.editor.undo')"
              data-testid="undo"
              @click="undo"
            >
              <Icon
                name="lucide:undo-2"
                class="size-4"
              />
            </UiButton>
          </UiTooltipTrigger>
          <UiTooltipContent>{{ t('admin.shapes.editor.undoHint') }}</UiTooltipContent>
        </UiTooltip>
        <UiTooltip>
          <UiTooltipTrigger as-child>
            <UiButton
              variant="ghost"
              size="icon-sm"
              :disabled="!canRedo"
              :aria-label="t('admin.shapes.editor.redo')"
              data-testid="redo"
              @click="redo"
            >
              <Icon
                name="lucide:redo-2"
                class="size-4"
              />
            </UiButton>
          </UiTooltipTrigger>
          <UiTooltipContent>{{ t('admin.shapes.editor.redoHint') }}</UiTooltipContent>
        </UiTooltip>
        <span class="mx-1 h-6 w-px bg-border" />
        <UiButton
          variant="outline"
          size="sm"
          :disabled="busy || cancelling"
          @click="cancelOpen = true"
        >
          {{ t('admin.common.cancel') }}
        </UiButton>
        <UiButton
          size="sm"
          :disabled="publishing || cancelling"
          data-testid="publish"
          @click="publish"
        >
          <Icon
            :name="publishing ? 'lucide:loader-2' : 'lucide:check'"
            class="size-4"
            :class="publishing ? 'animate-spin' : ''"
          />
          {{ t('admin.common.save') }}
        </UiButton>
      </div>
    </div>

    <!-- Narrow screens: the areas as chips -->
    <div class="border-b border-border px-3 py-2 lg:hidden">
      <AreaList
        compact
        :draft="draft"
        :selected="selected"
        :measures="measures"
        :problems="problems"
        :locked="guided"
        :placing="placing?.uid === null"
        @select="selected = $event"
        @add="startPlacing()"
      />
    </div>

    <div class="relative flex min-h-0 flex-1 flex-col lg:flex-row">
      <aside class="hidden w-60 shrink-0 border-r border-border lg:block">
        <AreaList
          :draft="draft"
          :selected="selected"
          :measures="measures"
          :problems="problems"
          :locked="guided"
          :placing="placing?.uid === null"
          @select="selected = $event"
          @add="startPlacing()"
        />
      </aside>

      <div class="relative min-h-0 min-w-0 flex-1">
        <ShapeViewport
          ref="viewport"
          :draft="draft"
          :selected="guided ? null : selected"
          :active-method="activeMethod"
          :strip-at="stripAt"
          :placing="placing !== null"
          :ruler="rulerProp"
          @select="selected = $event"
          @place="onPlace"
          @area="onArea"
          @zone="onZone"
          @measures="measures = $event"
          @model="onModel"
          @failed="flash"
        >
          <div
            v-if="toast"
            class="absolute left-3 top-14 flex lg:bottom-3 lg:top-auto max-w-[calc(100%-1.5rem)] items-center gap-3 rounded-xl bg-foreground px-3 py-2 text-sm text-background shadow-lg"
            role="status"
          >
            <span class="truncate">{{ toast.text }}</span>
            <button
              v-if="toast.undo"
              type="button"
              class="shrink-0 font-semibold underline-offset-2 hover:underline"
              data-testid="toast-undo"
              @click="undoRemove"
            >
              {{ t('admin.shapes.editor.restore') }}
            </button>
          </div>
          <div
            v-if="placing"
            class="absolute left-3 top-3"
          >
            <UiButton
              size="sm"
              variant="outline"
              class="bg-card/95"
              @click="placing = null"
            >
              <Icon
                name="lucide:x"
                class="size-4"
              />
              {{ t('admin.shapes.editor.cancelEsc') }}
            </UiButton>
          </div>
          <div
            v-else-if="activeMethod"
            class="pointer-events-none absolute inset-x-0 top-3 flex justify-center"
          >
            <span class="pointer-events-auto flex items-center gap-2 rounded-full bg-card/95 py-1 pl-3 pr-1 text-xs font-medium shadow-md">
              {{ activeMethod === 'engrave' ? t('admin.shapes.editor.laserZone') : t('admin.shapes.editor.printZone') }}
              <UiButton
                size="xs"
                class="rounded-full"
                @click="activeMethod = null"
              >{{ t('admin.shapes.editor.done') }}</UiButton>
            </span>
          </div>
        </ShapeViewport>
      </div>

      <!-- Inspector: a column on wide screens, a sheet over the view otherwise -->
      <aside
        class="relative flex shrink-0 flex-col overflow-hidden border-t border-border bg-card shadow-[0_-8px_24px_-16px_rgb(0_0_0/0.3)] lg:max-h-none lg:w-[22rem] lg:border-l lg:border-t-0 lg:shadow-none"
        :class="sheetOpen ? 'max-h-[55%]' : 'max-h-11'"
        data-testid="inspector"
      >
        <button
          type="button"
          class="flex h-11 shrink-0 items-center gap-2 px-4 text-sm font-semibold lg:hidden"
          :aria-expanded="sheetOpen"
          @click="sheetOpen = !sheetOpen"
        >
          <span class="absolute left-1/2 top-1.5 h-1 w-10 -translate-x-1/2 rounded-full bg-border" />
          <span class="truncate">{{ guided || !selectedArea ? (draft.kind === 'model' ? t('admin.shapes.editor.model3d') : t('admin.shapes.editor.shapeSize')) : selectedArea.name }}</span>
          <Icon
            name="lucide:chevron-down"
            class="ml-auto size-4 text-muted-foreground transition-transform"
            :class="sheetOpen ? '' : 'rotate-180'"
          />
        </button>
        <div class="min-h-0 flex-1 overflow-y-auto">
          <ShapePanel
            v-if="guided || !selectedArea"
            :draft="draft"
            :info="info"
            :guided="guided"
            :uploading="uploading"
            :upload-error="uploadError"
            :body-size="bodySize"
            @width="setWidth"
            @orient="orient"
            @file="replaceModel"
            @dims="setDims"
            @body-size="setBodySize"
            @done="finishSize"
          />
          <AreaInspector
            v-else
            :key="selectedArea.uid"
            :draft="draft"
            :area="selectedArea"
            :measure="measures[selectedArea.uid] ?? null"
            :problems="selectedProblems"
            :ops="ops"
            :active-method="activeMethod"
            :open-methods="openMethods"
            :strip-at="stripAt"
            :playing="playing"
            :rotation="rotation"
            @edit-zone="editZone"
            @open-method="toggleOpen"
            @strip-at="stripAt = $event; playing = false"
            @play="togglePlay"
          />
        </div>
      </aside>
    </div>

    <!-- What keeps the shape from being ready -->
    <UiDialog v-model:open="problemsOpen">
      <UiDialogContent class="sm:max-w-md">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.shapes.editor.notReady') }}</UiDialogTitle>
        </UiDialogHeader>
        <UiAlert
          v-if="serverProblem"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          {{ serverProblem }}
        </UiAlert>
        <ul
          class="max-h-80 space-y-1 overflow-y-auto"
          data-testid="problems"
        >
          <li
            v-for="(p, i) in readyProblems"
            :key="i"
          >
            <button
              type="button"
              class="flex w-full items-start gap-2 rounded-lg px-2 py-2 text-left text-sm hover:bg-muted"
              @click="showProblem(p)"
            >
              <Icon
                :name="p.blocking ? 'lucide:circle-alert' : 'lucide:triangle-alert'"
                class="mt-0.5 size-4 shrink-0"
                :class="p.blocking ? 'text-destructive' : 'text-amber-600'"
              />
              <span class="min-w-0 flex-1">
                <span class="block font-medium">{{ p.uid ? (draft.areas.find(a => a.uid === p.uid)?.name ?? t('admin.shapes.editor.area')) : draft.kind === 'model' ? t('admin.shapes.editor.model3d') : t('admin.shapes.editor.shape') }}</span>
                <span class="block text-muted-foreground">{{ p.text }}</span>
              </span>
              <Icon
                name="lucide:chevron-right"
                class="mt-0.5 size-4 shrink-0 text-muted-foreground"
              />
            </button>
          </li>
        </ul>
        <UiDialogFooter>
          <UiButton
            variant="outline"
            @click="problemsOpen = false"
          >
            {{ t('admin.common.close') }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>

    <UiAlertDialog v-model:open="cancelOpen">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ revision ? t('admin.shapes.editor.cancelRevision') : t('admin.shapes.editor.cancelReset') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>{{ t('admin.shapes.editor.keepEditing') }}</UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="cancelling"
            data-testid="confirm-cancel"
            @click="cancel"
          >
            <Icon
              v-if="cancelling"
              name="lucide:loader-2"
              class="size-4 animate-spin"
            />
            {{ t('admin.common.cancel') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
