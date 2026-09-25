// The Studio's rendering engine for a host that draws the editor itself
// (the mobile app, in a WebView on /embed/engine): the same 3D scene, area
// textures, mockups, print files and measurement as the Studio, driven by
// method calls. Loaded with a dynamic import (it pulls in three.js); the
// page serialises the calls, so no two run at once. docs/EMBED_ENGINE.md is
// the protocol.
import { faceOf, isDialArea } from '~/lib/design/dial';
import type { DesignDocument, Layer } from '~/lib/design/document';
import {
  designMethodOf, designProblems, effectiveLayers, emptyDocument, isCopy, normaliseDocument, pixelsAt, printScaleOf,
  printTargets, printZone, problemCount, settleStrips, sizedAreas, sizeMm, sticksOut, zoneBox,
} from '~/lib/design/document';
import { measureAreas, printJobs, usedAreas } from '~/lib/design/output';
import { paintPreview, prepareAssets, previewCanvas, renderPrintFile } from '~/lib/design/render';
import { ENGRAVE_TINT } from '~/lib/three/materials';
import { StudioScene } from '~/lib/three/studioScene';
import type { PrintArea, PublicColor, PublicProductDetail, PublicShape, PublicVariant } from '~/types/catalog';

/** A refused call: its message goes back to the host as is. */
export class EngineError extends Error {
  override name = 'EngineError';
}

/** A call's params, as the host's JSON has them. */
export type Params = Record<string, unknown>;

const id = (v: unknown) => (typeof v === 'number' && Number.isInteger(v) ? v : null);

const num = (v: string | null | undefined) => (v === null || v === undefined || v === '' ? null : Number(v));
const clampSize = (v: unknown, fallback: number) =>
  Math.round(Math.min(4096, Math.max(64, typeof v === 'number' && Number.isFinite(v) ? v : fallback)));

function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error ?? new Error('could not read the file'));
    reader.readAsDataURL(blob);
  });
}

export class EmbedEngine {
  private readonly scene: StudioScene;
  private product: PublicProductDetail | null = null;
  private variant: PublicVariant | null = null;
  private color: PublicColor | null = null;
  private shape: PublicShape | null = null;
  private doc: DesignDocument = emptyDocument();
  // The clothing size being designed for, null on a product without sizes.
  // It decides how much of each print area may be used (VariantSize
  // .print_scale), so the host must set it before it renders print files.
  private sizeLabel: string | null = null;
  private readonly canvases = new Map<string, HTMLCanvasElement>();
  // What the view shows: an area's framing, or a preset. Until the user
  // turns the product it is framed again whenever the view changes size.
  private area: string | null = null;
  private preset: number | null = null;
  private turned = false;

  constructor(canvas: HTMLCanvasElement, private readonly fetchProduct: (slug: string) => Promise<PublicProductDetail>) {
    this.scene = new StudioScene(canvas);
    // The host view is the whole page: one finger turns, a pinch zooms.
    const controls = this.scene.viewer.controls;
    controls.enableZoom = true;
    controls.enablePan = false;
    this.scene.onUserTurn(() => (this.turned = true));
  }

  /** `phase` start / end of a turn or pinch by the user. */
  onUserView(listener: (phase: 'start' | 'end') => void) {
    const controls = this.scene.viewer.controls;
    controls.addEventListener('start', () => listener('start'));
    controls.addEventListener('end', () => listener('end'));
  }

  /** 100 = the product as framed; more when zoomed in. */
  zoom(): number {
    const { baseDistance } = this.scene;
    return baseDistance ? Math.round((baseDistance / Math.max(this.scene.viewDistance(), 1e-6)) * 100) : 100;
  }

  get shownArea() {
    return this.area;
  }

  resize(width: number, height: number) {
    this.scene.viewer.resize(width, height, () => {
      if (this.shape && !this.turned) this.reframe();
    });
  }

  private reframe() {
    if (this.preset !== null) this.scene.viewPreset(this.preset);
    else if (this.area) this.scene.viewArea(this.area);
    else this.scene.viewAll();
  }

  private need() {
    if (!this.product || !this.variant || !this.color || !this.shape) throw new EngineError('no product loaded: call load first');
    return { product: this.product, variant: this.variant, color: this.color, shape: this.shape };
  }

  /** The chosen size, if it is one the variant sells. */
  private size() {
    return this.variant?.sizes.find(s => s.is_available && s.label === this.sizeLabel) ?? null;
  }

  private scale() {
    return printScaleOf(this.size());
  }

  private printSize() {
    const size = this.size();
    return size && this.scale() < 1 ? { label: size.label, scale: this.scale() } : null;
  }

  /** The shape's areas as the chosen size leaves them: the same millimetres
   * with every zone cut down to what that size prints. Everything that
   * draws, measures or checks a design uses these. */
  private areas() {
    return sizedAreas(this.shape?.areas ?? [], this.scale());
  }

  /** The size picked by the host, or the first one in stock on a product
   * that has sizes (never left unset: the print files depend on it). */
  private pickSize(label: unknown) {
    const sizes = this.variant?.sizes.filter(s => s.is_available) ?? [];
    if (typeof label === 'string' && label) {
      if (!sizes.some(s => s.label === label)) throw new EngineError(`size "${label}" is not on sale for this variant`);
      this.sizeLabel = label;
    }
    if (!sizes.some(s => s.label === this.sizeLabel)) this.sizeLabel = sizes[0]?.label ?? null;
  }

  private effective() {
    return effectiveLayers(this.doc, this.areas());
  }

  // ── Product ──

  async load(params: Params) {
    if (typeof params.productSlug !== 'string' || !params.productSlug) throw new EngineError('productSlug is required');
    this.product = await this.fetchProduct(params.productSlug);
    this.shape = null;
    return this.apply(id(params.variantId), id(params.colorId), params.size);
  }

  async setAppearance(params: Params) {
    const { variant } = this.need();
    return this.apply(id(params.variantId) ?? variant.id, id(params.colorId), params.size);
  }

  /** The clothing size. A smaller size prints a smaller picture, so the
   * zones, the 3D decal, the measured area and the print files all follow
   * it — and a design that no longer fits comes back as a problem. */
  async setSize(params: Params) {
    const { variant, shape } = this.need();
    this.pickSize(params.size);
    await this.paint();
    const layers = this.effective();
    const biggest = shape.areas.reduce<PrintArea | null>(
      (best, a) => (!best || Number(a.width_mm) * Number(a.height_mm) > Number(best.width_mm) * Number(best.height_mm) ? a : best),
      null,
    );
    const problems = designProblems(
      layers, this.areas(), variant.methods, designMethodOf(this.doc.layers, variant.methods, null),
      this.doc.strips, this.printSize(),
    );
    return {
      size: this.sizeLabel,
      printScale: this.scale(),
      printAreaMm: biggest ? sizeMm(biggest, this.scale()) : null,
      problems,
      problemCount: problemCount(problems),
    };
  }

  /** Chooses the type and colour (a colour not given: the current one if
   * the type has it, else its first) and builds the shape when it changes. */
  private async apply(variantId: number | null, colorId: number | null, size?: unknown) {
    const product = this.product!;
    const variant = variantId === null ? product.variants[0] : product.variants.find(v => v.id === variantId);
    if (!variant) throw new EngineError(variantId === null ? 'the product has nothing on sale' : `variant ${variantId} is not on sale`);
    const color = colorId !== null
      ? variant.colors.find(c => c.id === colorId)
      : variant.colors.find(c => c.id === this.color?.id) ?? variant.colors[0];
    if (!color) throw new EngineError(colorId === null ? `variant ${variant.id} has no colour on sale` : `colour ${colorId} is not on sale for variant ${variant.id}`);
    const shape = product.shapes.find(s => s.id === variant.shape_id);
    if (!shape) throw new EngineError(`variant ${variant.id} has no shape`);
    const shapeChanged = shape.id !== this.shape?.id;
    this.variant = variant;
    this.color = color;
    this.pickSize(size);
    if (shapeChanged) {
      this.shape = null;
      this.canvases.clear();
      if (!(await this.scene.setShape(shape, variant.material, color.hex))) throw new EngineError('superseded by another load');
      this.shape = shape;
      this.doc = settleStrips(this.doc, shape.areas);
      if (!shape.areas.some(a => a.key === this.area)) this.area = shape.areas[0]?.key ?? null;
      this.preset = null;
      this.turned = false;
      await this.paint();
      this.reframe();
      // Answered once the model is on screen (the app's loader waits for
      // this); a hidden WebView may not draw, so not longer than 2 s.
      await Promise.race([this.scene.viewer.nextFrame(), new Promise(resolve => setTimeout(resolve, 2000))]);
    }
    else {
      this.scene.setAppearance(variant.material, color.hex);
      await this.paint(); // engraving's tint depends on the material
    }
    return { ...this.state(), shapeChanged };
  }

  private state() {
    const { product, variant, color, shape } = this.need();
    const surface = this.scene.surfaceColors();
    const layers = this.effective();
    return {
      productSlug: product.slug,
      productName: product.name,
      variantId: variant.id,
      colorId: color.id,
      colorHex: color.hex,
      material: variant.material,
      methods: variant.methods,
      engraveTint: ENGRAVE_TINT[variant.material],
      shapeId: shape.id,
      shapeKind: shape.kind,
      sizes: variant.sizes,
      size: this.sizeLabel,
      printScale: this.scale(),
      areas: this.areas().map(a => this.describeArea(a, surface[a.key] ?? color.hex, variant, layers)),
      presets: this.scene.presets().map((p, index) => ({ index, area: p.area })),
      shownArea: this.area,
    };
  }

  private describeArea(area: PrintArea, surfaceColor: string, variant: PublicVariant, layers: Layer[]) {
    const face = faceOf(area);
    return {
      key: area.key,
      name: area.name,
      widthMm: Number(area.width_mm),
      heightMm: Number(area.height_mm),
      placementNote: area.placement_note,
      sortOrder: area.sort_order,
      pairKey: area.pair_key,
      pairMirror: area.pair_mirror,
      face: { shape: face.face, cornerRadiusMm: face.corner_radius_mm },
      dial: isDialArea(area),
      surfaceColor,
      methods: area.methods.map((m) => {
        const zone = zoneBox(m);
        return {
          method: m.method,
          available: variant.methods.includes(m.method),
          zone: { xMm: zone.x0, yMm: zone.y0, wMm: zone.x1 - zone.x0, hMm: zone.y1 - zone.y0 },
          maxWidthMm: num(m.max_width_mm),
          maxHeightMm: num(m.max_height_mm),
          stripWidthMm: num(m.strip_width_mm),
          // The strip's left edge now (the document's, or centred on the layers).
          stripXMm: m.strip_width_mm ? printZone(area, m, layers, this.doc.strips).x0 : null,
          minFontMm: num(m.min_font_mm),
          colorsAllowed: m.colors_allowed,
          dpi: m.dpi,
          printPx: {
            width: pixelsAt(sizeMm(area, this.scale()).w, m.dpi),
            height: pixelsAt(sizeMm(area, this.scale()).h, m.dpi),
          },
        };
      }),
      raw: area,
    };
  }

  // ── Design ──

  async setDocument(params: Params) {
    const { variant, shape } = this.need();
    const doc = params.document as DesignDocument | undefined;
    if (!doc || typeof doc !== 'object' || !Array.isArray(doc.layers)) throw new EngineError('document with a layers array is required');
    // Strips as the Studio keeps them: added where layers got one, moved
    // where the layers left theirs, dropped where there are none.
    this.doc = settleStrips(normaliseDocument({ ...doc, links: Array.isArray(doc.links) ? doc.links : [] }), this.areas());
    await this.paint();
    const layers = this.effective();
    const areas = this.areas();
    const problems = designProblems(
      layers, areas, variant.methods, designMethodOf(this.doc.layers, variant.methods, null), this.doc.strips,
      this.printSize(),
    );
    return {
      strips: this.doc.strips ?? [],
      placedCount: layers.length,
      usedAreas: usedAreas(layers),
      printTargets: printTargets(layers),
      problems,
      problemCount: problemCount(problems),
      croppedCount: layers.filter(l => !isCopy(l.id) && sticksOut(l, areas, layers, this.doc.strips)).length,
    };
  }

  /** Every area's design on the product, as the Studio shows it with no
   * editing marks. */
  private async paint() {
    const shape = this.shape;
    const variant = this.variant;
    if (!shape || !variant) return;
    const layers = this.effective();
    await prepareAssets(layers);
    for (const area of this.areas()) {
      let canvas = this.canvases.get(area.key);
      if (!canvas) {
        canvas = previewCanvas(area);
        this.canvases.set(area.key, canvas);
      }
      await paintPreview(canvas, area, layers, ENGRAVE_TINT[variant.material], this.doc.strips);
      this.scene.setAreaTexture(area.key, canvas);
    }
  }

  // ── View ──

  showArea(params: Params) {
    const { shape } = this.need();
    const area = shape.areas.find(a => a.key === params.key);
    if (!area) throw new EngineError(`no area "${String(params.key)}" on this shape`);
    this.area = area.key;
    return this.resetView();
  }

  resetView() {
    this.need();
    this.preset = null;
    this.turned = false;
    this.reframe();
    return { area: this.area };
  }

  viewPreset(params: Params) {
    this.need();
    const index = Number(params.index);
    const count = this.scene.presets().length;
    if (!Number.isInteger(index) || index < 0 || index >= count) throw new EngineError(`preset index must be 0…${count - 1}`);
    this.preset = index;
    this.turned = false;
    this.reframe();
    return { index, area: this.scene.presets()[index]!.area };
  }

  setBackground(params: Params) {
    const transparent = params.transparent === true;
    this.scene.viewer.setBackdrop(!transparent);
    return { transparent };
  }

  // ── Pictures, print files, measurement ──

  /** The cart's five mockups (the Studio's captureFrames). */
  captureFrames(params: Params) {
    const { shape } = this.need();
    const size = clampSize(params.size, 900);
    let areas = Array.isArray(params.areas) ? shape.areas.map(a => a.key).filter(k => (params.areas as unknown[]).includes(k)) : usedAreas(this.effective());
    if (!areas.length && this.area) areas = [this.area];
    const frames = this.scene.captureFrames(areas, size);
    if (!frames.length) throw new EngineError('the 3D view is not ready');
    return { size, areas, frames };
  }

  /** The product as seen now, centred with a tenth free on each side (transparent PNG). */
  captureView(params: Params) {
    this.need();
    const size = clampSize(params.size, 1600);
    const frame = this.scene.captureFitted(size, Math.round(size / 10));
    if (!frame) throw new EngineError('the 3D view is not ready');
    return { size, image: frame };
  }

  async renderPrintFiles() {
    const { variant } = this.need();
    const layers = this.effective();
    const areas = this.areas();
    await prepareAssets(layers);
    const files = [];
    for (const job of printJobs(areas, layers, this.scale())) {
      const blob = await renderPrintFile(job.area, job.method, layers, this.doc.strips, job.scale);
      const mm = sizeMm(job.area, job.scale);
      files.push({
        area: job.area.key,
        method: job.method.method,
        width: job.width,
        height: job.height,
        dpi: job.method.dpi,
        // The millimetres of the size ordered — what the factory cuts.
        widthMm: mm.w,
        heightMm: mm.h,
        printScale: job.scale,
        bytes: blob.size,
        dataUrl: await blobToDataUrl(blob),
      });
    }
    const problems = designProblems(
      layers, areas, variant.methods, designMethodOf(this.doc.layers, variant.methods, null), this.doc.strips,
      this.printSize(),
    );
    return { files, size: this.sizeLabel, printScale: this.scale(), problemCount: problemCount(problems) };
  }

  async measure() {
    this.need();
    return { areasCm2: await measureAreas(this.areas(), this.effective(), this.doc.strips) };
  }

  dispose() {
    this.scene.dispose();
  }
}
