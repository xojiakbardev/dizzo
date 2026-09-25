// The "Rasmlar" tab's model: which picture lists a product has (cover,
// product gallery, each type with its base shot, each colour of a type with
// its card picture), what the customer sees for a chosen type and colour, and
// matching uploaded files to those lists by their names.
import type { AdminCatalogProduct, CatalogImage, Variant, VariantColor } from '~/types/catalog';

// Two of the kinds hold exactly one picture and are not galleries at all:
// `variantMain` is the type's plain, colourless base shot (the first picture
// the customer sees, whichever colour is chosen) and `colorCard` is the
// clean tinted picture the variant cards show. Keeping them out of the
// galleries is the whole point: no list position means "the star" any more.
export type CellKind = 'cover' | 'product' | 'variant' | 'variantMain' | 'color' | 'colorCard';

export interface Cell {
  key: string; // "cover" | "product" | "v:12" | "vm:12" | "c:34" | "cc:34"
  kind: CellKind;
  id: number; // the product's, the type's or the colour's id
  max: number;
  images: CatalogImage[];
}

/** How many pictures each list holds. A colour shows five at most. */
export const CELL_MAX: Record<CellKind, number> = {
  cover: 1, product: 12, variant: 12, variantMain: 1, color: 5, colorCard: 1,
};

const CELL_PREFIX: Partial<Record<CellKind, string>> = { variant: 'v', variantMain: 'vm', color: 'c', colorCard: 'cc' };

export const cellKey = (kind: CellKind, id: number) => {
  const prefix = CELL_PREFIX[kind];
  return prefix ? `${prefix}:${id}` : kind;
};

export const liveVariants = (p: AdminCatalogProduct) => p.variants.filter(v => !v.archived);
export const liveColors = (v: Variant) => v.colors.filter(c => !c.archived);

/** Every picture list of the product, from the server's data. */
export function cellsOf(p: AdminCatalogProduct): Map<string, Cell> {
  const out = new Map<string, Cell>();
  const add = (kind: CellKind, id: number, images: CatalogImage[]) =>
    out.set(cellKey(kind, id), { key: cellKey(kind, id), kind, id, max: CELL_MAX[kind], images });
  add('cover', p.id, p.cover ? [p.cover] : []);
  add('product', p.id, p.images);
  for (const v of liveVariants(p)) {
    add('variant', v.id, v.images);
    for (const c of liveColors(v)) {
      add('color', c.id, c.images);
    }
  }
  return out;
}

/** The request that saves a cell's list. */
export function saveRequest(cell: Pick<Cell, 'kind' | 'id'>, ids: string[]) {
  const base = '/admin/catalog';
  switch (cell.kind) {
    case 'cover': return { verb: 'patch' as const, path: `${base}/products/${cell.id}/`, body: { cover_media_id: ids[0] ?? null } };
    case 'product': return { verb: 'put' as const, path: `${base}/products/${cell.id}/images/`, body: { media_ids: ids } };
    case 'variant': return { verb: 'put' as const, path: `${base}/variants/${cell.id}/images/`, body: { media_ids: ids } };
    case 'variantMain': return { verb: 'patch' as const, path: `${base}/variants/${cell.id}/`, body: { main_image_media_id: ids[0] ?? null } };
    case 'color': return { verb: 'put' as const, path: `${base}/colors/${cell.id}/images/`, body: { media_ids: ids } };
    case 'colorCard': return { verb: 'patch' as const, path: `${base}/colors/${cell.id}/`, body: { card_media_id: ids[0] ?? null } };
  }
}

export type PictureSource = 'color' | 'variant' | 'product' | 'cover';
export interface ShownPicture { url: string; source: PictureSource }

/** What the site and the app show for a type and colour, in that order: the
 * colour's own pictures (starting with the primary star image), then the ones that
 * hold for the whole product. A product with none of those falls back to its cover. */
export function galleryFor(
  images: (key: string) => CatalogImage[],
  variant: Variant | null, color: VariantColor | null,
): ShownPicture[] {
  const seen = new Set<string>();
  const out: ShownPicture[] = [];
  const push = (list: CatalogImage[], source: PictureSource) => {
    for (const img of list) {
      if (seen.has(img.url)) continue;
      seen.add(img.url);
      out.push({ url: img.url, source });
    }
  };
  if (color) push(images(cellKey('color', color.id)), 'color');
  push(images('product'), 'product');
  if (!out.length) push(images('cover'), 'cover');
  return out;
}

// ── Matching files by name: "<type>-<colour>-1.png", "<colour>-2.webp" ──

/** Lower case, no apostrophes (o‘, g‘, ’), every other gap a single dash. */
export function normalizeName(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .replace(/['‘’ʻʼ`´]/g, '')
    .replace(/[^a-z0-9а-яё]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export interface NameMatch { cellKey: string; order: number }

/** Finds the colour a file belongs to: the whole name (without a trailing
 * number) equals "<type>-<colour>"; failing that, "<colour>" when only one
 * type has a colour of that name. */
export function matchFileName(fileName: string, p: AdminCatalogProduct): NameMatch | null {
  const full = normalizeName(fileName.replace(/\.[^.]+$/, ''));
  const numbered = full.match(/^(.*?)-(\d+)$/);
  // The whole name first: a type may itself end in a number ("krujka-330").
  return find(full, 0, p) ?? (numbered ? find(numbered[1]!, Number(numbered[2]), p) : null);
}

function find(base: string, order: number, p: AdminCatalogProduct): NameMatch | null {
  const byColour = new Map<string, string[]>();
  for (const v of liveVariants(p)) {
    const vn = normalizeName(v.name);
    for (const c of liveColors(v)) {
      const cn = normalizeName(c.name);
      if (base === `${vn}-${cn}`) return { cellKey: cellKey('color', c.id), order };
      byColour.set(cn, [...(byColour.get(cn) ?? []), cellKey('color', c.id)]);
    }
  }
  const only = byColour.get(base);
  return only?.length === 1 ? { cellKey: only[0]!, order } : null;
}
