// Catalog reads for the server (sitemap, the Studio's 404 and head), kept in
// Nitro's cache so a crawler walking the site doesn't walk the API too.
import type { ProductSeoSource, SeoLang } from '#shared/seo';

export interface ProductListItem { slug: string; name: string; category: string; cover_url: string | null }
export interface ShelfListItem { slug: string; name: string }
export interface GalleryPiece {
  id: string;
  title: string | null;
  product_name: string;
  category: string | null;
  image_urls: string[];
  created_at: string;
}
export interface ServerProduct extends ProductSeoSource { slug: string; lang?: SeoLang }

function apiBase(): string {
  return `${String(useRuntimeConfig().public.apiUrl || '').replace(/\/$/, '')}/api`;
}

const inLang = (lang: SeoLang) => ({ 'Accept-Language': lang });

export const listProducts = defineCachedFunction(
  (lang: SeoLang = 'uz'): Promise<ProductListItem[]> =>
    $fetch<ProductListItem[]>('/catalog/products/', { baseURL: apiBase(), timeout: 10_000, headers: inLang(lang) }),
  { name: 'catalog-products', maxAge: 60 * 60, swr: true, getKey: (lang: SeoLang = 'uz') => lang },
);

export const listShelves = defineCachedFunction(
  (lang: SeoLang = 'uz'): Promise<ShelfListItem[]> =>
    $fetch<ShelfListItem[]>('/catalog/categories/', { baseURL: apiBase(), timeout: 10_000, headers: inLang(lang) }),
  { name: 'catalog-shelves', maxAge: 60 * 60, swr: true, getKey: (lang: SeoLang = 'uz') => lang },
);

/** Every gallery piece, a page of 100 at a time (at most 2000). */
export const listGalleryPieces = defineCachedFunction(
  async (lang: SeoLang = 'uz'): Promise<GalleryPiece[]> => {
    const all: GalleryPiece[] = [];
    for (let offset = 0; offset < 2000; offset += 100) {
      const page = await $fetch<GalleryPiece[]>('/gallery/', {
        baseURL: apiBase(), timeout: 10_000, query: { limit: 100, offset }, headers: inLang(lang),
      });
      all.push(...page);
      if (page.length < 100) break;
    }
    return all;
  },
  { name: 'gallery-pieces', maxAge: 60 * 60, swr: true, getKey: (lang: SeoLang = 'uz') => lang },
);

/**
 * The product, `null` when the API says it doesn't exist (404). Any other
 * failure throws, so an API outage never turns into a "not found".
 */
export const getProduct = defineCachedFunction(
  async (slug: string, lang: SeoLang = 'uz'): Promise<ServerProduct | null> => {
    try {
      const p = await $fetch<ServerProduct>(`/catalog/products/${encodeURIComponent(slug)}/`, {
        baseURL: apiBase(), timeout: 8_000, headers: inLang(lang),
      });
      return { slug: p.slug, name: p.name, description: p.description, cover_url: p.cover_url, lang };
    }
    catch (error) {
      if ((error as { response?: { status?: number } }).response?.status === 404) return null;
      throw error;
    }
  },
  { name: 'catalog-product', maxAge: 10 * 60, swr: true, getKey: (slug: string, lang: SeoLang = 'uz') => `${lang}:${slug}` },
);

/** The slug and language of a /studio/<slug> path (/ru/studio/…, /en/studio/…), or null. */
export function studioSlug(path: string): { slug: string; lang: SeoLang } | null {
  const match = /^(?:\/(ru|en))?\/studio\/([^/?#]+)\/?(?:\?.*)?$/.exec(path);
  if (!match) return null;
  try {
    return { slug: decodeURIComponent(match[2]!), lang: (match[1] as SeoLang | undefined) ?? 'uz' };
  }
  catch {
    return null;
  }
}

export function siteOrigin(event: Parameters<typeof getRequestURL>[0]): string {
  return String(useRuntimeConfig(event).public.siteUrl || getRequestURL(event).origin).replace(/\/$/, '');
}
