// Light-weight stickers and element helper.
// All heavy JSON files (index.json, more.json, packs) have been removed from frontend.
// Design assets are fetched dynamically from the backend API (Cloudflare R2).
import { shallowRef } from 'vue';

export interface StickerItem {
  n: string; // graphic name or id
  g: string; // group / category key
  l: string; // display name / label
  k: string; // search keywords
  w: number; // width
  h: number; // height
  p?: number; // popularity rank
  pk?: string;
  m?: 1;
}

export interface StickerIndex {
  v: 1;
  groups: { key: string; label: string }[];
  items: StickerItem[];
}

export interface ElementPick {
  library: 'shape' | 'icon' | 'sticker';
  name: string;
  w: number;
  h: number;
}

export const isPackedSticker = (_name: string) => false;
export const isMonoSticker = (_name: string) => false;

const emptyIndex: StickerIndex = {
  v: 1,
  groups: [],
  items: [],
};

export async function loadStickerIndex(): Promise<StickerIndex> {
  return emptyIndex;
}

export const packVersion = shallowRef(0);

export async function ensureStickers(_names: string[]): Promise<void> {
  // No-op since packs are removed and cloudflare R2 assets are loaded directly
}

export function stickerUrl(_name: string): string | null {
  return null;
}

export const foldText = (s: string) => s.toLowerCase().replace(/[‘’ʻʼ`']/g, '\'');
