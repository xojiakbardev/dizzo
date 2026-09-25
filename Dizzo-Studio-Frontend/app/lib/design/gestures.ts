// Moving, resizing and rotating a layer by pointer, in the area's
// millimetres, shared by the flat editor and the 3D editor: whichever view
// the pointer is in only has to say where it is on the area. Snapping works
// like Figma (lib/design/snap.ts): pink guides to the zone, the centre and
// other layers, equal gaps. A layer always stays inside its method's zone;
// with a strip it moves anywhere in the zone as long as the area's layers
// still fit one strip together (the strip stays until they reach its edge,
// then follows them: document.settleStrips), and grows only as far as that.
import type { Box, Layer, StripPosition } from '~/lib/design/document';
import { areaMethod, growLimit, isBackgroundLayer, isLocked, layerBox, placeInZone, printZone, zoneBox } from '~/lib/design/document';
import { dialHit } from '~/lib/design/dial';
import { fontString, layoutText } from '~/lib/design/render';
import type { GapMark, Guide } from '~/lib/design/snap';
import { guidesFor, snapAngle, snapMove, snapScale } from '~/lib/design/snap';
import type { PrintArea } from '~/types/catalog';
import { i18nT } from '~/lib/i18n';

export interface Point { x: number; y: number }

/** A point in the layer's own (unrotated, centred) frame. */
export function localPoint(layer: Layer, p: Point): Point {
  const a = (-layer.rotation * Math.PI) / 180;
  const dx = p.x - layer.x_mm;
  const dy = p.y - layer.y_mm;
  return { x: dx * Math.cos(a) - dy * Math.sin(a), y: dx * Math.sin(a) + dy * Math.cos(a) };
}

/** The topmost layer under the point, or null where the point is on none
 * of them (the press then belongs to nothing: the selection is cleared).
 * A clock's dial covers its whole face, so it is only taken when the press
 * is on the numerals or the marks themselves (`slack` mm either side). */
export function hitLayer(layers: Layer[], p: Point, slack = 2): Layer | null {
  for (const layer of [...layers].reverse()) {
    if (isBackgroundLayer(layer)) continue;
    const q = localPoint(layer, p);
    if (Math.abs(q.x) > layer.w_mm / 2 || Math.abs(q.y) > layer.h_mm / 2) continue;
    const dial = layer.dial;
    if (dial && !dialHit(dial, layer.w_mm, layer.h_mm, q, px => fontString(dial, px), slack)) continue;
    return layer;
  }
  return null;
}

function at(layer: Layer, lx: number, ly: number): Point {
  const a = (layer.rotation * Math.PI) / 180;
  return { x: layer.x_mm + lx * Math.cos(a) - ly * Math.sin(a), y: layer.y_mm + lx * Math.sin(a) + ly * Math.cos(a) };
}

/** Corners (clockwise from top-left), the rotate knob above the top edge
 * and the top edge's middle, for handles `handle` mm wide. */
export function cornersOf(layer: Layer, handle: number) {
  const hw = layer.w_mm / 2;
  const hh = layer.h_mm / 2;
  return {
    points: [at(layer, -hw, -hh), at(layer, hw, -hh), at(layer, hw, hh), at(layer, -hw, hh)],
    rotate: at(layer, 0, -hh - handle * 2.2),
    top: at(layer, 0, -hh),
  };
}

/** Just outside each corner: rotating starts there (as in Figma). */
export function rotateSpots(layer: Layer, handle: number): Point[] {
  const o = handle * 0.9;
  const hw = layer.w_mm / 2 + o;
  const hh = layer.h_mm / 2 + o;
  return [[-hw, -hh], [hw, -hh], [hw, hh], [-hw, hh]].map(([lx, ly]) => at(layer, lx!, ly!));
}

/** What the pointer is on for a selected layer: a corner (resize), a
 * rotate spot or the knob, or nothing. */
export function handleAt(layer: Layer, p: Point, handle: number): 'scale' | 'rotate' | null {
  const near = (q: Point, r: number) => Math.hypot(q.x - p.x, q.y - p.y) <= r;
  const c = cornersOf(layer, handle);
  if (c.points.some(q => near(q, handle * 0.75))) return 'scale';
  if (near(c.rotate, handle * 0.8) || rotateSpots(layer, handle).some(q => near(q, handle * 0.95))) return 'rotate';
  return null;
}

export function frameOf(area: PrintArea, layer: Layer) {
  const box: Box = { x0: 0, y0: 0, x1: Number(area.width_mm), y1: Number(area.height_mm) };
  const method = areaMethod(area, layer.method);
  return { zone: method ? zoneBox(method) : box, area: box };
}

const othersOf = (layers: Layer[], layer: Layer) => layers.filter(l => l.id !== layer.id && l.area === layer.area).map(l => layerBox(l));

export type Drag
  = | { kind: 'move'; id: string; start: Point; layer: Layer }
    | { kind: 'scale'; id: string; startDist: number; layer: Layer }
    | { kind: 'rotate'; id: string; startAngle: number; layer: Layer };

export function startDrag(kind: Drag['kind'], layer: Layer, p: Point): Drag {
  if (kind === 'scale') return { kind, id: layer.id, startDist: Math.hypot(p.x - layer.x_mm, p.y - layer.y_mm), layer: { ...layer } };
  if (kind === 'rotate') return { kind, id: layer.id, startAngle: Math.atan2(p.y - layer.y_mm, p.x - layer.x_mm), layer: { ...layer } };
  return { kind, id: layer.id, start: p, layer: { ...layer } };
}

export interface DragContext {
  area: PrintArea;
  layers: Layer[]; // the area's layers, for snapping to the others
  strips: StripPosition[] | undefined; // the document's
  threshold: number; // snap distance in mm
  snapping: boolean;
  fineAngle: boolean; // Shift: 15° steps
}

export interface DragResult {
  patch: Partial<Layer>;
  guides: Guide[];
  gaps: GapMark[];
  badge: string | null; // "12.5 × 30 mm" while resizing, "45°" while rotating
}

const fmt = (mm: number) => (Math.round(mm * 10) / 10).toString();

/** A layer scaled by `factor` about its centre: text by its font size and
 * never past the zone (or the method's max, or its strip with the area's
 * other `layers`), anything else at least 2 mm. */
export function scaledLayer(area: PrintArea, layer: Layer, factor: number, layers: Layer[] = []): Partial<Layer> {
  const method = areaMethod(area, layer.method);
  let f = factor;
  if (method) f = Math.min(f, growLimit({ ...layer }, method, layers));
  if (layer.text) {
    // Whole millimetres; down when the zone (or the method) is the limit.
    const minSize = Math.ceil(method?.min_font_mm ? Number(method.min_font_mm) : 1);
    const raw = layer.text.size_mm * f;
    const size = Math.max(minSize, f < factor ? Math.floor(raw) : Math.round(raw));
    const text = { ...layer.text, size_mm: size };
    const layout = layoutText(text);
    const next = { ...layer, text, w_mm: layout.w_mm, h_mm: layout.h_mm };
    const placed = method ? placeInZone(next, method, layers) : next;
    return { text, w_mm: layout.w_mm, h_mm: layout.h_mm, x_mm: placed.x_mm, y_mm: placed.y_mm };
  }
  f = Math.max(f, 2 / Math.min(layer.w_mm, layer.h_mm));
  const next = { ...layer, w_mm: layer.w_mm * f, h_mm: layer.h_mm * f };
  const placed = method ? placeInZone(next, method, layers) : next;
  return { w_mm: next.w_mm, h_mm: next.h_mm, x_mm: placed.x_mm, y_mm: placed.y_mm };
}

/** Where the dragged layer goes with the pointer at `p`: always where the
 * pointer is relative to where it took the layer (so a layer held back at
 * an edge comes back under it), kept in place by placeInZone. */
export function dragTo(drag: Drag, p: Point, ctx: DragContext): DragResult {
  const { layer } = drag;
  const method = areaMethod(ctx.area, layer.method);
  const others = othersOf(ctx.layers, layer);
  const frame = frameOf(ctx.area, layer);
  if (drag.kind === 'move') {
    const raw = { ...layer, x_mm: layer.x_mm + p.x - drag.start.x, y_mm: layer.y_mm + p.y - drag.start.y };
    let moved = raw;
    let guides: Guide[] = [];
    let gaps: GapMark[] = [];
    if (ctx.snapping) {
      const snap = snapMove(layerBox(moved), others, frame, ctx.threshold);
      moved = { ...moved, x_mm: moved.x_mm + snap.dx, y_mm: moved.y_mm + snap.dy };
      guides = snap.guides;
      gaps = snap.gaps;
    }
    let placed = method ? placeInZone(moved, method, ctx.layers) : moved;
    if (method?.strip_width_mm && placed.x_mm !== raw.x_mm) {
      // A snap never pushes the strip where the pointer alone wouldn't.
      const strip = printZone(ctx.area, method, ctx.layers, ctx.strips);
      const inStrip = (l: Layer) => {
        const b = layerBox(l);
        return b.x0 >= strip.x0 - 1e-6 && b.x1 <= strip.x1 + 1e-6;
      };
      const unsnapped = placeInZone(raw, method, ctx.layers);
      if (!inStrip(placed) && inStrip(unsnapped)) placed = { ...placed, x_mm: unsnapped.x_mm };
    }
    return { patch: { x_mm: placed.x_mm, y_mm: placed.y_mm }, guides, gaps, badge: null };
  }
  if (drag.kind === 'scale') {
    let factor = Math.hypot(p.x - layer.x_mm, p.y - layer.y_mm) / Math.max(drag.startDist, 0.01);
    if (ctx.snapping) {
      const f = snapScale(layerBox({ ...layer, w_mm: layer.w_mm * factor, h_mm: layer.h_mm * factor }), others, frame, ctx.threshold);
      if (f !== null) factor *= f;
    }
    const patch = scaledLayer(ctx.area, layer, factor, ctx.layers);
    const next = { ...layer, ...patch };
    return {
      patch,
      guides: ctx.snapping ? guidesFor(layerBox(next), others, frame) : [],
      gaps: [],
      badge: `${fmt(next.w_mm)} × ${fmt(next.h_mm)} ${i18nT('studio.common.mm')}`,
    };
  }
  let angle = layer.rotation + ((Math.atan2(p.y - layer.y_mm, p.x - layer.x_mm) - drag.startAngle) * 180) / Math.PI;
  angle = ((angle % 360) + 540) % 360 - 180;
  angle = snapAngle(angle, ctx.fineAngle);
  const turned = { ...layer, rotation: Number(angle.toFixed(1)) };
  const placed = method ? placeInZone(turned, method, ctx.layers) : turned;
  return { patch: { rotation: turned.rotation, x_mm: placed.x_mm, y_mm: placed.y_mm }, guides: [], gaps: [], badge: `${Math.round(turned.rotation)}°` };
}

/** Arrow keys move a layer by 1 mm (10 with Shift), inside its zone (and
 * its strip, with the area's other `layers`). */
export function nudge(area: PrintArea, layer: Layer, key: string, big: boolean, layers: Layer[]): Partial<Layer> | null {
  if (isLocked(layer)) return null;
  const step = big ? 10 : 1;
  const delta = ({ ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] } as Record<string, number[]>)[key];
  if (!delta) return null;
  const moved = { ...layer, x_mm: layer.x_mm + delta[0]!, y_mm: layer.y_mm + delta[1]! };
  const method = areaMethod(area, layer.method);
  const placed = method ? placeInZone(moved, method, layers) : moved;
  return { x_mm: placed.x_mm, y_mm: placed.y_mm };
}
