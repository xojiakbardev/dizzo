import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { useIsSuperAdmin } from '~/composables/queries/useAuth';

export interface SystemSettingItem {
  key: string;
  value: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export function useSystemSettings() {
  const api = useApi();
  const isSuperAdmin = useIsSuperAdmin();
  return useQuery<SystemSettingItem[]>({
    queryKey: ['system-settings'],
    queryFn: () => api.get<SystemSettingItem[]>('/admin/settings'),
    enabled: isSuperAdmin,
  });
}

export function useSaveSystemSetting() {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: { key: string; value: string; description?: string | null }) =>
      api.post<SystemSettingItem>('/admin/settings', payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['system-settings'] });
    },
  });
}

export function useDeleteSystemSetting() {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (key: string) => api.delete(`/admin/settings/${key}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['system-settings'] });
    },
  });
}
