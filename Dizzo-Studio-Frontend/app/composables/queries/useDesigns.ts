// The customer's saved Studio designs ("Dizaynlarim", newest first) —
// mirrors DesignSummary in app/schemas/design.py.
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';

export interface DesignSummary {
  id: string;
  product_slug: string;
  product_name: string;
  variant_name: string;
  color_name: string;
  color_hex: string;
  preview_url: string | null;
  /** The Studio's five views (saved with "Saqlash" or the cart); an older design has one or none. */
  previews: string[];
  updated_at: string;
}

const KEY = ['studio', 'designs'] as const;

export function useMyDesigns() {
  const api = useApi();
  const authed = useAuthState();
  return useQuery({ queryKey: KEY, queryFn: () => api.get<DesignSummary[]>('/studio/designs/'), enabled: authed });
}

export function useDeleteDesign() {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.delete(`/studio/designs/${id}/`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: KEY }),
  });
}

/** Where the Studio opened: a design's own link. */
export function designStudioPath(design: Pick<DesignSummary, 'id' | 'product_slug'>) {
  return `/studio/${design.product_slug}?design=${design.id}`;
}
