import { useMutation, useQuery } from '@tanstack/vue-query';
import type { DeliveryConfigResponse, DeliveryQuote } from '~/types/commerce';

export interface CalculateDeliveryPayload {
  provider: 'YANDEX' | 'BTS';
  latitude?: number | null;
  longitude?: number | null;
  address?: string;
  city?: string;
  branch_id?: number | null;
}

export function useDeliveryConfig() {
  const api = useApi();
  return useQuery<DeliveryConfigResponse>({
    queryKey: ['delivery', 'config'],
    queryFn: () => api.get<DeliveryConfigResponse>('/delivery/config/'),
    staleTime: 60 * 60 * 1000, // 1 hour
  });
}

export function useCalculateDelivery() {
  const api = useApi();
  return useMutation<DeliveryQuote, unknown, CalculateDeliveryPayload>({
    mutationFn: (payload) => api.post<DeliveryQuote>('/delivery/calculate/', payload),
  });
}
