// One renderer for everything a design is turned into — the editor view,
// the 3D textures, the painted-area measurement and the print files — so
// what the customer sees is exactly what gets printed.
//
// All drawing happens in pixels: `s` is pixels per millimetre and the area's
// top-left corner is (0, 0).
import type { AreaMethod, CatalogMethod, PrintArea } from '~/types/catalog';
import type { Layer, StripPosition, TextSource } from '~/lib/design/document';
import { areaMethod, imageDpi, LOW_DPI, MIN_DPI, MONO_COLOR, pixelsAt, printZone, sizeBox, sizeMm } from '~/lib/design/document';
import { drawDial, faceOf } from '~/lib/design/dial';
import { drawGraphic, resolveGraphic } from '~/lib/design/graphics';
import { ensureStickers, isMonoSticker, stickerUrl } from '~/lib/design/stickers';
import { i18nT } from '~/lib/i18n';
import { isLowEndDevice } from '~/lib/device';

const LINE_HEIGHT = 1.2;
const TEXT_PAD = 0.06; // of the font size, around the text box
const REFERENCE_PX = 200; // text is measured at this size, then scaled

// ── Assets ──────────────────────────────────────────────────────────────

const images = new Map<string, Promise<HTMLImageElement>>();
// Loaded, for drawing without waiting.
const loadedImages = new Map<string, HTMLImageElement>();
const loadedFonts = new Set<string>();
const monoImages = new WeakMap<HTMLImageElement, HTMLCanvasElement>();

export function loadImage(url: string): Promise<HTMLImageElement> {
  let pending = images.get(url);
  if (!pending) {
    pending = new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'anonymous'; // R2 sends CORS headers; keeps canvases exportable
      img.onload = () => {
        loadedImages.set(url, img);
        resolve(img);
      };
      img.onerror = () => reject(new Error(i18nT('studio.errors.imageLoad')));
      img.src = url;
    });
    images.set(url, pending);
    pending.catch(() => images.delete(url));
  }
  return pending;
}

/** Single-colour version of an image for mono methods (engraving): with
 * transparency, every opaque pixel is ink; without, every dark pixel is. */
export function monoImage(img: HTMLImageElement): HTMLCanvasElement {
  const cached = monoImages.get(img);
  if (cached) return cached;
  // A vector (a sticker) is drawn large first, so its single-colour version stays sharp.
  const k = /\.svg($|\?)|^data:image\/svg/.test(img.src) ? Math.max(1, 1024 / Math.max(img.naturalWidth, img.naturalHeight)) : 1;
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(img.naturalWidth * k);
  canvas.height = Math.round(img.naturalHeight * k);
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!;
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  const data = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const px = data.data;
  let transparent = false;
  for (let i = 3; i < px.length; i += 4) {
    if (px[i]! < 250) {
      transparent = true;
      break;
    }
  }
  for (let i = 0; i < px.length; i += 4) {
    const lum = (0.2126 * px[i]! + 0.7152 * px[i + 1]! + 0.0722 * px[i + 2]!) / 255;
    const ink = transparent ? px[i + 3]! > 127 : lum < 0.5;
    px[i] = 0;
    px[i + 1] = 0;
    px[i + 2] = 0;
    px[i + 3] = ink ? 255 : 0;
  }
  ctx.putImageData(data, 0, 0);
  monoImages.set(img, canvas);
  return canvas;
}

const tintedImages = new WeakMap<HTMLImageElement, Map<string, HTMLCanvasElement>>();

/** A single-colour sticker in `color` (its ink recoloured). */
function tintedImage(img: HTMLImageElement, color: string): HTMLCanvasElement {
  let byColor = tintedImages.get(img);
  if (!byColor) tintedImages.set(img, (byColor = new Map()));
  let canvas = byColor.get(color);
  if (!canvas) {
    const ink = monoImage(img);
    canvas = document.createElement('canvas');
    canvas.width = ink.width;
    canvas.height = ink.height;
    const ctx = canvas.getContext('2d')!;
    ctx.drawImage(ink, 0, 0);
    ctx.globalCompositeOperation = 'source-in';
    ctx.fillStyle = color;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    byColor.set(color, canvas);
  }
  return canvas;
}

const stickerNames = (layers: Layer[]) => layers.flatMap(l => (l.graphic?.library === 'sticker' ? [l.graphic.name] : []));

export function fontString(text: Pick<TextSource, 'font' | 'bold' | 'italic'>, px: number): string {
  return `${text.italic ? 'italic ' : ''}${text.bold ? 700 : 400} ${px}px "${text.font}", sans-serif`;
}

/** The picture a layer is drawn from: an uploaded image or a sticker. */
function pictureUrl(layer: Layer): string | null {
  if (layer.image) return layer.image.url;
  if (layer.graphic?.library === 'sticker') return stickerUrl(layer.graphic.name);
  return null;
}

async function loadFont(font: string, sample: string) {
  const key = `${font}|${sample}`;
  if (loadedFonts.has(key)) return;
  await document.fonts.load(font, sample);
  loadedFonts.add(key);
}

/** Loads every image and font the layers use (at once when they already are). */
export async function prepareAssets(layers: Layer[]): Promise<void> {
  await ensureStickers(stickerNames(layers));
  await Promise.all(layers.map(async (layer) => {
    const url = pictureUrl(layer);
    if (url && !loadedImages.has(url)) await loadImage(url);
    if (layer.text) await loadFont(fontString(layer.text, 64), layer.text.content);
    if (layer.dial) await loadFont(fontString(layer.dial, 64), '0123456789XIV');
  }));
}

// ── Text layout ─────────────────────────────────────────────────────────

let measureCtx: CanvasRenderingContext2D | null = null;

export interface TextLayout {
  w_mm: number;
  h_mm: number;
  // Relative to the box's top-left, in mm: the alignment point of every
  // line and each line's baseline.
  anchor_mm: number;
  baselines_mm: number[];
  lines: string[];
}

/** The box a text needs, sized so no glyph ever paints outside it (the
 * print file is checked against the zone pixel by pixel). */
export function layoutText(text: TextSource): TextLayout {
  measureCtx ??= document.createElement('canvas').getContext('2d')!;
  const ctx = measureCtx;
  ctx.font = fontString(text, REFERENCE_PX);
  ctx.textAlign = text.align;
  ctx.textBaseline = 'alphabetic';
  const lines = text.content.split('\n');
  let left = 0;
  let right = 0;
  let ascent = 0;
  let descent = 0;
  for (const line of lines) {
    const m = ctx.measureText(line || ' ');
    left = Math.max(left, m.actualBoundingBoxLeft);
    right = Math.max(right, m.actualBoundingBoxRight);
    ascent = Math.max(ascent, m.fontBoundingBoxAscent, m.actualBoundingBoxAscent);
    descent = Math.max(descent, m.fontBoundingBoxDescent, m.actualBoundingBoxDescent);
  }
  const k = text.size_mm / REFERENCE_PX;
  const pad = TEXT_PAD * REFERENCE_PX;
  const lineHeight = Math.max(LINE_HEIGHT * REFERENCE_PX, ascent + descent);
  const extra = (lineHeight - ascent - descent) / 2;
  return {
    w_mm: (left + right + 2 * pad) * k,
    h_mm: (lines.length * lineHeight + 2 * pad) * k,
    anchor_mm: (pad + left) * k,
    baselines_mm: lines.map((_, i) => (pad + i * lineHeight + extra + ascent) * k),
    lines,
  };
}

// ── Drawing ─────────────────────────────────────────────────────────────

interface DrawOptions {
  s: number; // pixels per mm
  mono: boolean; // single-colour method: black ink only
}

/** Draws one layer; its assets must be loaded (prepareAssets). */
function paint(ctx: CanvasRenderingContext2D, layer: Layer, options: DrawOptions) {
  const { s, mono } = options;
  const url = pictureUrl(layer);
  const source = url ? loadedImages.get(url) ?? null : null;
  if (url && !source) throw new Error(i18nT('studio.errors.imageNotLoaded'));
  ctx.save();
  ctx.translate(layer.x_mm * s, layer.y_mm * s);
  ctx.rotate((layer.rotation * Math.PI) / 180);
  const w = layer.w_mm * s;
  const h = layer.h_mm * s;
  if (source) {
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    const recolour = !mono && layer.graphic?.library === 'sticker' && isMonoSticker(layer.graphic.name);
    ctx.drawImage(mono ? monoImage(source) : recolour ? tintedImage(source, layer.graphic!.color) : source, -w / 2, -h / 2, w, h);
  }
  else if (layer.text) {
    const layout = layoutText(layer.text);
    ctx.font = fontString(layer.text, layer.text.size_mm * s);
    ctx.textAlign = layer.text.align;
    ctx.textBaseline = 'alphabetic';
    ctx.fillStyle = mono ? MONO_COLOR : layer.text.color;
    layout.lines.forEach((line, i) => {
      ctx.fillText(line, -w / 2 + layout.anchor_mm * s, -h / 2 + layout.baselines_mm[i]! * s);
    });
  }
  else if (layer.dial) {
    const dial = layer.dial;
    drawDial(ctx, dial, w, h, s, mono ? MONO_COLOR : dial.color, px => fontString(dial, px));
  }
  else if (layer.graphic) {
    const def = resolveGraphic(layer.graphic);
    if (!def) throw new Error(i18nT('studio.errors.graphicMissing', { name: layer.graphic.name }));
    drawGraphic(ctx, def, w, h, mono ? MONO_COLOR : layer.graphic.color);
  }
  ctx.restore();
}

export interface AreaRenderOptions {
  s: number;
  strips: StripPosition[] | undefined; // the document's, for where a strip is
  methods?: CatalogMethod[]; // only these methods' layers (default: all)
  tints?: Partial<Record<CatalogMethod, string>>; // recolour mono ink per method
  // The editor also shows what the zone crops away, faintly (0–1 opacity).
  ghost?: number;
  // Where the canvas starts in area millimetres (a print file cut to a
  // size's box starts at its corner, not at the area's). Layer coordinates
  // stay area millimetres; only the paper moves.
  origin?: { x: number; y: number };
}

// Canvases a run of layers is drawn into before it is tinted or ghosted,
// reused from paint to paint (by size, and CPU or GPU like the target).
const scratches = new Map<string, CanvasRenderingContext2D>();

function scratchFor(target: CanvasRenderingContext2D): CanvasRenderingContext2D {
  const { width, height } = target.canvas;
  const cpu = Boolean(target.getContextAttributes?.().willReadFrequently);
  const key = `${width}x${height}${cpu ? 'c' : 'g'}`;
  let ctx = scratches.get(key);
  if (ctx) {
    scratches.delete(key); // most recently used last
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, width, height);
  }
  else {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    ctx = canvas.getContext('2d', { willReadFrequently: cpu })!;
    if (scratches.size >= 4) scratches.delete(scratches.keys().next().value!);
  }
  scratches.set(key, ctx);
  return ctx;
}

/** Draws an area's layers (in document order) onto a canvas of the area's
 * size at `s` pixels per mm. */
export async function renderArea(area: PrintArea, layers: Layer[], options: AreaRenderOptions): Promise<HTMLCanvasElement> {
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(Number(area.width_mm) * options.s));
  canvas.height = Math.max(1, Math.round(Number(area.height_mm) * options.s));
  await drawAreaInto(canvas.getContext('2d')!, area, layers, options);
  return canvas;
}

const areaLayers = (area: PrintArea, layers: Layer[]) => layers.filter(l => l.area === area.key);

/** drawAreaNow once the layers' assets are loaded. */
export async function drawAreaInto(ctx: CanvasRenderingContext2D, area: PrintArea, layers: Layer[], options: AreaRenderOptions): Promise<void> {
  await prepareAssets(areaLayers(area, layers));
  drawAreaNow(ctx, area, layers, options);
}

/** Draws the layers cropped to their method's zone (or its strip): what is
 * printed. At once — the assets must be loaded (prepareAssets) — so no
 * other paint can come in between. Layers of one method in a row that are
 * tinted or ghosted are drawn together once into a scratch canvas, then
 * recoloured and copied in. */
export function drawAreaNow(ctx: CanvasRenderingContext2D, area: PrintArea, layers: Layer[], options: AreaRenderOptions): void {
  const { s } = options;
  const origin = options.origin;
  if (origin && (origin.x || origin.y)) {
    ctx.save();
    ctx.translate(-origin.x * s, -origin.y * s);
    drawAreaNow(ctx, area, layers, { ...options, origin: undefined });
    ctx.restore();
    return;
  }
  const own = areaLayers(area, layers).filter(l => (!options.methods || options.methods.includes(l.method)) && areaMethod(area, l.method));
  for (let i = 0; i < own.length;) {
    const method = areaMethod(area, own[i]!.method)!;
    let end = i;
    while (end < own.length && own[end]!.method === method.method) end++;
    const run = own.slice(i, end);
    i = end;
    const draw = { s, mono: !method.colors_allowed };
    const tint = draw.mono ? options.tints?.[method.method] : undefined;
    const zone = printZone(area, method, layers, options.strips);
    const face = faceOf(area);
    const clipped = (paintIt: () => void) => {
      ctx.save();
      ctx.beginPath();
      const zx = zone.x0 * s;
      const zy = zone.y0 * s;
      const zw = (zone.x1 - zone.x0) * s;
      const zh = (zone.y1 - zone.y0) * s;
      if (face.face === 'round') {
        ctx.ellipse(zx + zw / 2, zy + zh / 2, zw / 2, zh / 2, 0, 0, Math.PI * 2);
      } else if (face.corner_radius_mm > 0 && typeof ctx.roundRect === 'function') {
        const r = Math.min(face.corner_radius_mm * s, zw / 2, zh / 2);
        ctx.roundRect(zx, zy, zw, zh, r);
      } else {
        ctx.rect(zx, zy, zw, zh);
      }
      ctx.clip();
      paintIt();
      ctx.restore();
    };
    if (!tint && !options.ghost) {
      clipped(() => run.forEach(l => paint(ctx, l, draw)));
      continue;
    }
    const sc = scratchFor(ctx);
    run.forEach(l => paint(sc, l, draw));
    if (tint) {
      sc.globalCompositeOperation = 'source-in';
      sc.fillStyle = tint;
      sc.fillRect(0, 0, sc.canvas.width, sc.canvas.height);
      sc.globalCompositeOperation = 'source-over';
    }
    if (options.ghost) {
      ctx.save();
      ctx.globalAlpha = options.ghost;
      ctx.drawImage(sc.canvas, 0, 0);
      ctx.restore();
    }
    clipped(() => ctx.drawImage(sc.canvas, 0, 0));
  }
}

// ── 3D textures ─────────────────────────────────────────────────────────

// Weak phones: half the side (a quarter of the pixels to upload per edit).
const TEXTURE_MAX_PX = () => (isLowEndDevice() ? 1024 : 2048);
const TEXTURE_PX_PER_MM = 6; // enough on screen; print files are drawn separately

/** The canvas an area is painted into for the 3D product (reused on every paint). */
export function previewCanvas(area: PrintArea): HTMLCanvasElement {
  const w = Number(area.width_mm);
  const h = Number(area.height_mm);
  const s = Math.min(TEXTURE_PX_PER_MM, TEXTURE_MAX_PX() / Math.max(w, h));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(2, Math.round(w * s));
  canvas.height = Math.max(2, Math.round(h * s));
  return canvas;
}

/** paintPreviewNow once the layers' assets are loaded. */
export async function paintPreview(
  canvas: HTMLCanvasElement, area: PrintArea, layers: Layer[], engraveTint: string, strips: StripPosition[] | undefined,
): Promise<CanvasRenderingContext2D> {
  await prepareAssets(areaLayers(area, layers));
  return paintPreviewNow(canvas, area, layers, engraveTint, strips);
}

/** Repaints an area's design on its previewCanvas as the 3D product shows
 * it: engraving in `engraveTint` (the material's, ENGRAVE_TINT). Returns
 * the context, for editing marks drawn over it. */
export function paintPreviewNow(
  canvas: HTMLCanvasElement, area: PrintArea, layers: Layer[], engraveTint: string, strips: StripPosition[] | undefined,
): CanvasRenderingContext2D {
  // A CPU canvas: from a GPU one the texture upload could still show the
  // previous paint (the editing marks in a picture taken right after).
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  drawAreaNow(ctx, area, layers, { s: canvas.width / Number(area.width_mm), tints: { engrave: engraveTint }, strips });
  return ctx;
}

// ── Measurement and print files ─────────────────────────────────────────

const MEASURE_PX_PER_MM = 4;

/** Painted area (alpha > 0) per method in cm² — the estimate the Studio
 * sends with autosave; the cart re-measures from the print files. */
export async function measurePainted(
  areas: PrintArea[], layers: Layer[], strips: StripPosition[] | undefined,
): Promise<Partial<Record<CatalogMethod, number>>> {
  const result: Partial<Record<CatalogMethod, number>> = {};
  for (const area of areas) {
    for (const method of area.methods) {
      if (!layers.some(l => l.area === area.key && l.method === method.method)) continue;
      const canvas = await renderArea(area, layers, { s: MEASURE_PX_PER_MM, methods: [method.method], strips });
      const data = canvas.getContext('2d', { willReadFrequently: true })!.getImageData(0, 0, canvas.width, canvas.height).data;
      let painted = 0;
      for (let i = 3; i < data.length; i += 4) if (data[i]) painted++;
      const cm2 = painted / (MEASURE_PX_PER_MM * MEASURE_PX_PER_MM) / 100;
      result[method.method] = (result[method.method] ?? 0) + cm2;
    }
  }
  return result;
}

/** The print file of one area and method: a PNG exactly the size of what
 * the chosen size prints — the whole area at `scale` 1, that size's box
 * otherwise (document.sizeBox) — at the method's DPI. Checked by the
 * backend to the pixel, so this is what goes to the factory. */
export async function renderPrintFile(
  area: PrintArea, method: AreaMethod, layers: Layer[], strips: StripPosition[] | undefined, scale = 1,
): Promise<Blob> {
  const mm = sizeMm(area, scale);
  const box = sizeBox(area, scale);
  const width = pixelsAt(mm.w, method.dpi);
  const height = pixelsAt(mm.h, method.dpi);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  await drawAreaInto(canvas.getContext('2d')!, area, layers, {
    s: width / mm.w, methods: [method.method], strips, origin: box ? { x: box.x0, y: box.y0 } : undefined,
  });
  return new Promise((resolve, reject) => canvas.toBlob(
    blob => (blob ? resolve(blob) : reject(new Error(i18nT('studio.errors.printFile')))),
    'image/png',
  ));
}

export { imageDpi, LOW_DPI, MIN_DPI } from '~/lib/design/document';
