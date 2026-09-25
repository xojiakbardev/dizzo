// 3D bodies built from a shape's millimetre dimensions (cylinder, plane,
// disc), and for each print area a surface patch whose texture maps the
// area's millimetres exactly — the same coordinates the editor and the
// print files use. Units are millimetres (mm_per_unit = 1).
//
// Cylinder: axis Y, the handle points to +X. Around the body the unrolled
// coordinate u runs from the handle: [0, gap] is the unprintable arc, the
// printable arc starts at u = gap (as in the admin's flat drawing). Seen
// from outside, u grows to the viewer's right.
import * as THREE from 'three';
import type { Pose } from '~/lib/three/projector';
import type { CylinderDims, DiscDims, PlaneDims, PrintArea, ShapeKind } from '~/types/catalog';

const LIFT = 0.25; // print patches float this far above the surface (mm)
const HANDLE_ANGLE = Math.PI / 2;

export interface ParametricShape {
  kind: Exclude<ShapeKind, 'model'>;
  dims: Record<string, unknown>;
}

export interface ParametricBody {
  body: THREE.Group; // meshes get the variant's material
  patches: Map<string, THREE.BufferGeometry>; // by area key, uv = area mm
  poses: Map<string, Pose>; // each area's centre, facing out
}

type SizedArea = Pick<PrintArea, 'anchor' | 'width_mm' | 'height_mm'>;

const num = (v: unknown) => Number(v ?? 0) || 0;
const areaAnchor = (area: SizedArea) => area.anchor as Record<string, unknown>;

/** A grid patch: `at(u, v)` gives position and normal for u, v in [0, 1]
 * (v = 0 at the area's top); `keep` can drop cells (disc edge). */
function gridPatch(
  segU: number, segV: number,
  at: (u: number, v: number) => { p: THREE.Vector3; n: THREE.Vector3 },
  keep: (u: number, v: number) => boolean = () => true,
): THREE.BufferGeometry {
  const positions: number[] = [];
  const normals: number[] = [];
  const uvs: number[] = [];
  const push = (u: number, v: number) => {
    const { p, n } = at(u, v);
    positions.push(p.x, p.y, p.z);
    normals.push(n.x, n.y, n.z);
    uvs.push(u, 1 - v); // canvas top (v = 0) maps to texture top
  };
  for (let i = 0; i < segU; i++) {
    for (let j = 0; j < segV; j++) {
      const u0 = i / segU;
      const u1 = (i + 1) / segU;
      const v0 = j / segV;
      const v1 = (j + 1) / segV;
      if (!keep((u0 + u1) / 2, (v0 + v1) / 2)) continue;
      push(u0, v0);
      push(u0, v1);
      push(u1, v0);
      push(u1, v0);
      push(u0, v1);
      push(u1, v1);
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  return geometry;
}

/** Turns a surface inside out: its faces and normals point the other way.
 * A mug's inner wall faces in — so a print projected round the outside
 * never lands on it. */
function facingIn(geometry: THREE.BufferGeometry): THREE.BufferGeometry {
  const normal = geometry.getAttribute('normal');
  for (let i = 0; i < normal.count; i++) normal.setXYZ(i, -normal.getX(i), -normal.getY(i), -normal.getZ(i));
  const index = geometry.getIndex()!;
  for (let i = 0; i < index.count; i += 3) {
    const b = index.getX(i + 1);
    index.setX(i + 1, index.getX(i + 2));
    index.setX(i + 2, b);
  }
  return geometry;
}

function cylinder(dims: CylinderDims, areas: PrintArea[]): ParametricBody {
  const r = num(dims.diameter_mm) / 2;
  const height = num(dims.height_mm);
  const gap = num(dims.handle_gap_mm);
  const wall = Math.min(3, r * 0.08);
  const body = new THREE.Group();
  body.add(new THREE.Mesh(new THREE.CylinderGeometry(r, r, height, 128, 1, true)));
  const inner = new THREE.Mesh(facingIn(new THREE.CylinderGeometry(r - wall, r - wall, height - wall, 128, 1, true)));
  inner.position.y = wall / 2;
  body.add(inner);
  const rim = new THREE.Mesh(new THREE.RingGeometry(r - wall, r, 128));
  rim.rotation.x = -Math.PI / 2;
  rim.position.y = height / 2;
  const bottom = new THREE.Mesh(new THREE.CircleGeometry(r, 128));
  bottom.rotation.x = Math.PI / 2;
  bottom.position.y = -height / 2;
  const floor = new THREE.Mesh(new THREE.CircleGeometry(r - wall, 128));
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = -height / 2 + wall;
  body.add(rim, bottom, floor);
  if (dims.handle) {
    const handle = new THREE.Mesh(new THREE.TorusGeometry(height * 0.3, Math.max(3, r * 0.12), 20, 48, Math.PI));
    handle.geometry.rotateZ(-Math.PI / 2);
    handle.position.set(r - wall, 0, 0);
    body.add(handle);
  }

  const patches = new Map<string, THREE.BufferGeometry>();
  const poses = new Map<string, Pose>();
  for (const area of areas) {
    const a = areaAnchor(area);
    const u0 = gap + num(a.start_mm);
    const w = num(area.width_mm);
    const h = num(area.height_mm);
    const top = height / 2 - num(a.top_mm);
    patches.set(area.key, gridPatch(Math.max(8, Math.ceil(w / 2)), 1, (u, v) => {
      const n = radial(phiAt(dims, u0 + u * w));
      return { p: n.clone().multiplyScalar(r + LIFT).setY(top - v * h), n };
    }));
    poses.set(area.key, cylinderPose(dims, area));
  }
  return { body, patches, poses };
}

const radial = (phi: number) => new THREE.Vector3(Math.sin(phi), 0, Math.cos(phi));
/** The angle round the axis of the unrolled coordinate u (mm from the handle). */
const phiAt = (dims: CylinderDims, u: number) => HANDLE_ANGLE + (u - num(dims.handle_gap_mm) / 2) / (num(dims.diameter_mm) / 2);
const UP = () => new THREE.Vector3(0, 1, 0);

function cylinderPose(dims: CylinderDims, area: SizedArea): Pose {
  const a = areaAnchor(area);
  const n = radial(phiAt(dims, num(dims.handle_gap_mm) + num(a.start_mm) + num(area.width_mm) / 2));
  const y = num(dims.height_mm) / 2 - num(a.top_mm) - num(area.height_mm) / 2;
  return { point: n.clone().multiplyScalar(num(dims.diameter_mm) / 2).setY(y), normal: n, up: UP() };
}

function planePose(dims: PlaneDims, area: SizedArea, thickness: number): Pose {
  const a = areaAnchor(area);
  const back = a.side === 'back';
  const width = num(dims.width_mm);
  const x = num(a.x_mm) + num(area.width_mm) / 2;
  const n = new THREE.Vector3(0, 0, back ? -1 : 1);
  // Seen from behind, the area's left edge is at +x.
  const point = new THREE.Vector3(back ? width / 2 - x : -width / 2 + x, num(dims.height_mm) / 2 - num(a.y_mm) - num(area.height_mm) / 2, (n.z * thickness) / 2);
  return { point, normal: n, up: UP() };
}

function discPose(dims: DiscDims, area: SizedArea, thickness: number): Pose {
  const a = areaAnchor(area);
  const r = num(dims.diameter_mm) / 2;
  const point = new THREE.Vector3(-r + num(a.x_mm) + num(area.width_mm) / 2, r - num(a.y_mm) - num(area.height_mm) / 2, thickness / 2);
  return { point, normal: new THREE.Vector3(0, 0, 1), up: UP() };
}

function plane(dims: PlaneDims, areas: PrintArea[], thickness: number): ParametricBody {
  const width = num(dims.width_mm);
  const height = num(dims.height_mm);
  const body = new THREE.Group();
  body.add(new THREE.Mesh(new THREE.BoxGeometry(width, height, thickness)));
  const patches = new Map<string, THREE.BufferGeometry>();
  const poses = new Map<string, Pose>();
  for (const area of areas) {
    const a = areaAnchor(area);
    const back = a.side === 'back';
    const x0 = num(a.x_mm);
    const y0 = num(a.y_mm);
    const w = num(area.width_mm);
    const h = num(area.height_mm);
    const z = back ? -(thickness / 2 + LIFT) : thickness / 2 + LIFT;
    const n = new THREE.Vector3(0, 0, back ? -1 : 1);
    const xAt = (mm: number) => (back ? width / 2 - mm : -width / 2 + mm);
    patches.set(area.key, gridPatch(1, 1, (u, v) => ({ p: new THREE.Vector3(xAt(x0 + u * w), height / 2 - y0 - v * h, z), n })));
    poses.set(area.key, planePose(dims, area, thickness));
  }
  return { body, patches, poses };
}

function disc(dims: DiscDims, areas: PrintArea[], thickness: number): ParametricBody {
  const r = num(dims.diameter_mm) / 2;
  const body = new THREE.Group();
  const cylinderMesh = new THREE.Mesh(new THREE.CylinderGeometry(r, r, thickness, 128));
  cylinderMesh.geometry.rotateX(Math.PI / 2);
  body.add(cylinderMesh);
  const patches = new Map<string, THREE.BufferGeometry>();
  const poses = new Map<string, Pose>();
  const n = new THREE.Vector3(0, 0, 1);
  for (const area of areas) {
    const a = areaAnchor(area);
    const x0 = num(a.x_mm);
    const y0 = num(a.y_mm);
    const w = num(area.width_mm);
    const h = num(area.height_mm);
    const z = thickness / 2 + LIFT;
    // Area mm are measured on the disc's bounding square; cells outside the circle are dropped.
    const inCircle = (u: number, v: number) => Math.hypot(x0 + u * w - r, y0 + v * h - r) <= r;
    patches.set(area.key, gridPatch(64, 64, (u, v) => ({ p: new THREE.Vector3(-r + x0 + u * w, r - y0 - v * h, z), n }), inCircle));
    poses.set(area.key, discPose(dims, area, thickness));
  }
  return { body, patches, poses };
}

/** Body thickness of flat shapes: thin for paper, a plaque otherwise. */
export function flatThickness(material: string): number {
  return material === 'paper' ? 0.6 : 4;
}

const bodyThickness = (kind: ParametricShape['kind'], material: string) => (kind === 'disc' ? flatThickness(material) * 1.5 : flatThickness(material));

export function buildParametric(shape: ParametricShape, areas: PrintArea[], material: string): ParametricBody {
  if (shape.kind === 'cylinder') return cylinder(shape.dims as unknown as CylinderDims, areas);
  if (shape.kind === 'plane') return plane(shape.dims as unknown as PlaneDims, areas, bodyThickness('plane', material));
  return disc(shape.dims as unknown as DiscDims, areas, bodyThickness('disc', material));
}

/** Where an area sits on the body built with `material`: its centre on
 * the surface, facing out, and the radius its print wraps round (a
 * cylinder's), in mm. */
export function parametricPlacement(shape: ParametricShape, area: SizedArea, material: string): { pose: Pose; wrap: number | null } {
  if (shape.kind === 'cylinder') {
    const dims = shape.dims as unknown as CylinderDims;
    return { pose: cylinderPose(dims, area), wrap: num(dims.diameter_mm) / 2 };
  }
  if (shape.kind === 'plane') return { pose: planePose(shape.dims as unknown as PlaneDims, area, bodyThickness('plane', material)), wrap: null };
  return { pose: discPose(shape.dims as unknown as DiscDims, area, bodyThickness('disc', material)), wrap: null };
}

const clampMm = (v: number, max: number) => Math.min(Math.max(0, v), Math.max(0, max)).toFixed(1);

/** The anchor of an area of this size centred at `pose` (the inverse of
 * parametricPlacement), kept on the shape. */
export function parametricAnchor(shape: ParametricShape, wMm: number, hMm: number, pose: Pose): Record<string, string> {
  const { point, normal } = pose;
  if (shape.kind === 'cylinder') {
    const dims = shape.dims as unknown as CylinderDims;
    const r = num(dims.diameter_mm) / 2;
    const gap = num(dims.handle_gap_mm);
    const round = 2 * Math.PI * r;
    // Unrolled from the handle, once round.
    const u = ((((Math.atan2(point.x, point.z) - HANDLE_ANGLE) * r + gap / 2) % round) + round) % round;
    const height = num(dims.height_mm);
    return { start_mm: clampMm(u - gap - wMm / 2, round - gap - wMm), top_mm: clampMm(height / 2 - point.y - hMm / 2, height - hMm) };
  }
  if (shape.kind === 'plane') {
    const dims = shape.dims as unknown as PlaneDims;
    const width = num(dims.width_mm);
    const height = num(dims.height_mm);
    const back = normal.z < 0 && Number(dims.sides) === 2;
    const x = back ? width / 2 - point.x : point.x + width / 2;
    return { side: back ? 'back' : 'front', x_mm: clampMm(x - wMm / 2, width - wMm), y_mm: clampMm(height / 2 - point.y - hMm / 2, height - hMm) };
  }
  const d = num((shape.dims as unknown as DiscDims).diameter_mm);
  return { x_mm: clampMm(point.x + d / 2 - wMm / 2, d - wMm), y_mm: clampMm(d / 2 - point.y - hMm / 2, d - hMm) };
}

/** A parametric shape's size in mm: across the front, and top to bottom. */
export function parametricSize(shape: ParametricShape): { width: number; height: number } {
  const d = shape.dims;
  if (shape.kind === 'cylinder') return { width: num(d.diameter_mm), height: num(d.height_mm) };
  if (shape.kind === 'plane') return { width: num(d.width_mm), height: num(d.height_mm) };
  return { width: num(d.diameter_mm), height: num(d.diameter_mm) };
}

/** Its dims at a new size (mm); a disc takes the width. */
export function resizedDims(shape: ParametricShape, width: number, height: number): Record<string, unknown> {
  const mm = (v: number) => v.toFixed(1);
  if (shape.kind === 'cylinder') return { ...shape.dims, diameter_mm: mm(width), height_mm: mm(height) };
  if (shape.kind === 'plane') return { ...shape.dims, width_mm: mm(width), height_mm: mm(height) };
  return { ...shape.dims, diameter_mm: mm(width) };
}
