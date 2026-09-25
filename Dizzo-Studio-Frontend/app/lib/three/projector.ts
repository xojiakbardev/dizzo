// Decal projector for print areas on a GLB. The same code places areas in
// the admin configurator and renders designs in the Studio, so what the
// admin checks is exactly what the customer gets.
//
// Projector frame (scene space): origin `point`, z = `normal` (out of the
// surface, towards the viewer), y = `up` (top of the print), x = y × z
// (right, as seen from outside). The box spans width × height × depth
// around the point; a triangle receives the print only if it faces the
// projector by less than maxAngleDeg, so prints never wrap onto folds or
// through to the back.
//
// A wrapping print (wrapRadius set) goes round a cylinder instead: its
// axis runs along `up`, wrapRadius behind `point`; x is the arc length
// round it, y the height along it, z the distance off the cylinder — a
// mug's print from the handle round to the handle.
import * as THREE from 'three';
import type { BakedModel } from '~/lib/three/bakedModel';
import { refPart, refTri, trianglesNear, triRef, vertex, vertexNormal } from '~/lib/three/bakedModel';

export interface Pose {
  point: THREE.Vector3;
  normal: THREE.Vector3; // unit
  up: THREE.Vector3; // unit, orthogonal to normal
}

export interface ProjectorBox {
  width: number; // scene units
  height: number;
  depth: number;
  maxAngleDeg: number;
  wrapRadius?: number | null; // scene units; set for a print wrapping a cylinder
  round?: boolean; // only the ellipse inside the rectangle is printed (a clock's dial)
}

export interface DecalResult {
  geometry: THREE.BufferGeometry;
  coverage: number; // share of the print rectangle (its inscribed ellipse when round) that lands on the surface
  stretchedShare: number; // share of the printed surface stretched by more than STRETCH_LIMIT
  triangles: Set<number>; // source triangles touched (for overlap checks)
}

export const STRETCH_LIMIT = 1.15;
const COVERAGE_GRID = 100;
// Lifts the decal off the surface so it never z-fights with the fabric.
const LIFT = 1e-3;

export function right(pose: Pose): THREE.Vector3 {
  return new THREE.Vector3().crossVectors(pose.up, pose.normal).normalize();
}

/** The print's up direction at a surface point: the model's up axis
 * flattened onto the surface; on a surface facing straight up or down, the
 * model's forward axis instead. */
export function defaultUp(normal: THREE.Vector3, modelUp: THREE.Vector3, modelForward: THREE.Vector3): THREE.Vector3 {
  const reference = Math.abs(normal.dot(modelUp)) > 0.98 ? modelForward : modelUp;
  return reference.clone().addScaledVector(normal, -reference.dot(normal)).normalize();
}

/** Signed angle (degrees) of `up` from `reference` around `normal`. */
export function angleAround(normal: THREE.Vector3, reference: THREE.Vector3, up: THREE.Vector3): number {
  const cross = new THREE.Vector3().crossVectors(reference, up);
  return THREE.MathUtils.radToDeg(Math.atan2(cross.dot(normal), reference.dot(up)));
}

export function rotateAround(v: THREE.Vector3, axis: THREE.Vector3, degrees: number): THREE.Vector3 {
  return v.clone().applyAxisAngle(axis, THREE.MathUtils.degToRad(degrees)).normalize();
}

/** Area-weighted normal of the surface around `point` that faces roughly
 * like `hitNormal` — a stable projection direction on wrinkled cloth. */
export function averageNormal(model: BakedModel, point: THREE.Vector3, radius: number, hitNormal: THREE.Vector3): THREE.Vector3 {
  const lo = point.clone().subScalar(radius);
  const hi = point.clone().addScalar(radius);
  const a = new THREE.Vector3();
  const b = new THREE.Vector3();
  const c = new THREE.Vector3();
  const centroid = new THREE.Vector3();
  const face = new THREE.Vector3();
  const sum = new THREE.Vector3();
  for (const ref of trianglesNear(model, lo, hi)) {
    const part = model.parts[refPart(ref)]!;
    const t = refTri(ref);
    vertex(part, part.index[t * 3]!, a);
    vertex(part, part.index[t * 3 + 1]!, b);
    vertex(part, part.index[t * 3 + 2]!, c);
    centroid.copy(a).add(b).add(c).divideScalar(3);
    if (centroid.distanceTo(point) > radius) continue;
    face.subVectors(c, b).cross(a.clone().sub(b)); // length = 2 × area
    if (face.lengthSq() === 0) continue;
    // Winding in some GLBs is inconsistent; orient by the vertex normals.
    const shading = vertexNormal(part, part.index[t * 3]!, a).clone()
      .add(vertexNormal(part, part.index[t * 3 + 1]!, b))
      .add(vertexNormal(part, part.index[t * 3 + 2]!, c));
    if (face.dot(shading) < 0) face.negate();
    if (face.clone().normalize().dot(hitNormal) < 0.5) continue;
    sum.add(face);
  }
  return sum.lengthSq() > 0 ? sum.normalize() : hitNormal.clone().normalize();
}

interface ClipVertex { p: THREE.Vector3; n: THREE.Vector3 } // p in projector space

function clip(polygon: ClipVertex[], axis: 'x' | 'y' | 'z', limit: number, sign: 1 | -1): ClipVertex[] {
  const out: ClipVertex[] = [];
  const inside = (v: ClipVertex) => sign * v.p[axis] <= limit;
  for (let i = 0; i < polygon.length; i++) {
    const cur = polygon[i]!;
    const next = polygon[(i + 1) % polygon.length]!;
    const curIn = inside(cur);
    const nextIn = inside(next);
    if (curIn) out.push(cur);
    if (curIn !== nextIn) {
      const t = (sign * limit - cur.p[axis]) / (next.p[axis] - cur.p[axis]);
      out.push({ p: cur.p.clone().lerp(next.p, t), n: cur.n.clone().lerp(next.n, t).normalize() });
    }
  }
  return out;
}

/** Scene ↔ projector coordinates for a pose: flat, or round a cylinder. */
function projectorSpace(pose: Pose, box: ProjectorBox) {
  const x = right(pose);
  const { normal: z, up: y, point } = pose;
  const d = new THREE.Vector3();
  const R = box.wrapRadius ?? null;
  if (!R) {
    return {
      toLocal: (p: THREE.Vector3) => {
        d.subVectors(p, point);
        return new THREE.Vector3(d.dot(x), d.dot(y), d.dot(z));
      },
      toScene: (l: THREE.Vector3) => point.clone().addScaledVector(x, l.x).addScaledVector(y, l.y).addScaledVector(z, l.z),
      facing: (_centroid: THREE.Vector3) => z,
      reach: { x: box.width / 2, y: box.height / 2, z: box.depth / 2 },
      axisCentre: null as THREE.Vector3 | null,
    };
  }
  const centre = point.clone().addScaledVector(z, -R);
  return {
    toLocal: (p: THREE.Vector3) => {
      d.subVectors(p, centre);
      const rx = d.dot(x);
      const rz = d.dot(z);
      return new THREE.Vector3(Math.atan2(rx, rz) * R, d.dot(y), Math.hypot(rx, rz) - R);
    },
    toScene: (l: THREE.Vector3) => {
      const angle = l.x / R;
      const r = R + l.z;
      return centre.clone().addScaledVector(y, l.y).addScaledVector(z, Math.cos(angle) * r).addScaledVector(x, Math.sin(angle) * r);
    },
    facing: (centroid: THREE.Vector3) => {
      d.subVectors(centroid, centre);
      return d.addScaledVector(y, -d.dot(y)).normalize().clone();
    },
    reach: { x: R + box.depth / 2, y: box.height / 2, z: R + box.depth / 2 },
    axisCentre: centre,
  };
}

export function projectDecal(model: BakedModel, pose: Pose, box: ProjectorBox): DecalResult {
  const x = right(pose);
  const { normal: z, up: y } = pose;
  const space = projectorSpace(pose, box);
  const hw = box.width / 2;
  const hh = box.height / 2;
  const hd = box.depth / 2;
  const minCos = Math.cos(THREE.MathUtils.degToRad(box.maxAngleDeg));
  const wrapLimit = box.wrapRadius ? Math.PI * box.wrapRadius : Infinity;

  // Scene-space bounding box of the projector for the grid query.
  const origin = space.axisCentre ?? pose.point;
  const lo = new THREE.Vector3(Infinity, Infinity, Infinity);
  const hi = new THREE.Vector3(-Infinity, -Infinity, -Infinity);
  for (const sx of [-space.reach.x, space.reach.x]) {
    for (const sy of [-space.reach.y, space.reach.y]) {
      for (const sz of [-space.reach.z, space.reach.z]) {
        const corner = origin.clone().addScaledVector(x, sx).addScaledVector(y, sy).addScaledVector(z, sz);
        lo.min(corner);
        hi.max(corner);
      }
    }
  }

  const positions: number[] = [];
  const normals: number[] = [];
  const uvs: number[] = [];
  const triangles = new Set<number>();
  const covered = new Uint8Array(COVERAGE_GRID * COVERAGE_GRID);
  let printedArea = 0; // in uv units (1 = the whole print)
  let stretchedArea = 0;
  const lift = LIFT * Math.max(box.width, box.height);
  const va = new THREE.Vector3();
  const na = new THREE.Vector3();
  const centroid = new THREE.Vector3();

  for (const ref of trianglesNear(model, lo, hi)) {
    const part = model.parts[refPart(ref)]!;
    const t = refTri(ref);
    let polygon: ClipVertex[] = [];
    const shading = new THREE.Vector3();
    centroid.set(0, 0, 0);
    for (let k = 0; k < 3; k++) {
      const i = part.index[t * 3 + k]!;
      vertexNormal(part, i, na);
      shading.add(na);
      vertex(part, i, va);
      centroid.add(va);
      polygon.push({ p: space.toLocal(va), n: na.clone() });
    }
    if (shading.normalize().dot(space.facing(centroid.divideScalar(3))) < minCos) continue;
    // A triangle across the seam behind a wrapping print is not on it.
    const xs = polygon.map(v => v.p.x);
    if (Math.max(...xs) - Math.min(...xs) > wrapLimit) continue;
    polygon = clip(polygon, 'x', hw, 1);
    polygon = clip(polygon, 'x', hw, -1);
    polygon = clip(polygon, 'y', hh, 1);
    polygon = clip(polygon, 'y', hh, -1);
    polygon = clip(polygon, 'z', hd, 1);
    polygon = clip(polygon, 'z', hd, -1);
    if (polygon.length < 3) continue;
    triangles.add(triRef(refPart(ref), t));

    for (let k = 1; k < polygon.length - 1; k++) {
      const tri = [polygon[0]!, polygon[k]!, polygon[k + 1]!];
      const scene = tri.map(v => space.toScene(v.p));
      const uv = tri.map(v => [v.p.x / box.width + 0.5, v.p.y / box.height + 0.5] as const);
      const uvArea = Math.abs((uv[1]![0] - uv[0]![0]) * (uv[2]![1] - uv[0]![1]) - (uv[2]![0] - uv[0]![0]) * (uv[1]![1] - uv[0]![1])) / 2;
      const surfaceArea = new THREE.Vector3().subVectors(scene[1]!, scene[0]!).cross(new THREE.Vector3().subVectors(scene[2]!, scene[0]!)).length() / 2;
      if (uvArea > 0) {
        printedArea += uvArea;
        if (surfaceArea / (uvArea * box.width * box.height) > STRETCH_LIMIT) stretchedArea += uvArea;
        rasterize(covered, uv);
      }
      for (let v = 0; v < 3; v++) {
        const scenePoint = scene[v]!.addScaledVector(tri[v]!.n, lift);
        positions.push(scenePoint.x, scenePoint.y, scenePoint.z);
        normals.push(tri[v]!.n.x, tri[v]!.n.y, tri[v]!.n.z);
        uvs.push(uv[v]![0], uv[v]![1]);
      }
    }
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  let coveredCells = 0;
  let countedCells = 0;
  for (let i = 0; i < covered.length; i++) {
    if (box.round && !insideEllipse(i)) continue;
    countedCells++;
    coveredCells += covered[i]!;
  }
  return {
    geometry,
    coverage: countedCells ? coveredCells / countedCells : 0,
    stretchedShare: printedArea > 0 ? Math.min(1, stretchedArea / printedArea) : 0,
    triangles,
  };
}

// Whether coverage cell i (see rasterize) has its centre inside the ellipse
// inscribed in the print rectangle.
function insideEllipse(i: number): boolean {
  const n = COVERAGE_GRID;
  const px = (Math.floor(i / n) + 0.5) / n - 0.5;
  const py = ((i % n) + 0.5) / n - 0.5;
  return px * px + py * py <= 0.25;
}

// Marks the coverage cells whose centre lies inside the uv triangle.
function rasterize(covered: Uint8Array, uv: ReadonlyArray<readonly [number, number]>) {
  const n = COVERAGE_GRID;
  const [a, b, c] = uv as [readonly [number, number], readonly [number, number], readonly [number, number]];
  const x0 = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]) * n));
  const x1 = Math.min(n - 1, Math.ceil(Math.max(a[0], b[0], c[0]) * n));
  const y0 = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]) * n));
  const y1 = Math.min(n - 1, Math.ceil(Math.max(a[1], b[1], c[1]) * n));
  const edge = (p: readonly [number, number], q: readonly [number, number], px: number, py: number) =>
    (q[0] - p[0]) * (py - p[1]) - (q[1] - p[1]) * (px - p[0]);
  const area = edge(a, b, c[0], c[1]);
  if (area === 0) return;
  for (let gx = x0; gx <= x1; gx++) {
    for (let gy = y0; gy <= y1; gy++) {
      const px = (gx + 0.5) / n;
      const py = (gy + 0.5) / n;
      const w0 = edge(b, c, px, py) / area;
      const w1 = edge(c, a, px, py) / area;
      const w2 = edge(a, b, px, py) / area;
      if (w0 >= -1e-9 && w1 >= -1e-9 && w2 >= -1e-9) covered[gx * n + gy] = 1;
    }
  }
}

/** Default view of an area: straight on, far enough to show it whole with
 * a margin, in scene space. */
export function areaCamera(pose: Pose, box: ProjectorBox, fovDeg: number, aspect: number) {
  const tan = Math.tan(THREE.MathUtils.degToRad(fovDeg) / 2);
  const distance = 1.4 * Math.max(box.height / 2 / tan, box.width / 2 / (tan * aspect));
  return {
    position: pose.point.clone().addScaledVector(pose.normal, distance),
    target: pose.point.clone(),
  };
}
