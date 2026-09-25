// A three.js view of a catalog GLB. The loaded scene keeps its own
// coordinates ("model space" — where anchors, cameras and the scale points
// are stored); two wrapper groups only turn it upright, face its front to
// the default camera and fit it into view:
//
//   fit (centre + uniform scale) → orient (up axis, yaw) → model (GLB scene) → decals
import * as THREE from 'three';
import { isLowEndDevice, renderPixelRatio } from '~/lib/device';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import type { BakedModel } from '~/lib/three/bakedModel';
import { bakeModel, vertex, vertexNormal } from '~/lib/three/bakedModel';

export interface ModelOrientation {
  upAxis: 'y' | 'z';
  yawDeg: number;
}

export interface SurfaceHit {
  point: THREE.Vector3; // model space
  normal: THREE.Vector3; // model space, unit, facing the camera
}

export const VIEW_FOV = 35;
const FIT_SIZE = 2;
// The contact shadow: how far past the product's footprint the blot reaches,
// and how dark its middle is. Wider reads as a softer, higher light; too
// wide and captureFitted's 10 % margin clips the rim.
const SHADOW_SPREAD = 1.35;
const SHADOW_STRENGTH = 0.55;

export class ModelViewer {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(VIEW_FOV, 1, 0.01, 100);
  readonly controls: OrbitControls;
  readonly decals = new THREE.Group();
  readonly overlay = new THREE.Group(); // markers etc., in model space
  private readonly fit = new THREE.Group();
  private readonly orient = new THREE.Group();
  private model: THREE.Group | null = null;
  baked: BakedModel | null = null;
  private readonly raycaster = new THREE.Raycaster();
  private readonly environment: THREE.Texture;
  private readonly lights: Record<'key' | 'fill' | 'rim' | 'sky', THREE.DirectionalLight | THREE.HemisphereLight>;
  private readonly backdrop: THREE.Texture;
  private readonly shadow: THREE.Mesh;
  private dirty = true;
  private frameWaiters: Array<() => void> = [];

  constructor(canvas: HTMLCanvasElement) {
    // alpha: the view keeps its backdrop, but a picture can leave it out (transparent PNG).
    // Weak phones: no multisampling and one device pixel per CSS pixel.
    this.renderer = new THREE.WebGLRenderer({
      canvas, antialias: !isLowEndDevice(), preserveDrawingBuffer: true, alpha: true, powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(renderPixelRatio()); // sharper costs a lot on phones
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.NeutralToneMapping;
    this.backdrop = backdrop();
    this.scene.background = this.backdrop;
    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    pmrem.dispose();
    this.scene.environment = this.environment;
    // Less flat room light, a key light from the front-left and a rim from
    // behind (see setLighting for the values per kind of product).
    this.lights = {
      key: new THREE.DirectionalLight('#ffffff', 1),
      fill: new THREE.DirectionalLight('#e3e9ff', 1),
      rim: new THREE.DirectionalLight('#ffffff', 1),
      sky: new THREE.HemisphereLight('#ffffff', '#9aa4b2', 1),
    };
    this.scene.add(this.lights.key, this.lights.fill, this.lights.rim, this.lights.sky);
    this.setLighting('default');
    // A soft contact shadow: a ground plane whose alpha is a radial blot.
    // Without one a product floats in the middle of nothing, which is the
    // single thing that made the catalog's pictures look flat. It is a real
    // shadow map's cheap stand-in (one draw, no second pass, and it works
    // the same on a phone), and it lives beside the model rather than in it,
    // so captureFitted — which measures the model's own vertices — frames
    // the product exactly as it did before.
    this.shadow = new THREE.Mesh(
      new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({
        map: contactShadow(), transparent: true, depthWrite: false, opacity: SHADOW_STRENGTH, toneMapped: false,
      }),
    );
    this.shadow.rotation.x = -Math.PI / 2;
    this.shadow.renderOrder = -1; // under the decals, which are transparent too
    this.shadow.visible = false;
    this.scene.add(this.shadow);
    this.scene.add(this.fit);
    this.fit.add(this.orient);
    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.enableDamping = true;
    this.controls.minDistance = 0.3;
    this.controls.maxDistance = 12;
    // Frames are drawn only when something changed (camera moved, or a
    // caller changed the scene and called requestRender) — an idle view
    // costs nothing, which matters for heavy garments on phones.
    this.renderer.setAnimationLoop(() => {
      const moved = this.controls.update();
      if (!moved && !this.dirty) return;
      this.draw();
    });
  }

  private draw() {
    this.dirty = false;
    this.renderer.render(this.scene, this.camera);
    if (this.frameWaiters.length) this.frameWaiters.splice(0).forEach(done => done());
  }

  requestRender() {
    this.dirty = true;
  }

  /** Resolves once the scene as it is now has been drawn on the canvas
   * (loaders stay up until then, not just until the file is in). */
  nextFrame(): Promise<void> {
    this.requestRender();
    return new Promise(resolve => this.frameWaiters.push(resolve));
  }

  /** Hard goods (ceramic, glass, plastic) look best in a soft room light;
   * fabric needs less of it and a key light more from the side, or white
   * cloth turns into one flat patch and black loses its folds.
   *
   * `luminance` (0 black … 1 white, linear) is how dark the body actually
   * is. The material alone cannot tell: under one rig a black mug comes out
   * a silhouette and a white one clips. A dark body gets more exposure, more
   * rim (its edge is all it has) and a little more bounce; a near-white one
   * gets slightly less of everything so the highlights keep their shape. */
  setLighting(mode: 'default' | 'fabric', luminance = 0.5) {
    const fabric = mode === 'fabric';
    // Linear luminance: #333 is already ~0.03, mid grey ~0.22, #ccc ~0.60.
    const dark = THREE.MathUtils.clamp((0.12 - luminance) / 0.12, 0, 1);
    const light = THREE.MathUtils.clamp((luminance - 0.55) / 0.45, 0, 1);
    this.renderer.toneMappingExposure = 1 + dark * 0.4 - light * 0.1;
    this.scene.environmentIntensity = (fabric ? 0.42 : 0.8) * (1 + dark * 0.3 - light * 0.08);
    this.lights.key.intensity = (fabric ? 2.3 : 1.6) * (1 + dark * 0.2 - light * 0.1);
    this.lights.key.position.set(fabric ? 3.4 : 2.5, fabric ? 3.2 : 4, fabric ? 2 : 3);
    this.lights.fill.intensity = (fabric ? 0.28 : 0.45) * (1 + dark * 0.7);
    this.lights.fill.position.set(-3, 1, 2);
    this.lights.rim.intensity = (fabric ? 1.25 : 0.7) * (1 + dark * 1.1);
    this.lights.rim.position.set(0, 3, -4);
    this.lights.sky.intensity = (fabric ? 0.22 : 0.35) * (1 + dark * 0.4);
    this.requestRender();
  }

  /** Shows the backdrop behind the product, or nothing (the page behind
   * the canvas shows through). Mockup frames always have it. */
  setBackdrop(on: boolean) {
    this.scene.background = on ? this.backdrop : null;
    this.requestRender();
  }

  /** Lays the shadow under the model, as wide as its footprint. The fit
   * group has already centred the oriented box on the origin, so the
   * product's lowest point is half its height below it. */
  private placeShadow() {
    if (!this.baked) {
      this.shadow.visible = false;
      return;
    }
    const size = this.orientedBox().getSize(new THREE.Vector3()).multiplyScalar(this.fit.scale.x);
    const spread = Math.max(size.x, size.z, 1e-3) * SHADOW_SPREAD;
    this.shadow.scale.set(spread, spread, 1);
    this.shadow.position.set(0, -size.y / 2 - spread * 0.003, 0);
    this.shadow.visible = true;
  }

  /** Moves the camera towards the target (factor < 1) or away (> 1). */
  zoomBy(factor: number) {
    const offset = this.camera.position.clone().sub(this.controls.target).multiplyScalar(factor);
    offset.setLength(THREE.MathUtils.clamp(offset.length(), this.controls.minDistance, this.controls.maxDistance));
    this.camera.position.copy(this.controls.target).add(offset);
    this.controls.update();
    this.requestRender();
  }

  setModel(scene: THREE.Group, orientation: ModelOrientation) {
    if (this.model) {
      this.model.remove(this.decals, this.overlay);
      this.orient.remove(this.model);
      disposeTree(this.model);
    }
    // Model space is this identity wrapper: whatever transform the GLB's
    // own root carries is part of the model, same as in bakeModel.
    const space = new THREE.Group();
    space.add(scene);
    this.baked = bakeModel(space);
    space.add(this.decals, this.overlay);
    this.model = space;
    this.orient.add(space);
    this.setOrientation(orientation);
  }

  setOrientation({ upAxis, yawDeg }: ModelOrientation) {
    // Z-up models: turn +Z onto +Y. Then turn around the vertical axis.
    const upright = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), upAxis === 'z' ? -Math.PI / 2 : 0);
    const yaw = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), THREE.MathUtils.degToRad(yawDeg));
    this.orient.quaternion.copy(yaw.multiply(upright));
    this.fit.position.set(0, 0, 0);
    this.fit.scale.setScalar(1);
    this.fit.updateMatrixWorld(true);
    if (!this.baked) {
      this.shadow.visible = false;
      return;
    }
    const box = this.orientedBox();
    const scale = FIT_SIZE / Math.max(...box.getSize(new THREE.Vector3()).toArray(), 1e-9);
    this.fit.scale.setScalar(scale);
    this.fit.position.copy(box.getCenter(new THREE.Vector3()).multiplyScalar(-scale));
    this.fit.updateMatrixWorld(true);
    this.placeShadow();
    this.frameAll();
  }

  /** The model's bounding box after orientation, in model units. */
  orientedBox(): THREE.Box3 {
    const box = new THREE.Box3();
    if (!this.baked) return box;
    const m = new THREE.Matrix4().makeRotationFromQuaternion(this.orient.quaternion);
    return box.copy(this.baked.box).applyMatrix4(m);
  }

  /** The model-space direction that points up / towards the default camera. */
  modelUp(): THREE.Vector3 {
    return new THREE.Vector3(0, 1, 0).applyQuaternion(this.orient.quaternion.clone().invert());
  }

  modelForward(): THREE.Vector3 {
    return new THREE.Vector3(0, 0, 1).applyQuaternion(this.orient.quaternion.clone().invert());
  }

  toWorld(point: THREE.Vector3): THREE.Vector3 {
    return this.model ? this.model.localToWorld(point.clone()) : point.clone();
  }

  toModel(point: THREE.Vector3): THREE.Vector3 {
    return this.model ? this.model.worldToLocal(point.clone()) : point.clone();
  }

  /** World units per model unit (the fit scale). */
  worldPerUnit(): number {
    return this.fit.scale.x;
  }

  frameAll() {
    this.viewFrom(0);
  }

  /** The whole model from one side: 0° its front, 90° its left (the
   * wearer's), 180° its back, -90° its right. */
  viewFrom(azimuthDeg: number) {
    const a = THREE.MathUtils.degToRad(azimuthDeg);
    this.camera.up.set(0, 1, 0);
    this.controls.target.set(0, 0, 0);
    this.camera.position.set(Math.sin(a) * 4.2, 0.35, Math.cos(a) * 4.2);
    this.controls.update();
    this.requestRender();
  }

  /** Moves the camera to a model-space view, with `up` as screen-up. */
  view(position: THREE.Vector3, target: THREE.Vector3, up: THREE.Vector3) {
    const worldTarget = this.toWorld(target);
    this.camera.position.copy(this.toWorld(position));
    const worldUp = up.clone().applyQuaternion(this.orient.quaternion).normalize();
    this.camera.up.copy(worldUp);
    this.controls.target.copy(worldTarget);
    this.camera.lookAt(worldTarget);
    this.controls.update();
    this.requestRender();
  }

  currentView(): { position: THREE.Vector3; target: THREE.Vector3 } {
    return { position: this.toModel(this.camera.position), target: this.toModel(this.controls.target) };
  }

  /** Keeps the camera exactly as it is; the returned function puts it back.
   * A run of captures walks the camera round the product, and the customer
   * must find their own view where they left it. */
  holdView(): () => void {
    const position = this.camera.position.clone();
    const up = this.camera.up.clone();
    const target = this.controls.target.clone();
    return () => {
      this.camera.position.copy(position);
      this.camera.up.copy(up);
      this.controls.target.copy(target);
      this.camera.lookAt(target);
      this.controls.update();
      this.requestRender();
    };
  }

  /** The surface point under a screen position (model space), with the
   * smooth normal interpolated from the model's vertex normals. */
  pick(clientX: number, clientY: number): SurfaceHit | null {
    if (!this.model || !this.baked) return null;
    const rect = this.renderer.domElement.getBoundingClientRect();
    const ndc = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const meshes = this.baked.parts.map(p => p.mesh);
    const hit = this.raycaster.intersectObjects(meshes, false)[0];
    if (!hit || hit.faceIndex == null) return null;
    const part = this.baked.parts[this.baked.partOf.get(hit.object as THREE.Mesh)!]!;
    const t = hit.faceIndex;
    const ids = [part.index[t * 3]!, part.index[t * 3 + 1]!, part.index[t * 3 + 2]!];
    const [a, b, c] = ids.map(i => vertex(part, i, new THREE.Vector3())) as [THREE.Vector3, THREE.Vector3, THREE.Vector3];
    const point = this.toModel(hit.point);
    const bary = THREE.Triangle.getBarycoord(point, a, b, c, new THREE.Vector3()) ?? new THREE.Vector3(1 / 3, 1 / 3, 1 / 3);
    const [na, nb, nc] = ids.map(i => vertexNormal(part, i, new THREE.Vector3())) as [THREE.Vector3, THREE.Vector3, THREE.Vector3];
    const normal = na.multiplyScalar(bary.x).addScaledVector(nb, bary.y).addScaledVector(nc, bary.z).normalize();
    const towardsCamera = this.toModel(this.camera.position).sub(point);
    if (normal.dot(towardsCamera) < 0) normal.negate();
    return { point, normal };
  }

  /** Call from a ResizeObserver: the new size is drawn at once, in the
   * same frame as the layout change (resizing clears the canvas, and a
   * frame later the old picture would show stretched or blank).
   * `reframe` moves the camera for the new shape before that drawing. */
  resize(width: number, height: number, reframe?: () => void) {
    const now = this.renderer.getSize(new THREE.Vector2());
    if (now.x === width && now.y === height) return;
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / Math.max(height, 1);
    this.camera.updateProjectionMatrix();
    reframe?.();
    if (width && height) {
      this.controls.update();
      this.draw();
    }
  }

  snapshot(): string {
    this.renderer.render(this.scene, this.camera);
    return this.renderer.domElement.toDataURL('image/png');
  }

  /** A square picture of the product as it is seen now — the same side and
   * the same way up — centred and as large as fits with `marginPx` left
   * around it. Catalog cutouts pass `transparent`; Studio downloads keep the
   * same grey backdrop as the multi-view set. Every visible mesh counts. */
  captureFitted(size: number, marginPx: number, { transparent = true }: { transparent?: boolean } = {}): string | null {
    if (!this.model) return null;
    const dir = this.camera.position.clone().sub(this.controls.target).normalize(); // towards the camera
    const right = new THREE.Vector3().crossVectors(this.camera.up, dir).normalize();
    const up = new THREE.Vector3().crossVectors(dir, right).normalize();
    const points: THREE.Vector3[] = [];
    this.model.updateMatrixWorld(true);
    this.model.traverseVisible((object) => {
      const mesh = object as THREE.Mesh;
      const position = mesh.isMesh ? mesh.geometry.getAttribute('position') : null;
      if (!position) return;
      const step = Math.max(1, Math.floor(position.count / 20000));
      for (let i = 0; i < position.count; i += step) points.push(new THREE.Vector3().fromBufferAttribute(position, i).applyMatrix4(mesh.matrixWorld));
    });
    if (!points.length) return null;
    // Centre: the middle of the product across the view.
    const origin = new THREE.Box3().setFromPoints(points).getCenter(new THREE.Vector3());
    let [x0, x1, y0, y1] = [Infinity, -Infinity, Infinity, -Infinity];
    for (const p of points) {
      const q = p.clone().sub(origin);
      const [x, y] = [q.dot(right), q.dot(up)];
      [x0, x1, y0, y1] = [Math.min(x0, x), Math.max(x1, x), Math.min(y0, y), Math.max(y1, y)];
    }
    const centre = origin.addScaledVector(right, (x0 + x1) / 2).addScaledVector(up, (y0 + y1) / 2);
    // Distance: the nearest one that keeps every point inside the margin.
    const tan = Math.tan(THREE.MathUtils.degToRad(VIEW_FOV) / 2) * (1 - (2 * marginPx) / size);
    let distance = 0;
    for (const p of points) {
      const q = p.clone().sub(centre);
      distance = Math.max(distance, q.dot(dir) + Math.max(Math.abs(q.dot(right)), Math.abs(q.dot(up))) / tan);
    }
    // capture() takes model-space views.
    const modelUp = up.clone().applyQuaternion(this.orient.quaternion.clone().invert());
    const [frame] = this.capture([{
      position: this.toModel(centre.clone().addScaledVector(dir, distance)),
      target: this.toModel(centre),
      up: modelUp,
    }], size, { transparent });
    return frame ?? null;
  }

  /** Square frames from the given model-space views — JPEG on the backdrop,
   * or with `transparent` a PNG with nothing behind the product; the
   * on-screen view is restored afterwards. */
  capture(
    views: Array<{ position: THREE.Vector3; target: THREE.Vector3; up: THREE.Vector3 }>, size: number,
    { transparent = false }: { transparent?: boolean } = {},
  ): string[] {
    const background = this.scene.background;
    this.scene.background = transparent ? null : this.backdrop;
    if (transparent) this.renderer.setClearColor(0x000000, 0);
    const saved = {
      size: this.renderer.getSize(new THREE.Vector2()),
      ratio: this.renderer.getPixelRatio(),
      aspect: this.camera.aspect,
      position: this.camera.position.clone(),
      up: this.camera.up.clone(),
      target: this.controls.target.clone(),
    };
    this.renderer.setPixelRatio(1);
    this.renderer.setSize(size, size, false);
    this.camera.aspect = 1;
    this.camera.updateProjectionMatrix();
    const frames = views.map((v) => {
      this.view(v.position, v.target, v.up);
      this.renderer.render(this.scene, this.camera);
      return transparent ? this.renderer.domElement.toDataURL('image/png') : this.renderer.domElement.toDataURL('image/jpeg', 0.9);
    });
    this.scene.background = background;
    this.renderer.setPixelRatio(saved.ratio);
    this.renderer.setSize(saved.size.x, saved.size.y, false);
    this.camera.aspect = saved.aspect;
    this.camera.updateProjectionMatrix();
    this.camera.position.copy(saved.position);
    this.camera.up.copy(saved.up);
    this.controls.target.copy(saved.target);
    this.camera.lookAt(saved.target);
    this.controls.update();
    this.requestRender();
    return frames;
  }

  dispose() {
    this.frameWaiters.splice(0).forEach(done => done());
    this.renderer.setAnimationLoop(null);
    this.controls.dispose();
    disposeTree(this.scene);
    this.environment.dispose();
    this.backdrop.dispose();
    this.renderer.dispose();
  }
}

/** A soft grey-blue backdrop, lighter in the middle: white and black
 * products both stand out from it (it is in the mockup frames too). */
function backdrop(): THREE.Texture {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext('2d')!;
  const gradient = ctx.createRadialGradient(256, 230, 30, 256, 256, 400);
  gradient.addColorStop(0, '#e9edf2');
  gradient.addColorStop(0.6, '#d3d9e1');
  gradient.addColorStop(1, '#b9c1cc');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 512, 512);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** The contact shadow's blot: black and nearly solid where the product meets
 * the ground, gone well before the rim. A plain linear fade reads as fog; a
 * real soft shadow is tight in the middle and long in the tail. */
function contactShadow(): THREE.Texture {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 256;
  const ctx = canvas.getContext('2d')!;
  const gradient = ctx.createRadialGradient(128, 128, 0, 128, 128, 128);
  gradient.addColorStop(0, 'rgba(0,0,0,0.9)');
  gradient.addColorStop(0.3, 'rgba(0,0,0,0.44)');
  gradient.addColorStop(0.6, 'rgba(0,0,0,0.1)');
  gradient.addColorStop(0.85, 'rgba(0,0,0,0.015)');
  gradient.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 256, 256);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** Frees the GPU resources of every mesh under `root`. Geometries shared
 * with the model cache are simply re-uploaded if that model shows again. */
function disposeTree(root: THREE.Object3D) {
  root.traverse((object) => {
    const mesh = object as THREE.Mesh;
    if (!mesh.isMesh) return;
    mesh.geometry.dispose();
    const materials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    materials.forEach((m) => {
      (m as THREE.MeshBasicMaterial).map?.dispose();
      m.dispose();
    });
  });
}
