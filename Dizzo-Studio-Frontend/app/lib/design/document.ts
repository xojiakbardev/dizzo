// The Studio's design document — mirrors app/schemas/design.py.
//
// Millimetres in the print area: origin at the area's top-left corner,
// x right, y down. A layer is its centre, its unrotated size and a
// clockwise rotation in degrees. `area: null` = the current shape has no
// area with the layer's key; the layer is kept but never printed.
import type { AreaMethod, CatalogMethod, PrintArea } from '~/types/catalog';
import { i18nT } from '~/lib/i18n';

export const FONTS = [
  'Montserrat', 'Roboto', 'Open Sans', 'Rubik', 'Oswald', 'Lora', 'Playfair Display', 'PT Serif', 'Comfortaa',
  'Caveat', 'Lobster', 'Pacifico',
] as const;
export type Font = typeof FONTS[number];

export const MONO_COLOR = '#000000';

export interface ImageSource { media_id: string; url: string; px_w: number; px_h: number }

export interface TextSource {
  content: string;
  font: Font;
  size_mm: number;
  color: string;
  align: 'left' | 'center' | 'right';
  bold: boolean;
  italic: boolean;
}

/** A vector from the Studio's bundled library (lib/design/graphics.ts):
 * a basic shape or an icon, filled with one colour. */
// A sticker is many-coloured and drawn as it is; its colour stays MONO_COLOR.
export interface GraphicSource { library: 'shape' | 'icon' | 'sticker'; name: string; color: string }

/** A clock face's numerals and minute marks, laid out round the face (a
 * circle, or a rectangle with rounded corners). The layer covers the face. */
export interface DialSource {
  font: Font;
  size_mm: number;
  color: string;
  bold: boolean;
  italic: boolean;
  numerals: 'arabic' | 'roman' | 'none';
  ticks: boolean;
  face: 'round' | 'rect';
  corner_radius_mm: number;
}

export interface Layer {
  id: string;
  area: string | null;
  method: CatalogMethod;
  kind: 'image' | 'text' | 'graphic' | 'dial';
  x_mm: number;
  y_mm: number;
  w_mm: number;
  h_mm: number;
  rotation: number;
  image?: ImageSource;
  text?: TextSource;
  graphic?: GraphicSource;
  dial?: DialSource;
  // "user": locked by the customer; "system": by the Studio (clock numerals,
  // a coloured face) — the customer can't unlock it.
  locked?: 'user' | 'system';
}

/** The single ink colour of a text or graphic layer (images have none). */
export function layerColor(layer: Layer): string | null {
  return layer.text?.color ?? layer.graphic?.color ?? layer.dial?.color ?? null;
}

/** Synced areas: the target shows the source's layers — mirrored for an
 * admin-made mirrored pair — and has none of its own. One source may feed
 * several targets; a target is never a source. */
export interface AreaLink { source: string; target: string }

/** Where a method's strip (AreaMethod.strip_width_mm) sits in an area: its
 * left edge in area mm. It stays while the design moves inside it and is
 * pushed by the design's edge (followStrip). An area without one has the
 * strip centred on its layers (documents from before strips were stored). */
export interface StripPosition { area: string; method: CatalogMethod; x_mm: number }

export interface DesignDocument { version: 1; layers: Layer[]; links: AreaLink[]; strips?: StripPosition[] }

export const emptyDocument = (): DesignDocument => ({ version: 1, layers: [], links: [], strips: [] });

/** Documents saved before links (or strips) existed have none. */
export function normaliseDocument(doc: DesignDocument): DesignDocument {
  const strips = Array.isArray(doc.strips)
    ? doc.strips.filter(s => s && typeof s.area === 'string' && typeof s.method === 'string' && Number.isFinite(s.x_mm))
    : [];
  return { ...doc, links: doc.links ?? [], strips };
}

/** A "background": the print face filled with the product's colour (the
 * Studio adds, recolours and removes it; it isn't picked up by a press). */
export const BACKGROUND_PREFIX = 'bg-';
export const isBackgroundLayer = (layer: Pick<Layer, 'id'>) => layer.id.startsWith(BACKGROUND_PREFIX);

/** Doesn't move, resize or turn (the customer's lock or the Studio's). */
export const isLocked = (layer: Pick<Layer, 'id' | 'locked'>) => Boolean(layer.locked) || isBackgroundLayer(layer);

export function newLayerId(): string {
  return `l${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
}

// ── Geometry ────────────────────────────────────────────────────────────

export interface Box { x0: number; y0: number; x1: number; y1: number }

/** Axis-aligned bounds of the rotated layer (same as the backend). */
export function layerBox(layer: Pick<Layer, 'x_mm' | 'y_mm' | 'w_mm' | 'h_mm' | 'rotation'>): Box {
  const a = (layer.rotation * Math.PI) / 180;
  const hw = Math.abs((layer.w_mm / 2) * Math.cos(a)) + Math.abs((layer.h_mm / 2) * Math.sin(a));
  const hh = Math.abs((layer.w_mm / 2) * Math.sin(a)) + Math.abs((layer.h_mm / 2) * Math.cos(a));
  return { x0: layer.x_mm - hw, y0: layer.y_mm - hh, x1: layer.x_mm + hw, y1: layer.y_mm + hh };
}

export function zoneBox(method: AreaMethod): Box {
  const x = Number(method.zone_x_mm);
  const y = Number(method.zone_y_mm);
  return { x0: x, y0: y, x1: x + Number(method.zone_w_mm), y1: y + Number(method.zone_h_mm) };
}

/** `a` cut down to `b`; empty (width or height ≤ 0) when they miss. */
export const overlap = (a: Box, b: Box): Box =>
  ({ x0: Math.max(a.x0, b.x0), y0: Math.max(a.y0, b.y0), x1: Math.min(a.x1, b.x1), y1: Math.min(a.y1, b.y1) });

// ── Per-size print scaling ──────────────────────────────────────────────
// A shape's print area is measured for the LARGEST size (40 × 40 cm on a
// t-shirt is the maximum). A smaller size prints a proportionally smaller
// picture: a box `scale` of the area's width and height, centred on the
// same anchor. Layer millimetres never change with the size — the box
// around them does, so switching size never moves a design, it only says
// whether it still fits. The backend's design_rules.size_box.

/** The chosen size's share of the print area (VariantSize.print_scale),
 * as a number in (0, 1]. */
export const printScaleOf = (size: { print_scale?: string } | null | undefined): number => {
  const scale = Number(size?.print_scale ?? 1);
  return Number.isFinite(scale) && scale > 0 && scale <= 1 ? scale : 1;
};

/** What a size may print of the area. null at scale 1 (the largest size,
 * and everything without sizes): the whole area, as before sizes scaled. */
export function sizeBox(area: Pick<PrintArea, 'width_mm' | 'height_mm'>, scale: number): Box | null {
  if (!(scale < 1)) return null;
  const w = Number(area.width_mm);
  const h = Number(area.height_mm);
  return { x0: (w * (1 - scale)) / 2, y0: (h * (1 - scale)) / 2, x1: (w * (1 + scale)) / 2, y1: (h * (1 + scale)) / 2 };
}

/** The print file's millimetres for a size (the size box's), rounded the
 * way a stored millimetre is — the backend's design_rules.size_mm. */
export function sizeMm(area: Pick<PrintArea, 'width_mm' | 'height_mm'>, scale: number): { w: number; h: number } {
  const round2 = (v: number) => Math.round(v * 100) / 100;
  return { w: round2(Number(area.width_mm) * scale), h: round2(Number(area.height_mm) * scale) };
}

/** The area as the chosen size leaves it: the same millimetres (layer
 * coordinates are absolute) with every method's zone cut down to the size
 * box. Hand this to everything that draws, measures or checks a design and
 * the whole Studio shrinks with the size in one step. */
export function sizedArea(area: PrintArea, scale: number): PrintArea {
  const limit = sizeBox(area, scale);
  if (!limit) return area;
  const mm = (v: number) => Math.max(0, Math.round(v * 100) / 100).toFixed(2);
  return {
    ...area,
    methods: area.methods.map((m) => {
      const box = overlap(zoneBox(m), limit);
      return {
        ...m,
        zone_x_mm: mm(box.x0),
        zone_y_mm: mm(box.y0),
        zone_w_mm: mm(box.x1 - box.x0),
        zone_h_mm: mm(box.y1 - box.y0),
      };
    }),
  };
}

export const sizedAreas = (areas: PrintArea[], scale: number): PrintArea[] =>
  (scale < 1 ? areas.map(a => sizedArea(a, scale)) : areas);

/** The strip's width, when the method has one (never wider than the zone). */
export function stripWidth(method: AreaMethod, zone: Box = zoneBox(method)): number | null {
  return method.strip_width_mm ? Math.min(Number(method.strip_width_mm), zone.x1 - zone.x0) : null;
}

/** A horizontal extent; empty when lo > hi. */
export interface Span { lo: number; hi: number }

/** Across the zone, what the method's layers in the area cover of it
 * (what lies outside is cropped anyway); `skip`: a layer left out. */
function spanInZone(area: string | null, method: AreaMethod, zone: Box, layers: Layer[], skip?: string): Span {
  let lo = Infinity;
  let hi = -Infinity;
  for (const l of layers) {
    if (l.area !== area || l.method !== method.method || l.id === skip) continue;
    const b = layerBox(l);
    if (b.x1 <= zone.x0 || b.x0 >= zone.x1 || b.y1 <= zone.y0 || b.y0 >= zone.y1) continue;
    lo = Math.min(lo, Math.max(b.x0, zone.x0));
    hi = Math.max(hi, Math.min(b.x1, zone.x1));
  }
  return { lo, hi };
}

const clampStrip = (x: number, zone: Box, width: number) => Math.min(Math.max(x, zone.x0), zone.x1 - width);

/** The strip's left edge once the design covers `span`: it stays while the
 * design is inside it and is pushed by the design's edge otherwise, always
 * inside the zone. A design wider than the strip (only older designs, or
 * one that can't shrink further) doesn't move it. The backend's
 * design_rules.follow_strip. */
export function followStrip(x: number, span: Span, zone: Box, width: number): number {
  let next = x;
  if (span.lo <= span.hi && span.hi - span.lo <= width + 1e-6) {
    if (span.lo < next) next = span.lo;
    else if (span.hi > next + width) next = span.hi - width;
  }
  return clampStrip(next, zone, width);
}

/** The left edge of a strip centred on `span` (the rule before strips were stored). */
const centredStrip = (span: Span, zone: Box, width: number) =>
  clampStrip((span.lo <= span.hi ? (span.lo + span.hi) / 2 : (zone.x0 + zone.x1) / 2) - width / 2, zone, width);

export function storedStrip(strips: StripPosition[] | undefined, area: string, method: CatalogMethod): number | null {
  return strips?.find(s => s.area === area && s.method === method)?.x_mm ?? null;
}

/** Where a method's layers are printed: its zone, or — with a strip width
 * (a laser reaches only so far round a curved body) — a strip that wide and
 * as tall as the zone, where the document stored it (`strips`) or else
 * centred on the method's layers in the area, always inside the zone.
 * The backend's design_rules.print_zone. */
export function printZone(area: PrintArea, method: AreaMethod, layers: Layer[], strips: StripPosition[] | undefined): Box {
  const zone = zoneBox(method);
  const width = stripWidth(method, zone);
  if (width === null) return zone;
  const stored = storedStrip(strips, area.key, method.method);
  const x0 = stored === null ? centredStrip(spanInZone(area.key, method, zone, layers), zone, width) : clampStrip(stored, zone, width);
  return { x0, y0: zone.y0, x1: x0 + width, y1: zone.y1 };
}

/** The document with its strips brought up to date with its layers: an
 * area's strip method that got layers gets a strip (centred on them), one
 * whose layers moved past its edge follows them (followStrip), one with no
 * layers left (or no strip on this shape) is dropped. The same document
 * when nothing changes. Only the document's own layers count: a synced
 * area has none, and its copies keep the centred strip. */
export function settleStrips(doc: DesignDocument, areas: PrintArea[]): DesignDocument {
  if (!areas.length) return doc;
  const strips: StripPosition[] = [];
  for (const area of areas) {
    for (const m of area.methods) {
      const zone = zoneBox(m);
      const width = stripWidth(m, zone);
      if (width === null || !doc.layers.some(l => l.area === area.key && l.method === m.method)) continue;
      const span = spanInZone(area.key, m, zone, doc.layers);
      const stored = storedStrip(doc.strips, area.key, m.method);
      const x = stored === null ? centredStrip(span, zone, width) : followStrip(stored, span, zone, width);
      strips.push({ area: area.key, method: m.method, x_mm: x });
    }
  }
  const old = doc.strips ?? [];
  const same = strips.length === old.length
    && strips.every((s, i) => s.area === old[i]!.area && s.method === old[i]!.method && s.x_mm === old[i]!.x_mm);
  return same ? doc : { ...doc, strips };
}

/** Across the zone, where a layer may go so that it and the area's other
 * `layers` on its method still fit one strip; null without a strip. */
function stripRoom(layer: Layer, method: AreaMethod, layers: Layer[]): (Span & { width: number }) | null {
  const zone = zoneBox(method);
  const width = stripWidth(method, zone);
  if (width === null) return null;
  const others = spanInZone(layer.area, method, zone, layers, layer.id);
  return { lo: Math.max(zone.x0, others.hi - width), hi: Math.min(zone.x1, others.lo + width), width };
}

/** Moves the layer across (never resizes it) into its stripRoom. A layer
 * that can't fit there (wider than the strip, or an older design) is left
 * where it is. */
export function keepInStrip<T extends Layer>(layer: T, method: AreaMethod, layers: Layer[]): T {
  const room = stripRoom(layer, method, layers);
  if (!room) return layer;
  const box = layerBox(layer);
  const w = box.x1 - box.x0;
  if (w > room.width + 1e-9 || w > room.hi - room.lo + 1e-9) return layer;
  const dx = box.x0 < room.lo ? room.lo - box.x0 : box.x1 > room.hi ? room.hi - box.x1 : 0;
  return dx ? { ...layer, x_mm: layer.x_mm + dx } : layer;
}

/** A layer arriving on a method with a strip (added, duplicated, placed,
 * converted): placeInZone, then moved across into the strip where it is
 * now, so the strip doesn't move for it. Where the area has no strip yet
 * (no stored one, no other layers) it stays, and the strip is centred on
 * it; a layer wider than the strip only keeps to keepInStrip. `layers`:
 * the area's. */
export function placeInStrip<T extends Layer>(
  layer: T, area: PrintArea, method: AreaMethod, layers: Layer[], strips: StripPosition[] | undefined,
): T {
  const placed = placeInZone(layer, method, layers);
  const others = layers.filter(l => l.id !== layer.id && l.area === area.key && l.method === method.method);
  if (stripWidth(method) === null || (storedStrip(strips, area.key, method.method) === null && !others.length)) return placed;
  const strip = printZone(area, method, others, strips);
  const box = layerBox(placed);
  if (box.x1 - box.x0 > strip.x1 - strip.x0 + 1e-9) return placed;
  const dx = box.x0 < strip.x0 ? strip.x0 - box.x0 : box.x1 > strip.x1 ? strip.x1 - box.x1 : 0;
  return dx ? { ...placed, x_mm: placed.x_mm + dx } : placed;
}

/** The layers placed one by one into their strips (placeInStrip), each
 * next to the ones before it (after a method change or a template). */
export function fitIntoStrips(layers: Layer[], areas: PrintArea[], strips: StripPosition[] | undefined): Layer[] {
  const out: Layer[] = [];
  for (const l of layers) {
    const area = areas.find(a => a.key === l.area);
    const m = area && areaMethod(area, l.method);
    out.push(area && m ? placeInStrip(l, area, m, out, strips) : l);
  }
  return out;
}

// Backend slack (design_rules.TOLERANCE_MM) is 0.5; stay well inside it.
const EPS = 0.05;

export function inside(box: Box, zone: Box): boolean {
  return box.x0 >= zone.x0 - EPS && box.y0 >= zone.y0 - EPS && box.x1 <= zone.x1 + EPS && box.y1 <= zone.y1 + EPS;
}

/** Largest uniform scale (≤ 1) that makes the rotated layer fit the zone
 * and the method's max size. */
export function fitScale(layer: Layer, method: AreaMethod): number {
  return Math.min(1, roomScale(layer, method));
}

/** How far the layer could scale and still fit the zone (and max size,
 * and the strip). */
function roomScale(layer: Layer, method: AreaMethod): number {
  const box = layerBox(layer);
  const zone = zoneBox(method);
  const width = box.x1 - box.x0;
  const height = box.y1 - box.y0;
  const maxW = Math.min(stripWidth(method, zone) ?? zone.x1 - zone.x0, method.max_width_mm ? Number(method.max_width_mm) : Infinity);
  const maxH = Math.min(zone.y1 - zone.y0, method.max_height_mm ? Number(method.max_height_mm) : Infinity);
  return Math.min(maxW / width, maxH / height);
}

/** How far the layer could scale about its centre with all the method's
 * layers still in one strip (Infinity without a strip). When they already
 * don't fit, it may only stay as it is or shrink. */
function stripScale(layer: Layer, method: AreaMethod, layers: Layer[]): number {
  const zone = zoneBox(method);
  const width = stripWidth(method, zone);
  if (width === null) return Infinity;
  const box = layerBox(layer);
  const half = (box.x1 - box.x0) / 2;
  const cx = (box.x0 + box.x1) / 2;
  const others = spanInZone(layer.area, method, zone, layers, layer.id);
  const lo = Math.min(others.lo, cx);
  const hi = Math.max(others.hi, cx);
  // The span max(hi, cx + half·f) − min(lo, cx − half·f) stays ≤ width.
  const f = Math.min((width - (cx - lo)) / half, (width - (hi - cx)) / half, width / (2 * half));
  return Math.max(f, 1);
}

/** Moves the layer (never resizes it) so its bounds lie inside the zone as
 * far as possible. */
export function clampIntoZone<T extends Pick<Layer, 'x_mm' | 'y_mm' | 'w_mm' | 'h_mm' | 'rotation'>>(layer: T, method: AreaMethod): T {
  return clampInto(layer, zoneBox(method));
}

/** clampIntoZone for any box (a strip). */
export function clampInto<T extends Pick<Layer, 'x_mm' | 'y_mm' | 'w_mm' | 'h_mm' | 'rotation'>>(layer: T, zone: Box): T {
  const box = layerBox(layer);
  let dx = 0;
  let dy = 0;
  if (box.x1 - box.x0 <= zone.x1 - zone.x0) {
    if (box.x0 < zone.x0) dx = zone.x0 - box.x0;
    else if (box.x1 > zone.x1) dx = zone.x1 - box.x1;
  }
  else {
    dx = (zone.x0 + zone.x1) / 2 - layer.x_mm;
  }
  if (box.y1 - box.y0 <= zone.y1 - zone.y0) {
    if (box.y0 < zone.y0) dy = zone.y0 - box.y0;
    else if (box.y1 > zone.y1) dy = zone.y1 - box.y1;
  }
  else {
    dy = (zone.y0 + zone.y1) / 2 - layer.y_mm;
  }
  return { ...layer, x_mm: layer.x_mm + dx, y_mm: layer.y_mm + dy };
}

/** Anything may stick out of the zone: the print file keeps only what is
 * inside it (the customer is told). Clock numerals are laid out on the
 * face itself. The backend's design_rules.crops. */
export const crops = (layer: Pick<Layer, 'kind'>) => layer.kind !== 'dial';

/** Part of it lies outside the zone (or the strip) and won't be printed.
 * `layers`: everything placed, `strips`: the document's, for where a strip is. */
export function sticksOut(layer: Layer, areas: PrintArea[], layers: Layer[], strips: StripPosition[] | undefined): boolean {
  const area = areas.find(a => a.key === layer.area);
  const method = area && areaMethod(area, layer.method);
  return Boolean(area && method && crops(layer) && !inside(layerBox(layer), printZone(area, method, layers, strips)));
}

/** Keeps a layer where it can be printed: clock numerals wholly inside the
 * zone, anything else with its centre inside. With `layers` (the area's)
 * and a strip, also across so that it and the others fit one strip — which
 * then follows it (settleStrips). */
export function placeInZone<T extends Layer>(layer: T, method: AreaMethod, layers?: Layer[]): T {
  let placed: T;
  if (!crops(layer)) {
    placed = clampIntoZone(layer, method);
  }
  else {
    const zone = zoneBox(method);
    placed = { ...layer, x_mm: Math.min(zone.x1, Math.max(zone.x0, layer.x_mm)), y_mm: Math.min(zone.y1, Math.max(zone.y0, layer.y_mm)) };
  }
  return layers ? keepInStrip(placed, method, layers) : placed;
}

/** The largest scale a layer may take: text up to the zone (and max size),
 * a cropped layer up to three times the zone — and with a strip, never so
 * wide that the method's layers (`layers`, the area's) outgrow it. */
export function growLimit(layer: Layer, method: AreaMethod, layers: Layer[] = []): number {
  // (fitScale caps at 1, which kept text from ever being dragged bigger)
  const strip = stripScale(layer, method, layers);
  if (!crops(layer)) return Math.min(roomScale(layer, method), strip);
  const zone = zoneBox(method);
  return Math.min(strip, (3 * Math.max(zone.x1 - zone.x0, zone.y1 - zone.y0)) / Math.max(layer.w_mm, layer.h_mm));
}

/** Pixels for a length at a DPI — the backend's print_files.expected_pixels. */
export function pixelsAt(mm: number, dpi: number): number {
  return Math.floor((mm * dpi) / 25.4 + 0.5);
}

export function areaMethod(area: PrintArea, method: CatalogMethod): AreaMethod | undefined {
  return area.methods.find(m => m.method === method);
}

export const MIN_DPI = 100;
export const LOW_DPI = 150;

/** Effective resolution of an image layer as placed (for the low-quality warning/blocking). */
export function imageDpi(layer: Layer): number | null {
  if (!layer.image) return null;
  return Math.min(layer.image.px_w / (layer.w_mm / 25.4), layer.image.px_h / (layer.h_mm / 25.4));
}

// ── Problems (same rules as the backend's design_rules) ─────────────────

export interface LayerProblem { layerId: string; message: string }

export function layerLabel(layer: Layer): string {
  if (layer.text) {
    const content = layer.text.content.replace(/\n/g, ' ');
    return i18nT('studio.layer.textNamed', { text: `${content.slice(0, 24)}${content.length > 24 ? '…' : ''}` });
  }
  if (layer.graphic) return i18nT(`studio.layer.kind.${layer.graphic.library}`);
  if (layer.dial) return i18nT('studio.layer.dial');
  return i18nT('studio.layer.image');
}

/** The size a design is being made for: its label and what it may print
 * (VariantSize.print_scale). null on a product without sizes. */
export interface PrintSize { label: string; scale: number }

/** `layers`: everything placed, `strips`: the document's, for where a strip
 * is, `printSize`: the chosen size, whose box the design has to fit. */
export function layerProblems(
  layer: Layer, areas: PrintArea[], methods: CatalogMethod[], layers: Layer[], strips: StripPosition[] | undefined,
  printSize?: PrintSize | null,
): string[] {
  if (layer.area === null) return [];
  const area = areas.find(a => a.key === layer.area);
  if (!area) return [i18nT('studio.problems.noArea', { area: layer.area })];
  const method = areaMethod(area, layer.method);
  if (!method || !methods.includes(layer.method)) return [i18nT('studio.problems.noMethod', { area: area.name })];
  const problems: string[] = [];
  const zone = printZone(area, method, layers, strips);
  // A smaller size prints a smaller picture: what does not fit its box is
  // refused, never quietly cropped — the box is on screen while designing.
  const limit = printSize ? sizeBox(area, printSize.scale) : null;
  if (limit && !inside(layerBox(layer), limit)) {
    const mm = sizeMm(area, printSize!.scale);
    problems.push(i18nT('studio.problems.tooBigForSize', { size: printSize!.label, width: mm.w, height: mm.h }));
  }
  let box = layerBox(layer);
  if (crops(layer)) {
    box = { x0: Math.max(box.x0, zone.x0), y0: Math.max(box.y0, zone.y0), x1: Math.min(box.x1, zone.x1), y1: Math.min(box.y1, zone.y1) };
  }
  else if (!inside(box, zone)) {
    problems.push(i18nT('studio.problems.outside'));
  }
  if (method.max_width_mm && box.x1 - box.x0 > Number(method.max_width_mm) + EPS) problems.push(i18nT('studio.problems.maxWidth', { mm: Number(method.max_width_mm) }));
  if (method.max_height_mm && box.y1 - box.y0 > Number(method.max_height_mm) + EPS) problems.push(i18nT('studio.problems.maxHeight', { mm: Number(method.max_height_mm) }));
  const color = layerColor(layer);
  if (color && !method.colors_allowed && color.toLowerCase() !== MONO_COLOR) problems.push(i18nT('studio.problems.noColor'));
  const size = layer.text?.size_mm ?? layer.dial?.size_mm;
  if (size !== undefined && method.min_font_mm && size < Number(method.min_font_mm) - 1e-6) {
    problems.push(i18nT('studio.problems.minFont', { mm: Number(method.min_font_mm) }));
  }
  if (layer.image) {
    const dpi = imageDpi(layer);
    if (dpi !== null && dpi < MIN_DPI - 1e-3) {
      problems.push(i18nT('studio.problems.lowDpi', { dpi: Math.round(dpi) }));
    }
  }
  return problems;
}

/** The whole design is printed one way — colour print or laser engraving:
 * what its layers use, else the one chosen, else the type's first. */
export function designMethodOf(layers: Layer[], methods: CatalogMethod[], preferred: CatalogMethod | null): CatalogMethod | null {
  const used = layers.find(l => methods.includes(l.method))?.method;
  if (used) return used;
  if (preferred && methods.includes(preferred)) return preferred;
  return methods[0] ?? null;
}

/** The design's problems by layer id (`layers`: the effective ones); a
 * copy's problem is also reported on its source layer. */
export function designProblems(
  layers: Layer[], areas: PrintArea[], methods: CatalogMethod[], designMethod: CatalogMethod | null,
  strips: StripPosition[] | undefined, printSize?: PrintSize | null,
): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const l of layers) {
    const list = layerProblems(l, areas, methods, layers, strips, printSize);
    if (designMethod && l.method !== designMethod) list.push(i18nT('studio.problems.otherMethod'));
    if (!list.length) continue;
    out[l.id] = list;
    if (isCopy(l.id)) {
      const where = areas.find(a => a.key === l.area)?.name ?? l.area;
      (out[sourceId(l.id)] ??= []).push(...list.map(p => `${where}: ${p}`));
    }
  }
  return out;
}

/** How many layers of the design (copies not counted) have a problem. */
export const problemCount = (problems: Record<string, string[]>) => Object.keys(problems).filter(id => !isCopy(id)).length;

// ── Area pairs ───────────────────────────────────────────────────────────

const COPY_MARK = '@';

export const isCopy = (id: string) => id.includes(COPY_MARK);
export const sourceId = (id: string) => id.split(COPY_MARK)[0]!;

export function isPair(source: PrintArea, target: PrintArea): boolean {
  return source.pair_key === target.key && target.pair_key === source.key;
}

/** An admin-made pair, or any two areas of the same size (the backend's
 * design_rules.linkable). */
export function linkable(source: PrintArea, target: PrintArea): boolean {
  const sameSize = Number(source.width_mm) === Number(target.width_mm) && Number(source.height_mm) === Number(target.height_mm);
  return source.key !== target.key && (isPair(source, target) || sameSize);
}

export const mirrored = (source: PrintArea, target: PrintArea) => isPair(source, target) && target.pair_mirror;

/** A layer as it appears on a synced area (the backend's
 * design_rules.copy_to_partner): same place, or mirrored left-right. */
export function copyToPartner(layer: Layer, source: PrintArea, target: PrintArea): Layer {
  const base = { ...layer, id: `${layer.id}${COPY_MARK}${target.key}`, area: target.key };
  return mirrored(source, target) ? { ...base, x_mm: Number(target.width_mm) - layer.x_mm, rotation: -layer.rotation } : base;
}

/** The links whose areas exist on this shape and can be synced. */
export function validLinks(doc: DesignDocument, areas: PrintArea[]): Array<{ source: PrintArea; target: PrintArea }> {
  return doc.links.flatMap((link) => {
    const source = areas.find(a => a.key === link.source);
    const target = areas.find(a => a.key === link.target);
    return source && target && linkable(source, target) ? [{ source, target }] : [];
  });
}

/** Placed layers plus the copies synced areas add — what gets printed. */
export function effectiveLayers(doc: DesignDocument, areas: PrintArea[]): Layer[] {
  const layers = doc.layers.filter(l => l.area !== null);
  for (const { source, target } of validLinks(doc, areas)) {
    layers.push(...doc.layers.filter(l => l.area === source.key).map(l => copyToPartner(l, source, target)));
  }
  // Dial numerals and markings must always sit on top of background images and customer designs
  const dials: Layer[] = [];
  const others: Layer[] = [];
  for (const l of layers) {
    if (l.dial) dials.push(l);
    else others.push(l);
  }
  return dials.length ? [...others, ...dials] : layers;
}

/** The area this one is synced from, if it is a target. */
export const syncedFrom = (doc: DesignDocument, key: string) => doc.links.find(l => l.target === key)?.source ?? null;
/** The areas that show this one's design. */
export const syncTargets = (doc: DesignDocument, key: string) => doc.links.filter(l => l.source === key).map(l => l.target);

/** The (area, method) pairs that need a print file, linked partners included. */
export function printTargets(layers: Layer[]): Array<{ area: string; method: CatalogMethod }> {
  const seen = new Map<string, { area: string; method: CatalogMethod }>();
  for (const layer of layers) {
    if (layer.area !== null) seen.set(`${layer.area}:${layer.method}`, { area: layer.area, method: layer.method });
  }
  return [...seen.values()];
}
