// Everything a 3D view needs, loaded with one dynamic `import()` from a
// component's onMounted — so three.js and the Draco decoder (whose module
// resolves files relative to import.meta.url) never run during SSR.
export * as THREE from 'three';
export * from '~/lib/three/autoFit';
export * from '~/lib/three/materials';
export * from '~/lib/three/modelLoader';
export * from '~/lib/three/modelViewer';
export * from '~/lib/three/parametric';
export * from '~/lib/three/projector';
export * from '~/lib/three/testPattern';

// Components import this type only (`import type`), and the module itself
// with `await import('~/lib/three/kit')`.
export type Kit = typeof import('~/lib/three/kit');
