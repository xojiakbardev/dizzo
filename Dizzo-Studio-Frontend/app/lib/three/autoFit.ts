// Sizing and moving prints on any GLB: the body's width measured straight
// across the front (so the admin only types the real size), a placed print
// slid over the surface (arrows and dragging in the shape editor), the
// room left from its edges to where the surface ends (the distances shown
// round it), and the radius a print wraps round when it can't lie flat.
//
// Everything works in model space along the model's own axes (the
// configurator only turns models by quarter turns), casting rays through
// the baked triangle grid: hundreds of rays stay cheap on heavy garments.
import * as THREE from 'three';
import type { BakedModel } from '~/lib/three/bakedModel';
import { refPart, refTri, trianglesNear, vertex, vertexNormal } from '~/lib/three/bakedModel';
import type { Pose } from '~/lib/three/projector';

/** The model's axes: `side` points to the wearer's left (screen right
 * from the front), `u`/`s`/`f` are coordinates from the box centre. */
export interface ModelFrame {
  up: THREE.Vector3;
  forward: THREE.Vector3;
  side: THREE.Vector3;
  centre: THREE.Vector3;
  min: { s: number; u: number; f: number };
  max: { s: number; u: number; f: number };
}

export function modelFrame(model: BakedModel, up: THREE.Vector3, forward: THREE.Vector3): ModelFrame {
  const side = new THREE.Vector3().crossVectors(up, forward).normalize();
  const centre = model.box.getCenter(new THREE.Vector3());
  const min = { s: Infinity, u: Infinity, f: Infinity };
  const max = { s: -Infinity, u: -Infinity, f: -Infinity };
  for (const x of [model.box.min.x, model.box.max.x]) {
    for (const y of [model.box.min.y, model.box.max.y]) {
      for (const z of [model.box.min.z, model.box.max.z]) {
        const rel = new THREE.Vector3(x, y, z).sub(centre);
        const c = { s: rel.dot(side), u: rel.dot(up), f: rel.dot(forward) };
        for (const k of ['s', 'u', 'f'] as const) {
          min[k] = Math.min(min[k], c[k]);
          max[k] = Math.max(max[k], c[k]);
        }
      }
    }
  }
  return { up: up.clone(), forward: forward.clone(), side, centre, min, max };
}

export function framePoint(frame: ModelFrame, s: number, u: number, f: number): THREE.Vector3 {
  return frame.centre.clone().addScaledVector(frame.side, s).addScaledVector(frame.up, u).addScaledVector(frame.forward, f);
}

export const frameHeight = (frame: ModelFrame) => frame.max.u - frame.min.u;
const frameDepth = (frame: ModelFrame) => frame.max.f - frame.min.f;

type From = 'front' | 'back';

interface RayHit {
  point: THREE.Vector3;
  normal: THREE.Vector3; // unit, facing where the ray came from
  f: number;
}

/** The first surface point on the segment from `origin` to `target`. */
function castSegment(model: BakedModel, frame: ModelFrame, origin: THREE.Vector3, target: THREE.Vector3): RayHit | null {
  const pad = model.grid.cell * 0.01;
  const lo = origin.clone().min(target).subScalar(pad);
  const hi = origin.clone().max(target).addScalar(pad);
  const dir = target.clone().sub(origin);
  const length = dir.length();
  dir.divideScalar(length);

  const a = new THREE.Vector3();
  const b = new THREE.Vector3();
  const c = new THREE.Vector3();
  const e1 = new THREE.Vector3();
  const e2 = new THREE.Vector3();
  const p = new THREE.Vector3();
  const q = new THREE.Vector3();
  const tv = new THREE.Vector3();
  let best: { t: number; ref: number; u: number; v: number } | null = null;
  for (const ref of trianglesNear(model, lo, hi)) {
    const part = model.parts[refPart(ref)]!;
    const tri = refTri(ref);
    vertex(part, part.index[tri * 3]!, a);
    vertex(part, part.index[tri * 3 + 1]!, b);
    vertex(part, part.index[tri * 3 + 2]!, c);
    // Möller–Trumbore, both faces.
    e1.subVectors(b, a);
    e2.subVectors(c, a);
    p.crossVectors(dir, e2);
    const det = e1.dot(p);
    if (Math.abs(det) < 1e-12) continue;
    tv.subVectors(origin, a);
    const bu = tv.dot(p) / det;
    if (bu < 0 || bu > 1) continue;
    q.crossVectors(tv, e1);
    const bv = dir.dot(q) / det;
    if (bv < 0 || bu + bv > 1) continue;
    const t = e2.dot(q) / det;
    if (t > 0 && t <= length && (!best || t < best.t)) best = { t, ref, u: bu, v: bv };
  }
  if (!best) return null;
  const part = model.parts[refPart(best.ref)]!;
  const tri = refTri(best.ref);
  const normal = vertexNormal(part, part.index[tri * 3]!, a).clone().multiplyScalar(1 - best.u - best.v)
    .addScaledVector(vertexNormal(part, part.index[tri * 3 + 1]!, b), best.u)
    .addScaledVector(vertexNormal(part, part.index[tri * 3 + 2]!, c), best.v)
    .normalize();
  if (normal.dot(dir) > 0) normal.negate();
  const point = origin.clone().addScaledVector(dir, best.t);
  return { point, normal, f: point.clone().sub(frame.centre).dot(frame.forward) };
}

/** The first surface point on a ray through (s, u) parallel to `forward`,
 * coming from the front or from the back. */
function castAcross(model: BakedModel, frame: ModelFrame, s: number, u: number, from: From): RayHit | null {
  const outside = frameDepth(frame) * 0.05;
  const start = from === 'front' ? frame.max.f + outside : frame.min.f - outside;
  const end = from === 'front' ? frame.min.f - outside : frame.max.f + outside;
  return castSegment(model, frame, framePoint(frame, s, u, start), framePoint(frame, s, u, end));
}

// ── Width ────────────────────────────────────────────────────────────────

/** Where the body is measured across, as a share of the height from the
 * bottom: a garment's chest, below the sleeves. */
export const DEFAULT_WIDTH_LEVEL = 0.55;

export interface WidthLine {
  a: THREE.Vector3; // model space, on the front, the body's two edges
  b: THREE.Vector3;
  units: number;
  sLeft: number;
  sRight: number;
  u: number;
}

/** The body's width at `level`: the unbroken run of surface across the
 * front through the centre, so sleeves hanging beside it are left out. */
export function measureWidth(model: BakedModel, frame: ModelFrame, level = DEFAULT_WIDTH_LEVEL): WidthLine | null {
  const samples = 240;
  const u = frame.min.u + frameHeight(frame) * level;
  const step = (frame.max.s - frame.min.s) / samples;
  const sAt = (i: number) => frame.min.s + step * (i + 0.5);
  const hit = Array.from({ length: samples }, (_, i) => castAcross(model, frame, sAt(i), u, 'front') !== null);
  const middle = Math.min(samples - 1, Math.max(0, Math.round(-frame.min.s / step - 0.5)));
  let start = -1;
  for (let d = 0; d <= samples / 10 && start < 0; d++) {
    if (hit[middle - d]) start = middle - d;
    else if (hit[middle + d]) start = middle + d;
  }
  if (start < 0) return null;
  let left = start;
  let right = start;
  while (left > 0 && hit[left - 1]) left--;
  while (right < samples - 1 && hit[right + 1]) right++;
  const sLeft = sAt(left) - step / 2;
  const sRight = sAt(right) + step / 2;
  return {
    a: framePoint(frame, sLeft, u, frame.max.f), b: framePoint(frame, sRight, u, frame.max.f),
    units: sRight - sLeft, sLeft, sRight, u,
  };
}

// ── Placement ────────────────────────────────────────────────────────────

/** Prints face their projector by less than this: never onto folds or
 * through to the back. */
export const AUTO_MAX_ANGLE = 85;

interface SurfacePoint { point: THREE.Vector3; height: number } // height: off the print's flat or round surface

/** Where the print's own point (x, y) — right and up from its centre, or
 * round and up for a wrapping print — meets the surface. */
export function surfaceAt(model: BakedModel, frame: ModelFrame, pose: Pose, wrapRadius: number | null, x: number, y: number): SurfacePoint | null {
  const right = new THREE.Vector3().crossVectors(pose.up, pose.normal).normalize();
  if (!wrapRadius) {
    // From just outside the model to its far side: the surface may curve
    // well behind the print's plane (a torso's sides).
    const depth = frameDepth(frame);
    const through = pose.point.clone().addScaledVector(right, x).addScaledVector(pose.up, y);
    const hit = castSegment(model, frame, through.clone().addScaledVector(pose.normal, depth * 0.6), through.clone().addScaledVector(pose.normal, -depth));
    return hit ? { point: hit.point, height: hit.point.clone().sub(through).dot(pose.normal) } : null;
  }
  const angle = x / wrapRadius;
  const dir = pose.normal.clone().multiplyScalar(Math.cos(angle)).addScaledVector(right, Math.sin(angle));
  const base = pose.point.clone().addScaledVector(pose.normal, -wrapRadius).addScaledVector(pose.up, y);
  const reach = wrapRadius * 0.8;
  const hit = castSegment(model, frame, base.clone().addScaledVector(dir, wrapRadius + reach), base.clone().addScaledVector(dir, wrapRadius - reach));
  return hit ? { point: hit.point, height: hit.point.clone().sub(base).dot(dir) - wrapRadius } : null;
}

/** The pose of a print moved to the point where its (x, y) lands; a
 * wrapping print turns round its axis and keeps it. */
function movedTo(pose: Pose, wrapRadius: number | null, x: number, y: number, hit: THREE.Vector3): Pose {
  if (!wrapRadius) return { ...pose, point: hit };
  const right = new THREE.Vector3().crossVectors(pose.up, pose.normal).normalize();
  const angle = x / wrapRadius;
  const normal = pose.normal.clone().multiplyScalar(Math.cos(angle)).addScaledVector(right, Math.sin(angle)).normalize();
  const point = pose.point.clone().addScaledVector(pose.normal, -wrapRadius).addScaledVector(pose.up, y).addScaledVector(normal, wrapRadius);
  return { point, normal, up: pose.up.clone() };
}

/** Moves a placed print over the surface by (dx, dy) in its own frame,
 * keeping its facing. Null when that falls off the model. */
export function slideOnSurface(model: BakedModel, frame: ModelFrame, pose: Pose, wrapRadius: number | null, dx: number, dy: number): Pose | null {
  const hit = surfaceAt(model, frame, pose, wrapRadius, dx, dy);
  return hit ? movedTo(pose, wrapRadius, dx, dy, hit.point) : null;
}

/** Where a surface point lies in a print's own frame: right and up from its
 * centre, or round and up for a wrapping print (surfaceAt's x, y). */
export function surfaceOffset(pose: Pose, wrapRadius: number | null, point: THREE.Vector3): { x: number; y: number } {
  const right = new THREE.Vector3().crossVectors(pose.up, pose.normal).normalize();
  if (!wrapRadius) {
    const d = point.clone().sub(pose.point);
    return { x: d.dot(right), y: d.dot(pose.up) };
  }
  const d = point.clone().sub(pose.point.clone().addScaledVector(pose.normal, -wrapRadius));
  return { x: Math.atan2(d.dot(right), d.dot(pose.normal)) * wrapRadius, y: d.dot(pose.up) };
}

/** A wrapping print's pose with its centre under a picked surface point:
 * the point's turn round the axis and height along it. */
export function wrapPoseAt(pose: Pose, wrapRadius: number, point: THREE.Vector3): Pose {
  const centre = pose.point.clone().addScaledVector(pose.normal, -wrapRadius);
  const rel = point.clone().sub(centre);
  const y = rel.dot(pose.up);
  const normal = rel.addScaledVector(pose.up, -y).normalize();
  return { point: centre.addScaledVector(pose.up, y).addScaledVector(normal, wrapRadius), normal, up: pose.up.clone() };
}

export interface Margins { top: number; bottom: number; left: number; right: number }

/** Room from each edge of a w × h print to where the surface ends — the
 * model's edge, a neckline, a mug's rim or handle: the ray misses, or the
 * surface jumps by a fifth of the model's depth. A wrapping print looks all
 * the way round, so both sides stop at the handle. Model units, negative
 * when the print runs past it. */
export function marginsOf(model: BakedModel, frame: ModelFrame, pose: Pose, wrapRadius: number | null, width: number, height: number, step: number): Margins {
  const jump = frameDepth(frame) * 0.2;
  const start = surfaceAt(model, frame, pose, wrapRadius, 0, 0);
  const across = wrapRadius ? 2 * Math.PI * wrapRadius : (frame.max.s - frame.min.s) * 1.5;
  const along = (frame.max.u - frame.min.u) * 1.5;
  const reach = (dx: number, dy: number, limit: number) => {
    let last = start!;
    let reached = 0;
    const on = (t: number) => {
      const hit = surfaceAt(model, frame, pose, wrapRadius, dx * t, dy * t);
      return hit && Math.abs(hit.height - last.height) <= jump ? hit : null;
    };
    for (let t = step; t <= limit; t += step) {
      const hit = on(t);
      if (!hit) {
        // The edge is within this step: halve it down to a twentieth.
        let hi = t;
        for (let i = 0; i < 5; i++) {
          const mid = (reached + hi) / 2;
          if (on(mid)) reached = mid;
          else hi = mid;
        }
        return reached;
      }
      last = hit;
      reached = t;
    }
    return reached;
  };
  if (!start) return { top: -height / 2, bottom: -height / 2, left: -width / 2, right: -width / 2 };
  return {
    top: reach(0, 1, along) - height / 2,
    bottom: reach(0, -1, along) - height / 2,
    left: reach(-1, 0, across) - width / 2,
    right: reach(1, 0, across) - width / 2,
  };
}

/** The radius a w-wide print should wrap round at its pose: the circle
 * through the surface at its centre and a quarter of its width either
 * side, when the surface curves round behind it (a mug). */
export function wrapRadiusFor(model: BakedModel, frame: ModelFrame, pose: Pose, width: number): number | null {
  const a = Math.min(width / 4, (frame.max.s - frame.min.s) / 4);
  const points = [-a, 0, a].map(x => surfaceAt(model, frame, pose, null, x, 0)?.point);
  if (points.some(p => !p)) return null;
  const flat = points.map(p => p!.clone().addScaledVector(pose.up, -p!.dot(pose.up)));
  const [p0, p1, p2] = flat as [THREE.Vector3, THREE.Vector3, THREE.Vector3];
  const ab = p1.distanceTo(p0);
  const bc = p2.distanceTo(p1);
  const ca = p0.distanceTo(p2);
  const area = new THREE.Vector3().subVectors(p1, p0).cross(new THREE.Vector3().subVectors(p2, p0)).length() / 2;
  if (area < 1e-12) return null;
  const radius = (ab * bc * ca) / (4 * area);
  // The middle point must stand out towards the viewer: a bulge, not a hollow.
  const bulge = p1.clone().sub(p0.clone().add(p2).multiplyScalar(0.5)).dot(pose.normal);
  return bulge > 0 ? radius : null;
}
