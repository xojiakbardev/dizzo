<script setup lang="ts">
// The shape editor's 3D view. It draws the draft as it is (the model or a
// built body, every area as a test print on it) and turns what the admin
// does on it into draft changes: a click to place a new area, dragging an
// area over the surface, its handles to resize it, and — while a method's
// zone is being edited — the zone's own move and handles. Lengths go out
// in mm; placements as the anchors the API stores.
import type * as THREE from 'three';
import type { Kit } from '~/lib/three/kit';
import type { Margins, ModelFrame, WidthLine } from '~/lib/three/autoFit';
import type { ModelViewer } from '~/lib/three/modelViewer';
import type { Pose } from '~/lib/three/projector';
import type { AreaAnchor, AreaCamera, CatalogMethod, Material, ShapeKind, Vec3 } from '~/types/catalog';
import { isPlacedModelAnchor } from '~/types/catalog';
import type { AreaMeasure, AreaSide, DraftArea, DraftScale, ModelInfo, Phase, ShapeDraft, ZoneRect } from '~/lib/admin/shapeDraft';
import { round1 } from '~/lib/admin/shapeDraft';

type ViewportMeasure = AreaMeasure & { side: AreaSide };

const props = defineProps<{
  draft: ShapeDraft;
  selected: string | null;
  activeMethod: CatalogMethod | null;
  stripAt: number | null;
  placing: boolean;
  /** Size step: the model's measured lines, labelled with this scale. */
  ruler: { mmPerUnit: number | null } | null;
}>();
const emit = defineEmits<{
  select: [uid: string | null];
  place: [make: (wMm: number, hMm: number) => AreaAnchor | null];
  area: [uid: string, patch: Pick<DraftArea, 'w' | 'h' | 'anchor'> | Pick<DraftArea, 'anchor'>, phase: Phase];
  zone: [uid: string, method: CatalogMethod, rect: ZoneRect, phase: Phase];
  measures: [value: Record<string, ViewportMeasure>];
  model: [info: ModelInfo | null];
  failed: [message: string];
}>();

const MIN_MM = 5;
const MARGIN_STEP_MM = 1;
const MARGIN_TOLERANCE_MM = 0.5;

const { t } = useI18n();
const wrapRef = ref<HTMLDivElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);
let kit: Kit | null = null;
let viewer: ModelViewer | null = null;
let resizeObserver: ResizeObserver | null = null;
const loadState = ref<'empty' | 'loading' | 'ready' | 'error'>('loading');
let frame: ModelFrame | null = null;
let widthLine: WidthLine | null = null;
let shown: { key: string; url: string | null; params: string | null } = { key: '', url: null, params: null };
let loadToken = 0;

type Built = Exclude<ShapeKind, 'model'>;
const parametric = computed(() => (props.draft.kind === 'model' ? null : { kind: props.draft.kind as Built, dims: props.draft.dims }));
const bodyLook = computed<Material>(() => (props.draft.kind === 'cylinder' ? 'ceramic_glossy' : 'plastic'));
const mpu = computed(() => (parametric.value ? 1 : props.draft.model.mmPerUnit));

interface Placement { pose: Pose; wrap: number | null } // wrap radius in model units

const vec = (v: Vec3) => new kit!.THREE.Vector3(...v);
const r5 = (v: THREE.Vector3): Vec3 => [Number(v.x.toFixed(5)), Number(v.y.toFixed(5)), Number(v.z.toFixed(5))];

function placementOf(area: DraftArea): Placement | null {
  if (!kit) return null;
  if (parametric.value) {
    if (!Object.keys(area.anchor).length) return null;
    return kit.parametricPlacement(parametric.value, { anchor: area.anchor, width_mm: String(area.w), height_mm: String(area.h) }, bodyLook.value);
  }
  const a = area.anchor;
  if (!isPlacedModelAnchor(a) || !mpu.value) return null;
  return { pose: { point: vec(a.point), normal: vec(a.normal), up: vec(a.up) }, wrap: a.wrap_radius_mm ? Number(a.wrap_radius_mm) / mpu.value : null };
}

const faceOf = (area: DraftArea) => {
  const a = isPlacedModelAnchor(area.anchor) ? area.anchor : null;
  return {
    ...(a?.round ? { round: true } : {}),
    ...(a?.corner_radius_mm && Number(a.corner_radius_mm) > 0 ? { corner_radius_mm: a.corner_radius_mm } : {}),
    ...(a?.dial ? { dial: true } : {}),
  };
};

const depthFor = (wMm: number, hMm: number, perUnit: number) => {
  const full = frame ? Math.round((frame.max.f - frame.min.f) * perUnit) : 400;
  return Math.min(full, Math.max(50, wMm, hMm));
};

function boxOf(wMm: number, hMm: number, wrap: number | null, round: boolean, perUnit = mpu.value!) {
  return { width: wMm / perUnit, height: hMm / perUnit, depth: depthFor(wMm, hMm, perUnit) / perUnit, maxAngleDeg: kit!.AUTO_MAX_ANGLE, wrapRadius: wrap, round };
}

function anchorOf(placed: Placement, wMm: number, hMm: number, face: Record<string, unknown>, perUnit = mpu.value!): AreaAnchor {
  if (parametric.value) return kit!.parametricAnchor(parametric.value, wMm, hMm, placed.pose) as unknown as AreaAnchor;
  return {
    point: r5(placed.pose.point), normal: r5(placed.pose.normal), up: r5(placed.pose.up),
    depth_mm: depthFor(wMm, hMm, perUnit).toFixed(2), max_angle_deg: kit!.AUTO_MAX_ANGLE,
    wrap_radius_mm: placed.wrap ? (placed.wrap * perUnit).toFixed(2) : null,
    ...face,
  } as AreaAnchor;
}

/** Flat if it lands whole on the surface, otherwise wrapped round the
 * model when that fits better (a mug's print). */
function flatOrWrapped(pose: Pose, wMm: number, hMm: number, round: boolean): Placement {
  if (parametric.value) return { pose, wrap: parametric.value.kind === 'cylinder' ? Number(parametric.value.dims.diameter_mm) / 2 : null };
  const baked = viewer!.baked!;
  const flat = kit!.projectDecal(baked, pose, boxOf(wMm, hMm, null, round));
  flat.geometry.dispose();
  if (flat.coverage >= 0.95 || !frame) return { pose, wrap: null };
  const radius = kit!.wrapRadiusFor(baked, frame, pose, wMm / mpu.value!);
  if (!radius) return { pose, wrap: null };
  const wrapped = kit!.projectDecal(baked, pose, boxOf(wMm, hMm, radius, round));
  wrapped.geometry.dispose();
  return { pose, wrap: wrapped.coverage > flat.coverage ? radius : null };
}

const ready = () => Boolean(kit && viewer?.baked && frame && mpu.value && loadState.value === 'ready');
const areaBy = (uid: string | null) => props.draft.areas.find(a => a.uid === uid) ?? null;

// ── Decals ──────────────────────────────────────────────────────────────
interface Drawn { geomKey: string; texKey: string; mesh: THREE.Mesh; coverage: number; stretched: number }
const drawn = new Map<string, Drawn>();

function removeDecal(uid: string) {
  const d = drawn.get(uid);
  if (!d) return;
  viewer?.decals.remove(d.mesh);
  d.mesh.geometry.dispose();
  const material = d.mesh.material as THREE.MeshBasicMaterial;
  material.map?.dispose();
  material.dispose();
  drawn.delete(uid);
}
const clearDecals = () => [...drawn.keys()].forEach(removeDecal);

function textureFor(area: DraftArea, selected: boolean) {
  const face = faceOf(area);
  const canvas = kit!.areaPatternCanvas({
    name: selected || props.draft.areas.length > 1 ? area.name : '',
    width: area.w,
    height: area.h,
    zones: area.methods.map(m => ({ method: m.method, x: m.x, y: m.y, w: m.w, h: m.h, strip: m.strip })),
  }, {
    highlighted: selected,
    activeMethod: selected ? props.activeMethod : null,
    stripAt: selected && props.activeMethod === 'engrave' ? props.stripAt : selected ? 0.5 : null,
    round: face.round === true,
    cornerMm: Number(face.corner_radius_mm ?? 0),
    showSize: true,
  });
  const texture = new kit!.THREE.CanvasTexture(canvas);
  texture.colorSpace = kit!.THREE.SRGBColorSpace;
  texture.anisotropy = 4;
  return texture;
}

let lastMeasures = '';
function syncDecals() {
  if (!ready()) {
    clearDecals();
    return;
  }
  const seen = new Set<string>();
  const measures: Record<string, ViewportMeasure> = {};
  for (const area of props.draft.areas) {
    const placed = placementOf(area);
    if (!placed || !(area.w > 0) || !(area.h > 0)) continue;
    seen.add(area.uid);
    const selected = area.uid === props.selected;
    const face = faceOf(area);
    const geomKey = JSON.stringify([area.w, area.h, area.anchor, props.draft.dims, mpu.value, shown.key]);
    const texKey = JSON.stringify([
      selected || props.draft.areas.length > 1 ? area.name : '', area.w, area.h, area.methods, selected,
      selected ? props.activeMethod : null, selected ? props.stripAt : null, face,
    ]);
    let d = drawn.get(area.uid);
    if (!d || d.geomKey !== geomKey) {
      const result = kit!.projectDecal(viewer!.baked!, placed.pose, boxOf(area.w, area.h, placed.wrap, face.round === true));
      if (d) {
        d.mesh.geometry.dispose();
        d.mesh.geometry = result.geometry;
        Object.assign(d, { geomKey, coverage: result.coverage, stretched: result.stretchedShare });
      }
      else {
        const mesh = new kit!.THREE.Mesh(result.geometry, new kit!.THREE.MeshBasicMaterial({
          transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4,
          side: kit!.THREE.DoubleSide, toneMapped: false,
        }));
        mesh.userData.uid = area.uid;
        viewer!.decals.add(mesh);
        d = { geomKey, texKey: '', mesh, coverage: result.coverage, stretched: result.stretchedShare };
        drawn.set(area.uid, d);
      }
    }
    if (d.texKey !== texKey) {
      const material = d.mesh.material as THREE.MeshBasicMaterial;
      material.map?.dispose();
      material.map = textureFor(area, selected);
      material.needsUpdate = true;
      d.texKey = texKey;
    }
    d.mesh.renderOrder = selected ? 2 : 1;
    measures[area.uid] = { coverage: d.coverage, stretched: d.stretched, side: sideOf(area, placed) };
  }
  for (const uid of [...drawn.keys()]) if (!seen.has(uid)) removeDecal(uid);
  const json = JSON.stringify(measures);
  if (json !== lastMeasures) {
    lastMeasures = json;
    emit('measures', measures);
  }
  viewer!.requestRender();
}

function sideOf(area: DraftArea, placed: Placement): AreaSide {
  if (parametric.value) {
    if (parametric.value.kind === 'cylinder') return 'round';
    return (area.anchor as { side?: string }).side === 'back' ? 'back' : 'front';
  }
  if (placed.wrap) return 'round';
  const n = placed.pose.normal;
  const f = n.dot(frame!.forward);
  const s = n.dot(frame!.side);
  const u = n.dot(frame!.up);
  const most = Math.max(Math.abs(f), Math.abs(s), Math.abs(u));
  if (most === Math.abs(f)) return f >= 0 ? 'front' : 'back';
  if (most === Math.abs(s)) return s >= 0 ? 'left' : 'right';
  return u >= 0 ? 'top' : 'bottom';
}

// ── Overlay: handles, distances to the edges, the size ruler ─────────────
interface Handle { id: string; x: number; y: number; sx: number; sy: number; cursor: string; zone: boolean }
interface Label { id: string; x: number; y: number; text: string; tone: 'margin' | 'bad' | 'ruler' }
const handles = ref<Handle[]>([]);
const labels = ref<Label[]>([]);
let guides: Array<{ key: keyof Margins; from: THREE.Vector3; to: THREE.Vector3; mm: number }> = [];
let rulerLines: Array<{ id: string; from: THREE.Vector3; to: THREE.Vector3; units: number }> = [];
let guidesKey = '';

let frameRequest = 0;
let pendingSync = false;
let pendingGuides = false;
function schedule(what: { sync?: boolean; guides?: boolean } = {}) {
  pendingSync ||= what.sync === true;
  pendingGuides ||= what.guides === true;
  if (frameRequest) return;
  frameRequest = requestAnimationFrame(() => {
    frameRequest = 0;
    if (pendingSync) syncDecals();
    if (pendingGuides) measureGuides();
    pendingSync = false;
    pendingGuides = false;
    placeOverlay();
  });
}

/** A point of the area's own frame (model units from its centre) on the
 * surface, or on its plane where the surface isn't. */
function localPoint(placed: Placement, x: number, y: number): THREE.Vector3 {
  const hit = kit!.surfaceAt(viewer!.baked!, frame!, placed.pose, placed.wrap, x, y);
  if (hit) return hit.point;
  const right = kit!.right(placed.pose);
  return placed.pose.point.clone().addScaledVector(right, x).addScaledVector(placed.pose.up, y);
}

function toScreen(p: THREE.Vector3, rect: DOMRect) {
  const v = viewer!.toWorld(p).project(viewer!.camera);
  return { x: ((v.x + 1) / 2) * rect.width, y: ((1 - v.y) / 2) * rect.height, visible: v.z < 1 };
}

function facesCamera(placed: Placement) {
  const worldPoint = viewer!.toWorld(placed.pose.point);
  const worldNormal = viewer!.toWorld(placed.pose.point.clone().add(placed.pose.normal)).sub(worldPoint);
  return worldNormal.dot(viewer!.camera.position.clone().sub(worldPoint)) > 0 || Boolean(placed.wrap);
}

const HANDLE_SPOTS: Array<[number, number, string]> = [
  [-1, 1, 'nwse-resize'], [0, 1, 'ns-resize'], [1, 1, 'nesw-resize'], [1, 0, 'ew-resize'],
  [1, -1, 'nwse-resize'], [0, -1, 'ns-resize'], [-1, -1, 'nesw-resize'], [-1, 0, 'ew-resize'],
];

function placeOverlay() {
  if (!viewer || !canvasRef.value) return;
  const rect = canvasRef.value.getBoundingClientRect();
  const out: Handle[] = [];
  const texts: Label[] = [];
  const area = areaBy(props.selected);
  const placed = area && ready() ? placementOf(area) : null;
  if (area && placed && facesCamera(placed) && !props.placing) {
    const m = mpu.value!;
    const zone = props.activeMethod ? area.methods.find(x => x.method === props.activeMethod) : null;
    for (const [sx, sy, cursor] of HANDLE_SPOTS) {
      let x: number;
      let y: number;
      if (zone) {
        // Area mm from the top-left → the area's frame.
        const ax = zone.x + (zone.w * (sx + 1)) / 2;
        const ay = zone.y + (zone.h * (1 - sy)) / 2;
        x = (ax - area.w / 2) / m;
        y = (area.h / 2 - ay) / m;
      }
      else {
        x = (sx * area.w) / 2 / m;
        y = (sy * area.h) / 2 / m;
      }
      const s = toScreen(localPoint(placed, x, y), rect);
      if (s.visible) out.push({ id: `${sx}${sy}`, x: s.x, y: s.y, sx, sy, cursor, zone: Boolean(zone) });
    }
    if (!zone) {
      for (const g of guides) {
        const s = toScreen(g.from.clone().add(g.to).multiplyScalar(0.5), rect);
        const value = Math.abs(g.mm) < MARGIN_TOLERANCE_MM ? 0 : g.mm;
        texts.push({ id: g.key, x: s.x, y: s.y, text: `${Math.round(value)} ${t('admin.shapeParts.mm')}`, tone: value < 0 ? 'bad' : 'margin' });
      }
    }
  }
  if (props.ruler && frame) {
    for (const line of rulerLines) {
      const s = toScreen(line.from.clone().add(line.to).multiplyScalar(0.5), rect);
      const perUnit = props.ruler.mmPerUnit;
      texts.push({ id: line.id, x: s.x, y: s.y, text: `${perUnit ? Math.round(line.units * perUnit) : '?'} ${t('admin.shapeParts.mm')}`, tone: 'ruler' });
    }
  }
  handles.value = out;
  labels.value = texts;
}

function clearOverlay() {
  if (!viewer) return;
  for (const child of [...viewer.overlay.children]) {
    viewer.overlay.remove(child);
    const line = child as THREE.Line;
    line.geometry?.dispose();
    (line.material as THREE.Material | undefined)?.dispose();
  }
}

/** The dashed lines from the selected area to where the surface ends, and
 * the ruler of the size step. */
function measureGuides() {
  if (!viewer || !kit) return;
  const area = areaBy(props.selected);
  const placed = area && ready() && !props.activeMethod ? placementOf(area) : null;
  const key = JSON.stringify([area?.w, area?.h, area?.anchor, props.activeMethod, Boolean(props.ruler), shown.key, mpu.value]);
  if (key === guidesKey) return;
  guidesKey = key;
  clearOverlay();
  guides = [];
  rulerLines = [];
  if (area && placed) {
    const m = mpu.value!;
    const hw = area.w / 2 / m;
    const hh = area.h / 2 / m;
    const margins = kit.marginsOf(viewer.baked!, frame!, placed.pose, placed.wrap, hw * 2, hh * 2, MARGIN_STEP_MM / m);
    const at = (x: number, y: number) => kit!.surfaceAt(viewer!.baked!, frame!, placed.pose, placed.wrap, x, y)?.point ?? null;
    const ends: Array<[keyof Margins, number, number, number, number]> = [
      ['top', 0, hh, 0, hh + Math.max(0, margins.top)], ['bottom', 0, -hh, 0, -hh - Math.max(0, margins.bottom)],
      ['left', -hw, 0, -hw - Math.max(0, margins.left), 0], ['right', hw, 0, hw + Math.max(0, margins.right), 0],
    ];
    const material = new kit.THREE.LineDashedMaterial({ color: '#e11d48', dashSize: 4 / m, gapSize: 3 / m, depthTest: false });
    for (const [side, x0, y0, x1, y1] of ends) {
      const from = at(x0, y0);
      const to = at(x1, y1);
      if (!from || !to) continue;
      guides.push({ key: side, from, to, mm: margins[side] * m });
      const line = new kit.THREE.Line(new kit.THREE.BufferGeometry().setFromPoints([from, to]), material);
      line.computeLineDistances();
      line.renderOrder = 10;
      viewer.overlay.add(line);
    }
  }
  if (props.ruler && frame && viewer.baked) {
    const f = frame;
    const P = (s: number, u: number, d: number) => kit!.framePoint(f, s, u, d);
    const box = new kit.THREE.LineBasicMaterial({ color: '#94a3b8', depthTest: false, transparent: true, opacity: 0.8 });
    const corners: THREE.Vector3[] = [];
    for (const s of [f.min.s, f.max.s]) for (const u of [f.min.u, f.max.u]) for (const d of [f.min.f, f.max.f]) corners.push(P(s, u, d));
    const edges: Array<[number, number]> = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]];
    const segments = new kit.THREE.BufferGeometry().setFromPoints(edges.flatMap(([a, b]) => [corners[a]!, corners[b]!]));
    const boxLines = new kit.THREE.LineSegments(segments, box);
    boxLines.renderOrder = 9;
    viewer.overlay.add(boxLines);
    const blue = new kit.THREE.LineBasicMaterial({ color: '#2563eb', depthTest: false });
    const pad = (f.max.s - f.min.s) * 0.06;
    const lines: Array<{ id: string; from: THREE.Vector3; to: THREE.Vector3; units: number }> = [
      { id: 'height', from: P(f.max.s + pad, f.min.u, f.max.f), to: P(f.max.s + pad, f.max.u, f.max.f), units: f.max.u - f.min.u },
      { id: 'depth', from: P(f.max.s + pad, f.min.u, f.min.f), to: P(f.max.s + pad, f.min.u, f.max.f), units: f.max.f - f.min.f },
    ];
    if (widthLine) lines.unshift({ id: 'width', from: widthLine.a, to: widthLine.b, units: widthLine.units });
    for (const l of lines) {
      const line = new kit.THREE.Line(new kit.THREE.BufferGeometry().setFromPoints([l.from, l.to]), blue);
      line.renderOrder = 10;
      viewer.overlay.add(line);
    }
    rulerLines = lines;
  }
  viewer.requestRender();
}

// ── Pointer: placing, moving, resizing ───────────────────────────────────
type Drag =
  | { kind: 'click'; x: number; y: number }
  | { kind: 'move'; uid: string; grab: { x: number; y: number }; moved: boolean }
  | { kind: 'resize'; uid: string; sx: number; sy: number; base: Placement; w0: number; h0: number; last: { w: number; h: number; anchor: AreaAnchor } | null }
  | { kind: 'zone'; uid: string; method: CatalogMethod; sx: number; sy: number; base: Placement; start: { x: number; y: number }; rect0: ZoneRect; last: ZoneRect | null };
let drag: Drag | null = null;
const currentDrag = () => drag;
let raycaster: THREE.Raycaster | null = null;
let pendingMove: PointerEvent | null = null;

function ndc(event: PointerEvent) {
  const rect = canvasRef.value!.getBoundingClientRect();
  return new kit!.THREE.Vector2(((event.clientX - rect.left) / rect.width) * 2 - 1, -((event.clientY - rect.top) / rect.height) * 2 + 1);
}

function decalUnder(event: PointerEvent): { uid: string; point: THREE.Vector3 } | null {
  if (!kit || !viewer) return null;
  raycaster ??= new kit.THREE.Raycaster();
  raycaster.setFromCamera(ndc(event), viewer.camera);
  const hit = raycaster.intersectObjects([...drawn.values()].map(d => d.mesh), false)[0];
  return hit ? { uid: hit.object.userData.uid as string, point: viewer.toModel(hit.point) } : null;
}

/** Where the pointer is in a placement's own frame (model units): on its
 * plane for a flat print, on the surface (or else the plane) for a wrapped one. */
function pointerLocal(event: PointerEvent, base: Placement): { x: number; y: number } | null {
  if (base.wrap) {
    const hit = viewer!.pick(event.clientX, event.clientY);
    if (hit) return kit!.surfaceOffset(base.pose, base.wrap, hit.point);
  }
  raycaster ??= new kit!.THREE.Raycaster();
  raycaster.setFromCamera(ndc(event), viewer!.camera);
  const origin = viewer!.toModel(raycaster.ray.origin);
  const dir = viewer!.toModel(raycaster.ray.origin.clone().add(raycaster.ray.direction)).sub(origin).normalize();
  const denom = dir.dot(base.pose.normal);
  if (Math.abs(denom) < 1e-6) return null;
  const t = base.pose.point.clone().sub(origin).dot(base.pose.normal) / denom;
  if (t < 0) return null;
  const point = origin.addScaledVector(dir, t);
  const d = point.sub(base.pose.point);
  return { x: d.dot(kit!.right(base.pose)), y: d.dot(base.pose.up) };
}

function onCanvasDown(event: PointerEvent) {
  if (event.button !== 0 || !viewer || !kit) return;
  if (props.placing || !ready()) {
    drag = { kind: 'click', x: event.clientX, y: event.clientY };
    return;
  }
  const under = decalUnder(event);
  if (!under) {
    drag = { kind: 'click', x: event.clientX, y: event.clientY };
    return;
  }
  const area = areaBy(under.uid);
  const placed = area && placementOf(area);
  if (!area || !placed) return;
  if (props.activeMethod && area.uid === props.selected) {
    const zone = area.methods.find(m => m.method === props.activeMethod);
    const local = pointerLocal(event, placed);
    if (zone && local) {
      const ax = local.x * mpu.value! + area.w / 2;
      const ay = area.h / 2 - local.y * mpu.value!;
      if (ax >= zone.x && ax <= zone.x + zone.w && ay >= zone.y && ay <= zone.y + zone.h) {
        drag = { kind: 'zone', uid: area.uid, method: zone.method, sx: 0, sy: 0, base: placed, start: { x: ax, y: ay }, rect0: { x: zone.x, y: zone.y, w: zone.w, h: zone.h }, last: null };
        captureOn(event, canvasRef.value!);
        return;
      }
    }
    drag = { kind: 'click', x: event.clientX, y: event.clientY };
    return;
  }
  if (area.uid !== props.selected) emit('select', area.uid);
  drag = { kind: 'move', uid: area.uid, grab: kit.surfaceOffset(placed.pose, placed.wrap, under.point), moved: false };
  captureOn(event, canvasRef.value!);
}

function onHandleDown(event: PointerEvent, handle: Handle) {
  const area = areaBy(props.selected);
  const placed = area && placementOf(area);
  if (event.button !== 0 || !area || !placed) return;
  event.stopPropagation();
  if (handle.zone && props.activeMethod) {
    const zone = area.methods.find(m => m.method === props.activeMethod);
    if (!zone) return;
    drag = { kind: 'zone', uid: area.uid, method: zone.method, sx: handle.sx, sy: handle.sy, base: placed, start: { x: 0, y: 0 }, rect0: { x: zone.x, y: zone.y, w: zone.w, h: zone.h }, last: null };
  }
  else {
    drag = { kind: 'resize', uid: area.uid, sx: handle.sx, sy: handle.sy, base: placed, w0: area.w, h0: area.h, last: null };
  }
  captureOn(event, event.currentTarget as HTMLElement);
}

function captureOn(event: PointerEvent, el: HTMLElement) {
  if (viewer) viewer.controls.enabled = false;
  el.setPointerCapture(event.pointerId);
}

function onPointerMove(event: PointerEvent) {
  if (!drag || drag.kind === 'click') return;
  const scheduled = pendingMove !== null;
  pendingMove = event;
  if (scheduled) return;
  requestAnimationFrame(() => {
    const e = pendingMove;
    pendingMove = null;
    if (e && drag) dragTo(e);
  });
}

function dragTo(event: PointerEvent) {
  const drag = currentDrag();
  if (!drag || drag.kind === 'click' || !ready()) return;
  const m = mpu.value!;
  const baked = viewer!.baked!;
  if (drag.kind === 'move') {
    const area = areaBy(drag.uid);
    const placed = area && placementOf(area);
    const hit = viewer!.pick(event.clientX, event.clientY);
    if (!area || !placed || !hit) return;
    let pose: Pose;
    if (placed.wrap) {
      pose = kit!.wrapPoseAt(placed.pose, placed.wrap, hit.point);
    }
    else {
      // The print follows the surface under the pointer, keeping its turn.
      const radius = Math.min(area.w, area.h) / 2 / m;
      const normal = kit!.averageNormal(baked, hit.point, radius, hit.normal);
      const up0 = kit!.defaultUp(placed.pose.normal, viewer!.modelUp(), viewer!.modelForward());
      const turn = kit!.angleAround(placed.pose.normal, up0, placed.pose.up);
      pose = { point: hit.point, normal, up: kit!.rotateAround(kit!.defaultUp(normal, viewer!.modelUp(), viewer!.modelForward()), normal, turn) };
    }
    const shifted = kit!.slideOnSurface(baked, frame!, pose, placed.wrap, -drag.grab.x, -drag.grab.y);
    if (!shifted) return;
    drag.moved = true;
    emit('area', area.uid, { anchor: anchorOf({ pose: shifted, wrap: placed.wrap }, area.w, area.h, faceOf(area)) }, 'live');
    return;
  }
  if (drag.kind === 'resize') {
    const area = areaBy(drag.uid);
    const local = pointerLocal(event, drag.base);
    if (!area || !local) return;
    const fx = local.x * m;
    const fy = local.y * m;
    let w = drag.sx ? Math.max(MIN_MM, drag.sx * fx + drag.w0 / 2) : drag.w0;
    let h = drag.sy ? Math.max(MIN_MM, drag.sy * fy + drag.h0 / 2) : drag.h0;
    if (event.shiftKey && drag.sx && drag.sy) {
      const s = Math.max(w / drag.w0, h / drag.h0);
      w = drag.w0 * s;
      h = drag.h0 * s;
    }
    w = Math.min(5000, Math.round(w));
    h = Math.min(5000, Math.round(h));
    const cx = (drag.sx * (w - drag.w0)) / 2 / m;
    const cy = (drag.sy * (h - drag.h0)) / 2 / m;
    const pose = kit!.slideOnSurface(baked, frame!, drag.base.pose, drag.base.wrap, cx, cy)
      ?? { ...drag.base.pose, point: drag.base.pose.point.clone().addScaledVector(kit!.right(drag.base.pose), cx).addScaledVector(drag.base.pose.up, cy) };
    const anchor = anchorOf({ pose, wrap: drag.base.wrap }, w, h, faceOf(area));
    drag.last = { w, h, anchor };
    emit('area', area.uid, { w, h, anchor }, 'live');
    return;
  }
  // A zone: moved by its middle, or resized by a handle; kept in the area.
  const area = areaBy(drag.uid);
  const local = pointerLocal(event, drag.base);
  if (!area || !local) return;
  const ax = local.x * m + area.w / 2;
  const ay = area.h / 2 - local.y * m;
  const r0 = drag.rect0;
  let next: ZoneRect;
  if (!drag.sx && !drag.sy) {
    next = {
      ...r0,
      x: Math.min(Math.max(0, Math.round(r0.x + ax - drag.start.x)), Math.max(0, area.w - r0.w)),
      y: Math.min(Math.max(0, Math.round(r0.y + ay - drag.start.y)), Math.max(0, area.h - r0.h)),
    };
  }
  else {
    let left = r0.x;
    let right = r0.x + r0.w;
    let top = r0.y;
    let bottom = r0.y + r0.h;
    const snap = (v: number) => Math.round(v);
    if (drag.sx < 0) left = Math.min(Math.max(0, snap(ax)), right - 1);
    if (drag.sx > 0) right = Math.max(Math.min(area.w, snap(ax)), left + 1);
    if (drag.sy > 0) top = Math.min(Math.max(0, snap(ay)), bottom - 1);
    if (drag.sy < 0) bottom = Math.max(Math.min(area.h, snap(ay)), top + 1);
    next = { x: left, y: top, w: right - left, h: bottom - top };
  }
  drag.last = next;
  emit('zone', area.uid, drag.method, next, 'live');
}

function onPointerUp(event: PointerEvent) {
  const d = drag;
  drag = null;
  pendingMove = null;
  if (viewer) viewer.controls.enabled = true;
  const target = event.currentTarget as HTMLElement | null;
  if (target?.hasPointerCapture?.(event.pointerId)) target.releasePointerCapture(event.pointerId);
  if (!d) return;
  if (d.kind === 'click') {
    if (Math.hypot(event.clientX - d.x, event.clientY - d.y) > 5) return;
    if (props.placing) placeAt(event);
    else if (ready() && !props.activeMethod) {
      const under = decalUnder(event);
      if (under && under.uid !== props.selected) emit('select', under.uid);
    }
    return;
  }
  if (d.kind === 'move') {
    const area = areaBy(d.uid);
    if (area && d.moved) emit('area', area.uid, { anchor: area.anchor }, 'commit');
    return;
  }
  if (d.kind === 'resize') {
    const area = areaBy(d.uid);
    if (!area || !d.last) return;
    // A new size may lie flat or need to wrap round.
    const placed = placementOf(area);
    const anchor = placed && !parametric.value
      ? anchorOf(flatOrWrapped(placed.pose, d.last.w, d.last.h, faceOf(area).round === true), d.last.w, d.last.h, faceOf(area))
      : d.last.anchor;
    emit('area', area.uid, { w: d.last.w, h: d.last.h, anchor }, 'commit');
    return;
  }
  if (d.last) emit('zone', d.uid, d.method, d.last, 'commit');
}

function placeAt(event: PointerEvent) {
  if (!ready()) return;
  const hit = viewer!.pick(event.clientX, event.clientY);
  if (!hit) return;
  const point = hit.point.clone();
  const hitNormal = hit.normal.clone();
  emit('place', (wMm, hMm) => {
    if (!ready()) return null;
    const normal = kit!.averageNormal(viewer!.baked!, point, Math.min(wMm, hMm) / 2 / mpu.value!, hitNormal);
    const pose = { point, normal, up: kit!.defaultUp(normal, viewer!.modelUp(), viewer!.modelForward()) };
    return anchorOf(flatOrWrapped(pose, wMm, hMm, false), wMm, hMm, {});
  });
}

// ── Commands for the toolbar and the inspector ──────────────────────────
function aligned(placed: Placement, wMm: number, hMm: number, how: 'x' | 'y' | 'centre' | 'top' | 'bottom'): Placement {
  const m = mpu.value!;
  let current = placed;
  // Twice: on a curved surface the first step lands close, the second exact.
  for (let i = 0; i < 2; i++) {
    const g = kit!.marginsOf(viewer!.baked!, frame!, current.pose, current.wrap, wMm / m, hMm / m, MARGIN_STEP_MM / m);
    const dx = how === 'x' || how === 'centre' ? (g.right - g.left) / 2 : 0;
    const dy = how === 'top' ? g.top : how === 'bottom' ? -g.bottom : how === 'y' || how === 'centre' ? (g.top - g.bottom) / 2 : 0;
    const next = kit!.slideOnSurface(viewer!.baked!, frame!, current.pose, current.wrap, dx, dy);
    if (!next) break;
    current = { ...current, pose: next };
  }
  return current;
}

function withArea<T>(uid: string, fn: (area: DraftArea, placed: Placement) => T): T | null {
  const area = areaBy(uid);
  const placed = area && ready() ? placementOf(area) : null;
  return area && placed ? fn(area, placed) : null;
}

function align(uid: string, how: 'x' | 'y' | 'top' | 'bottom'): AreaAnchor | null {
  return withArea(uid, (area, placed) => anchorOf(aligned(placed, area.w, area.h, how), area.w, area.h, faceOf(area)));
}

function nudge(uid: string, dxMm: number, dyMm: number): AreaAnchor | null {
  return withArea(uid, (area, placed) => {
    const next = kit!.slideOnSurface(viewer!.baked!, frame!, placed.pose, placed.wrap, dxMm / mpu.value!, dyMm / mpu.value!);
    return next ? anchorOf({ ...placed, pose: next }, area.w, area.h, faceOf(area)) : null;
  });
}

/** The area turned round its normal (models only; a turned print lies flat
 * or wraps anew). */
function rotate(uid: string, deg: number): AreaAnchor | null {
  if (parametric.value) return null;
  return withArea(uid, (area, placed) => {
    const up = kit!.rotateAround(placed.pose.up, placed.pose.normal, deg);
    const pose = { ...placed.pose, up };
    return anchorOf(flatOrWrapped(pose, area.w, area.h, faceOf(area).round === true), area.w, area.h, faceOf(area));
  });
}

function rotation(uid: string): number | null {
  if (parametric.value) return null;
  return withArea(uid, (_, placed) => {
    const up0 = kit!.defaultUp(placed.pose.normal, viewer!.modelUp(), viewer!.modelForward());
    const deg = kit!.angleAround(placed.pose.normal, up0, placed.pose.up);
    return Math.round(deg * 10) / 10;
  });
}

/** The anchor for a new size typed in (the same centre; flat or wrapped anew). */
function resized(uid: string, wMm: number, hMm: number): AreaAnchor | null {
  return withArea(uid, (area, placed) => {
    const round = faceOf(area).round === true;
    return anchorOf(parametric.value ? placed : flatOrWrapped(placed.pose, wMm, hMm, round), wMm, hMm, faceOf(area));
  });
}

/** For a copy: the same area moved over by its width (or left, or kept). */
function besideCopy(uid: string): AreaAnchor | null {
  return withArea(uid, (area, placed) => {
    const step = (area.w + 10) / mpu.value!;
    const next = kit!.slideOnSurface(viewer!.baked!, frame!, placed.pose, placed.wrap, step, 0)
      ?? kit!.slideOnSurface(viewer!.baked!, frame!, placed.pose, placed.wrap, -step, 0);
    return anchorOf({ ...placed, pose: next ?? placed.pose }, area.w, area.h, faceOf(area));
  });
}

/** The area mirrored to the other side of the model: left ↔ right, front ↔ back. */
function opposite(uid: string, across: 'side' | 'front'): AreaAnchor | null {
  if (parametric.value) return null;
  return withArea(uid, (area, placed) => {
    const axis = across === 'side' ? frame!.side : frame!.forward;
    const reflect = (v: THREE.Vector3) => v.clone().addScaledVector(axis, -2 * v.dot(axis));
    const rel = placed.pose.point.clone().sub(frame!.centre);
    const point = frame!.centre.clone().add(reflect(rel));
    const pose = { point, normal: reflect(placed.pose.normal).normalize(), up: reflect(placed.pose.up).normalize() };
    const hit = kit!.surfaceAt(viewer!.baked!, frame!, pose, null, 0, 0);
    if (!hit) return null;
    const round = faceOf(area).round === true;
    return anchorOf(flatOrWrapped({ ...pose, point: hit.point }, area.w, area.h, round), area.w, area.h, faceOf(area));
  });
}

function viewFrom(deg: number) {
  viewer?.viewFrom(deg);
}
function zoom(factor: number) {
  viewer?.zoomBy(factor);
}
function lookAt(uid: string) {
  const area = areaBy(uid);
  const placed = area && ready() ? placementOf(area) : null;
  if (!area || !placed || !viewer || !kit) return;
  if (area.camera) {
    viewer.view(vec(area.camera.position), vec(area.camera.target), viewer.modelUp());
    return;
  }
  const box = boxOf(area.w, area.h, placed.wrap, false);
  const cam = kit.areaCamera(placed.pose, { ...box, width: box.width * 1.6, height: box.height * 1.6 }, kit.VIEW_FOV, viewer.camera.aspect);
  viewer.view(cam.position, cam.target, viewer.modelUp());
}
function currentCamera(): AreaCamera | null {
  if (!viewer) return null;
  const v = viewer.currentView();
  return { position: r5(v.position), target: r5(v.target) };
}

/** The scale from the model's measured width being `mm`. */
function scaleFor(mm: number): DraftScale | null {
  if (!widthLine) return null;
  return { a: r5(widthLine.a), b: r5(widthLine.b), mm: round1(mm) };
}

function info(): ModelInfo | null {
  if (!frame || !kit) return null;
  const f = frame;
  const line = widthLine ?? {
    a: kit.framePoint(f, f.min.s, 0, f.max.f), b: kit.framePoint(f, f.max.s, 0, f.max.f), units: f.max.s - f.min.s,
  };
  if (!widthLine) widthLine = { ...line, sLeft: f.min.s, sRight: f.max.s, u: 0 };
  return { widthUnits: line.units, heightUnits: f.max.u - f.min.u, depthUnits: f.max.f - f.min.f, line: { a: r5(line.a), b: r5(line.b) } };
}

/** Loads another GLB in place of the model and moves every placed area to
 * the same spot on it (the same share of its box, onto its surface). The
 * old real width gives the new scale. */
async function replaceModel(url: string): Promise<{ anchors: Record<string, AreaAnchor>; scale: DraftScale | null; mmPerUnit: number | null; info: ModelInfo | null }> {
  if (!kit || !viewer) throw new Error(t('admin.shapeParts.viewNotReady'));
  const oldFrame = frame;
  const oldMm = widthLine && mpu.value ? widthLine.units * mpu.value : props.draft.model.scale?.mm ?? null;
  const scene = await kit.loadModel(url);
  loadToken++;
  const old = props.draft.areas.map(a => ({ area: a, placed: placementOf(a) }));
  viewer.setModel(scene, { upAxis: props.draft.model.upAxis, yawDeg: props.draft.model.yawDeg });
  clearDecals();
  guidesKey = '';
  shown = { key: loadKey(url), url, params: null };
  measureModel();
  loadState.value = 'ready';
  const newMpu = oldMm && widthLine ? oldMm / widthLine.units : null;
  const anchors: Record<string, AreaAnchor> = {};
  if (oldFrame && frame && newMpu) {
    const f0 = oldFrame;
    const f1 = frame;
    const share = (v: number, lo: number, hi: number) => (hi - lo > 1e-9 ? (v - lo) / (hi - lo) : 0.5);
    for (const { area, placed } of old) {
      if (!placed) continue;
      const rel = placed.pose.point.clone().sub(f0.centre);
      const s = share(rel.dot(f0.side), f0.min.s, f0.max.s);
      const u = share(rel.dot(f0.up), f0.min.u, f0.max.u);
      const d = share(rel.dot(f0.forward), f0.min.f, f0.max.f);
      const point = kit.framePoint(f1, f1.min.s + s * (f1.max.s - f1.min.s), f1.min.u + u * (f1.max.u - f1.min.u), f1.min.f + d * (f1.max.f - f1.min.f));
      const pose = { point, normal: placed.pose.normal.clone(), up: placed.pose.up.clone() };
      const hit = kit.surfaceAt(viewer.baked!, f1, pose, null, 0, 0);
      if (!hit) continue;
      const wrap = placed.wrap && mpu.value ? (placed.wrap * mpu.value) / newMpu : null;
      anchors[area.uid] = anchorOf({ pose: { ...pose, point: hit.point }, wrap }, area.w, area.h, faceOf(area), newMpu);
    }
  }
  const scale = oldMm ? scaleFor(oldMm) : null;
  return { anchors, scale, mmPerUnit: newMpu, info: info() };
}

/** Where every area of a built body goes when its dims change: the same
 * spot relative to the middle. */
function anchorsForDims(dims: Record<string, unknown>): Record<string, AreaAnchor> {
  const shape = parametric.value;
  if (!shape || !kit) return {};
  const now = kit.parametricSize(shape);
  const next = kit.parametricSize({ kind: shape.kind, dims });
  const out: Record<string, AreaAnchor> = {};
  for (const area of props.draft.areas) {
    if (!Object.keys(area.anchor).length) continue;
    const { pose } = kit.parametricPlacement(shape, { anchor: area.anchor, width_mm: String(area.w), height_mm: String(area.h) }, bodyLook.value);
    const across = next.width / (now.width || 1);
    pose.point.multiply(new kit.THREE.Vector3(across, next.height / (now.height || 1), shape.kind === 'cylinder' ? across : 1));
    out[area.uid] = kit.parametricAnchor({ kind: shape.kind, dims }, area.w, area.h, pose) as unknown as AreaAnchor;
  }
  return out;
}

/** The size of a built body (mm) and its dims at a new size. */
function bodySize(): { width: number; height: number } | null {
  return parametric.value && kit ? kit.parametricSize(parametric.value) : null;
}
function resizedDims(width: number, height: number): Record<string, unknown> | null {
  return parametric.value && kit ? kit.resizedDims(parametric.value, width, height) : null;
}

defineExpose({ align, nudge, rotate, rotation, resized, besideCopy, opposite, viewFrom, zoom, lookAt, currentCamera, scaleFor, replaceModel, anchorsForDims, bodySize, resizedDims, info });

// ── Loading ─────────────────────────────────────────────────────────────
function loadKey(url = props.draft.model.url) {
  if (parametric.value) return `p:${JSON.stringify(parametric.value)}`;
  return url ? `m:${url}|${props.draft.model.upAxis}|${props.draft.model.yawDeg}` : '';
}

function measureModel() {
  frame = kit!.modelFrame(viewer!.baked!, viewer!.modelUp(), viewer!.modelForward());
  widthLine = kit!.measureWidth(viewer!.baked!, frame);
  emit('model', info());
}

async function load() {
  if (!kit || !viewer) return;
  const key = loadKey();
  if (key === shown.key) return;
  const token = ++loadToken;
  if (!key) {
    loadState.value = 'empty';
    return;
  }
  const orientation = { upAxis: props.draft.model.upAxis, yawDeg: props.draft.model.yawDeg };
  try {
    if (parametric.value) {
      const params = JSON.stringify(parametric.value);
      const body = kit.buildParametric(parametric.value, [], bodyLook.value).body;
      body.traverse((o) => {
        const mesh = o as THREE.Mesh;
        if (mesh.isMesh) mesh.material = kit!.bodyMaterial(bodyLook.value, '#ffffff');
      });
      viewer.setModel(body, { upAxis: 'y', yawDeg: 0 });
      shown = { key, url: null, params };
    }
    else if (shown.url === props.draft.model.url && viewer.baked) {
      viewer.setOrientation(orientation);
      shown = { ...shown, key };
    }
    else {
      loadState.value = 'loading';
      const scene = await kit.loadModel(props.draft.model.url!);
      if (token !== loadToken) return;
      viewer.setModel(scene, orientation);
      shown = { key, url: props.draft.model.url, params: null };
    }
  }
  catch (err) {
    if (token !== loadToken) return;
    loadState.value = 'error';
    emit('failed', t('admin.shapeParts.modelLoadFailed', { error: err instanceof Error ? err.message : String(err) }));
    return;
  }
  clearDecals();
  guidesKey = '';
  measureModel();
  loadState.value = 'ready';
  schedule({ sync: true, guides: true });
}

watch(loadKey, () => void load());
watch(() => props.draft, () => schedule({ sync: true, guides: true }), { deep: true });
watch(() => [props.selected, props.activeMethod, props.stripAt, props.placing, props.ruler?.mmPerUnit, Boolean(props.ruler)], () => schedule({ sync: true, guides: true }));

onMounted(async () => {
  kit = await import('~/lib/three/kit');
  if (!canvasRef.value || !wrapRef.value) return;
  viewer = new kit.ModelViewer(canvasRef.value);
  viewer.controls.enableZoom = true;
  viewer.controls.addEventListener('change', () => schedule());
  resizeObserver = new ResizeObserver(() => {
    const rect = wrapRef.value!.getBoundingClientRect();
    viewer?.resize(rect.width, rect.height);
    schedule();
  });
  resizeObserver.observe(wrapRef.value);
  await load();
});

onBeforeUnmount(() => {
  if (frameRequest) cancelAnimationFrame(frameRequest);
  resizeObserver?.disconnect();
  clearDecals();
  clearOverlay();
  viewer?.dispose();
  viewer = null;
});

const SIDES = computed(() => [
  { label: t('admin.shapeParts.side.front'), deg: 0 }, { label: t('admin.shapeParts.side.left'), deg: 90 },
  { label: t('admin.shapeParts.side.back'), deg: 180 }, { label: t('admin.shapeParts.side.right'), deg: -90 },
]);
</script>

<template>
  <div
    ref="wrapRef"
    class="relative size-full overflow-hidden bg-muted"
    data-testid="shape-viewport"
  >
    <canvas
      ref="canvasRef"
      class="absolute inset-0 size-full touch-none"
      :class="placing ? 'cursor-crosshair' : ''"
      :aria-label="t('admin.shapeParts.model3d')"
      @pointerdown="onCanvasDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
    />

    <div class="pointer-events-none absolute inset-0">
      <span
        v-for="l in labels"
        :key="l.id"
        class="absolute -translate-x-1/2 -translate-y-1/2 whitespace-nowrap rounded-md px-1.5 py-0.5 text-[11px] font-semibold tabular-nums text-white shadow-sm"
        :class="l.tone === 'ruler' ? 'bg-blue-600' : l.tone === 'bad' ? 'bg-rose-700' : 'bg-rose-500'"
        :style="{ left: `${l.x}px`, top: `${l.y}px` }"
        :data-label="l.id"
      >{{ l.text }}</span>
      <button
        v-for="h in handles"
        :key="h.id"
        type="button"
        tabindex="-1"
        class="pointer-events-auto absolute size-3.5 -translate-x-1/2 -translate-y-1/2 touch-none rounded-[4px] border-2 bg-white shadow-sm transition-transform hover:scale-125"
        :class="h.zone ? (activeMethod === 'engrave' ? 'border-amber-700' : 'border-sky-700') : 'border-rose-600'"
        :style="{ left: `${h.x}px`, top: `${h.y}px`, cursor: h.cursor }"
        :aria-label="h.zone ? t('admin.shapeParts.zoneSize') : t('admin.shapeParts.areaSize')"
        :data-handle="h.id"
        @pointerdown="onHandleDown($event, h)"
        @pointermove="onPointerMove"
        @pointerup="onPointerUp"
        @pointercancel="onPointerUp"
      />
    </div>

    <div
      v-if="loadState !== 'ready'"
      class="absolute inset-0 grid place-items-center p-6 text-center text-sm text-muted-foreground"
    >
      <Icon
        v-if="loadState === 'loading'"
        name="lucide:loader-2"
        class="size-6 animate-spin"
      />
      <div
        v-else
        class="flex flex-col items-center gap-2"
      >
        <span
          class="flex size-11 items-center justify-center rounded-xl"
          :class="loadState === 'error' ? 'bg-destructive/10 text-destructive' : 'bg-card text-muted-foreground'"
        >
          <Icon
            name="lucide:box"
            class="size-5"
          />
        </span>
        <p class="font-medium text-foreground">
          {{ loadState === 'error' ? t('admin.shapeParts.modelOpenFailed') : t('admin.shapeParts.modelNotLoaded') }}
        </p>
      </div>
    </div>

    <div
      v-if="placing"
      class="pointer-events-none absolute inset-x-0 top-3 flex justify-center"
    >
      <span class="rounded-full bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground shadow-md">
        {{ t('admin.shapeParts.clickToPlace') }}
      </span>
    </div>

    <!-- The view: sides, zoom and back to the whole model. -->
    <div
      v-if="loadState === 'ready'"
      class="absolute bottom-3 right-3 flex flex-col items-end gap-2"
    >
      <div class="flex items-center gap-0.5 rounded-xl border border-border bg-card/95 p-1 shadow-sm backdrop-blur-sm">
        <UiTooltip
          v-for="z in [{ label: t('admin.shapeParts.zoomIn'), icon: 'lucide:zoom-in', f: 0.8 }, { label: t('admin.shapeParts.zoomOut'), icon: 'lucide:zoom-out', f: 1.25 }]"
          :key="z.label"
        >
          <UiTooltipTrigger as-child>
            <UiButton
              variant="ghost"
              size="icon-sm"
              :aria-label="z.label"
              @click="zoom(z.f)"
            >
              <Icon
                :name="z.icon"
                class="size-4"
              />
            </UiButton>
          </UiTooltipTrigger>
          <UiTooltipContent>{{ z.label }}</UiTooltipContent>
        </UiTooltip>
        <UiTooltip>
          <UiTooltipTrigger as-child>
            <UiButton
              variant="ghost"
              size="icon-sm"
              :aria-label="t('admin.shapeParts.wholeModel')"
              @click="viewFrom(0)"
            >
              <Icon
                name="lucide:scan"
                class="size-4"
              />
            </UiButton>
          </UiTooltipTrigger>
          <UiTooltipContent>{{ t('admin.shapeParts.wholeModel') }}</UiTooltipContent>
        </UiTooltip>
      </div>
      <div
        class="flex gap-0.5 rounded-xl border border-border bg-card/95 p-1 shadow-sm backdrop-blur-sm"
        role="group"
        :aria-label="t('admin.shapeParts.view')"
      >
        <UiButton
          v-for="s in SIDES"
          :key="s.deg"
          variant="ghost"
          size="sm"
          class="h-8 px-2.5 text-muted-foreground hover:bg-primary/10 hover:text-primary"
          @click="viewFrom(s.deg)"
        >
          {{ s.label }}
        </UiButton>
      </div>
    </div>
    <slot />
  </div>
</template>
