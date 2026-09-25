import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { queryKeys } from '~/lib/queryKeys';
import type { CheckoutInput, CheckoutResult } from '~/types/commerce';

/**
 * Places the order. `idempotencyKey` is one UUID per checkout attempt, sent
 * again on a retry, so a request that got through but whose answer was lost
 * doesn't create the order twice (the backend keys on `Idempotency-Key`).
 */
export function useCheckout() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ input, idempotencyKey }: { input: CheckoutInput; idempotencyKey: string }) =>
      api.post<CheckoutResult>('/checkout/', input, { 'Idempotency-Key': idempotencyKey }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.cart });
      queryClient.invalidateQueries({ queryKey: queryKeys.orders });
    },
  });
}
