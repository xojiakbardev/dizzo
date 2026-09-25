// A clock face's numerals and minute marks. Everything is placed along
// rays from the centre, 6° apart (every minute, 12 at the top, clockwise):
// on a round face they sit on a circle (an ellipse in a non-square box),
// on a rectangular one where each ray meets the rounded rectangle, the way
// square wall clocks are laid out. Sizes follow the face, so the marks are
// right for any clock; the numerals take the customer's font and size.
import type { DialSource, Layer } from '~/lib/design/document';
import { areaMethod, zoneBox } from '~/lib/design/document';
import { isPlacedModelAnchor } from '~/types/catalog';
import type { PrintArea } from '~/types/catalog';

const ROMAN = ['XII', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];
export const DIAL_PREFIX = 'dial-';

/** The face edge along the ray at `angle` (radians, 0 = up, clockwise): its
 * distance from the centre, for a face of w × h (mm or px alike). */
function edgeDistance(dial: Pick<DialSource, 'face' | 'corner_radius_mm'>, w: number, h: number, angle: number, cornerPx: number): number {
  const dx = Math.sin(angle);
  const dy = -Math.cos(angle);
  const hw = w / 2;
  const hh = h / 2;
  if (dial.face === 'round') return 1 / Math.sqrt((dx / hw) ** 2 + (dy / hh) ** 2);
  const r = Math.min(cornerPx, hw, hh);
  // Inside a rounded rectangle (signed distance ≤ 0), found by bisection.
  const inside = (t: number) => {
    const qx = Math.abs(dx * t) - (hw - r);
    const qy = Math.abs(dy * t) - (hh - r);
    return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r <= 0;
  };
  let lo = 0;
  let hi = Math.hypot(hw, hh);
  for (let i = 0; i < 32; i++) {
    const mid = (lo + hi) / 2;
    if (inside(mid)) lo = mid;
    else hi = mid;
  }
  return lo;
}

/** Draws the dial into the box (-w/2, -h/2)–(w/2, h/2) of the current transform. */
export function drawDial(
  ctx: CanvasRenderingContext2D, dial: DialSource, w: number, h: number, s: number, color: string, font: (px: number) => string,
) {
  const d = Math.min(w, h);
  const margin = d * 0.022;
  const hourTick = dial.ticks ? d * 0.055 : 0;
  const minuteTick = d * 0.026;
  const corner = dial.corner_radius_mm * s;
  ctx.save();
  ctx.fillStyle = color;
  ctx.strokeStyle = color;
  ctx.lineCap = 'butt';
  if (dial.ticks) {
    for (let i = 0; i < 60; i++) {
      const angle = (i * Math.PI) / 30;
      const hour = i % 5 === 0;
      const edge = edgeDistance(dial, w, h, angle, corner) - margin;
      const len = hour ? hourTick : minuteTick;
      const dx = Math.sin(angle);
      const dy = -Math.cos(angle);
      ctx.lineWidth = hour ? d * 0.011 : d * 0.0045;
      ctx.beginPath();
      ctx.moveTo(dx * edge, dy * edge);
      ctx.lineTo(dx * (edge - len), dy * (edge - len));
      ctx.stroke();
    }
  }
  if (dial.numerals !== 'none') {
    const px = dial.size_mm * s;
    ctx.font = font(px);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < 12; i++) {
      const angle = (i * Math.PI) / 6;
      const label = dial.numerals === 'roman' ? ROMAN[i]! : String(i === 0 ? 12 : i);
      const m = ctx.measureText(label);
      // Far enough in that the whole numeral clears the marks, whichever way the ray runs.
      const dx = Math.sin(angle);
      const dy = -Math.cos(angle);
      const half = Math.abs(dx) * (m.width / 2) + Math.abs(dy) * (px * 0.42);
      const r = edgeDistance(dial, w, h, angle, corner) - margin - hourTick - d * 0.02 - half;
      ctx.fillText(label, dx * r, dy * r + px * 0.04);
    }
  }
  ctx.restore();
}

// Measuring the numerals for a hit test (the same text the dial draws).
let measureCtx: CanvasRenderingContext2D | null | undefined;
function measurer(): CanvasRenderingContext2D | null {
  if (measureCtx === undefined) measureCtx = import.meta.client ? document.createElement('canvas').getContext('2d') : null;
  return measureCtx;
}

/** Whether a press lands on what the dial actually draws — a numeral or a
 * mark — and not merely inside its face: the layer covers the whole face,
 * so without this the dial would be selected anywhere on the clock. `p` is
 * in the layer's own frame (mm from the centre, y down) and every mark is
 * widened by `slack` mm so a finger still catches it. */
export function dialHit(
  dial: DialSource, w: number, h: number, p: { x: number; y: number }, font: (px: number) => string, slack = 2,
): boolean {
  const d = Math.min(w, h);
  const margin = d * 0.022;
  const hourTick = dial.ticks ? d * 0.055 : 0;
  const minuteTick = d * 0.026;
  const corner = dial.corner_radius_mm;
  const r = Math.hypot(p.x, p.y);
  if (dial.ticks) {
    // The mark nearest the press runs along its own ray (every 6°).
    const angle = Math.atan2(p.x, -p.y);
    const minute = Math.round((angle * 30) / Math.PI);
    const ray = (minute * Math.PI) / 30;
    const across = Math.abs(r * Math.sin(angle - ray));
    const edge = edgeDistance(dial, w, h, ray, corner) - margin;
    const len = minute % 5 === 0 ? hourTick : minuteTick;
    if (across <= slack && r <= edge + slack && r >= edge - len - slack) return true;
  }
  if (dial.numerals !== 'none') {
    const px = dial.size_mm;
    const ctx = measurer();
    if (ctx) ctx.font = font(px);
    for (let i = 0; i < 12; i++) {
      const angle = (i * Math.PI) / 6;
      const label = dial.numerals === 'roman' ? ROMAN[i]! : String(i === 0 ? 12 : i);
      const width = ctx ? ctx.measureText(label).width : px * 0.62 * label.length;
      const dx = Math.sin(angle);
      const dy = -Math.cos(angle);
      const half = Math.abs(dx) * (width / 2) + Math.abs(dy) * (px * 0.42);
      const at = edgeDistance(dial, w, h, angle, corner) - margin - hourTick - d * 0.02 - half;
      if (Math.abs(p.x - dx * at) <= width / 2 + slack && Math.abs(p.y - (dy * at + px * 0.04)) <= px * 0.6 + slack) return true;
    }
  }
  return false;
}

/** The face an area's clock numerals follow (from its model anchor). */
export function faceOf(area: PrintArea): Pick<DialSource, 'face' | 'corner_radius_mm'> {
  const a = isPlacedModelAnchor(area.anchor) ? area.anchor : null;
  return { face: a?.round ? 'round' : 'rect', corner_radius_mm: a?.corner_radius_mm ? Number(a.corner_radius_mm) : 0 };
}

export const isDialArea = (area: PrintArea) => isPlacedModelAnchor(area.anchor) && area.anchor.dial === true;

/** A new clock face's numerals: covering the colour-print zone, locked by the Studio. */
export function newDialLayer(area: PrintArea, color: string): Layer | null {
  const m = areaMethod(area, 'uv') ?? area.methods[0];
  if (!m) return null;
  const z = zoneBox(m);
  const w = z.x1 - z.x0;
  const h = z.y1 - z.y0;
  return {
    id: `${DIAL_PREFIX}${Date.now().toString(36)}`, area: area.key, method: m.method, kind: 'dial', locked: 'system',
    x_mm: (z.x0 + z.x1) / 2, y_mm: (z.y0 + z.y1) / 2, w_mm: w, h_mm: h, rotation: 0,
    dial: {
      font: 'Montserrat', size_mm: Math.max(6, Math.round(Math.min(w, h) * 0.075)), color: m.colors_allowed ? color : '#000000',
      bold: true, italic: false, numerals: 'arabic', ticks: true, ...faceOf(area),
    },
  };
}
