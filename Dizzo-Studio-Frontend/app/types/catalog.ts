import type { DesignDocument } from '~/lib/design/document';
import { i18nT } from '~/lib/i18n';

// Mirrors the backend's app/schemas/catalog.py. Money and lengths arrive as
// decimal strings ("149000.00", "226.00") — never floats — and are sent back
// the same way, so nothing is lost to rounding.

// Admin content in Russian and English: `{ ru: { name: … }, en: { … } }`.
// Uzbek stays in the resource's own fields; an empty value is untranslated.
export type TranslationLang = 'ru' | 'en';
export type Translations<T> = Partial<Record<TranslationLang, Partial<T>>>;

export type CatalogMethod = 'uv' | 'engrave';
export type ShapeKind = 'cylinder' | 'plane' | 'disc' | 'model';
export const MATERIALS = [
  'ceramic_glossy', 'ceramic_matte', 'glass_clear', 'glass_frosted', 'fabric', 'paper', 'plastic', 'metal', 'wood',
] as const;
export type Material = typeof MATERIALS[number];

export interface CylinderDims { diameter_mm: string; height_mm: string; handle: boolean; handle_gap_mm: string }
export interface PlaneDims { width_mm: string; height_mm: string; sides: 1 | 2 }
export interface DiscDims { diameter_mm: string }
export type ShapeDims = CylinderDims | PlaneDims | DiscDims | Record<string, never>;

export interface CylinderAnchor { start_mm: string; top_mm: string }
export interface PlaneAnchor { side: 'front' | 'back'; x_mm: string; y_mm: string }
export interface DiscAnchor { x_mm: string; y_mm: string }
export type Vec3 = [number, number, number];
// Decal projector on a GLB, in model space; {} = not placed yet.
// wrap_radius_mm: the print wraps round a cylinder (a mug) instead of lying flat.
// round: only the circle inside the area is printed (a clock's dial), so coverage is measured on it.
// corner_radius_mm: rounded corners of a rectangular face (the editor and the clock numerals follow them).
// dial: a clock face — new designs start with its numerals and minute marks.
export interface ModelAnchor {
  point: Vec3; normal: Vec3; up: Vec3; depth_mm: string; max_angle_deg: number; wrap_radius_mm?: string | null; round?: boolean;
  corner_radius_mm?: string | null; dial?: boolean;
}
export type AreaAnchor = CylinderAnchor | PlaneAnchor | DiscAnchor | ModelAnchor | Record<string, never>;
export interface AreaCamera { position: Vec3; target: Vec3 }

export interface ModelTransform {
  up_axis: 'y' | 'z';
  yaw_deg: 0 | 90 | 180 | 270;
  scale_ref: { a: Vec3; b: Vec3; mm: string } | null;
}

// Measured by the 3D configurator, sent when a GLB shape is marked ready.
export interface AreaCheck { coverage: number; stretched_share: number }

export function isPlacedModelAnchor(anchor: AreaAnchor): anchor is ModelAnchor {
  return 'point' in anchor && 'normal' in anchor && 'up' in anchor;
}

export interface AreaMethod {
  method: CatalogMethod;
  zone_x_mm: string;
  zone_y_mm: string;
  zone_w_mm: string;
  zone_h_mm: string;
  max_width_mm: string | null;
  max_height_mm: string | null;
  // A laser strip this wide (as tall as the zone) that slides across it:
  // all the method's layers go in one strip. null: the whole zone.
  strip_width_mm: string | null;
  min_font_mm: string | null;
  colors_allowed: boolean;
  dpi: number;
}

export interface PrintArea {
  id: number;
  key: string;
  name: string;
  width_mm: string;
  height_mm: string;
  anchor: AreaAnchor;
  camera: AreaCamera | null;
  placement_note: string;
  sort_order: number;
  // Symmetric partner (left ↔ right sleeve): same size and methods, zones
  // mirrored when pair_mirror.
  pair_key: string | null;
  pair_mirror: boolean;
  methods: AreaMethod[];
  translations?: Translations<{ name: string; placement_note: string }>; // admin API only
}

export interface Shape {
  id: number;
  name: string;
  description?: string; // a short line under the name in pickers (absent on an older API)
  kind: ShapeKind;
  dims: ShapeDims;
  model_url: string | null;
  model_media_id?: string | null; // admin API only
  model_transform: ModelTransform | null;
  mm_per_unit: string | null;
  status: 'draft' | 'ready';
  locked: boolean;
  archived: boolean;
  replaces_id: number | null; // a revision: takes that shape's place once ready
  areas: PrintArea[];
  translations?: Translations<{ name: string; description: string }>; // admin API only
}

/** Where a catalog picture came from: an admin's file, or drawn from the
 * 3D shape. A regenerate throws away the drawn ones and keeps the photos. */
export type PictureSourceKind = 'manual' | 'render';

export interface CatalogImage { media_id: string; url: string; source?: PictureSourceKind }

export interface VariantColor {
  id: number;
  name: string;
  hex: string;
  surcharge: string;
  is_available: boolean;
  sort_order: number;
  archived: boolean;
  images: CatalogImage[];
  // The one clean, colour-tinted picture the variant cards show. It is not
  // part of `images` — the gallery and the cards never fight over an index.
  card_image?: CatalogImage | null;
  card_image_url?: string | null;
  card_media_id?: string | null;
  translations?: Translations<{ name: string }>; // admin API only
}

export interface SpecItem { label: string; value: string }

// A clothing size, in the order the customer sees it. A variant with an
// empty list has no sizes (a mug) and none is ever chosen.
//
// print_scale is how much of the print area this size may use: the shape's
// area is measured for the LARGEST size (40 × 40 cm on a t-shirt is the
// maximum), and a smaller garment prints a proportionally smaller picture,
// centred on the same anchor. "1.00" = the whole area.
export interface VariantSize { label: string; surcharge: string; is_available: boolean; print_scale: string }

/** What the lead starts a new garment from; edited freely afterwards, with
 * the print scale a garment of that size normally takes (the backend's
 * services/catalog.py DEFAULT_PRINT_SCALES and migration 0029). */
export const DEFAULT_SIZES = ['S', 'M', 'L', 'XL', 'XXL'] as const;
export const DEFAULT_PRINT_SCALES: Record<string, string> = {
  '3XL': '1.00', 'XXXL': '1.00', 'XXL': '0.95', '2XL': '0.95', 'XL': '0.90', 'L': '0.85', 'M': '0.80', 'S': '0.75',
};
export const defaultPrintScale = (label: string): string => DEFAULT_PRINT_SCALES[label.trim().toUpperCase()] ?? '1.00';

export interface Variant {
  id: number;
  shape_id: number;
  name: string;
  short_description: string;
  description: string;
  specs: SpecItem[];
  base_price: string;
  methods: CatalogMethod[];
  material: Material;
  white_underbase: boolean;
  is_available: boolean;
  sort_order: number;
  archived: boolean;
  sizes: VariantSize[];
  main_image?: CatalogImage | null;
  main_image_url?: string | null;
  main_image_media_id?: string | null;
  images: CatalogImage[];
  colors: VariantColor[];
  translations?: Translations<{
    name: string; short_description: string; description: string; specs: SpecItem[];
    /** Only word labels: [{ label: 'Katta', name: 'Большой' }]; codes (S, XL, 42) are left out. */
    sizes: Array<{ label: string; name: string }>;
  }>; // admin API only
}

// The storefront shelf a product sits on: a category's slug. The shelves
// (name, icon, order) are managed in the admin.
export type ProductCategory = string;
export interface PublicCategory { slug: string; name: string; icon_svg: string; image_url: string | null }
export interface AdminCategory extends PublicCategory {
  id: number;
  image_media_id: string | null;
  sort_order: number;
  is_active: boolean;
  product_count: number;
  translations?: Translations<{ name: string }>;
}
/** A shelf as the chips and the catalog show it. */
export interface ShelfOption { value: string; label: string; icon_svg: string; image_url: string | null }

export interface PriceTier { method: CatalogMethod; min_cm2: string; max_cm2: string | null; surcharge: string }

export interface AdminCatalogProduct {
  id: number;
  slug: string;
  name: string;
  description: string;
  cover: CatalogImage | null;
  is_featured: boolean;
  is_available: boolean;
  sort_order: number;
  category: ProductCategory;
  archived: boolean;
  images: CatalogImage[];
  shapes: Shape[];
  variants: Variant[];
  price_tiers: PriceTier[];
  sellable: boolean;
  issues: string[];
  translations?: Translations<{ name: string; description: string }>;
}

export interface AdminCatalogListItem {
  id: number;
  slug: string;
  name: string;
  cover_url: string | null;
  is_featured: boolean;
  is_available: boolean;
  archived: boolean;
  sort_order: number;
  category: ProductCategory;
  variant_count: number;
  shape_count: number;
  sellable: boolean;
  from_price: string | null; // the cheapest sellable type and colour
}

export interface PublicProductCard {
  slug: string;
  name: string;
  cover_url: string | null;
  from_price: string;
  is_featured: boolean;
  category: ProductCategory;
}

export interface PublicColor {
  id: number;
  name: string;
  hex: string;
  surcharge: string;
  /** The colour's gallery, at most five pictures. Every one of them is of
   * this colour: none is reserved for anything else. */
  images: string[];
  /** The clean, colour-tinted shot the variant/colour cards show. */
  card_image_url: string | null;
}

export interface PublicVariant {
  id: number;
  shape_id: number;
  name: string;
  short_description: string;
  description: string;
  specs: SpecItem[];
  base_price: string;
  methods: CatalogMethod[]; // what the customer can use: variant ∩ the shape's areas
  material: Material;
  white_underbase: boolean;
  /** The plain, colourless base shot of the type — the first picture of the
   * detail gallery, whichever colour is chosen. */
  main_image_url: string | null;
  /** @deprecated The old name of `main_image_url`; the same picture. */
  variant_main_image?: string | null;
  images: string[];
  colors: PublicColor[]; // only colours on sale
  sizes: VariantSize[]; // in order; an out-of-stock size is listed, greyed out
}

export interface PublicShape {
  id: number;
  kind: ShapeKind;
  dims: ShapeDims;
  model_url: string | null;
  model_transform: ModelTransform | null;
  mm_per_unit: string | null;
  areas: PrintArea[];
}

export interface PublicProductDetail {
  slug: string;
  name: string;
  /** Prose about the product itself, above the types. */
  description: string;
  cover_url: string | null;
  /** Pictures of the product that hold for every type and colour (how it is
   * packed, a size chart): they close the detail gallery. */
  images: string[];
  from_price: string;
  variants: PublicVariant[]; // only variants on sale
  shapes: PublicShape[];
}

export interface QuoteLine { method: CatalogMethod; area_cm2: string; tier_min_cm2: string; tier_max_cm2: string | null; surcharge: string }

export interface Quote {
  variant_id: number;
  color_id: number;
  base_price: string;
  color_surcharge: string;
  size: string | null;
  size_surcharge: string;
  // The chosen size's share of the print area, and the largest painted area
  // it can hold per method (cm²) — what the price was capped to. Empty on a
  // product without sizes and on the largest size.
  print_scale: string;
  print_area_cm2: Partial<Record<CatalogMethod, string>>;
  methods: QuoteLine[];
  unit_price: string;
  quantity: number;
  total: string;
}

// Gallery designs (templates, app/schemas/template.py): made by admins in
// the Studio, offered on the variants they were checked against and shown
// with their pictures in the "Galereya".
export interface PublicTemplate {
  id: number;
  name: string;
  category: string;
  preview_url: string;
  variant_ids: number[];
  document: DesignDocument;
}

export interface AdminTemplate extends PublicTemplate {
  product_id: number;
  product_name: string;
  product_slug: string;
  is_active: boolean;
  sort_order: number;
  images: CatalogImage[];
  in_gallery: boolean;
  color_id: number | null;
  updated_at: string;
  translations?: Translations<{ name: string }>;
}

// The label maps below are getters: every read is in the page's current
// language (common.json), so `METHOD_LABELS[m]` stays reactive in templates.
const label = (key: string) => i18nT(`common.catalog.${key}`);

export const METHOD_LABELS: Record<CatalogMethod, string> = {
  get uv() { return label('method.uv'); },
  get engrave() { return label('method.engrave'); },
};

// What a customer reads before choosing how the design is put on.
export const METHOD_INFO: Record<CatalogMethod, { icon: string; short: string; details: string }> = {
  uv: {
    icon: 'lucide:palette',
    get short() { return label('methodInfo.uv.short'); },
    get details() { return label('methodInfo.uv.details'); },
  },
  engrave: {
    icon: 'lucide:zap',
    get short() { return label('methodInfo.engrave.short'); },
    get details() { return label('methodInfo.engrave.details'); },
  },
};

export const KIND_LABELS: Record<ShapeKind, string> = {
  get cylinder() { return label('kind.cylinder'); },
  get plane() { return label('kind.plane'); },
  get disc() { return label('kind.disc'); },
  get model() { return label('kind.model'); },
};

export const MATERIAL_LABELS: Record<Material, string> = {
  get ceramic_glossy() { return label('material.ceramic_glossy'); },
  get ceramic_matte() { return label('material.ceramic_matte'); },
  get glass_clear() { return label('material.glass_clear'); },
  get glass_frosted() { return label('material.glass_frosted'); },
  get fabric() { return label('material.fabric'); },
  get paper() { return label('material.paper'); },
  get plastic() { return label('material.plastic'); },
  get metal() { return label('material.metal'); },
  get wood() { return label('material.wood'); },
};

export interface DesignAsset {
  id: number;
  media_id: string;
  name: string;
  category: string;
  type: 'icon' | 'sticker' | 'photo';
  is_active: boolean;
  sort_order: number;
  url: string;
  px_w?: number | null;
  px_h?: number | null;
  created_at: string;
  updated_at: string;
}

