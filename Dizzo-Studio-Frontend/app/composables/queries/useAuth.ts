import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { claimGuestMedia, clearEditorDrafts } from '~/composables/useMediaUpload';
import { queryKeys } from '~/lib/queryKeys';
import type { AuthPayload, CurrentUser, RegisterPayload } from '~/types/commerce';
import { localizedPath, stripLocalePrefix } from '~/lib/i18n';

export function useCurrentUser() {
  const api = useApi();
  const authState = useAuthState();

  return useQuery<CurrentUser | null>({
    queryKey: queryKeys.currentUser,
    queryFn: () => api.get<CurrentUser>('/users/profile/me/'),
    enabled: authState,
    staleTime: 5 * 60_000,
    refetchInterval: 5 * 60_000,
    refetchIntervalInBackground: true,
  });
}

// Signed in, but the user hasn't loaded yet: the account's spot shows a
// skeleton of the avatar's size meanwhile instead of flashing "Kirish".
export function useCurrentUserPending() {
  const { data, isError } = useCurrentUser();
  const signedIn = useSignedIn();
  return computed(() => signedIn.value && data.value === undefined && !isError.value);
}

export interface UpdateProfilePayload {
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  avatar?: string | null;
}

export function useUpdateProfile() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: UpdateProfilePayload) => api.patch<CurrentUser>('/users/profile/me/', payload),
    onSuccess: (user) => {
      queryClient.setQueryData(queryKeys.currentUser, user);
    },
  });
}

// Single source of truth for "is this account an admin/staff account at
// all" — a plain function (not a composable) so it can be read straight out
// of the query cache in contexts where Vue Query hooks aren't safe to call
// (e.g. global route middleware, outside a component's setup scope), as
// well as from the reactive useIsAdmin() composable below.
export const ALL_ADMIN_ROLES = [
  'branch_worker',
  'branch_manager',
  'branch_admin',
  'moderator',
  'admin',
  'super_admin',
] as const;

export function isAdminUser(user: CurrentUser | null | undefined): boolean {
  if (!user) return false;
  return Boolean(
    user.is_staff ||
    user.is_super_admin ||
    (user.role && (ALL_ADMIN_ROLES as readonly string[]).includes(user.role))
  );
}

/** Filial ishchisi dashboardga kirmaydi — login va `/admin` buyurtmalarga ochiladi. */
export function adminHomePath(user: CurrentUser | null | undefined): string {
  if (user?.role === 'branch_worker') return '/admin/orders';
  if (isAdminUser(user)) return '/admin';
  return '/';
}

// Single unified Dizzo admin panel check
export function useIsAdmin() {
  const { data } = useCurrentUser();
  return computed(() => isAdminUser(data.value));
}

export function useIsSuperAdmin() {
  const { data } = useCurrentUser();
  return computed(() => Boolean(data.value?.role === 'super_admin'));
}

export function useCurrentUserRoles() {
  const { data } = useCurrentUser();
  return computed(() => {
    const u = data.value;
    const role = u?.role ?? 'customer';
    const isSuperAdmin = role === 'super_admin';
    const isAdmin = isSuperAdmin || role === 'admin';
    const isModerator = isSuperAdmin || role === 'moderator';
    const isBranchManager = role === 'branch_admin' || role === 'branch_manager';
    const isBranchWorker = role === 'branch_worker';
    const isBranchStaff = isBranchManager || isBranchWorker;
    const isGlobalStaff = isSuperAdmin || role === 'admin' || role === 'moderator';
    return {
      role,
      isSuperAdmin,
      isAdmin,
      isModerator,
      isBranchManager,
      isBranchWorker,
      isBranchStaff,
      isGlobalStaff,
      branchId: u?.branch_id ?? null,
      branchName: u?.branch_name ?? null,
    };
  });
}

type QueryClient = ReturnType<typeof useQueryClient>;

function afterSignIn(queryClient: QueryClient, user: CurrentUser) {
  syncAuthState(true);
  queryClient.setQueryData(queryKeys.currentUser, user);
  queryClient.invalidateQueries({ queryKey: queryKeys.cart });
  queryClient.invalidateQueries({ queryKey: queryKeys.orders });
}

// Runs inside the sign-in mutation, before it resolves — so the redirect
// back to the editor only happens once local drafts point at the claimed
// URLs. A failed claim never fails the sign-in: the guest list is kept and
// the next sign-in retries it.
async function claimGuestUploads(api: ReturnType<typeof useApi>) {
  try {
    await claimGuestMedia(api);
  }
  catch (err) {
    console.error('[media] claiming guest uploads failed, will retry on next sign-in', err);
  }
}

export function useLogin() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: AuthPayload) => {
      const response = await api.post<{ access_token: string; user: CurrentUser }>('/auth/login/', payload);
      if (response.access_token) {
        setSignedInFlag(true);
      }
      await claimGuestUploads(api);
      return response.user;
    },
    onSuccess: user => afterSignIn(queryClient, user),
  });
}

export function useRegister() {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: RegisterPayload) => {
      const firstName = payload.first_name.trim();
      const lastName = payload.last_name.trim();
      const displayName = payload.display_name?.trim() || [firstName, lastName].filter(Boolean).join(' ');

      const response = await api.post<{ access_token: string; user: CurrentUser }>('/auth/register/', {
        ...payload,
        display_name: displayName,
        password_confirm: payload.password,
      });
      if (response.access_token) {
        setSignedInFlag(true);
      }
      await claimGuestUploads(api);
      return response.user;
    },
    onSuccess: user => afterSignIn(queryClient, user),
  });
}

function useOAuthLoginMutation<TInput>(path: string, toBody: (input: TInput) => Record<string, unknown>) {
  const api = useApi();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: TInput) => {
      const response = await api.post<{ access_token: string; user: CurrentUser }>(path, toBody(input));
      if (response.access_token) {
        setSignedInFlag(true);
      }
      await claimGuestUploads(api);
      return response.user;
    },
    onSuccess: user => afterSignIn(queryClient, user),
  });
}

export function useGoogleLogin() {
  return useOAuthLoginMutation<string | { id_token?: string; access_token?: string }>(
    '/auth/oauth/google/',
    input => (typeof input === 'string' ? { id_token: input } : input),
  );
}

export function useTelegramLogin() {
  return useOAuthLoginMutation<Record<string, unknown>>('/auth/oauth/telegram/', payload => payload);
}

// Telegram's newer OIDC login (telegram-login.js popup + postMessage) hands
// back a real signed JWT instead of the classic widget's HMAC payload —
// verified server-side via /oauth/telegram-oidc/ against Telegram's JWKS.
export function useTelegramOidcLogin() {
  return useOAuthLoginMutation<string>('/auth/oauth/telegram-oidc/', idToken => ({ id_token: idToken }));
}

// Requests a one-time deep-link token so the current user can connect their
// Telegram account for order messages (staff: new orders; customers: their
// orders' status — see ProfileSettings). Doesn't touch currentUser's cache — the link only becomes
// `telegram_linked: true` after the bot round-trip completes, which the
// page re-polls for separately.
export function useCreateTelegramLinkToken() {
  const api = useApi();

  return useMutation({
    mutationFn: () => api.post<{ token: string; deep_link: string | null; expires_in_seconds: number }>('/auth/telegram/link-token/'),
  });
}

// The admin panel and the customer's cabinet: a logout there lands on /.
const PRIVATE_PATH = /^\/(admin|user)(\/|$)/;

export function useLogout() {
  const api = useApi();
  const queryClient = useQueryClient();
  const router = useRouter();

  return useMutation({
    mutationFn: () => api.post('/auth/logout/'),
    onSettled: async () => {
      // Off the pages that need an account first, while the token still
      // stands (else the admin panel's own requests fail and send us to
      // /login, or it waits for a user that never comes).
      queryClient.setQueryData(queryKeys.currentUser, null);
      if (PRIVATE_PATH.test(stripLocalePrefix(router.currentRoute.value.path))) await router.replace(localizedPath('/'));
      setSignedInFlag(false);
      syncAuthState(false);
      queryClient.removeQueries({ queryKey: queryKeys.cart });
      queryClient.removeQueries({ queryKey: queryKeys.orders });
      queryClient.removeQueries({ queryKey: ['reviews', 'mine'] });
      queryClient.removeQueries({ queryKey: ['studio', 'designs'] });
      clearEditorDrafts();
    },
  });
}

/** Deletes the account (DELETE /users/profile/me/): the server revokes every
 * token and empties the account; here the session ends like a logout. */
export function useDeleteAccount() {
  const api = useApi();
  const queryClient = useQueryClient();
  const router = useRouter();

  return useMutation({
    mutationFn: () => api.delete('/users/profile/me/'),
    onSuccess: async () => {
      queryClient.setQueryData(queryKeys.currentUser, null);
      setSignedInFlag(false);
      syncAuthState(false);
      queryClient.removeQueries({ queryKey: queryKeys.cart });
      queryClient.removeQueries({ queryKey: queryKeys.orders });
      queryClient.removeQueries({ queryKey: ['reviews', 'mine'] });
      queryClient.removeQueries({ queryKey: ['studio', 'designs'] });
      clearEditorDrafts();
      await router.replace({ path: localizedPath('/'), query: { deleted: '1' } });
    },
  });
}
