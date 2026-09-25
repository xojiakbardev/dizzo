// The Studio's 3D view of a product: the variant's body (parametric or
// GLB) in its material and colour, with every print area's design as a
// texture on a patch that maps the area's millimetres exactly. Mockup
// frames for the cart are taken from here too.
import * as THREE from 'three';
import { isLowEndDevice } from '~/lib/device';
import { bodyMaterial, printMaterial } from '~/lib/three/materials';
import { loadModel } from '~/lib/three/modelLoader';
import { ModelViewer, VIEW_FOV } from '~/lib/three/modelViewer';
import { buildParametric } from '~/lib/three/parametric';
import type { Pose, ProjectorBox } from '~/lib/three/projector';
import { areaCamera, projectDecal } from '~/lib/three/projector';
import type { Material, PublicShape } from '~/types/catalog';
import { isPlacedModelAnchor } from '~/types/catalog';

interface Patch {
  key: string;
  mesh: THREE.Mesh;
  texture: THREE.CanvasTexture | null;
  pose: Pose;
  box: ProjectorBox; // model units
}

export class StudioScene {
  readonly viewer: ModelViewer;
  private shape: PublicShape | null = null;
  private material: Material = 'ceramic_glossy';
  private patches = new Map<string, Patch>();
  private bodyMeshes: THREE.Mesh[] = [];
  private body: THREE.Object3D | null = null;
  private loadToken = 0;
  private whiteUnderbase = true;
  private currentHex = '#ffffff';

  setWhiteUnderbase(val: boolean) {
    if (this.whiteUnderbase === val) return;
    this.whiteUnderbase = val;
    for (const patch of this.patches.values()) {
      if (patch.texture) this.applyTexture(patch, patch.texture);
    }
    this.viewer.requestRender();
  }

  constructor(canvas: HTMLCanvasElement) {
    this.viewer = new ModelViewer(canvas);
    // The preview sits in a scrolling column: the wheel scrolls the page;
    // the product is turned by dragging.
    this.viewer.controls.enableZoom = false;
  }

  /** Builds the body and the area patches. Resolves false if another
   * setShape started meanwhile (the result is dropped). */
  /** `hex` null: a model keeps its own colours (admin pictures). */
  async setShape(shape: PublicShape, material: Material, hex: string | null): Promise<boolean> {
    const token = ++this.loadToken;
    const mmPerUnit = shape.kind === 'model' ? Number(shape.mm_per_unit) : 1;
    let body: THREE.Group;
    let parametricPatches: Map<string, THREE.BufferGeometry> | null = null;
    let poses = new Map<string, Pose>();
    if (shape.kind === 'model') {
      body = await loadModel(shape.model_url!);
      if (token !== this.loadToken) return false;
    }
    else {
      const built = buildParametric({ kind: shape.kind, dims: shape.dims as Record<string, unknown> }, shape.areas, material);
      body = built.body;
      parametricPatches = built.patches;
      poses = built.poses;
    }
    this.clearPatches();
    this.shape = shape;
    this.material = material;
    this.bodyMeshes = [];
    this.body = body;
    body.traverse((o) => {
      const mesh = o as THREE.Mesh;
      if (!mesh.isMesh) return;
      // GLB materials are shared by every copy of the model: tint a clone.
      mesh.material = Array.isArray(mesh.material) ? mesh.material.map(m => m.clone()) : mesh.material.clone();
      this.bodyMeshes.push(mesh);
    });
    const t = shape.model_transform;
    this.viewer.setModel(body, shape.kind === 'model' && t ? { upAxis: t.up_axis, yawDeg: t.yaw_deg } : { upAxis: 'y', yawDeg: 0 });
    if (hex !== null || shape.kind !== 'model') {
      this.setAppearance(material, hex ?? '#ffffff');
    }
    else {
      // The model keeps its own baked colours; the rig still has to suit them.
      this.material = material;
      this.tuneLighting();
    }

    for (const area of shape.areas) {
      const box: ProjectorBox = {
        width: Number(area.width_mm) / mmPerUnit, height: Number(area.height_mm) / mmPerUnit, depth: 1, maxAngleDeg: 70,
      };
      let geometry: THREE.BufferGeometry;
      let pose: Pose;
      if (shape.kind === 'model') {
        if (!isPlacedModelAnchor(area.anchor)) continue;
        const a = area.anchor;
        pose = { point: new THREE.Vector3(...a.point), normal: new THREE.Vector3(...a.normal), up: new THREE.Vector3(...a.up) };
        box.depth = Number(a.depth_mm) / mmPerUnit;
        box.maxAngleDeg = a.max_angle_deg;
        box.wrapRadius = a.wrap_radius_mm ? Number(a.wrap_radius_mm) / mmPerUnit : null;
        box.round = a.round === true;
        geometry = projectDecal(this.viewer.baked!, pose, box).geometry;
      }
      else {
        geometry = parametricPatches!.get(area.key)!;
        pose = poses.get(area.key)!;
      }
      const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ visible: false }));
      mesh.renderOrder = 1;
      this.viewer.decals.add(mesh);
      this.patches.set(area.key, { key: area.key, mesh, texture: null, pose, box });
    }
    this.viewer.requestRender();
    return true;
  }

  setAppearance(material: Material, hex: string) {
    this.material = material;
    this.currentHex = hex;
    if (this.shape?.kind === 'model') {
      // Keep the model's own maps (fabric weave etc.); only the colour
      // changes. A model whose materials name some parts "tint…" (a mug's
      // inside and handle, a clock's frame) takes the colour on those parts
      // only; any other model takes it everywhere.
      const all = this.bodyMeshes.flatMap(mesh => (Array.isArray(mesh.material) ? mesh.material : [mesh.material]));
      const tinted = all.filter(m => m.name.toLowerCase().startsWith('tint'));
      const colour = material === 'fabric' ? clothColour(hex) : new THREE.Color(hex);
      (tinted.length ? tinted : all).forEach((m) => {
        const standard = m as THREE.MeshStandardMaterial;
        standard.color?.copy(colour);
        standard.userData.trueHex = hex.toLowerCase();
        if (material === 'fabric' && 'roughness' in standard) standard.roughness = 0.88;
      });
    }
    else {
      for (const mesh of this.bodyMeshes) {
        (Array.isArray(mesh.material) ? mesh.material : [mesh.material]).forEach(m => m.dispose());
        const mat = bodyMaterial(material, hex);
        mat.userData.trueHex = hex.toLowerCase();
        mesh.material = mat;
      }
    }
    for (const patch of this.patches.values()) {
      if (patch.texture) this.applyTexture(patch, patch.texture);
    }
    this.tuneLighting();
    this.viewer.requestRender();
  }

  /** Lights the body for how dark it really is, not only for its material:
   * two presets keyed off "fabric" gave a black mug and a white mug the very
   * same rig, and the black one came out a silhouette. */
  private tuneLighting() {
    this.viewer.setLighting(this.material === 'fabric' ? 'fabric' : 'default', this.bodyLuminance());
  }

  /** Mean lightness of what the customer is looking at (0 black, 1 white).
   * The printed surfaces come first — a mug tinted only on the inside is a
   * white mug — and before the patches exist (the first paint of a shape)
   * the body's own materials stand in. */
  private bodyLuminance(): number {
    const surfaces = Object.values(this.surfaceColors());
    const colours = surfaces.length
      ? surfaces.map(hex => new THREE.Color(hex))
      : this.bodyMeshes
          .flatMap(mesh => (Array.isArray(mesh.material) ? mesh.material : [mesh.material]))
          .map(m => (m as THREE.MeshStandardMaterial).color)
          .filter(Boolean);
    if (!colours.length) return 0.5;
    return colours.reduce((sum, c) => sum + 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, 0) / colours.length;
  }

  /** The colour of the surface each area of a GLB is printed on, by area
   * key: the chosen colour where the model tints it (a soft-touch mug),
   * the model's own elsewhere (an inside-coloured mug's white outside, a
   * clock's white dial). Sampled with rays at nine points of the area;
   * see-through parts (a clock's glass) are looked through, and the most
   * common colour wins (a clock's hands cross the dial). */
  surfaceColors(): Record<string, string> {
    const out: Record<string, string> = {};
    if (this.shape?.kind !== 'model' || !this.body) return out;
    this.body.updateMatrixWorld(true);
    const ray = new THREE.Raycaster();
    const materialOf = (hit: THREE.Intersection) => {
      const m = (hit.object as THREE.Mesh).material;
      return (Array.isArray(m) ? m[hit.face?.materialIndex ?? 0] : m) as THREE.MeshStandardMaterial;
    };
    for (const [key, { pose, box }] of this.patches) {
      const right = new THREE.Vector3().crossVectors(pose.up, pose.normal).normalize();
      const reach = Math.max(box.width, box.height);
      const counts = new Map<string, number>();
      for (const fx of [-0.3, 0, 0.3]) {
        for (const fy of [-0.3, 0, 0.3]) {
          let normal = pose.normal.clone();
          let point: THREE.Vector3;
          if (box.wrapRadius) {
            const angle = (fx * box.width) / box.wrapRadius;
            normal = pose.normal.clone().multiplyScalar(Math.cos(angle)).addScaledVector(right, Math.sin(angle));
            point = pose.point.clone().addScaledVector(pose.normal, -box.wrapRadius).addScaledVector(normal, box.wrapRadius);
          }
          else {
            point = pose.point.clone().addScaledVector(right, fx * box.width);
          }
          point.addScaledVector(pose.up, fy * box.height);
          const from = this.body.localToWorld(point.clone().addScaledVector(normal, reach));
          const to = this.body.localToWorld(point.clone().addScaledVector(normal, -reach));
          ray.set(from, to.sub(from).normalize());
          const hit = ray.intersectObjects(this.bodyMeshes, false)
            .find(h => !(materialOf(h).transparent && materialOf(h).opacity < 0.5));
          const hitMat = hit ? materialOf(hit) : null;
          if (!hitMat) continue;
          const hex = hitMat.userData?.trueHex || (hitMat.color ? `#${hitMat.color.getHexString()}` : null);
          if (!hex) continue;
          counts.set(hex.toLowerCase(), (counts.get(hex.toLowerCase()) ?? 0) + 1);
        }
      }
      const best = [...counts].sort((a, b) => b[1] - a[1])[0];
      if (best) out[key] = best[0];
    }
    return out;
  }

  /** Where a screen point lands on the areas: the area and the point in its
   * millimetres (top-left origin), or null when it misses them or another
   * part of the product is in front. `only` restricts it to one area (while
   * dragging, the pointer may slide past a handle or the rim). */
  pickArea(clientX: number, clientY: number, only?: string): { key: string; x: number; y: number } | null {
    if (!this.shape) return null;
    const rect = this.viewer.renderer.domElement.getBoundingClientRect();
    const ndc = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    const ray = new THREE.Raycaster();
    ray.setFromCamera(ndc, this.viewer.camera);
    const entries = [...this.patches].filter(([key]) => !only || key === only);
    const hit = ray.intersectObjects(entries.map(([, p]) => p.mesh), false)[0];
    if (!hit?.uv) return null;
    if (!only) {
      const front = ray.intersectObjects(this.bodyMeshes, false).find((h) => {
        const m = (h.object as THREE.Mesh).material;
        const mat = (Array.isArray(m) ? m[h.face?.materialIndex ?? 0] : m) as THREE.MeshStandardMaterial;
        return !(mat.transparent && mat.opacity < 0.5);
      });
      // The patch floats a hair above the surface it lies on.
      if (front && front.distance < hit.distance - 0.01 * hit.distance) return null;
    }
    const entry = entries.find(([, p]) => p.mesh === hit.object);
    const area = entry && this.shape.areas.find(a => a.key === entry[0]);
    if (!entry || !area) return null;
    const flipY = entry[1].texture?.flipY ?? true;
    return {
      key: entry[0],
      x: hit.uv.x * Number(area.width_mm),
      y: (flipY ? 1 - hit.uv.y : hit.uv.y) * Number(area.height_mm),
    };
  }

  /** Screen pixels per millimetre of an area around its centre, as seen now. */
  screenPxPerMm(key: string): number | null {
    const patch = this.patches.get(key);
    if (!patch || !this.shape) return null;
    const mmPerUnit = this.shape.kind === 'model' ? Number(this.shape.mm_per_unit) : 1;
    const right = new THREE.Vector3().crossVectors(patch.pose.up, patch.pose.normal).normalize();
    const size = this.viewer.renderer.getSize(new THREE.Vector2());
    const toScreen = (p: THREE.Vector3) => {
      const v = patch.mesh.localToWorld(p.clone()).project(this.viewer.camera);
      return new THREE.Vector2((v.x * size.x) / 2, (v.y * size.y) / 2);
    };
    const a = toScreen(patch.pose.point);
    // Measured on the texture itself: two screen points either side of the
    // centre, and how many of the area's millimetres lie between them.
    const rect = this.viewer.renderer.domElement.getBoundingClientRect();
    const cx = rect.left + rect.width / 2 + a.x;
    const cy = rect.top + rect.height / 2 - a.y;
    const l = this.pickArea(cx - 20, cy, key);
    const r = this.pickArea(cx + 20, cy, key);
    const mm = l && r ? Math.hypot(l.x - r.x, l.y - r.y) : 0;
    if (mm > 0.01) return 40 / mm;
    const b = toScreen(patch.pose.point.clone().addScaledVector(right, 10 / mmPerUnit));
    const px = a.distanceTo(b) / 10;
    return px > 0 ? px : null;
  }

  /** The product as seen now, centred in a square picture with a margin. */
  captureFitted(size = 1600, marginPx = 160, opts?: { transparent?: boolean }): string | null {
    return this.viewer.captureFitted(size, marginPx, opts);
  }

  /** Stops (or lets) the mouse turn the product: off while dragging a layer. */
  setTurning(on: boolean) {
    this.viewer.controls.enabled = on;
  }

  /** Shows a rendered area (transparent canvas of the area's size) on its patch. */
  setAreaTexture(key: string, canvas: HTMLCanvasElement) {
    const patch = this.patches.get(key);
    if (!patch) return;
    if (patch.texture && patch.texture.image === canvas) {
      patch.texture.needsUpdate = true;
    }
    else {
      patch.texture?.dispose();
      const texture = new THREE.CanvasTexture(canvas);
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.anisotropy = isLowEndDevice() ? 2 : 8;
      this.applyTexture(patch, texture);
    }
    this.viewer.requestRender();
  }

  private applyTexture(patch: Patch, texture: THREE.CanvasTexture) {
    (patch.mesh.material as THREE.Material).dispose();
    patch.texture = texture;
    const surface = this.surfaceColors()[patch.key] || this.currentHex;
    patch.mesh.material = printMaterial(this.material, texture, surface, this.whiteUnderbase);
  }

  private areaView(key: string, aspect: number) {
    const patch = this.patches.get(key);
    const area = this.shape?.areas.find(a => a.key === key);
    if (!patch || !area) return null;
    if (area.camera) {
      return { position: new THREE.Vector3(...area.camera.position), target: new THREE.Vector3(...area.camera.target), up: patch.pose.up };
    }
    return { ...areaCamera(patch.pose, patch.box, VIEW_FOV, aspect), up: patch.pose.up };
  }

  /** The direction the area faces, flattened a little towards level. */
  private areaDir(key: string): THREE.Vector3 | null {
    const patch = this.patches.get(key);
    if (!patch) return null;
    const up = this.viewer.modelUp();
    return patch.pose.normal.clone().addScaledVector(up, -0.5 * patch.pose.normal.dot(up)).normalize();
  }

  /** The whole product seen along `dir` (model space), as large as a view
   * of this aspect allows: the box's extent across the view decides the
   * distance. */
  private framing(dir: THREE.Vector3, aspect: number) {
    const box = this.viewer.baked!.box;
    const centre = box.getCenter(new THREE.Vector3());
    const half = box.getSize(new THREE.Vector3()).multiplyScalar(0.5);
    const up = this.viewer.modelUp();
    const right = new THREE.Vector3().crossVectors(up, dir).normalize();
    const screenUp = new THREE.Vector3().crossVectors(dir, right).normalize();
    const extent = (axis: THREE.Vector3) => Math.abs(axis.x) * half.x + Math.abs(axis.y) * half.y + Math.abs(axis.z) * half.z;
    const vFov = THREE.MathUtils.degToRad(VIEW_FOV);
    const hFov = 2 * Math.atan(Math.tan(vFov / 2) * aspect);
    const distance = Math.max(extent(screenUp) / Math.tan(vFov / 2), extent(right) / Math.tan(hFov / 2)) * 1.15 + extent(dir);
    return { position: centre.clone().addScaledVector(dir, distance), target: centre, up };
  }

  /** The whole product, seen from the side the area faces. */
  viewArea(key: string) {
    const dir = this.areaDir(key);
    if (!dir || !this.viewer.baked) return;
    const v = this.framing(dir, this.viewer.camera.aspect);
    this.viewer.view(v.position, v.target, v.up);
    this.baseDistance = this.viewDistance();
  }

  /** Up to four ways to look at the product: each area from the side it
   * faces, then the first one turned a quarter, half and three quarters. */
  presets(): Array<{ area: string | null; dir: THREE.Vector3 }> {
    if (!this.shape || !this.viewer.baked) return [];
    const up = this.viewer.modelUp();
    const out: Array<{ area: string | null; dir: THREE.Vector3 }> = [];
    for (const a of this.shape.areas) {
      const dir = this.areaDir(a.key);
      if (dir && out.length < 4 && !out.some(p => p.dir.dot(dir) > 0.95)) out.push({ area: a.key, dir });
    }
    const first = out[0]?.dir ?? this.viewer.modelForward();
    for (const turn of [0, 0.5, 1, 1.5]) {
      if (out.length >= 4) break;
      const dir = first.clone().applyAxisAngle(up, turn * Math.PI).normalize();
      if (!out.some(p => p.dir.dot(dir) > 0.95)) out.push({ area: null, dir });
    }
    return out;
  }

  /** A three-quarter view of the whole product from the area's side (or its
   * front), slightly from above — square, for pictures. */
  sideViews(areaKey: string | null) {
    const up = this.viewer.modelUp();
    const base = (areaKey && this.areaDir(areaKey)) || this.viewer.modelForward();
    const dir = base.clone().applyAxisAngle(up, THREE.MathUtils.degToRad(38)).addScaledVector(up, 0.28).normalize();
    return [this.framing(dir, 1)];
  }

  /** Square pictures of the presets (JPEG data URLs); `only` picks one. */
  presetThumbnails(size = 160, only?: number): string[] {
    if (!this.viewer.baked) return [];
    const presets = this.presets().filter((_, i) => only === undefined || i === only);
    return this.viewer.capture(presets.map(p => this.framing(p.dir, 1)), size);
  }

  viewPreset(index: number) {
    const preset = this.presets()[index];
    if (!preset || !this.viewer.baked) return;
    const v = this.framing(preset.dir, this.viewer.camera.aspect);
    this.viewer.view(v.position, v.target, v.up);
    this.baseDistance = this.viewDistance();
  }

  /** How far the camera is from what it turns around (world units). */
  viewDistance(): number {
    return this.viewer.camera.position.distanceTo(this.viewer.controls.target);
  }

  /** The distance of the last framing: 100 % zoom. */
  baseDistance = 0;

  /** Called whenever the camera moves (turned, zoomed or framed). */
  onViewChange(listener: () => void) {
    this.viewer.controls.addEventListener('change', listener);
  }

  /** Called when the customer starts turning the model by hand. */
  onUserTurn(listener: () => void) {
    this.viewer.controls.addEventListener('start', listener);
  }

  viewAll() {
    this.viewer.frameAll();
  }

  /** The cart's mockups: five square pictures of the whole product (JPEG
   * data URLs), the first one straight at the first used area. Then every
   * other used area from its front, three-quarter views either side (as
   * sideViews), the back and a view from above. A flat product has nothing
   * on its back: a close-up of the design takes that place. */
  captureFrames(usedAreas: string[], size = 900): string[] {
    const views = this.frameViews(usedAreas);
    return views.length ? this.viewer.capture(views, size) : [];
  }

  /** The same five views, but each one fitted and with nothing behind it
   * (transparent PNGs). This is what the catalog wants: a picture that sits
   * on any background, framed the same way whatever the product's shape,
   * instead of a JPEG glued to the grey backdrop. */
  captureFittedFrames(usedAreas: string[], size = 1600, marginPx = 160): string[] {
    const views = this.frameViews(usedAreas);
    if (!views.length) return [];
    // captureFitted only restores the view it was itself called in, so the
    // camera is put back once, at the end.
    const restore = this.viewer.holdView();
    const frames: string[] = [];
    for (const v of views) {
      this.viewer.view(v.position, v.target, v.up);
      const frame = this.viewer.captureFitted(size, marginPx);
      if (frame) frames.push(frame);
    }
    restore();
    return frames;
  }

  /** Where the mockups are taken from: the first used area straight on, then
   * every other used area from its front, three-quarter views either side,
   * the back and a view from above. */
  private frameViews(usedAreas: string[]) {
    if (!this.shape || !this.viewer.baked) return [];
    const up = this.viewer.modelUp();
    // Straight up or down can't be framed (no screen-right): those areas get the close-up only.
    const level = (dir: THREE.Vector3) => Math.abs(dir.dot(up)) < 0.95;
    const fronts = usedAreas.map(key => this.areaDir(key)).filter((d): d is THREE.Vector3 => d !== null && level(d));
    const base = fronts[0] ?? this.viewer.modelForward();
    const turned = (deg: number, lift: number) =>
      base.clone().applyAxisAngle(up, THREE.MathUtils.degToRad(deg)).addScaledVector(up, lift).normalize();
    const flat = this.shape.kind === 'plane' || this.shape.kind === 'disc';
    const candidates = [
      ...fronts.map(d => d.clone().addScaledVector(up, 0.1).normalize()),
      turned(-38, 0.28),
      turned(38, 0.28),
      ...(flat ? [] : [turned(180, 0.15)]),
      turned(0, 0.65),
    ];
    const dirs: THREE.Vector3[] = [];
    for (const dir of candidates) {
      if (dirs.length < 5 && !dirs.some(d => d.dot(dir) > 0.95)) dirs.push(dir);
    }
    const views = dirs.map(dir => this.framing(dir, 1));
    const closeUp = usedAreas[0] ? this.areaView(usedAreas[0], 1) : null;
    if (closeUp && views.length < 5) views.push(closeUp);
    return views;
  }

  private clearPatches() {
    for (const patch of this.patches.values()) {
      this.viewer.decals.remove(patch.mesh);
      patch.mesh.geometry.dispose();
      (patch.mesh.material as THREE.Material).dispose();
      patch.texture?.dispose();
    }
    this.patches.clear();
  }

  dispose() {
    this.loadToken++;
    this.clearPatches();
    this.viewer.dispose();
  }
}

/** Cloth never reflects all the light (or none of it): the chosen colour
 * kept inside the range real fabric has, so white shows its folds instead
 * of clipping to a flat patch, and black keeps its shape. */
function clothColour(hex: string): THREE.Color {
  const colour = new THREE.Color(hex);
  const lum = 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b;
  const MAX = 0.62;
  const MIN = 0.032;
  if (lum > MAX) colour.multiplyScalar(MAX / lum);
  else if (lum < MIN) colour.lerp(new THREE.Color(MIN, MIN, MIN), 1 - lum / MIN);
  return colour;
}
