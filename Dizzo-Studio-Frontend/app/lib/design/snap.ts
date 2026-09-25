// Figma-like snapping for the editor, in area millimetres. A moving box
// (the rotated layer's bounds) sticks to the zone's edges and centre, the
// area's centre, the edges and centres of the other layers, the middle
// between its two neighbours, and to gaps equal to one already between two
// layers. The result says how far to shift and what to draw: guide lines
// and the equal gaps.
import type { Box } from '~/lib/design/document';

export interface Guide { axis: 'x' | 'y'; at: number; from: number; to: number }
export interface GapMark { axis: 'x' | 'y'; from: number; to: number; at: number; mm: number }
export interface SnapResult { dx: number; dy: number; guides: Guide[]; gaps: GapMark[] }

interface Frame { zone: Box; area: Box }

type Axis = 'x' | 'y';
const lo = (b: Box, a: Axis) => (a === 'x' ? b.x0 : b.y0);
const hi = (b: Box, a: Axis) => (a === 'x' ? b.x1 : b.y1);
const mid = (b: Box, a: Axis) => (lo(b, a) + hi(b, a)) / 2;
const other = (a: Axis): Axis => (a === 'x' ? 'y' : 'x');
const overlaps = (a: Box, b: Box, axis: Axis) => lo(a, axis) < hi(b, axis) && lo(b, axis) < hi(a, axis);
const EPS = 0.01;

interface Candidate { delta: number; gap?: GapMark[] }

/** The best shift along one axis (within `threshold` mm), if any. */
function snapAxis(box: Box, boxes: Box[], frame: Frame, axis: Axis, threshold: number): Candidate | null {
  const edges = [lo(box, axis), mid(box, axis), hi(box, axis)];
  const lines = [lo(frame.zone, axis), mid(frame.zone, axis), hi(frame.zone, axis), mid(frame.area, axis)];
  for (const b of boxes) lines.push(lo(b, axis), mid(b, axis), hi(b, axis));
  let best: Candidate | null = null;
  const consider = (c: Candidate) => {
    if (Math.abs(c.delta) <= threshold && (!best || Math.abs(c.delta) < Math.abs(best.delta) - EPS)) best = c;
  };
  for (const line of lines) for (const edge of edges) consider({ delta: line - edge });

  // Gaps only count between layers side by side with the moving one.
  const cross = other(axis);
  const row = boxes.filter(b => overlaps(b, box, cross));
  const before = row.filter(b => hi(b, axis) <= lo(box, axis) + EPS).sort((a, b) => hi(b, axis) - hi(a, axis))[0];
  const after = row.filter(b => lo(b, axis) >= hi(box, axis) - EPS).sort((a, b) => lo(a, axis) - lo(b, axis))[0];
  const at = (a: Box, b: Box) => (Math.max(lo(a, cross), lo(b, cross)) + Math.min(hi(a, cross), hi(b, cross))) / 2;
  const mark = (from: number, to: number, a: Box, b: Box): GapMark => ({ axis, from, to, at: at(a, b), mm: to - from });
  if (before && after) {
    // Right in the middle of its two neighbours.
    const delta = (hi(before, axis) + lo(after, axis) - lo(box, axis) - hi(box, axis)) / 2;
    const moved = shift(box, axis, delta);
    consider({ delta, gap: [mark(hi(before, axis), lo(moved, axis), before, moved), mark(hi(moved, axis), lo(after, axis), moved, after)] });
  }
  // The same gap as between two other layers side by side.
  for (const a of boxes) {
    for (const b of boxes) {
      if (a === b || !overlaps(a, b, cross) || hi(a, axis) > lo(b, axis)) continue;
      const g = lo(b, axis) - hi(a, axis);
      if (g <= EPS) continue;
      const existing = mark(hi(a, axis), lo(b, axis), a, b);
      if (before) {
        const delta = hi(before, axis) + g - lo(box, axis);
        const moved = shift(box, axis, delta);
        consider({ delta, gap: [existing, mark(hi(before, axis), lo(moved, axis), before, moved)] });
      }
      if (after) {
        const delta = lo(after, axis) - g - hi(box, axis);
        const moved = shift(box, axis, delta);
        consider({ delta, gap: [existing, mark(hi(moved, axis), lo(after, axis), moved, after)] });
      }
    }
  }
  return best;
}

function shift(box: Box, axis: Axis, d: number): Box {
  return axis === 'x' ? { ...box, x0: box.x0 + d, x1: box.x1 + d } : { ...box, y0: box.y0 + d, y1: box.y1 + d };
}

/** Guide lines through every edge or centre of `box` that lines up with a target. */
export function guidesFor(box: Box, boxes: Box[], frame: Frame): Guide[] {
  const guides: Guide[] = [];
  for (const axis of ['x', 'y'] as const) {
    const cross = other(axis);
    const edges = [lo(box, axis), mid(box, axis), hi(box, axis)];
    const add = (at: number, from: number, to: number) => {
      if (!edges.some(e => Math.abs(e - at) < EPS)) return;
      guides.push({ axis, at, from: Math.min(from, lo(box, cross)), to: Math.max(to, hi(box, cross)) });
    };
    for (const at of [lo(frame.zone, axis), mid(frame.zone, axis), hi(frame.zone, axis)]) add(at, lo(frame.zone, cross), hi(frame.zone, cross));
    add(mid(frame.area, axis), lo(frame.area, cross), hi(frame.area, cross));
    for (const b of boxes) for (const at of [lo(b, axis), mid(b, axis), hi(b, axis)]) add(at, lo(b, cross), hi(b, cross));
  }
  return guides;
}

/** Where a box being moved sticks. */
export function snapMove(box: Box, boxes: Box[], frame: Frame, threshold: number): SnapResult {
  const x = snapAxis(box, boxes, frame, 'x', threshold);
  const y = snapAxis(box, boxes, frame, 'y', threshold);
  const dx = x?.delta ?? 0;
  const dy = y?.delta ?? 0;
  const moved = shift(shift(box, 'x', dx), 'y', dy);
  const gaps = [...(x?.gap ?? []), ...(y?.gap ?? [])];
  return { dx, dy, guides: guidesFor(moved, boxes, frame), gaps };
}

/** Uniform scale about the centre: the factor that lands an edge of the
 * box on a target line, if one is within `threshold` mm. */
export function snapScale(box: Box, boxes: Box[], frame: Frame, threshold: number): number | null {
  const cx = mid(box, 'x');
  const cy = mid(box, 'y');
  let best: { f: number; d: number } | null = null;
  for (const axis of ['x', 'y'] as const) {
    const c = axis === 'x' ? cx : cy;
    const half = (hi(box, axis) - lo(box, axis)) / 2;
    if (half <= EPS) continue;
    const lines = [lo(frame.zone, axis), hi(frame.zone, axis)];
    for (const b of boxes) lines.push(lo(b, axis), hi(b, axis));
    for (const line of lines) {
      const edge = line < c ? lo(box, axis) : hi(box, axis);
      const d = Math.abs(line - edge);
      if (d <= threshold && (!best || d < best.d)) best = { f: Math.abs(line - c) / half, d };
    }
  }
  return best?.f ?? null;
}

/** Rotation that sticks to every 45° (15° steps with Shift). */
export function snapAngle(angle: number, fine: boolean): number {
  const step = fine ? 15 : 45;
  const snapped = Math.round(angle / step) * step;
  if (fine || Math.abs(angle - snapped) < 5) return snapped === -180 ? 180 : snapped;
  return angle;
}
