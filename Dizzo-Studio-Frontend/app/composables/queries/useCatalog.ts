import { useInfiniteQuery, useQuery } from '@tanstack/vue-query';
import { ApiError } from '~/composables/useApi';
import type { PublicCategory, PublicProductCard, PublicProductDetail } from '~/types/catalog';

/** Products on sale, as the admin arranged them (landing, footer, Studio). */
export function usePublicProducts() {
  const api = useApi();
  const { locale } = useI18n();
  return useQuery({
    queryKey: computed(() => ['catalog', 'products', locale.value] as const),
    queryFn: () => api.get<PublicProductCard[]>('/catalog/products/'),
    staleTime: 60_000,
  });
}

/** The best sellers (pieces ordered), then the newest — the landing's first `limit`. */
export function usePopularProducts(limit = 8) {
  const api = useApi();
  const { locale } = useI18n();
  return useQuery({
    queryKey: computed(() => ['catalog', 'products', 'popular', limit, locale.value] as const),
    queryFn: () => api.get<PublicProductCard[]>('/catalog/products/', { sort: 'popular', limit }),
    staleTime: 60_000,
  });
}

export const CATALOG_PAGE = 24;

/** The catalog page: products a page at a time (loaded as it scrolls), one
 * shelf and a search done by the server. */
export function useProductFeed(category: Ref<string | null>, search: Ref<string>) {
  const api = useApi();
  const { locale } = useI18n();
  return useInfiniteQuery({
    queryKey: computed(() => ['catalog', 'feed', category.value, search.value.trim(), locale.value] as const),
    queryFn: ({ pageParam }) => api.get<PublicProductCard[]>('/catalog/products/', {
      limit: CATALOG_PAGE,
      offset: pageParam,
      ...(category.value ? { category: category.value } : {}),
      ...(search.value.trim() ? { q: search.value.trim() } : {}),
    }),
    initialPageParam: 0,
    getNextPageParam: (last, pages) => (last.length < CATALOG_PAGE ? undefined : pages.length * CATALOG_PAGE),
    staleTime: 60_000,
    placeholderData: previous => previous,
  });
}

/** How many products each shelf has. */
export function useProductShelves() {
  const api = useApi();
  return useQuery({
    queryKey: ['catalog', 'shelves'] as const,
    queryFn: () => api.get<{ total: number; counts: Record<string, number> }>('/catalog/products/shelves/'),
    staleTime: 60_000,
  });
}

/** One product with its variants and shapes (the product page; the Studio
 * reads the same cache key, so opening it after the page costs nothing). */
export function useProductDetail(slug: Ref<string>) {
  const api = useApi();
  const { locale } = useI18n();
  return useQuery({
    queryKey: computed(() => ['catalog', 'product', slug.value, locale.value] as const),
    queryFn: () => api.get<PublicProductDetail>(`/catalog/products/${encodeURIComponent(slug.value)}/`),
    retry: (count, error) => !(error instanceof ApiError && error.status === 404) && count < 2,
    staleTime: 60_000,
  });
}

/** The storefront shelves, in the admin's order. */
export function useCategories() {
  const api = useApi();
  const { locale } = useI18n();
  return useQuery({
    queryKey: computed(() => ['catalog', 'categories', locale.value] as const),
    queryFn: () => api.get<PublicCategory[]>('/catalog/categories/'),
    staleTime: 5 * 60_000,
  });
}

/** The same products, the admin's featured ones first. */
export function useStorefrontProducts() {
  const query = usePublicProducts();
  const list = computed(() => [...(query.data.value ?? [])].sort((a, b) => Number(b.is_featured) - Number(a.is_featured)));
  return { query, list };
}
