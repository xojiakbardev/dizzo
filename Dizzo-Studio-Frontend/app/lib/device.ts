// A weak phone (few cores or little memory, or "save data" on): the 3D
// view draws fewer pixels and smaller design textures, and the page drops
// its blur effects (the `lite` class on <html>, app/plugins/lite.client.ts).

let cached: boolean | null = null;

export function isLowEndDevice(): boolean {
  if (cached !== null) return cached;
  if (typeof navigator === 'undefined') return false;
  const nav = navigator as Navigator & { deviceMemory?: number; connection?: { saveData?: boolean } };
  const cores = nav.hardwareConcurrency || 8;
  const memory = nav.deviceMemory ?? 8;
  cached = cores <= 4 || memory <= 4 || nav.connection?.saveData === true;
  return cached;
}

/** Device pixels per CSS pixel for WebGL: sharp enough, never costly. */
export function renderPixelRatio(): number {
  if (typeof window === 'undefined') return 1;
  return Math.min(window.devicePixelRatio || 1, isLowEndDevice() ? 1 : 1.5);
}
