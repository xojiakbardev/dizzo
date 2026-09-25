import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import type { AdminDashboard, DeliveryMethod, OrderDetail, OrderItem, OrderStatus, OrderSummary, PaginatedResponse } from '~/types/commerce';

export interface AdminOrderFilters {
  status?: string;
  delivery_method?: DeliveryMethod;
  search?: string;
  page?: number;
  [key: string]: unknown;
}

export interface UpdateAdminOrderPayload {
  status?: OrderStatus;
  admin_notes?: string;
  tracking_number?: string;
  carrier?: string;
}

export interface AdminOperator {
  id: number;
  email: string;
  full_name: string;
}

export function useAdminOrders(
  filters: Ref<AdminOrderFilters> | AdminOrderFilters = {},
  options: { refetchInterval?: number | false | Ref<number | false> } = {},
) {
  const api = useApi();
  const isAdmin = useIsAdmin();
  const filtersRef = isRef(filters) ? filters : ref(filters);

  return useQuery<PaginatedResponse<OrderSummary>>({
    queryKey: ['admin', 'orders', filtersRef],
    queryFn: () => api.get<PaginatedResponse<OrderSummary>>('/orders/admin/orders/', filtersRef.value),
    enabled: isAdmin,
    refetchInterval: options.refetchInterval,
  });
}

/** The "Boshqaruv paneli" figures for the last `days` days. */
export function useAdminDashboard(days: Ref<number>) {
  const api = useApi();
  const isAdmin = useIsAdmin();
  const roles = useCurrentUserRoles();

  return useQuery<AdminDashboard>({
    queryKey: computed(() => ['admin', 'dashboard', days.value] as const),
    queryFn: () => api.get<AdminDashboard>('/admin/dashboard/', { days: days.value }),
    enabled: computed(() => isAdmin.value && !roles.value.isBranchWorker),
    placeholderData: previous => previous,
  });
}

export function useAdminOrder(id: number | undefined) {
  const api = useApi();
  const isAdmin = useIsAdmin();

  return useQuery<OrderDetail | null>({
    queryKey: ['admin', 'orders', 'detail', id] as const,
    queryFn: () => (id ? api.get<OrderDetail>(`/orders/admin/orders/${id}/`) : Promise.resolve(null)),
    enabled: computed(() => Boolean(id) && isAdmin.value),
  });
}

export function useUpdateAdminOrder() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: { id: number; payload: UpdateAdminOrderPayload }) =>
      api.patch<OrderDetail>(`/orders/admin/orders/${input.id}/`, input.payload),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'orders', 'detail', variables.id] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'orders'] });
    },
  });
}

export function useUpdateOrderProductionStatus() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: { orderId: number; status: string }) =>
      // Keep status changes on the admin endpoint. It has the same
      // transition validation, and is the endpoint available to the admin
      // order page alongside notes, carrier, and tracking updates.
      api.patch<OrderDetail>(`/orders/admin/orders/${input.orderId}/`, { status: input.status }),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'orders', 'detail', variables.orderId] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'orders'] });
    },
  });
}

export function useUpdateOrderItemProduction() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: { orderId: number; itemId: number; status: OrderItem['production_status'] }) =>
      api.patch<OrderDetail>(`/orders/admin/orders/${input.orderId}/items/${input.itemId}/`, { production_status: input.status }),
    onSuccess: (data, variables) => {
      queryClient.setQueryData(['admin', 'orders', 'detail', variables.orderId], data);
    },
  });
}
