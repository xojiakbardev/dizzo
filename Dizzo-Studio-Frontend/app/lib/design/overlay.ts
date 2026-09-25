// What the 3D editor draws over an area's design while editing: the print
// zones, the selected layer's frame with its corner and rotate handles,
// problem layers and the snap guides. Drawn into the same texture as the
// design, so it lies on the product's surface; never part of print files
// or mockups (the preview repaints without it before capturing).
import type { Layer, StripPosition } from '~/lib/design/document';
import { isLocked, printZone, zoneBox } from '~/lib/design/document';
import { cornersOf } from '~/lib/design/gestures';
import type { GapMark, Guide } from '~/lib/design/snap';
import type { CatalogMethod, PrintArea } from '~/types/catalog';

export interface OverlayState {
  strips: StripPosition[] | undefined; // the document's, as painted under the overlay
  selectedId: string | null;
  methods: CatalogMethod[];
  problems: Record<string, string[]>;
  guides: Guide[];
  gaps: GapMark[];
  handle: number; // handle size in mm
  readonly: boolean;
}

const RED = '#e11d48';
const PINK = '#ec4899';

/** `s`: canvas pixels per mm. */
export function drawOverlay(ctx: CanvasRenderingContext2D, area: PrintArea, layers: Layer[], state: OverlayState, s: number) {
  const px = (mm: number) => mm * s;
  const line = Math.max(1.5, state.handle * 0.16 * s);
  ctx.save();
  ctx.lineJoin = 'round';

  // print zones, dashed; a zone with a strip faint (where the strip may
  // travel), the strip itself as a zone
  ctx.setLineDash([line * 4, line * 3]);
  ctx.lineWidth = line * 0.8;
  for (const m of area.methods) {
    if (!state.methods.includes(m.method)) continue;
    const z = zoneBox(m);
    const strip = m.strip_width_mm ? printZone(area, m, layers, state.strips) : null;
    const [rgb, alpha] = m.method === 'uv' ? ['11, 126, 163', 0.75] : ['183, 121, 31', 0.8];
    ctx.strokeStyle = `rgba(${rgb}, ${strip ? 0.3 : alpha})`;
    ctx.strokeRect(px(z.x0), px(z.y0), px(z.x1 - z.x0), px(z.y1 - z.y0));
    if (!strip) continue;
    ctx.strokeStyle = `rgba(${rgb}, ${alpha})`;
    ctx.strokeRect(px(strip.x0), px(strip.y0), px(strip.x1 - strip.x0), px(strip.y1 - strip.y0));
  }

  // layers with problems, dashed red
  ctx.strokeStyle = RED;
  ctx.lineWidth = line;
  for (const layer of layers) {
    if (layer.area !== area.key || !state.problems[layer.id] || layer.id === state.selectedId) continue;
    outline(ctx, layer, s);
  }
  ctx.setLineDash([]);

  // snap guides and equal gaps
  ctx.strokeStyle = PINK;
  ctx.lineWidth = line * 0.8;
  for (const g of state.guides) {
    ctx.beginPath();
    if (g.axis === 'x') {
      ctx.moveTo(px(g.at), px(g.from));
      ctx.lineTo(px(g.at), px(g.to));
    }
    else {
      ctx.moveTo(px(g.from), px(g.at));
      ctx.lineTo(px(g.to), px(g.at));
    }
    ctx.stroke();
  }
  for (const m of state.gaps) {
    ctx.beginPath();
    if (m.axis === 'x') {
      ctx.moveTo(px(m.from), px(m.at));
      ctx.lineTo(px(m.to), px(m.at));
    }
    else {
      ctx.moveTo(px(m.at), px(m.from));
      ctx.lineTo(px(m.at), px(m.to));
    }
    ctx.stroke();
  }

  // the selected layer: frame, corners, rotate knob
  const selected = layers.find(l => l.id === state.selectedId && l.area === area.key);
  if (selected && !state.readonly) {
    const c = cornersOf(selected, state.handle);
    ctx.strokeStyle = RED;
    ctx.lineWidth = line;
    if (isLocked(selected)) {
      // Locked: its frame only, dashed — no handles to pull.
      ctx.setLineDash([line * 3, line * 2.5]);
      outline(ctx, selected, s);
      ctx.restore();
      return;
    }
    outline(ctx, selected, s);
    ctx.beginPath();
    ctx.moveTo(px(c.top.x), px(c.top.y));
    ctx.lineTo(px(c.rotate.x), px(c.rotate.y));
    ctx.stroke();
    ctx.fillStyle = '#ffffff';
    const h = px(state.handle);
    for (const p of c.points) {
      ctx.fillRect(px(p.x) - h / 2, px(p.y) - h / 2, h, h);
      ctx.strokeRect(px(p.x) - h / 2, px(p.y) - h / 2, h, h);
    }
    ctx.beginPath();
    ctx.arc(px(c.rotate.x), px(c.rotate.y), h * 0.55, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  }
  ctx.restore();
}

function outline(ctx: CanvasRenderingContext2D, layer: Layer, s: number) {
  const pts = cornersOf(layer, 0).points;
  ctx.beginPath();
  pts.forEach((p, i) => (i ? ctx.lineTo(p.x * s, p.y * s) : ctx.moveTo(p.x * s, p.y * s)));
  ctx.closePath();
  ctx.stroke();
}
