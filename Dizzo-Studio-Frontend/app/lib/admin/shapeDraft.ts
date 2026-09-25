// The shape editor's working copy: the shape as plain numbers (mm), edited
// locally with undo and saved in one piece (PUT /shapes/{id}/layout/).
// Everything here is pure: no Vue, no three.js (texts come from the i18n
// messages, looked up when they are needed).
import type { AreaAnchor, AreaCamera, CatalogMethod, ModelTransform, PrintArea, Shape, ShapeKind, Vec3 } from '~/types/catalog';
import { isPlacedModelAnchor } from '~/types/catalog';
import type { TextTranslations } from '~/lib/admin/translations';
import { missingLangs, textTranslations, trimTranslations } from '~/lib/admin/translations';

const tr = (key: string, params?: Record<string, unknown>, locale?: 'uz' | 'ru' | 'en') => {
  const i18n = useNuxtApp().$i18n;
  return locale ? i18n.t(key, params ?? {}, { locale }) : i18n.t(key, params ?? {});
};

/** Translated fields: the shape's, and each area's. */
export const SHAPE_TR_FIELDS = ['name', 'description'] as const;
export const AREA_TR_FIELDS = ['name', 'placement_note'] as const;
export const emptyAreaTr = () => textTranslations(null, AREA_TR_FIELDS);

export const METHODS: CatalogMethod[] = ['uv', 'engrave'];
export const MIN_COVERAGE = 0.95; // the backend's shape_ready_errors rule
export const MAX_MM = 5000;
export const DPI_CHOICES = [150, 300, 600, 1200];
export const KEY_RE = /^[a-z][a-z0-9_]*$/;

export interface DraftMethod {
  method: CatalogMethod;
  x: number; // the zone, in mm from the area's top-left corner
  y: number;
  w: number;
  h: number;
  maxW: number | null;
  maxH: number | null;
  strip: number | null; // laser strip width; null: the whole zone
  minFont: number | null;
  colors: boolean;
  dpi: number;
}

export interface DraftArea {
  uid: string; // stable within the editor (ids come only after a save)
  id: number | null;
  key: string;
  name: string;
  w: number;
  h: number;
  anchor: AreaAnchor;
  camera: AreaCamera | null;
  note: string;
  pairKey: string | null;
  pairMirror: boolean;
  methods: DraftMethod[];
  /** Russian and English name and placement_note. */
  tr: TextTranslations;
}

export interface DraftScale { a: Vec3; b: Vec3; mm: number }

export interface DraftModel {
  mediaId: string | null; // the GLB (unknown on an older API until one is uploaded here)
  url: string | null;
  upAxis: ModelTransform['up_axis'];
  yawDeg: ModelTransform['yaw_deg'];
  scale: DraftScale | null;
  mmPerUnit: number | null;
}

export interface ShapeDraft {
  name: string;
  description: string | null; // null: the API has no such field yet
  /** Russian and English name and description. */
  tr: TextTranslations;
  kind: ShapeKind;
  dims: Record<string, unknown>;
  model: DraftModel;
  areas: DraftArea[];
}

// ── What the 3D view reports ─────────────────────────────────────────────

export interface ModelInfo {
  widthUnits: number; // across the front at chest height (the scale line)
  heightUnits: number;
  depthUnits: number;
  line: { a: Vec3; b: Vec3 };
}
export interface ZoneRect { x: number; y: number; w: number; h: number }
/** 'live' while dragging (no undo step yet), 'commit' when it is done. */
export type Phase = 'live' | 'commit';
export type AreaSide = 'front' | 'back' | 'left' | 'right' | 'top' | 'bottom' | 'round';
const SIDES: AreaSide[] = ['front', 'back', 'left', 'right', 'top', 'bottom', 'round'];
/** The side's name in the current language (read when used). */
export const SIDE_LABELS = Object.defineProperties({} as Record<AreaSide, string>, Object.fromEntries(
  SIDES.map(side => [side, { enumerable: true, get: () => tr(`admin.shapes.side.${side}`) }]),
));

export const ZONE_COLOURS: Record<CatalogMethod, { line: string; fill: string; strong: string }> = {
  uv: { line: '#0b7ea3', fill: 'rgba(11, 126, 163, 0.10)', strong: 'rgba(11, 126, 163, 0.22)' },
  engrave: { line: '#95652a', fill: 'rgba(149, 101, 42, 0.14)', strong: 'rgba(149, 101, 42, 0.26)' },
};

// ── Numbers ──────────────────────────────────────────────────────────────

export const round1 = (v: number) => Math.round(v * 10) / 10;
export const round2 = (v: number) => Math.round(v * 100) / 100;
export const mmText = (v: number) => String(round2(v));
const num = (v: unknown) => (v === null || v === undefined || v === '' ? null : Number(v));
export const cmHint = (mm: number | null | undefined) => (mm && mm > 0 ? tr('admin.shapes.cm', { n: Number((mm / 10).toFixed(1)) }) : '');

let uidSeq = 0;
export const newUid = () => `a${Date.now().toString(36)}${(uidSeq++).toString(36)}`;

// ── From and to the API ──────────────────────────────────────────────────

function methodFrom(m: PrintArea['methods'][number]): DraftMethod {
  return {
    method: m.method, x: Number(m.zone_x_mm), y: Number(m.zone_y_mm), w: Number(m.zone_w_mm), h: Number(m.zone_h_mm),
    maxW: num(m.max_width_mm), maxH: num(m.max_height_mm), strip: num(m.strip_width_mm), minFont: num(m.min_font_mm),
    colors: m.colors_allowed, dpi: m.dpi,
  };
}

export function draftFromShape(shape: Shape): ShapeDraft {
  const t = shape.model_transform;
  const ref = t?.scale_ref;
  return {
    name: shape.name,
    description: shape.description ?? null,
    tr: textTranslations(shape.translations, SHAPE_TR_FIELDS),
    kind: shape.kind,
    dims: { ...(shape.dims as Record<string, unknown>) },
    model: {
      mediaId: shape.model_media_id ?? null,
      url: shape.model_url,
      upAxis: t?.up_axis ?? 'y',
      yawDeg: t?.yaw_deg ?? 0,
      scale: ref ? { a: [...ref.a] as Vec3, b: [...ref.b] as Vec3, mm: Number(ref.mm) } : null,
      mmPerUnit: shape.mm_per_unit ? Number(shape.mm_per_unit) : null,
    },
    areas: shape.areas.map(a => ({
      uid: `id${a.id}`, id: a.id, key: a.key, name: a.name, w: Number(a.width_mm), h: Number(a.height_mm),
      anchor: JSON.parse(JSON.stringify(a.anchor)), camera: a.camera ? JSON.parse(JSON.stringify(a.camera)) : null,
      note: a.placement_note, pairKey: a.pair_key, pairMirror: a.pair_mirror,
      methods: [...a.methods].sort((p, q) => METHODS.indexOf(p.method) - METHODS.indexOf(q.method)).map(methodFrom),
      tr: textTranslations(a.translations, AREA_TR_FIELDS),
    })),
  };
}

export const cloneDraft = (d: ShapeDraft): ShapeDraft => JSON.parse(JSON.stringify(d));

function methodBody(m: DraftMethod) {
  const opt = (v: number | null) => (v !== null && v > 0 ? mmText(v) : null);
  return {
    method: m.method, zone_x_mm: mmText(m.x), zone_y_mm: mmText(m.y), zone_w_mm: mmText(m.w), zone_h_mm: mmText(m.h),
    max_width_mm: opt(m.maxW), max_height_mm: opt(m.maxH), strip_width_mm: m.method === 'engrave' ? opt(m.strip) : null,
    min_font_mm: opt(m.minFont), colors_allowed: m.method === 'engrave' ? false : m.colors, dpi: Math.round(m.dpi),
  };
}

/** The body of PUT /shapes/{id}/layout/. `known`: the area ids the server
 * has now (an area deleted and brought back by undo is created again). */
export function layoutBody(d: ShapeDraft, known: Set<number>) {
  const model = d.kind === 'model';
  return {
    name: d.name.trim() || undefined,
    ...(d.description === null ? {} : { description: d.description.trim() }),
    translations: trimTranslations(d.tr),
    ...(model ? {} : { dims: d.dims }),
    ...(model && d.model.mediaId ? { model_media_id: d.model.mediaId } : {}),
    ...(model && d.model.url ? { model_transform: { up_axis: d.model.upAxis, yaw_deg: d.model.yawDeg } } : {}),
    ...(model && d.model.scale ? { scale: { a: d.model.scale.a, b: d.model.scale.b, mm: mmText(d.model.scale.mm) } } : {}),
    areas: d.areas.map((a, i) => ({
      id: a.id !== null && known.has(a.id) ? a.id : null,
      key: a.key, name: a.name.trim(), width_mm: mmText(a.w), height_mm: mmText(a.h),
      anchor: a.anchor, camera: a.camera, placement_note: a.note, sort_order: i,
      pair_key: a.pairKey, pair_mirror: a.pairMirror,
      translations: trimTranslations(a.tr),
      methods: a.methods.map(methodBody),
    })),
  };
}
export type LayoutBody = ReturnType<typeof layoutBody>;

// ── Methods and zones ────────────────────────────────────────────────────

export function newMethod(method: CatalogMethod, w: number, h: number): DraftMethod {
  return {
    method, x: 0, y: 0, w, h, maxW: null, maxH: null, strip: null,
    minFont: method === 'engrave' ? 2 : null, colors: method === 'uv', dpi: method === 'engrave' ? 600 : 300,
  };
}

const coversWhole = (m: DraftMethod, w: number, h: number) => m.x === 0 && m.y === 0 && Math.abs(m.w - w) < 0.05 && Math.abs(m.h - h) < 0.05;

/** The methods of an area going from w0 × h0 to w × h: a zone on the whole
 * area stays on the whole area, any other is kept inside it. */
export function resizeMethods(methods: DraftMethod[], w0: number, h0: number, w: number, h: number): DraftMethod[] {
  return methods.map((m) => {
    if (coversWhole(m, w0, h0)) return { ...m, w, h, ...limits(m, w, h) };
    const zw = Math.min(m.w, w);
    const zh = Math.min(m.h, h);
    const next = { ...m, w: zw, h: zh, x: Math.min(m.x, round2(w - zw)), y: Math.min(m.y, round2(h - zh)) };
    return { ...next, ...limits(next, next.w, next.h) };
  });
}
function limits(m: DraftMethod, zw: number, zh: number) {
  return {
    maxW: m.maxW !== null ? Math.min(m.maxW, zw) : null,
    maxH: m.maxH !== null ? Math.min(m.maxH, zh) : null,
    strip: m.strip !== null ? Math.min(m.strip, zw) : null,
  };
}

/** A method as a mirrored partner has it: the zone flipped left-right. */
export function partnerMethod(m: DraftMethod, areaW: number, mirror: boolean): DraftMethod {
  return mirror ? { ...m, x: round2(areaW - m.x - m.w) } : { ...m };
}

/** Pair partners always match: the partner takes this area's size and methods. */
export function syncPartner(d: ShapeDraft, uid: string) {
  const area = d.areas.find(a => a.uid === uid);
  if (!area?.pairKey) return;
  const partner = d.areas.find(a => a.key === area.pairKey && a.uid !== uid);
  if (!partner) return;
  partner.w = area.w;
  partner.h = area.h;
  partner.pairKey = area.key;
  partner.pairMirror = area.pairMirror;
  partner.methods = area.methods.map(m => partnerMethod(m, area.w, area.pairMirror));
}

export const partnerOf = (d: ShapeDraft, area: DraftArea) =>
  (area.pairKey ? d.areas.find(a => a.key === area.pairKey && a.uid !== area.uid) ?? null : null);

// ── Keys ─────────────────────────────────────────────────────────────────

const LATIN: Record<string, string> = { 'o‘': 'o', 'g‘': 'g', 'sh': 'sh', 'ch': 'ch' };
/** An area key from its name: "Chap yeng" → "chap_yeng". */
export function keyFromName(name: string, taken: Set<string>): string {
  let base = name.toLowerCase().trim();
  for (const [from, to] of Object.entries(LATIN)) base = base.split(from).join(to);
  base = base.normalize('NFKD').replace(/[‘’'`ʻʼ]/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  if (!/^[a-z]/.test(base)) base = `hudud${base ? `_${base}` : ''}`;
  base = base.slice(0, 28);
  let key = base;
  for (let n = 2; taken.has(key); n++) key = `${base}_${n}`;
  return key;
}

/** A new area's numbered name ("Hudud 3"), in Uzbek and translated. */
export function nextName(d: ShapeDraft): { name: string; tr: TextTranslations } {
  const names = new Set(d.areas.map(a => a.name));
  const uz = (i: number) => tr('admin.shapes.areaN', { n: i }, 'uz');
  let n = d.areas.length + 1;
  while (names.has(uz(n))) n++;
  return { name: uz(n), tr: namedTr('admin.shapes.areaN', { n }) };
}

/** A message in Russian and English, as an area's translated name. */
export function namedTr(key: string, params: Record<string, unknown> = {}): TextTranslations {
  const out = emptyAreaTr();
  out.ru.name = tr(key, params, 'ru');
  out.en.name = tr(key, params, 'en');
  return out;
}

// ── Problems ─────────────────────────────────────────────────────────────

export interface Problem {
  uid: string | null; // the area, or null for the shape
  method?: CatalogMethod;
  field?: string;
  text: string;
  /** Blocks saving (the server would refuse); otherwise only blocks marking it ready. */
  blocking: boolean;
}

export interface AreaMeasure { coverage: number; stretched: number; side?: AreaSide }

export const isPlaced = (d: ShapeDraft, a: DraftArea) => (d.kind === 'model' ? isPlacedModelAnchor(a.anchor) : Object.keys(a.anchor).length > 0);

const methodName = (method: CatalogMethod) => tr(`admin.shapes.methodShort.${method}`);

/** The "enter the RU/EN name" message, or null when both are there. */
export function missingNameText(source: TextTranslations, field = 'name'): string | null {
  const missing = missingLangs(source, field);
  if (!missing.length) return null;
  return missing.length > 1 ? tr('admin.translate.required.both') : tr(`admin.translate.required.${missing[0]}`);
}

export function methodProblems(m: DraftMethod, areaW: number, areaH: number): Array<{ field: string; text: string }> {
  const out: Array<{ field: string; text: string }> = [];
  const add = (field: string, text: string) => out.push({ field, text });
  if (!(m.w > 0)) add('w', tr('admin.shapes.problem.zoneW'));
  if (!(m.h > 0)) add('h', tr('admin.shapes.problem.zoneH'));
  if (m.x < 0) add('x', tr('admin.shapes.problem.xNegative'));
  if (m.y < 0) add('y', tr('admin.shapes.problem.yNegative'));
  if (m.x + m.w > areaW + 0.005) add('w', tr('admin.shapes.problem.zoneOut', { a: mmText(m.x + m.w), b: mmText(areaW) }));
  if (m.y + m.h > areaH + 0.005) add('h', tr('admin.shapes.problem.zoneOut', { a: mmText(m.y + m.h), b: mmText(areaH) }));
  if (m.maxW !== null && m.maxW > m.w + 0.005) add('maxW', tr('admin.shapes.problem.maxW'));
  if (m.maxH !== null && m.maxH > m.h + 0.005) add('maxH', tr('admin.shapes.problem.maxH'));
  if (m.method === 'engrave') {
    if (m.strip !== null && m.strip > m.w + 0.005) add('strip', tr('admin.shapes.problem.strip'));
    if (!(m.minFont && m.minFont > 0)) add('minFont', tr('admin.shapes.problem.minFont'));
  }
  if (!(m.dpi >= 150 && m.dpi <= 1200)) add('dpi', tr('admin.shapes.problem.dpi'));
  return out;
}

export function draftProblems(d: ShapeDraft, measures: Record<string, AreaMeasure> = {}): Problem[] {
  const out: Problem[] = [];
  const keys = new Map<string, number>();
  for (const a of d.areas) keys.set(a.key, (keys.get(a.key) ?? 0) + 1);
  if (!d.name.trim()) out.push({ uid: null, field: 'name', text: tr('admin.shapes.problem.shapeName'), blocking: true });
  else {
    const missing = missingNameText(d.tr);
    if (missing) out.push({ uid: null, field: 'name', text: missing, blocking: true });
  }
  if (d.kind === 'model') {
    if (!d.model.url) out.push({ uid: null, text: tr('admin.shapes.problem.noModel'), blocking: false });
    else if (!d.model.mmPerUnit) out.push({ uid: null, text: tr('admin.shapes.problem.noModelSize'), blocking: false });
  }
  if (!d.areas.length) out.push({ uid: null, text: tr('admin.shapes.problem.noAreas'), blocking: false });
  for (const a of d.areas) {
    const p = (text: string, blocking: boolean, extra: Partial<Problem> = {}) => out.push({ uid: a.uid, text, blocking, ...extra });
    if (!a.name.trim()) p(tr('admin.shapes.problem.areaName'), true, { field: 'name' });
    else {
      const missing = missingNameText(a.tr);
      if (missing) p(missing, true, { field: 'name' });
    }
    if (!KEY_RE.test(a.key) || a.key.length > 32) p(tr('admin.shapes.problem.key'), true, { field: 'key' });
    else if ((keys.get(a.key) ?? 0) > 1) p(tr('admin.shapes.problem.keyTaken', { key: a.key }), true, { field: 'key' });
    if (!(a.w > 0) || a.w > MAX_MM) p(tr('admin.shapes.problem.width'), true, { field: 'w' });
    if (!(a.h > 0) || a.h > MAX_MM) p(tr('admin.shapes.problem.height'), true, { field: 'h' });
    if (!a.methods.length) p(tr('admin.shapes.problem.noMethod'), true);
    for (const m of a.methods) {
      for (const problem of methodProblems(m, a.w, a.h)) p(`${methodName(m.method)}: ${problem.text}`, true, { method: m.method, field: problem.field });
    }
    if (a.pairKey) {
      const partner = partnerOf(d, a);
      if (!partner || partner.pairKey !== a.key) p(tr('admin.shapes.problem.noPartner'), true, { field: 'pair' });
    }
    if (!isPlaced(d, a)) {
      p(tr('admin.shapes.problem.notPlaced'), false);
      continue;
    }
    const measure = measures[a.uid];
    if (d.kind === 'model' && measure && measure.coverage < MIN_COVERAGE) {
      p(tr('admin.shapes.problem.coverage', { n: Math.round(measure.coverage * 100) }), false);
    }
  }
  return out;
}

// ── Undo ─────────────────────────────────────────────────────────────────

/** Snapshots of the draft. `commit` records the draft as it is now (a
 * run of commits with the same `group` within a second is one step:
 * typing a number). */
export class DraftHistory {
  private past: string[] = [];
  private future: string[] = [];
  private current: string;
  private lastGroup: string | null = null;
  private lastAt = 0;

  constructor(draft: ShapeDraft, private readonly limit = 200) {
    this.current = JSON.stringify(draft);
  }

  commit(draft: ShapeDraft, group?: string) {
    const next = JSON.stringify(draft);
    if (next === this.current) return false;
    const now = Date.now();
    const merge = group !== undefined && group === this.lastGroup && now - this.lastAt < 1000 && this.past.length > 0;
    if (!merge) {
      this.past.push(this.current);
      if (this.past.length > this.limit) this.past.shift();
    }
    this.current = next;
    this.future = [];
    this.lastGroup = group ?? null;
    this.lastAt = now;
    return true;
  }

  get canUndo() {
    return this.past.length > 0;
  }

  get canRedo() {
    return this.future.length > 0;
  }

  undo(): ShapeDraft | null {
    const prev = this.past.pop();
    if (prev === undefined) return null;
    this.future.push(this.current);
    this.current = prev;
    this.lastGroup = null;
    return JSON.parse(prev);
  }

  redo(): ShapeDraft | null {
    const next = this.future.pop();
    if (next === undefined) return null;
    this.past.push(this.current);
    this.current = next;
    this.lastGroup = null;
    return JSON.parse(next);
  }

  /** Areas saved for the first time get their ids in every snapshot. */
  assignIds(ids: Map<string, number>) {
    const fix = (json: string) => {
      const d = JSON.parse(json) as ShapeDraft;
      let changed = false;
      for (const a of d.areas) {
        const id = ids.get(a.uid);
        if (id !== undefined && a.id !== id) {
          a.id = id;
          changed = true;
        }
      }
      return changed ? JSON.stringify(d) : json;
    };
    this.past = this.past.map(fix);
    this.future = this.future.map(fix);
    this.current = fix(this.current);
  }
}
