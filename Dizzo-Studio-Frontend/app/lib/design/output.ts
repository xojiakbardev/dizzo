// What a finished design is turned into for the cart — the print files to
// render, the painted area to price and the areas the mockups look at —
// shared by the Studio (useStudio) and the app's engine (/embed/engine), so
// both hand the backend exactly the same thing.
import type { Layer, StripPosition } from '~/lib/design/document';
import { areaMethod, pixelsAt, printTargets, sizeMm } from '~/lib/design/document';
import { measurePainted, prepareAssets } from '~/lib/design/render';
import type { AreaMethod, PrintArea } from '~/types/catalog';

export interface PrintJob {
  area: PrintArea;
  method: AreaMethod;
  width: number; // px, as renderPrintFile draws it
  height: number;
  scale: number; // the size's share of the area (VariantSize.print_scale)
}

/** The print files a design needs (one per area and method, linked
 * partners included), in the order the cart uploads them. `layers`: the
 * effective layers, `scale`: the chosen size's print scale — the sheet is
 * that size's box, not the whole area, so a smaller size really goes to
 * production as a smaller print (the backend checks it to the pixel). */
export function printJobs(areas: PrintArea[], layers: Layer[], scale = 1): PrintJob[] {
  return printTargets(layers).flatMap((t) => {
    const area = areas.find(a => a.key === t.area);
    const method = area && areaMethod(area, t.method);
    if (!area || !method) return [];
    const mm = sizeMm(area, scale);
    return [{ area, method, scale, width: pixelsAt(mm.w, method.dpi), height: pixelsAt(mm.h, method.dpi) }];
  });
}

/** The areas that hold something to print: what the mockups look at. */
export const usedAreas = (layers: Layer[]) => [...new Set(printTargets(layers).map(t => t.area))];

const round2 = (v: number) => Math.round(v * 100) / 100;

/** Painted cm² per method as the backend takes it (`areas_cm2`: two decimals). */
export async function measureAreas(
  areas: PrintArea[], layers: Layer[], strips: StripPosition[] | undefined,
): Promise<Record<string, string>> {
  await prepareAssets(layers);
  const painted = await measurePainted(areas, layers, strips);
  return Object.fromEntries(Object.entries(painted).map(([m, v]) => [m, round2(v!).toFixed(2)]));
}
