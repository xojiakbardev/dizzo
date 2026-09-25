// Pictures of shapes for cards and pickers: one hidden renderer draws each
// shape in turn with its print areas on it (a page of cards must not open a
// WebGL context per card), and every picture is kept for the page's life —
// and for the tab's, in sessionStorage, so going back to a list is instant.
import type { Material, PublicShape } from '~/types/catalog';
import { StudioScene } from '~/lib/three/studioScene';
import { testPatternCanvas } from '~/lib/three/testPattern';

let scene: StudioScene | null = null;
let queue: Promise<unknown> = Promise.resolve();
const pictures = new Map<string, Promise<string>>();

// How each kind looks here; the variant's real material shows in the Studio.
const LOOK: Record<PublicShape['kind'], Material> = { model: 'fabric', cylinder: 'ceramic_glossy', plane: 'paper', disc: 'plastic' };

/** What the picture depends on: the body and where its areas are. */
const signature = (shape: PublicShape) => JSON.stringify([shape.id, shape.model_url, shape.dims, shape.mm_per_unit,
  shape.model_transform, shape.areas.map(a => [a.key, a.width_mm, a.height_mm, a.anchor, a.methods])]);

async function draw(shape: PublicShape, size: number): Promise<string> {
  if (!scene) {
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    scene = new StudioScene(canvas);
    scene.viewer.resize(size, size);
  }
  // A model shows in its own colours (a mug's coloured inside, a clock's
  // frame), so shapes tell apart at a glance.
  await scene.setShape(shape, LOOK[shape.kind], shape.kind === 'model' ? null : '#ffffff');
  for (const area of shape.areas) scene.setAreaTexture(area.key, testPatternCanvas({ ...area, name: '' }, true));
  // Three quarters from the side of the first area, a little from above:
  // the silhouette (handle, taper, depth) shows as well as the print area.
  const [view] = scene.sideViews(shape.areas[0]?.key ?? null);
  return scene.viewer.capture([view!], size)[0]!;
}

const STORE_PREFIX = 'dizzo-shape-picture:';

/** A short, stable name for a long signature (two 32-bit hashes). */
function hashKey(text: string): string {
  let a = 5381;
  let b = 52711;
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    a = (Math.imul(a, 33) ^ c) >>> 0;
    b = (Math.imul(b, 31) + c) >>> 0;
  }
  return `${a.toString(36)}${b.toString(36)}${text.length.toString(36)}`;
}

function stored(key: string): string | null {
  try {
    return sessionStorage.getItem(STORE_PREFIX + key);
  }
  catch {
    return null;
  }
}

function store(key: string, value: string) {
  try {
    sessionStorage.setItem(STORE_PREFIX + key, value);
  }
  catch {
    // Storage full or unavailable: the picture stays in memory only.
  }
}

/** A square JPEG of the shape (data URL), drawn once per look. */
export function shapePicture(shape: PublicShape, size = 480): Promise<string> {
  const key = hashKey(`${signature(shape)}@${size}`);
  let picture = pictures.get(key);
  if (!picture) {
    const saved = stored(key);
    if (saved) {
      picture = Promise.resolve(saved);
    }
    else {
      picture = queue.then(() => draw(shape, size));
      queue = picture.catch(() => undefined);
      picture.then(url => store(key, url)).catch(() => undefined);
    }
    pictures.set(key, picture);
  }
  return picture;
}
