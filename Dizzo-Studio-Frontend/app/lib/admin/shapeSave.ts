// Saving the shape editor's draft. One request (PUT /shapes/{id}/layout/),
// all or nothing. An API from before that endpoint gets the same state step
// by step through the old endpoints instead, each step valid on its own.
import { ApiError } from '~/composables/useApi';
import type { AdminCatalogProduct, PrintArea, Shape } from '~/types/catalog';
import type { LayoutBody } from '~/lib/admin/shapeDraft';
import { AREA_TR_FIELDS } from '~/lib/admin/shapeDraft';
import { textTranslations, trimTranslations } from '~/lib/admin/translations';

type Run = (verb: 'post' | 'patch' | 'put' | 'delete', path: string, body?: unknown) => Promise<AdminCatalogProduct>;

let layoutMissing = false;

export async function saveLayout(run: Run, shapeId: number, body: LayoutBody): Promise<AdminCatalogProduct> {
  if (!layoutMissing) {
    try {
      return await run('put', `/admin/catalog/shapes/${shapeId}/layout/`, body);
    }
    catch (err) {
      // An older backend has no such route: the framework's bare "Not Found"
      // (a missing shape comes with the API's own, localized message).
      const noRoute = err instanceof ApiError && (err.status === 405 || (err.status === 404 && err.data.detail === 'Not Found'));
      if (!noRoute) throw err;
      layoutMissing = true;
    }
  }
  return saveStepByStep(run, shapeId, body);
}

const shapeOf = (product: AdminCatalogProduct, id: number) => product.shapes.find(s => s.id === id)!;
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
type MethodBody = LayoutBody['areas'][number]['methods'][number];

/** Method rows as the API gives them, comparable with the ones sent. */
function apiMethods(area: PrintArea): MethodBody[] {
  const n = (v: string | null) => (v === null ? null : String(Number(v)));
  return [...area.methods].sort((a, b) => a.method.localeCompare(b.method)).map(m => ({
    method: m.method, zone_x_mm: n(m.zone_x_mm)!, zone_y_mm: n(m.zone_y_mm)!, zone_w_mm: n(m.zone_w_mm)!, zone_h_mm: n(m.zone_h_mm)!,
    max_width_mm: n(m.max_width_mm), max_height_mm: n(m.max_height_mm), strip_width_mm: n(m.strip_width_mm),
    min_font_mm: n(m.min_font_mm), colors_allowed: m.colors_allowed, dpi: m.dpi,
  }));
}
const sorted = (methods: MethodBody[]) => [...methods].sort((a, b) => a.method.localeCompare(b.method));

/** Zones that fit the area both before and after a resize. */
function fittingBoth(methods: MethodBody[], w: number, h: number): MethodBody[] {
  const cap = (v: string | null, max: number) => (v === null ? null : String(Math.min(Number(v), max)));
  return methods.map((m) => {
    const zw = Math.min(Number(m.zone_w_mm), w);
    const zh = Math.min(Number(m.zone_h_mm), h);
    return {
      ...m, zone_x_mm: '0', zone_y_mm: '0', zone_w_mm: String(zw), zone_h_mm: String(zh),
      max_width_mm: cap(m.max_width_mm, zw), max_height_mm: cap(m.max_height_mm, zh), strip_width_mm: cap(m.strip_width_mm, zw),
    };
  });
}

async function saveStepByStep(run: Run, shapeId: number, body: LayoutBody): Promise<AdminCatalogProduct> {
  const patch: Record<string, unknown> = {};
  if (body.name) patch.name = body.name;
  if ('description' in body) patch.description = body.description;
  patch.translations = body.translations;
  if ('dims' in body) patch.dims = body.dims;
  if ('model_media_id' in body) patch.model_media_id = body.model_media_id;
  if ('model_transform' in body) patch.model_transform = body.model_transform;
  if ('scale' in body) patch.scale = body.scale;
  let product = await run('patch', `/admin/catalog/shapes/${shapeId}/`, patch);
  let shape: Shape = shapeOf(product, shapeId);

  // Pairs come apart first, so nothing is kept in step with a stale partner.
  for (const area of shape.areas) {
    const wanted = body.areas.find(a => a.id === area.id);
    if (area.pair_key && (!wanted || wanted.pair_key !== area.pair_key)) {
      product = await run('put', `/admin/catalog/areas/${area.id}/pair/`, { pair_key: null });
    }
  }
  shape = shapeOf(product, shapeId);
  for (const area of shape.areas) {
    if (!body.areas.some(a => a.id === area.id)) product = await run('delete', `/admin/catalog/areas/${area.id}/`);
  }

  for (const item of body.areas) {
    const fields = {
      key: item.key, name: item.name, width_mm: item.width_mm, height_mm: item.height_mm, anchor: item.anchor,
      camera: item.camera, placement_note: item.placement_note, sort_order: item.sort_order, translations: item.translations,
    };
    shape = shapeOf(product, shapeId);
    let current = item.id === null ? null : shape.areas.find(a => a.id === item.id) ?? null;
    if (!current) {
      product = await run('post', `/admin/catalog/shapes/${shapeId}/areas/`, fields);
      current = shapeOf(product, shapeId).areas.find(a => a.key === item.key)!;
    }
    else {
      const resized = Number(current.width_mm) !== Number(item.width_mm) || Number(current.height_mm) !== Number(item.height_mm);
      if (resized && current.methods.length) {
        const w = Math.min(Number(current.width_mm), Number(item.width_mm));
        const h = Math.min(Number(current.height_mm), Number(item.height_mm));
        product = await run('put', `/admin/catalog/areas/${current.id}/methods/`, { methods: fittingBoth(item.methods, w, h) });
      }
      const now = shapeOf(product, shapeId).areas.find(a => a.id === current!.id)!;
      const unchanged = now.key === fields.key && now.name === fields.name && !resized && same(now.anchor, fields.anchor)
        && same(now.camera, fields.camera) && now.placement_note === fields.placement_note && now.sort_order === fields.sort_order
        && same(trimTranslations(textTranslations(now.translations, AREA_TR_FIELDS)), fields.translations);
      if (!unchanged) product = await run('put', `/admin/catalog/areas/${current.id}/`, fields);
      current = shapeOf(product, shapeId).areas.find(a => a.id === current!.id)!;
    }
    if (!same(apiMethods(current), sorted(item.methods))) {
      product = await run('put', `/admin/catalog/areas/${current.id}/methods/`, { methods: item.methods });
    }
  }

  // Pairs last: the partner takes this area's size and methods (already equal).
  shape = shapeOf(product, shapeId);
  for (const item of body.areas) {
    if (!item.pair_key) continue;
    const area = shape.areas.find(a => a.key === item.key);
    if (area && (area.pair_key !== item.pair_key || area.pair_mirror !== item.pair_mirror)) {
      product = await run('put', `/admin/catalog/areas/${area.id}/pair/`, { pair_key: item.pair_key, mirror: item.pair_mirror });
      shape = shapeOf(product, shapeId);
    }
  }
  return product;
}
