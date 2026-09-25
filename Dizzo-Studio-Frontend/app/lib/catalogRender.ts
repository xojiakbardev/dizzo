// Catalog pictures drawn from a type's 3D shape: the body in the chosen
// colour, from up to five sides, on a transparent background (PNG data
// URLs). One hidden renderer, one job at a time.
import type { Material, PublicShape } from '~/types/catalog';

type Scene = import('~/lib/three/studioScene').StudioScene;

let scene: Scene | null = null;
let queue: Promise<unknown> = Promise.resolve();

const SIZE = 1024;
const MARGIN = 72;

async function draw(
  shape: PublicShape, material: Material, hex: string | null, onProgress: (done: number, total: number) => void,
): Promise<string[]> {
  if (!scene) {
    const { StudioScene } = await import('~/lib/three/studioScene');
    const canvas = document.createElement('canvas');
    canvas.width = SIZE;
    canvas.height = SIZE;
    scene = new StudioScene(canvas);
    scene.viewer.resize(SIZE, SIZE);
  }
  // A model without a colour keeps its own look; a parametric body is white.
  if (!(await scene.setShape(shape, material, hex ?? (shape.kind === 'model' ? null : '#ffffff')))) return [];
  const views = scene.presets().length;
  const total = views + 1;
  const frames: string[] = [];
  for (let i = 0; i < views; i++) {
    scene.viewPreset(i);
    const frame = scene.captureFitted(SIZE, MARGIN);
    if (frame) frames.push(frame);
    onProgress(i + 1, total);
    await new Promise(r => setTimeout(r, 0)); // let the progress paint
  }
  // A three-quarter view from above: the silhouette as the catalog cards show it.
  const [side] = scene.sideViews(shape.areas[0]?.key ?? null);
  if (side) {
    scene.viewer.view(side.position, side.target, side.up);
    const frame = scene.captureFitted(SIZE, MARGIN);
    if (frame) frames.unshift(frame);
  }
  onProgress(total, total);
  return frames.slice(0, 5);
}

/** 3–5 transparent PNG pictures of the shape in `hex` (null: its own colours). */
export function renderPictures(
  shape: PublicShape, material: Material, hex: string | null,
  onProgress: (done: number, total: number) => void = () => {},
): Promise<string[]> {
  const job = queue.then(() => draw(shape, material, hex, onProgress));
  queue = job.catch(() => undefined);
  return job;
}
