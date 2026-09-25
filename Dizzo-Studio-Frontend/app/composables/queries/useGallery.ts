import type { AdminTemplate, Translations } from '~/types/catalog';
import { useInfiniteQuery, useQuery, useQueryClient } from '@tanstack/vue-query';

export interface GalleryItem {
  /** Negative for admin-curated showcase items. */
  order_item_id: number;
  product_name: string;
  /** May be empty for showcase items. */
  customer_name: string;
  preview_image_url: string;
  created_at: string;
  /** "order-5" / "showcase-3" (newer backends). */
  id?: string;
  kind?: 'order' | 'showcase' | 'template';
  /** A gallery design: open it in the Studio with these. */
  template_id?: number | null;
  variant_id?: number | null;
  color_id?: number | null;
  product_slug?: string | null;
  /** The product's catalog shelf. */
  category?: string | null;
  title?: string | null;
  /** Every picture of the piece, the preview first. */
  image_urls?: string[];
}

export const galleryKey = (item: GalleryItem) => item.id ?? item.order_item_id;
export const galleryImages = (item: GalleryItem) =>
  item.image_urls?.length ? item.image_urls : [item.preview_image_url];

// Public showcase feed — designs from orders that actually shipped
// (COMPLETED), then the pieces the admin put up. No auth needed.
export function useGallery(limit = 24) {
  const api = useApi();

  return useQuery<GalleryItem[]>({
    queryKey: ['gallery', limit] as const,
    queryFn: () => api.get<GalleryItem[]>('/gallery/', { limit }),
    staleTime: 60_000,
  });
}

const FEED_PAGE = 24;

/** The gallery page: the feed a page at a time (loaded as it scrolls),
 * optionally one catalog shelf. */
export function useGalleryFeed(category: Ref<string | null>) {
  const api = useApi();
  return useInfiniteQuery({
    queryKey: computed(() => ['gallery', 'feed', category.value] as const),
    queryFn: ({ pageParam }) => api.get<GalleryItem[]>('/gallery/', {
      limit: FEED_PAGE,
      offset: pageParam,
      ...(category.value ? { category: category.value } : {}),
    }),
    initialPageParam: 0,
    getNextPageParam: (last, pages) => (last.length < FEED_PAGE ? undefined : pages.length * FEED_PAGE),
    staleTime: 60_000,
  });
}

/** One piece (a shared /gallery?p= link). */
export function useGalleryItem(id: Ref<string | null>) {
  const api = useApi();
  return useQuery({
    queryKey: computed(() => ['gallery', 'item', id.value ?? ''] as const),
    queryFn: () => api.get<GalleryItem>(`/gallery/item/${encodeURIComponent(id.value ?? '')}/`),
    enabled: computed(() => !!id.value),
    retry: false,
    staleTime: 60_000,
  });
}

/** How many pieces each catalog shelf has in the gallery. */
export function useGalleryShelves() {
  const api = useApi();
  return useQuery({
    queryKey: ['gallery', 'shelves'] as const,
    queryFn: () => api.get<{ total: number; counts: Record<string, number> }>('/gallery/shelves/'),
    staleTime: 60_000,
  });
}

// ── Admin: the gallery's designs (templates of every product) ──
export interface GalleryDesignPatch {
  name?: string;
  translations?: Translations<{ name: string }>;
  images?: string[];
  in_gallery?: boolean;
  color_id?: number | null;
  is_active?: boolean;
}

const ADMIN_KEY = ['gallery', 'admin'] as const;

export function useAdminGalleryDesigns() {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery({
    queryKey: ADMIN_KEY,
    queryFn: () => api.get<AdminTemplate[]>('/admin/catalog/templates/'),
    enabled: isAdmin,
  });
}

/** Admin changes; every one refreshes the admin list, the public feed and
 * the Studio's lists. */
export function useAdminGalleryActions() {
  const api = useApi();
  const queryClient = useQueryClient();
  const busy = ref(false);
  async function run<T>(action: () => Promise<T>): Promise<T> {
    busy.value = true;
    try {
      return await action();
    }
    finally {
      busy.value = false;
      await queryClient.invalidateQueries({ queryKey: ['gallery'] });
      await queryClient.invalidateQueries({ queryKey: ['catalog', 'templates'] });
    }
  }
  return {
    busy,
    update: (id: number, body: GalleryDesignPatch) =>
      run(() => api.patch<AdminTemplate>(`/admin/catalog/templates/${id}/`, body)),
    remove: (id: number) => run(() => api.delete(`/admin/catalog/templates/${id}/`)),
    reorder: (ids: number[]) => run(async () => {
      // Show the new order at once; the server's answer replaces it.
      queryClient.setQueryData<AdminTemplate[]>(ADMIN_KEY, old =>
        old && ids.map(id => old.find(i => i.id === id)!).filter(Boolean));
      const list = await api.put<AdminTemplate[]>('/admin/catalog/templates/order/', { ids });
      queryClient.setQueryData(ADMIN_KEY, list);
      return list;
    }),
  };
}
