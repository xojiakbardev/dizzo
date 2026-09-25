// Singleton wrapper around Google Identity Services (accounts.google.com/gsi/client).
// GIS only supports one `google.accounts.id.initialize()` call per page — call it
// twice with different callbacks and the second call silently overwrites the first,
// which would break whichever of GoogleOneTap / AuthGoogleButton mounted first (both
// want GIS active). So this module loads the script and calls initialize() exactly
// once, with a single shared callback that performs the actual login; callers (the
// One Tap prompt, the button's renderButton) just trigger Google's own UI — no
// redirect, no popup window with a URL bar, everything happens inside GIS's own
// iframe/FedCM flow.

import { getApiErrorMessage } from '~/composables/useApi';
import { i18nT } from '~/lib/i18n';

// The one declaration of `window.google` (AuthGoogleButton uses oauth2 from it).
declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: Record<string, unknown>) => void;
          renderButton: (el: HTMLElement, options: Record<string, unknown>) => void;
          prompt: () => void;
        };
        oauth2: {
          initTokenClient: (config: {
            client_id: string;
            scope: string;
            callback: (response: { access_token?: string; error?: string }) => void;
            error_callback?: (err: unknown) => void;
          }) => {
            requestAccessToken: (options?: { prompt?: string }) => void;
          };
        };
      };
    };
  }
}

const isLoggingIn = ref(false);
const lastError = ref<string | null>(null);
let readyPromise: Promise<boolean> | null = null;

function loadScript(): Promise<void> {
  const src = 'https://accounts.google.com/gsi/client';
  if (typeof window !== 'undefined' && window.google?.accounts?.id) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src*="accounts.google.com/gsi/client"]`);
    if (existing) {
      if (window.google?.accounts?.id) {
        resolve();
        return;
      }
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error(i18nT('common.errors.googleScript'))), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error(i18nT('common.errors.googleScript')));
    document.head.appendChild(script);
  });
}

export function useGoogleGis() {
  const { ensureConfig, redirectAfterLogin } = useOAuth();
  const googleLogin = useGoogleLogin();

  // Resolves to false if Google OAuth isn't configured server-side at all;
  // otherwise loads the script + initializes exactly once and resolves true.
  function ensureReady(): Promise<boolean> {
    readyPromise ??= (async () => {
      const config = await ensureConfig();
      if (!config.google.enabled || !config.google.client_id) return false;

      await loadScript();
      if (!window.google?.accounts?.id) return false;

      window.google.accounts.id.initialize({
        client_id: config.google.client_id,
        auto_select: false,
        use_fedcm_for_prompt: true,
        callback: async (response: { credential: string }) => {
          isLoggingIn.value = true;
          lastError.value = null;
          try {
            await googleLogin.mutateAsync(response.credential);
            await redirectAfterLogin();
          }
          catch (err) {
            lastError.value = getApiErrorMessage(err, i18nT('common.errors.googleSignIn'));
          }
          finally {
            isLoggingIn.value = false;
          }
        },
      });
      return true;
    })();
    return readyPromise;
  }

  return { ensureReady, isLoggingIn, lastError };
}
