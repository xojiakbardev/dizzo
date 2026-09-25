// The product page's tabs, shared with the pages under it (a variant's
// page keeps the same tab row). `adds`: the tab puts its add button at the
// row's right end (it teleports into #product-tab-actions).
// `label` is the Uzbek name; show productTabLabel(id) (the site's language).
import type { AdminCatalogProduct } from '~/types/catalog';

export const PRODUCT_TABS = [
  { id: 'info', label: 'Asosiy', icon: 'lucide:file-text', adds: false },
  { id: 'shapes', label: 'Shakllar', icon: 'lucide:box', adds: true },
  { id: 'variants', label: 'Variantlar', icon: 'lucide:layers', adds: true },
  { id: 'images', label: 'Rasmlar', icon: 'lucide:images', adds: false },
  { id: 'prices', label: 'Narxlar', icon: 'lucide:banknote', adds: false },
  { id: 'templates', label: 'Galereya', icon: 'lucide:layout-template', adds: false },
] as const;
export type ProductTabId = (typeof PRODUCT_TABS)[number]['id'];

/** A tab's name in the current language (admin.productTabs.<id>). */
export function productTabLabel(id: ProductTabId): string {
  return useNuxtApp().$i18n.t(`admin.productTabs.${id}`);
}

/** How many live items a tab holds, shown next to its name. */
export function productTabCount(p: AdminCatalogProduct | null, id: ProductTabId): number | null {
  if (!p) return null;
  if (id === 'shapes') return p.shapes.filter(s => !s.archived && s.replaces_id === null).length;
  if (id === 'variants') return p.variants.filter(v => !v.archived).length;
  return null;
}
