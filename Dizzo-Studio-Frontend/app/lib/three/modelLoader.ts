// Loads GLB models for the catalog (admin configurator and Studio).
// Draco- and meshopt-compressed models are supported; the decoder files
// are bundled from `three` so nothing is fetched from a third-party CDN.
import type * as THREE from 'three';
import { DRACOLoader } from 'three/examples/jsm/loaders/DRACOLoader.js';
import type { GLTF } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { i18nT } from '~/lib/i18n';
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js';
import dracoWasmUrl from 'three/examples/jsm/libs/draco/draco_decoder.wasm?url';
import dracoWrapperUrl from 'three/examples/jsm/libs/draco/draco_wasm_wrapper.js?url';

// Must match the backend's "model" upload rules (app/api/v1/media.py).
export const MODEL_MAX_MB = 20;
export const MODEL_MAX_TRIANGLES = 500_000;
export const MODEL_MAX_TEXTURE_PX = 4096;
export const GLB_CONTENT_TYPE = 'model/gltf-binary';

let loader: GLTFLoader | null = null;
const cache = new Map<string, Promise<GLTF>>();

function gltfLoader(): GLTFLoader {
  if (!loader) {
    const draco = new DRACOLoader().setDecoderPath({ js: dracoWrapperUrl, wasm: dracoWasmUrl });
    loader = new GLTFLoader().setDRACOLoader(draco).setMeshoptDecoder(MeshoptDecoder);
    loader.setCrossOrigin('anonymous');
  }
  return loader;
}

/** Loads a model once per URL; every caller gets its own copy of the scene. */
export async function loadModel(url: string): Promise<THREE.Group> {
  let pending = cache.get(url);
  if (!pending) {
    pending = gltfLoader().loadAsync(url);
    cache.set(url, pending);
    pending.catch(() => cache.delete(url));
  }
  return (await pending).scene.clone(true);
}

export interface ModelStats {
  triangles: number;
  meshes: number;
  maxTexturePx: number;
}

export function modelStats(scene: THREE.Object3D): ModelStats {
  let triangles = 0;
  let meshes = 0;
  let maxTexturePx = 0;
  scene.traverse((object) => {
    const mesh = object as THREE.Mesh;
    if (!mesh.isMesh) return;
    meshes++;
    const geometry = mesh.geometry;
    triangles += Math.floor((geometry.index ? geometry.index.count : geometry.attributes.position!.count) / 3);
    const materials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    for (const material of materials) {
      for (const value of Object.values(material)) {
        const texture = value as THREE.Texture | null;
        const image = texture?.isTexture ? (texture.image as { width?: number; height?: number } | null) : null;
        if (image?.width && image.height) maxTexturePx = Math.max(maxTexturePx, image.width, image.height);
      }
    }
  });
  return { triangles, meshes, maxTexturePx };
}

/** Parses a GLB picked by the admin and checks it against the upload rules.
 * Returns the problem in the page's language, or the stats when it is fine. */
export async function inspectGlbFile(file: File): Promise<{ error: string } | { stats: ModelStats }> {
  if (file.size > MODEL_MAX_MB * 1024 * 1024) return { error: i18nT('studio.model.tooLarge', { mb: MODEL_MAX_MB }) };
  const buffer = await file.arrayBuffer();
  const magic = new TextDecoder().decode(new Uint8Array(buffer, 0, Math.min(4, buffer.byteLength)));
  if (magic !== 'glTF') return { error: i18nT('studio.model.notGlb') };
  let gltf: GLTF;
  try {
    gltf = await gltfLoader().parseAsync(buffer, '');
  }
  catch (err) {
    return { error: i18nT('studio.model.unreadable', { reason: err instanceof Error ? err.message : String(err) }) };
  }
  const stats = modelStats(gltf.scene);
  if (!stats.meshes) return { error: i18nT('studio.model.noMeshes') };
  if (stats.triangles > MODEL_MAX_TRIANGLES) {
    return { error: i18nT('studio.model.tooHeavy', { count: stats.triangles.toLocaleString('ru-RU'), max: MODEL_MAX_TRIANGLES.toLocaleString('ru-RU') }) };
  }
  if (stats.maxTexturePx > MODEL_MAX_TEXTURE_PX) {
    return { error: i18nT('studio.model.textureTooLarge', { px: stats.maxTexturePx, max: MODEL_MAX_TEXTURE_PX }) };
  }
  return { stats };
}
