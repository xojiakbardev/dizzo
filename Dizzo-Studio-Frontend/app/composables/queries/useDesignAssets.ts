import type { DesignAsset } from '~/types/catalog';
import { useQuery, useQueryClient } from '@tanstack/vue-query';

export interface DesignAssetCreateIn {
  media_id: string;
  name: string;
  category: string;
  type?: 'icon' | 'sticker' | 'photo';
  is_active?: boolean;
  sort_order?: number;
}

export interface DesignAssetBulkItemIn {
  media_id: string;
  name: string;
}

export interface DesignAssetBulkCreateIn {
  category: string;
  type?: 'icon' | 'sticker' | 'photo';
  items: DesignAssetBulkItemIn[];
}

export interface DesignAssetPatchIn {
  name?: string;
  category?: string;
  type?: 'icon' | 'sticker' | 'photo';
  is_active?: boolean;
  sort_order?: number;
}

export interface AssetMetaCategory {
  key: string;
  label: Record<string, string>;
  icon: string;
}

export interface AssetMetaType {
  key: string;
  label: Record<string, string>;
}

export interface AssetMeta {
  categories: AssetMetaCategory[];
  types: AssetMetaType[];
}

const PUBLIC_KEY = ['catalog', 'assets', 'public'] as const;
const ADMIN_KEY = ['catalog', 'assets', 'admin'] as const;

/** Get categories and types with multi-language labels from backend */
export function useDesignAssetsMeta() {
  const api = useApi();
  return useQuery<AssetMeta>({
    queryKey: ['catalog', 'assets', 'meta'],
    queryFn: () => api.get<AssetMeta>('/catalog/assets/meta/'),
    staleTime: 5 * 60_000,
  });
}

/** Public icons, stickers and graphics for Studio */
export function usePublicDesignAssets(
  category?: Ref<string | null> | ComputedRef<string | null>,
  type?: Ref<string | null> | ComputedRef<string | null>,
) {
  const api = useApi();
  return useQuery<DesignAsset[]>({
    queryKey: computed(() => [
      ...PUBLIC_KEY,
      category?.value ?? 'all',
      type?.value ?? 'all',
    ]),
    queryFn: () => {
      const params: Record<string, string> = {};
      if (category?.value && category.value !== 'all') params.category = category.value;
      if (type?.value && type.value !== 'all') params.type = type.value;
      return api.get<DesignAsset[]>('/catalog/assets/', params);
    },
    staleTime: 60_000,
  });
}

/** Admin management query for all assets (active & hidden) */
export function useAdminDesignAssets(
  category?: Ref<string | null> | ComputedRef<string | null>,
  type?: Ref<string | null> | ComputedRef<string | null>,
) {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery<DesignAsset[]>({
    queryKey: computed(() => [
      ...ADMIN_KEY,
      category?.value ?? 'all',
      type?.value ?? 'all',
    ]),
    queryFn: () => {
      const params: Record<string, string> = {};
      if (category?.value && category.value !== 'all') params.category = category.value;
      if (type?.value && type.value !== 'all') params.type = type.value;
      return api.get<DesignAsset[]>('/admin/catalog/assets/', params);
    },
    enabled: isAdmin,
    staleTime: 10_000,
  });
}

/** Admin mutations for creating, bulk uploading, updating, toggling and deleting assets */
export function useAdminDesignAssetActions() {
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
      await queryClient.invalidateQueries({ queryKey: ['catalog', 'assets'] });
    }
  }

  return {
    busy,
    create: (body: DesignAssetCreateIn) =>
      run(() => api.post<DesignAsset>('/admin/catalog/assets/', body)),
    bulkCreate: (body: DesignAssetBulkCreateIn) =>
      run(() => api.post<DesignAsset[]>('/admin/catalog/assets/bulk/', body)),
    update: (id: number, body: DesignAssetPatchIn) =>
      run(() => api.patch<DesignAsset>(`/admin/catalog/assets/${id}/`, body)),
    remove: (id: number) =>
      run(() => api.delete(`/admin/catalog/assets/${id}/`)),
    reorder: (ids: number[]) =>
      run(() => api.put<DesignAsset[]>('/admin/catalog/assets/order/', { ids })),
  };
}
