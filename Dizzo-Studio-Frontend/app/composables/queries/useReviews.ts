// Customer reviews ("Mijozlarimiz") — mirrors app/schemas/review.py.
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { i18nT } from '~/lib/i18n';

export type ReviewStatus = 'pending' | 'approved' | 'rejected';

export interface PublicReview {
  id: number;
  name: string;
  city: string;
  rating: number;
  text: string;
  product_name: string;
  product_slug: string;
  photos: string[];
  created_at: string;
}

export interface Review extends PublicReview {
  status: ReviewStatus;
  order_id: number | null;
  order_number: string | null;
  from_customer: boolean;
  sort_order: number;
}

// Getters: each read is in the page's current language.
export const REVIEW_STATUS_LABELS: Record<ReviewStatus, string> = {
  get pending() { return i18nT('common.reviewStatus.pending'); },
  get approved() { return i18nT('common.reviewStatus.approved'); },
  get rejected() { return i18nT('common.reviewStatus.rejected'); },
};

const KEYS = {
  public: ['reviews', 'public'] as const,
  mine: ['reviews', 'mine'] as const,
  admin: ['reviews', 'admin'] as const,
};

export function usePublicReviews(limit = 12) {
  const api = useApi();
  return useQuery({
    queryKey: [...KEYS.public, limit],
    queryFn: () => api.get<PublicReview[]>(`/reviews/?limit=${limit}`),
    staleTime: 60_000,
  });
}

export function useMyReviews() {
  const api = useApi();
  const authed = useAuthState();
  return useQuery({ queryKey: KEYS.mine, queryFn: () => api.get<Review[]>('/reviews/mine/'), enabled: authed });
}

export function useCreateReview() {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: { order_id: number; rating: number; text: string; city: string; photo_ids: string[] }) =>
      api.post<Review>('/reviews/', body),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: KEYS.mine }),
  });
}

export function useAdminReviews(status: Ref<ReviewStatus | null>) {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery({
    queryKey: computed(() => [...KEYS.admin, status.value] as const),
    queryFn: () => api.get<Review[]>(`/admin/reviews/${status.value ? `?status=${status.value}` : ''}`),
    enabled: isAdmin,
  });
}

/** Admin changes; every one refreshes the admin and the public lists. */
export function useAdminReviewActions() {
  const api = useApi();
  const queryClient = useQueryClient();
  const refresh = () => Promise.all([
    queryClient.invalidateQueries({ queryKey: KEYS.admin }),
    queryClient.invalidateQueries({ queryKey: KEYS.public }),
  ]);
  const busy = ref(false);
  async function run<T>(action: () => Promise<T>): Promise<T> {
    busy.value = true;
    try {
      const out = await action();
      await refresh();
      return out;
    }
    finally {
      busy.value = false;
    }
  }
  return {
    busy,
    create: (body: { name: string; city: string; rating: number; text: string; product_slug: string; photo_ids: string[] }) =>
      run(() => api.post<Review>('/admin/reviews/', body)),
    update: (id: number, body: Partial<Pick<Review, 'status' | 'name' | 'city' | 'rating' | 'text' | 'sort_order'>>) =>
      run(() => api.patch<Review>(`/admin/reviews/${id}/`, body)),
    remove: (id: number) => run(() => api.delete(`/admin/reviews/${id}/`)),
  };
}
