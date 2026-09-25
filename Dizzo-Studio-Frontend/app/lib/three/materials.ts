// How a variant's material looks in 3D, and how engraving shows on it.
import * as THREE from 'three';
import type { Material } from '~/types/catalog';

interface Look { roughness: number; metalness?: number; clearcoat?: number; transmission?: number; sheen?: number }

const LOOKS: Record<Material, Look> = {
  ceramic_glossy: { roughness: 0.18, clearcoat: 0.8 },
  ceramic_matte: { roughness: 0.78 },
  glass_clear: { roughness: 0.04, transmission: 0.92 },
  glass_frosted: { roughness: 0.45, transmission: 0.8 },
  fabric: { roughness: 0.95, sheen: 0.6 },
  paper: { roughness: 0.9 },
  plastic: { roughness: 0.4 },
  metal: { roughness: 0.3, metalness: 0.9 },
  wood: { roughness: 0.72 },
};

// Engraving isn't ink: previews show it in the colour it leaves on the material.
export const ENGRAVE_TINT: Record<Material, string> = {
  ceramic_glossy: '#6f6a66',
  // A laser peels off the coat and bares the grey base under it.
  ceramic_matte: '#6f6a66',
  glass_clear: 'rgba(255, 255, 255, 0.85)',
  glass_frosted: 'rgba(255, 255, 255, 0.95)',
  fabric: '#3f3f46',
  paper: '#3f3f46',
  plastic: '#e4e4e7',
  metal: '#d4d4d8',
  wood: '#4a2c17',
};

export function bodyMaterial(material: Material, hex: string): THREE.MeshPhysicalMaterial {
  const look = LOOKS[material];
  return new THREE.MeshPhysicalMaterial({
    color: new THREE.Color(hex),
    roughness: look.roughness,
    metalness: look.metalness ?? 0,
    clearcoat: look.clearcoat ?? 0,
    transmission: look.transmission ?? 0,
    thickness: look.transmission ? 2 : 0,
    sheen: look.sheen ?? 0,
    sheenColor: new THREE.Color('#ffffff'),
  });
}

export function printMaterial(
  material: Material,
  texture: THREE.Texture,
  _surfaceHex?: string | null,
  _whiteUnderbase: boolean = true,
): THREE.MeshStandardMaterial {
  return new THREE.MeshStandardMaterial({
    map: texture,
    transparent: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2,
    roughness: Math.max(0.3, LOOKS[material].roughness),
    metalness: 0,
    side: THREE.DoubleSide,
  });
}
