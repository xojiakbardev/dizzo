// The vector library behind graphic layers: basic shapes ("Elementlar") and
// icons ("Ikonkalar"). A graphic is drawn from these paths at any size, so
// the editor, the 3D textures and the print files get the same crisp edge.
// Every path stays inside its view box (control points included): the box
// is the layer's box, and ink outside it would leave the print zone.
import type { GraphicSource } from '~/lib/design/document';
import { ICON_VIEWBOX, ICONS } from '~/lib/design/icon-set';
import { i18nT } from '~/lib/i18n';

export interface GraphicPath { d: string; evenOdd?: boolean }

export interface GraphicDef {
  name: string;
  label: string; // Uzbek; graphicLabel() gives the page's language
  width: number; // view box, from (0, 0)
  height: number;
  paths: GraphicPath[];
}

export const SHAPES: GraphicDef[] = [
  { name: 'square', label: 'Kvadrat', width: 100, height: 100, paths: [{ d: 'M0 0H100V100H0Z' }] },
  {
    name: 'rounded', label: 'Yumaloq burchakli', width: 100, height: 100,
    paths: [{ d: 'M20 0H80A20 20 0 0 1 100 20V80A20 20 0 0 1 80 100H20A20 20 0 0 1 0 80V20A20 20 0 0 1 20 0Z' }],
  },
  { name: 'circle', label: 'Doira', width: 100, height: 100, paths: [{ d: 'M50 0A50 50 0 1 1 50 100A50 50 0 1 1 50 0Z' }] },
  { name: 'triangle', label: 'Uchburchak', width: 100, height: 87, paths: [{ d: 'M50 0L100 87H0Z' }] },
  {
    name: 'star', label: 'Yulduz', width: 100, height: 95.11,
    paths: [{ d: 'M50 0L62.36 35.56L100 36.33L70 59.07L80.9 95.11L50 73.6L19.1 95.11L30 59.07L0 36.33L37.64 35.56Z' }],
  },
  {
    name: 'heart', label: 'Yurak', width: 100, height: 92,
    paths: [{ d: 'M50 92C30 76 0 58 0 32C0 14 13 4 27 4C38 4 46 10 50 18C54 10 62 4 73 4C87 4 100 14 100 32C100 58 70 76 50 92Z' }],
  },
  { name: 'hexagon', label: 'Oltiburchak', width: 100, height: 86.6, paths: [{ d: 'M25 0H75L100 43.3L75 86.6H25L0 43.3Z' }] },
  { name: 'diamond', label: 'Romb', width: 100, height: 100, paths: [{ d: 'M50 0L100 50L50 100L0 50Z' }] },
  {
    name: 'burst', label: 'Nishon', width: 100, height: 100,
    paths: [{
      d: 'M50 0L59.84 13.29L75 6.7L76.87 23.13L93.3 25L86.71 40.16L100 50L86.71 59.84L93.3 75L76.87 76.87L75 93.3'
        + 'L59.84 86.71L50 100L40.16 86.71L25 93.3L23.13 76.87L6.7 75L13.29 59.84L0 50L13.29 40.16L6.7 25L23.13 23.13'
        + 'L25 6.7L40.16 13.29Z',
    }],
  },
  { name: 'semicircle', label: 'Yarim doira', width: 100, height: 50, paths: [{ d: 'M0 50A50 50 0 0 1 100 50Z' }] },
  {
    name: 'bubble', label: 'Nutq pufagi', width: 100, height: 90,
    paths: [{ d: 'M14 0H86A14 14 0 0 1 100 14V56A14 14 0 0 1 86 70H44L24 90V70H14A14 14 0 0 1 0 56V14A14 14 0 0 1 14 0Z' }],
  },
  { name: 'arrow', label: 'Strelka', width: 100, height: 60, paths: [{ d: 'M0 20H60V0L100 30L60 60V40H0Z' }] },
  { name: 'plus', label: 'Plyus', width: 100, height: 100, paths: [{ d: 'M35 0H65V35H100V65H65V100H35V65H0V35H35Z' }] },
  {
    name: 'ring', label: 'Halqa', width: 100, height: 100,
    paths: [{ d: 'M50 0A50 50 0 1 1 50 100A50 50 0 1 1 50 0ZM50 10A40 40 0 1 0 50 90A40 40 0 1 0 50 10Z', evenOdd: true }],
  },
  { name: 'frame', label: 'Ramka', width: 100, height: 100, paths: [{ d: 'M0 0H100V100H0ZM8 8V92H92V8Z', evenOdd: true }] },
  {
    name: 'frame-round', label: 'Yumaloq ramka', width: 100, height: 100,
    paths: [{
      d: 'M20 0H80A20 20 0 0 1 100 20V80A20 20 0 0 1 80 100H20A20 20 0 0 1 0 80V20A20 20 0 0 1 20 0Z'
        + 'M20 8A12 12 0 0 0 8 20V80A12 12 0 0 0 20 92H80A12 12 0 0 0 92 80V20A12 12 0 0 0 80 8Z',
      evenOdd: true,
    }],
  },
  { name: 'line', label: 'Chiziq', width: 100, height: 4, paths: [{ d: 'M0 0H100V4H0Z' }] },
  { name: 'line-double', label: 'Qo‘sh chiziq', width: 100, height: 10, paths: [{ d: 'M0 0H100V3H0ZM0 7H100V10H0Z' }] },
];

// Icon bodies are Iconify markup; only <path d> elements are used.
const iconPaths = new Map<string, GraphicPath[]>();
const [, , ICON_W, ICON_H] = ICON_VIEWBOX.split(' ').map(Number) as [number, number, number, number];

function pathsOf(body: string): GraphicPath[] {
  return [...body.matchAll(/<path\b([^>]*)>/g)].map((m) => {
    const attrs = m[1]!;
    return { d: /\bd="([^"]+)"/.exec(attrs)![1]!, evenOdd: /fill-rule="evenodd"/.test(attrs) };
  });
}

export function resolveGraphic(g: Pick<GraphicSource, 'library' | 'name'>): GraphicDef | null {
  if (g.library === 'shape') return SHAPES.find(s => s.name === g.name) ?? null;
  const icon = ICONS.find(i => i.name === g.name);
  if (!icon) return null;
  let paths = iconPaths.get(icon.name);
  if (!paths) {
    paths = pathsOf(icon.body);
    iconPaths.set(icon.name, paths);
  }
  return { name: icon.name, label: icon.label, width: ICON_W, height: ICON_H, paths };
}

/** A shape's or icon's name in the page's language (null: no such graphic). */
export function graphicLabel(g: Pick<GraphicSource, 'library' | 'name'>): string | null {
  const def = resolveGraphic(g);
  if (!def) return null;
  const key = `studio.graphics.${g.library === 'shape' ? 'shapes' : 'icons'}.${g.name}`;
  const label = i18nT(key);
  return label && label !== key ? label : def.label;
}

/** Fills the graphic into the box (-w/2, -h/2)–(w/2, h/2) of the current transform. */
export function drawGraphic(ctx: CanvasRenderingContext2D, def: GraphicDef, w: number, h: number, color: string) {
  ctx.save();
  ctx.translate(-w / 2, -h / 2);
  ctx.scale(w / def.width, h / def.height);
  ctx.fillStyle = color;
  for (const path of def.paths) ctx.fill(new Path2D(path.d), path.evenOdd ? 'evenodd' : 'nonzero');
  ctx.restore();
}
