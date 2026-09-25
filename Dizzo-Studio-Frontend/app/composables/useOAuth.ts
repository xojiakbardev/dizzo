import { useQueryClient } from '@tanstack/vue-query';
import { localizedPath, stripLocalePrefix } from '~/lib/i18n';
import { adminHomePath } from '~/composables/queries/useAuth';
import { queryKeys } from '~/lib/queryKeys';
import type { CurrentUser } from '~/types/commerce';

export interface OAuthProviderConfig {
  enabled: boolean;
  client_id?: string;
  bot_username?: string;
  bot_id?: string;
}

export interface OAuthConfigResponse {
  google: OAuthProviderConfig;
  telegram: OAuthProviderConfig;
}

const oauthConfig = ref<OAuthConfigResponse | null>(null);
let configPromise: Promise<OAuthConfigResponse> | null = null;

export function useOAuth() {
  const api = useApi();
  const router = useRouter();
  const queryClient = useQueryClient();
  const authModal = useAuthModal();
  const error = ref<string | null>(null);

  // After Google/Telegram sign-in: the modal just closes (the page carries
  // on), /login and /register go to their ?redirect=, and any other page
  // (Google One Tap) stays where it is.
  async function redirectAfterLogin() {
    if (authModal.open.value) {
      authModal.finish(true);
      return;
    }
    const route = router.currentRoute.value;
    const path = stripLocalePrefix(route.path);
    if (!path.startsWith('/login') && !path.startsWith('/register')) return;
    // A redirect taken from route.fullPath already carries its language prefix.
    const redirect = route.query.redirect;
    if (typeof redirect === 'string' && redirect.startsWith('/') && !redirect.startsWith('//')) {
      await navigateTo(redirect);
      return;
    }
    const user = queryClient.getQueryData<CurrentUser>(queryKeys.currentUser);
    await navigateTo(localizedPath(adminHomePath(user)));
  }

  async function ensureConfig(): Promise<OAuthConfigResponse> {
    if (oauthConfig.value) return oauthConfig.value;
    configPromise ??= api.get<OAuthConfigResponse>('/auth/oauth/config/');
    oauthConfig.value = await configPromise;
    return oauthConfig.value;
  }

  return { error, ensureConfig, redirectAfterLogin };
}
