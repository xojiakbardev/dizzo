// A GLB's triangles "baked" into its own scene coordinates, the space every
// model anchor is stored in. Built once per loaded model; the projector,
// normal averaging and placement all read from here instead of walking the
// three.js scene graph, and a uniform grid makes area queries cheap even on
// garments with hundreds of thousands of triangles.
import * as THREE from 'three';

export interface BakedPart {
  mesh: THREE.Mesh;
  positions: Float32Array; // xyz per vertex, scene space
  normals: Float32Array; // unit xyz per vertex, scene space
  index: Uint32Array; // 3 vertex indices per triangle
}

export interface BakedModel {
  parts: BakedPart[];
  partOf: Map<THREE.Mesh, number>;
  box: THREE.Box3;
  triangleCount: number;
  grid: TriangleGrid;
}

// Triangles are referenced as (part << 22 | triangle); 4M triangles per part
// and 1023 parts are far above the upload limits.
const TRI_BITS = 22;
const TRI_MASK = (1 << TRI_BITS) - 1;
export const triRef = (part: number, tri: number) => (part << TRI_BITS) | tri;
export const refPart = (ref: number) => ref >>> TRI_BITS;
export const refTri = (ref: number) => ref & TRI_MASK;

export function bakeModel(scene: THREE.Object3D): BakedModel {
  scene.updateMatrixWorld(true);
  const sceneInverse = scene.matrixWorld.clone().invert();
  const parts: BakedPart[] = [];
  const partOf = new Map<THREE.Mesh, number>();
  const box = new THREE.Box3();
  const toScene = new THREE.Matrix4();
  const normalMatrix = new THREE.Matrix3();
  const v = new THREE.Vector3();

  scene.traverse((object) => {
    const mesh = object as THREE.Mesh;
    if (!mesh.isMesh || !mesh.geometry.attributes.position) return;
    let geometry = mesh.geometry as THREE.BufferGeometry;
    if (!geometry.attributes.normal) {
      geometry = geometry.clone();
      geometry.computeVertexNormals();
    }
    toScene.multiplyMatrices(sceneInverse, mesh.matrixWorld);
    normalMatrix.getNormalMatrix(toScene);

    const pos = geometry.attributes.position as THREE.BufferAttribute;
    const nor = geometry.attributes.normal as THREE.BufferAttribute;
    const positions = new Float32Array(pos.count * 3);
    const normals = new Float32Array(pos.count * 3);
    for (let i = 0; i < pos.count; i++) {
      v.fromBufferAttribute(pos, i).applyMatrix4(toScene).toArray(positions, i * 3);
      box.expandByPoint(v);
      v.fromBufferAttribute(nor, i).applyMatrix3(normalMatrix).normalize().toArray(normals, i * 3);
    }
    const index = geometry.index
      ? Uint32Array.from(geometry.index.array as ArrayLike<number>)
      : Uint32Array.from({ length: pos.count - (pos.count % 3) }, (_, i) => i);
    partOf.set(mesh, parts.length);
    parts.push({ mesh, positions, normals, index });
  });

  const triangleCount = parts.reduce((sum, p) => sum + p.index.length / 3, 0);
  return { parts, partOf, box, triangleCount, grid: buildGrid(parts, box, triangleCount) };
}

export function vertex(part: BakedPart, i: number, out: THREE.Vector3): THREE.Vector3 {
  return out.fromArray(part.positions, i * 3);
}

export function vertexNormal(part: BakedPart, i: number, out: THREE.Vector3): THREE.Vector3 {
  return out.fromArray(part.normals, i * 3);
}

// ── Uniform grid over the model's bounding box ──────────────────────────

export interface TriangleGrid {
  min: THREE.Vector3;
  cell: number;
  dims: [number, number, number];
  cells: Map<number, number[]>;
}

function buildGrid(parts: BakedPart[], box: THREE.Box3, triangleCount: number): TriangleGrid {
  const size = box.getSize(new THREE.Vector3());
  const volume = Math.max(size.x * size.y * size.z, 1e-12);
  // Roughly 8 triangles per cell.
  const cell = Math.max(Math.cbrt((volume * 8) / Math.max(triangleCount, 1)), Math.max(size.x, size.y, size.z) / 256, 1e-9);
  const dims: [number, number, number] = [
    Math.max(1, Math.ceil(size.x / cell)), Math.max(1, Math.ceil(size.y / cell)), Math.max(1, Math.ceil(size.z / cell)),
  ];
  const grid: TriangleGrid = { min: box.min.clone(), cell, dims, cells: new Map() };
  const a = new THREE.Vector3();
  const b = new THREE.Vector3();
  const c = new THREE.Vector3();
  const lo = new THREE.Vector3();
  const hi = new THREE.Vector3();
  parts.forEach((part, p) => {
    for (let t = 0; t < part.index.length / 3; t++) {
      vertex(part, part.index[t * 3]!, a);
      vertex(part, part.index[t * 3 + 1]!, b);
      vertex(part, part.index[t * 3 + 2]!, c);
      lo.copy(a).min(b).min(c);
      hi.copy(a).max(b).max(c);
      forEachCell(grid, lo, hi, (key) => {
        let list = grid.cells.get(key);
        if (!list) grid.cells.set(key, (list = []));
        list.push(triRef(p, t));
      });
    }
  });
  return grid;
}

function forEachCell(grid: TriangleGrid, lo: THREE.Vector3, hi: THREE.Vector3, fn: (key: number) => void) {
  const [nx, ny, nz] = grid.dims;
  const clamp = (v: number, n: number) => Math.min(n - 1, Math.max(0, Math.floor(v)));
  const x0 = clamp((lo.x - grid.min.x) / grid.cell, nx);
  const x1 = clamp((hi.x - grid.min.x) / grid.cell, nx);
  const y0 = clamp((lo.y - grid.min.y) / grid.cell, ny);
  const y1 = clamp((hi.y - grid.min.y) / grid.cell, ny);
  const z0 = clamp((lo.z - grid.min.z) / grid.cell, nz);
  const z1 = clamp((hi.z - grid.min.z) / grid.cell, nz);
  for (let x = x0; x <= x1; x++) {
    for (let y = y0; y <= y1; y++) {
      for (let z = z0; z <= z1; z++) fn((x * ny + y) * nz + z);
    }
  }
}

/** Every triangle whose bounding box may touch the given box (deduplicated). */
export function trianglesNear(model: BakedModel, lo: THREE.Vector3, hi: THREE.Vector3): number[] {
  const seen = new Set<number>();
  forEachCell(model.grid, lo, hi, (key) => {
    const list = model.grid.cells.get(key);
    if (list) for (const ref of list) seen.add(ref);
  });
  return [...seen];
}
