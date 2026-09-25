import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';

export interface GalleryShowcaseImage {
  media_id: string;
  url: string;
}

export interface GalleryShowcase {
  id: number;
  product_id: number;
  product_name: string;
  product_slug: string;
  title: string | null;
  customer_name: string | null;
  sort_order: number;
  is_published: boolean;
  status: string;
  created_by_name: string | null;
  branch_name: string | null;
  rejection_reason: string | null;
  created_at: string;
  images: GalleryShowcaseImage[];
}

export function useAdminShowcases() {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery<GalleryShowcase[]>({
    queryKey: ['admin', 'gallery', 'showcases'],
    queryFn: () => api.get<GalleryShowcase[]>('/admin/gallery/'),
    enabled: isAdmin,
  });
}

export function useSubmitShowcase() {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: { product_id: number; media_ids: string[]; title?: string | null; customer_name?: string | null }) =>
      api.post<GalleryShowcase>('/admin/gallery/submit/', payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'gallery', 'showcases'] });
    },
  });
}
