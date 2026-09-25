// The picture that sells a product in a listing: the transparent hero frame
// `renderPictures` draws first (a three-quarter view, slightly from above)
// composed on Dizzo's own background — brand orange, bold blocks, a cream
// surface the product stands on, and a soft drop shadow. Everything is laid
// out from the product's real outline, measured from the frame's alpha, so a
// tall mug and a wide board are both framed the way a photographer would.
import { i18nT } from '~/lib/i18n';

const BRAND = '#ed5123';
const BRAND_LIGHT = '#ff7c47';
const BRAND_DEEP = '#b8360f';
const CREAM = '#fdf4ee';
const INK = (alpha: number) => `rgba(86, 22, 4, ${alpha})`;

/** Fractions of the picture's side. The product never fills more than this,
 * which is where the generous margins come from. */
const PRODUCT_MAX_W = 0.58;
const PRODUCT_MAX_H = 0.52;
/** Where the product's outline ends, and where the surface it stands on
 * begins — the product overlaps the edge, so it sits on it instead of
 * floating above it. */
const PRODUCT_FOOT = 0.775;
const SURFACE_LEFT = 0.735;
const SURFACE_RIGHT = 0.695;

export interface CoverOptions {
  /** The side of the square picture. The catalog wants 1200. */
  size?: number;
}

/** A branded 1200×1200 cover (a WebP data URL) from one transparent frame. */
export async function composeCover(hero: string, { size = 1200 }: CoverOptions = {}): Promise<string> {
  const image = await loadImage(hero);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error(i18nT('common.errors.canvasUnavailable'));

  drawBackground(ctx, size);
  drawSurface(ctx, size);
  drawProduct(ctx, size, image);

  // WebP where the browser can encode it; anything else falls back to PNG on
  // its own and the upload re-encodes it.
  return canvas.toDataURL('image/webp', 0.92);
}

/** Orange from corner to corner, a light bloom where the key light falls,
 * two wide bars for structure, and a vignette that pushes the middle forward. */
function drawBackground(ctx: CanvasRenderingContext2D, s: number) {
  const base = ctx.createLinearGradient(0, 0, s, s);
  base.addColorStop(0, BRAND_LIGHT);
  base.addColorStop(0.52, BRAND);
  base.addColorStop(1, BRAND_DEEP);
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, s, s);

  const bloom = ctx.createRadialGradient(s * 0.3, s * 0.24, 0, s * 0.3, s * 0.24, s * 0.72);
  bloom.addColorStop(0, 'rgba(255, 214, 184, 0.5)');
  bloom.addColorStop(0.55, 'rgba(255, 190, 150, 0.14)');
  bloom.addColorStop(1, 'rgba(255, 190, 150, 0)');
  ctx.fillStyle = bloom;
  ctx.fillRect(0, 0, s, s);

  // Two diagonal bars, barely there: the picture reads as built, not filled.
  ctx.save();
  ctx.translate(s * 0.5, s * 0.5);
  ctx.rotate(-Math.PI / 4);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.075)';
  ctx.fillRect(-s, -s * 0.62, s * 2, s * 0.2);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.045)';
  ctx.fillRect(-s, s * 0.3, s * 2, s * 0.34);
  ctx.restore();

  const vignette = ctx.createRadialGradient(s * 0.5, s * 0.46, s * 0.3, s * 0.5, s * 0.5, s * 0.78);
  vignette.addColorStop(0, 'rgba(120, 30, 0, 0)');
  vignette.addColorStop(1, 'rgba(120, 30, 0, 0.28)');
  ctx.fillStyle = vignette;
  ctx.fillRect(0, 0, s, s);
}

/** The cream surface the product stands on: a bold block with a gently
 * tilted edge, lit along that edge so it reads as a real surface. */
function drawSurface(ctx: CanvasRenderingContext2D, s: number) {
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(0, s * SURFACE_LEFT);
  ctx.lineTo(s, s * SURFACE_RIGHT);
  ctx.lineTo(s, s);
  ctx.lineTo(0, s);
  ctx.closePath();
  ctx.fillStyle = CREAM;
  ctx.fill();
  // The edge catches the light; the far side of the surface falls away.
  ctx.clip();
  const fade = ctx.createLinearGradient(0, s * SURFACE_RIGHT, 0, s);
  fade.addColorStop(0, 'rgba(255, 255, 255, 0.55)');
  fade.addColorStop(0.35, 'rgba(255, 255, 255, 0)');
  fade.addColorStop(1, INK(0.09));
  ctx.fillStyle = fade;
  ctx.fillRect(0, s * SURFACE_RIGHT, s, s);
  ctx.restore();
}

/** The product itself: its outline measured, scaled into the free space,
 * stood on the surface and turned to stand square to it. */
function drawProduct(ctx: CanvasRenderingContext2D, s: number, image: HTMLImageElement) {
  const box = outlineOf(image);
  const scale = Math.min((s * PRODUCT_MAX_W) / box.width, (s * PRODUCT_MAX_H) / box.height);
  const width = box.width * scale;
  const height = box.height * scale;
  // The surface falls to the right, so the product leans with it: standing
  // upright on a tilted table is what looks wrong.
  const tilt = -Math.atan2(SURFACE_LEFT - SURFACE_RIGHT, 1);
  ctx.save();
  ctx.translate(s * 0.5, s * PRODUCT_FOOT);
  ctx.rotate(tilt);
  ctx.shadowColor = INK(0.34);
  ctx.shadowBlur = s * 0.055;
  ctx.shadowOffsetY = s * 0.022;
  ctx.drawImage(image, box.x, box.y, box.width, box.height, -width / 2, -height, width, height);
  ctx.restore();
}

/** The part of the frame that is not transparent: `captureFitted` leaves a
 * margin and the contact shadow spreads past the product, so the picture's
 * own square says nothing about where the product actually is. */
function outlineOf(image: HTMLImageElement): { x: number; y: number; width: number; height: number } {
  const whole = { x: 0, y: 0, width: image.naturalWidth, height: image.naturalHeight };
  const canvas = document.createElement('canvas');
  canvas.width = whole.width;
  canvas.height = whole.height;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return whole;
  ctx.drawImage(image, 0, 0);
  let data: Uint8ClampedArray;
  try {
    data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
  }
  catch {
    return whole; // a tainted canvas: the frame came from somewhere else
  }
  let [x0, y0, x1, y1] = [canvas.width, canvas.height, -1, -1];
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      // Well above the contact shadow's faintest tail, which would otherwise
      // decide the outline instead of the product.
      if (data[(y * canvas.width + x) * 4 + 3]! < 24) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < x0 || y1 < y0) return whole; // nothing was drawn
  return { x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1 };
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(i18nT('common.pictures.coverFailed')));
    image.src = src;
  });
}
