// Test print for placing an area on a model: a centimetre grid with a
// "TEPA ↑" arrow and the method zones, drawn to the area's real proportions,
// so a stretched, rotated or mirrored placement is visible at a glance. The
// area being edited is drawn bright; the others grey, with just their name.
// In the shape editor the zone being edited stands out, and a laser's strip
// shows as a band at its place in the zone.
import * as THREE from 'three';
import type { CatalogMethod, PrintArea } from '~/types/catalog';
import { ZONE_COLOURS } from '~/lib/admin/shapeDraft';
import { i18nT } from '~/lib/i18n';

const MAX_SIDE_PX = 2048;
const PX_PER_MM = 4;

export interface PatternZone {
  method: CatalogMethod;
  x: number; // mm from the area's top-left corner
  y: number;
  w: number;
  h: number;
  strip?: number | null;
}

export interface PatternArea {
  name: string;
  width: number; // mm
  height: number;
  zones: PatternZone[];
}

export interface PatternOptions {
  highlighted: boolean;
  /** The zone being edited: the others fade. */
  activeMethod?: CatalogMethod | null;
  /** Where the laser strip sits across its zone, 0 (left) … 1 (right). */
  stripAt?: number | null;
  /** The face: 'round' prints the ellipse only; corner radius in mm. */
  round?: boolean;
  cornerMm?: number;
  showSize?: boolean;
}

export { ZONE_COLOURS };

export function areaPatternCanvas(area: PatternArea, options: PatternOptions): HTMLCanvasElement {
  const w = Math.max(0.1, area.width);
  const h = Math.max(0.1, area.height);
  const scale = Math.min(PX_PER_MM, MAX_SIDE_PX / Math.max(w, h));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(2, Math.round(w * scale));
  canvas.height = Math.max(2, Math.round(h * scale));
  const ctx = canvas.getContext('2d')!;
  const mm = (v: number) => v * scale;
  const outline = Math.max(4, canvas.width / 120);

  const face = new Path2D();
  const cornerPx = options.round ? 0 : Math.min(mm(options.cornerMm ?? 0), canvas.width / 2, canvas.height / 2);
  if (options.round) face.ellipse(canvas.width / 2, canvas.height / 2, canvas.width / 2, canvas.height / 2, 0, 0, Math.PI * 2);
  else if (cornerPx > 0) face.roundRect(0, 0, canvas.width, canvas.height, cornerPx);
  else face.rect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.clip(face);

  if (!options.highlighted) {
    ctx.fillStyle = 'rgba(100, 116, 139, 0.45)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = 'rgba(51, 65, 85, 0.9)';
    ctx.lineWidth = outline * 2;
    ctx.stroke(face);
    const label = Math.max(14, Math.min(canvas.width / 8, canvas.height / 4));
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `700 ${label}px system-ui, sans-serif`;
    if (area.name) ctx.fillText(area.name, canvas.width / 2, canvas.height / 2, canvas.width * 0.9);
    ctx.restore();
    return canvas;
  }

  ctx.fillStyle = 'rgba(255, 255, 255, 0.82)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Grid: 1 cm lines, every 5 cm stronger.
  for (let x = 0; x <= w; x += 10) {
    ctx.strokeStyle = x % 50 === 0 ? 'rgba(15, 23, 42, 0.45)' : 'rgba(15, 23, 42, 0.14)';
    ctx.lineWidth = x % 50 === 0 ? 2 : 1;
    ctx.beginPath();
    ctx.moveTo(mm(x), 0);
    ctx.lineTo(mm(x), canvas.height);
    ctx.stroke();
  }
  for (let y = 0; y <= h; y += 10) {
    ctx.strokeStyle = y % 50 === 0 ? 'rgba(15, 23, 42, 0.45)' : 'rgba(15, 23, 42, 0.14)';
    ctx.lineWidth = y % 50 === 0 ? 2 : 1;
    ctx.beginPath();
    ctx.moveTo(0, mm(y));
    ctx.lineTo(canvas.width, mm(y));
    ctx.stroke();
  }

  const active = options.activeMethod ?? null;
  // The active zone last, so it lies on top.
  const zones = [...area.zones].sort((a, b) => Number(a.method === active) - Number(b.method === active));
  for (const zone of zones) {
    const colour = ZONE_COLOURS[zone.method];
    const faded = active !== null && zone.method !== active;
    const rect = [mm(zone.x), mm(zone.y), mm(zone.w), mm(zone.h)] as const;
    ctx.save();
    ctx.globalAlpha = faded ? 0.35 : 1;
    ctx.strokeStyle = colour.line;
    ctx.fillStyle = zone.method === active ? colour.strong : colour.fill;
    ctx.lineWidth = Math.max(3, canvas.width / (zone.method === active ? 110 : 200));
    if (zone.method === 'engrave') ctx.setLineDash([mm(4), mm(2)]);
    ctx.fillRect(...rect);
    ctx.strokeRect(...rect);
    ctx.restore();

    // The laser strip: one band as tall as the zone, somewhere across it.
    if (zone.method === 'engrave' && zone.strip && zone.strip < zone.w && (active === null || active === 'engrave') && options.stripAt !== null) {
      const at = Math.min(1, Math.max(0, options.stripAt ?? 0.5));
      const left = zone.x + (zone.w - zone.strip) * at;
      ctx.save();
      ctx.globalAlpha = active === 'engrave' ? 1 : 0.7;
      ctx.fillStyle = 'rgba(234, 88, 12, 0.30)';
      ctx.fillRect(mm(left), mm(zone.y), mm(zone.strip), mm(zone.h));
      ctx.strokeStyle = '#ea580c';
      ctx.lineWidth = Math.max(3, canvas.width / 160);
      ctx.strokeRect(mm(left), mm(zone.y), mm(zone.strip), mm(zone.h));
      ctx.restore();
    }
  }

  ctx.strokeStyle = '#e11d48';
  ctx.lineWidth = outline * 2;
  ctx.stroke(face);

  const font = Math.max(14, Math.min(canvas.width, canvas.height) / 9);
  const cm = (v: number) => String(Number((v / 10).toFixed(1)));
  ctx.fillStyle = '#e11d48';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.font = `700 ${font}px system-ui, sans-serif`;
  ctx.fillText(i18nT('studio.testPattern.top'), canvas.width / 2, font * 0.5);
  ctx.textBaseline = 'middle';
  ctx.font = `600 ${font * 0.7}px system-ui, sans-serif`;
  if (area.name) ctx.fillText(area.name, canvas.width / 2, canvas.height / 2 - font * 0.45, canvas.width * 0.9);
  if (options.showSize !== false) {
    ctx.fillText(options.showSize === true ? `${Math.round(w * 10) / 10} × ${Math.round(h * 10) / 10} ${i18nT('studio.common.mm')}` : `${cm(w)} × ${cm(h)} ${i18nT('studio.common.cm')}`, canvas.width / 2, canvas.height / 2 + font * 0.45);
  }
  // An "L" in the bottom-left corner makes mirroring obvious.
  ctx.textAlign = 'left';
  ctx.textBaseline = 'bottom';
  ctx.fillText('L', font * 0.4 + cornerPx * 0.3, canvas.height - font * 0.3 - cornerPx * 0.3);
  ctx.restore();
  return canvas;
}

type ApiArea = Pick<PrintArea, 'name' | 'width_mm' | 'height_mm' | 'methods'>;

const fromApi = (area: ApiArea): PatternArea => ({
  name: area.name,
  width: Number(area.width_mm),
  height: Number(area.height_mm),
  zones: area.methods.map(m => ({
    method: m.method, x: Number(m.zone_x_mm), y: Number(m.zone_y_mm), w: Number(m.zone_w_mm), h: Number(m.zone_h_mm),
    strip: m.strip_width_mm ? Number(m.strip_width_mm) : null,
  })),
});

export function testPatternCanvas(area: ApiArea, highlighted: boolean): HTMLCanvasElement {
  return areaPatternCanvas(fromApi(area), { highlighted, stripAt: null, showSize: true });
}

export function testPatternTexture(area: ApiArea, highlighted: boolean) {
  const texture = new THREE.CanvasTexture(testPatternCanvas(area, highlighted));
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 4;
  return texture;
}
