import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import type { ComputedRef, Ref } from 'vue';
import type { Branch, BranchProduct, BranchWorker } from '~/types/commerce';

export function useBranches(includeInactive = false) {
  const api = useApi();
  return useQuery<Branch[]>({
    queryKey: ['branches', { includeInactive }],
    queryFn: () => api.get<Branch[]>('/branches', { params: { include_inactive: includeInactive } }),
    staleTime: 60_000,
  });
}

export function useBranch(branchId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  const api = useApi();
  return useQuery<Branch>({
    queryKey: ['branch', branchId],
    queryFn: () => api.get<Branch>(`/branches/${unref(branchId)}`),
    enabled: computed(() => Boolean(unref(branchId))),
  });
}

export function useBranchProducts(branchId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  const api = useApi();
  return useQuery<BranchProduct[]>({
    queryKey: ['branch-products', branchId],
    queryFn: () => api.get<BranchProduct[]>(`/branches/${unref(branchId)}/products`),
    enabled: computed(() => Boolean(unref(branchId))),
  });
}

export function useUpdateBranchProductAvailability(branchId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ productId, isAvailable, reason }: { productId: number; isAvailable: boolean; reason?: string | null }) =>
      api.patch<BranchProduct>(`/branches/${unref(branchId)}/products/${productId}/availability`, {
        is_available: isAvailable,
        reason,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['branch-products', branchId] });
      queryClient.invalidateQueries({ queryKey: ['branches'] });
    },
  });
}

export function useBranchWorkers(branchId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  const api = useApi();
  return useQuery<BranchWorker[]>({
    queryKey: ['branch-workers', branchId],
    queryFn: () => api.get<BranchWorker[]>(`/branches/${unref(branchId)}/workers`),
    enabled: computed(() => Boolean(unref(branchId))),
  });
}

export function useAssignBranchWorker(branchId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: { user_id: number; role?: string }) =>
      api.post<BranchWorker>(`/branches/${unref(branchId)}/workers`, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['branch-workers', branchId] });
    },
  });
}

export function useRemoveBranchWorker(branchId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (workerId: number) =>
      api.delete(`/branches/${unref(branchId)}/workers/${workerId}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['branch-workers', branchId] });
    },
  });
}
