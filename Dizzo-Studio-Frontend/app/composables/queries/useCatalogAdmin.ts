import { useQuery, useQueryClient } from '@tanstack/vue-query';
import type { AdminCatalogListItem, AdminCatalogProduct, AdminCategory } from '~/types/catalog';

const LIST_KEY = ['catalog-admin', 'list'] as const;
const productKey = (id: number) => ['catalog-admin', 'product', id] as const;

export function useCatalogAdminList() {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery({
    queryKey: LIST_KEY,
    queryFn: () => api.get<AdminCatalogListItem[]>('/admin/catalog/products/'),
    enabled: isAdmin,
  });
}

export function useCatalogAdminProduct(id: Ref<number>) {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery({
    queryKey: computed(() => productKey(id.value)),
    queryFn: () => api.get<AdminCatalogProduct>(`/admin/catalog/products/${id.value}/`),
    enabled: computed(() => isAdmin.value && Number.isFinite(id.value)),
  });
}

const CATEGORIES_KEY = ['catalog-admin', 'categories'] as const;

/** Storefront shelves, all of them (hidden ones too), in order. */
export function useAdminCategories() {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery({
    queryKey: CATEGORIES_KEY,
    queryFn: () => api.get<AdminCategory[]>('/admin/catalog/categories/'),
    enabled: isAdmin,
  });
}

// `translations`: { ru: { name }, en: { name } } — merged per language on PATCH.
export type CategoryForm = Pick<AdminCategory, 'slug' | 'name' | 'icon_svg' | 'image_media_id' | 'sort_order' | 'is_active' | 'translations'>;

export function useAdminCategoryActions() {
  const api = useApi();
  const queryClient = useQueryClient();
  const busy = ref(false);
  async function refresh() {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: CATEGORIES_KEY }),
      queryClient.invalidateQueries({ queryKey: ['catalog', 'categories'] }),
      queryClient.invalidateQueries({ queryKey: LIST_KEY }),
    ]);
  }
  async function wrap<T>(work: () => Promise<T>): Promise<T> {
    busy.value = true;
    try {
      const result = await work();
      await refresh();
      return result;
    }
    finally {
      busy.value = false;
    }
  }
  return {
    busy,
    create: (form: CategoryForm) => wrap(() => api.post<AdminCategory>('/admin/catalog/categories/', form)),
    update: (id: number, form: Partial<CategoryForm>) => wrap(() => api.patch<AdminCategory>(`/admin/catalog/categories/${id}/`, form)),
    remove: (id: number) => wrap(() => api.delete<void>(`/admin/catalog/categories/${id}/`)),
  };
}

type Verb = 'post' | 'patch' | 'put' | 'delete';

// Every catalog mutation returns the whole, freshly loaded product: it is
// written straight into the cache, so every editor on the page re-renders
// from the server's truth without a refetch.
export function useCatalogAdminActions() {
  const api = useApi();
  const queryClient = useQueryClient();
  const busy = ref(0);

  async function run(verb: Verb, path: string, body?: unknown): Promise<AdminCatalogProduct> {
    busy.value++;
    try {
      const product = verb === 'delete'
        ? await api.delete<AdminCatalogProduct>(path)
        : await api[verb]<AdminCatalogProduct>(path, body);
      queryClient.setQueryData(productKey(product.id), product);
      await queryClient.invalidateQueries({ queryKey: LIST_KEY });
      return product;
    }
    finally {
      busy.value--;
    }
  }

  return { run, busy: computed(() => busy.value > 0) };
}
