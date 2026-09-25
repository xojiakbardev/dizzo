<script setup lang="ts">
import { getApiErrorMessage } from '~/composables/useApi';

// `window.google` is declared in composables/useGoogleGis.ts.

const emit = defineEmits<{ error: [message: string] }>();
const { ensureConfig, redirectAfterLogin } = useOAuth();
const googleLogin = useGoogleLogin();
const { t } = useI18n();

const loading = ref(true);
const failed = ref(false);
const processing = ref(false);
let tokenClient: { requestAccessToken: (options?: { prompt?: string }) => void } | null = null;

function loadScript(src: string): Promise<void> {
  if (typeof window !== 'undefined' && window.google?.accounts?.oauth2) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src*="accounts.google.com/gsi/client"]`);
    if (existing) {
      if (window.google?.accounts?.oauth2) {
        resolve();
        return;
      }
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error('Google script failed to load')), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Google script failed to load'));
    document.head.appendChild(script);
  });
}

onMounted(async () => {
  try {
    const config = await ensureConfig();
    if (!config.google.enabled || !config.google.client_id) {
      failed.value = true;
      loading.value = false;
      return;
    }

    await loadScript('https://accounts.google.com/gsi/client');
    if (!window.google?.accounts?.oauth2) {
      failed.value = true;
      loading.value = false;
      return;
    }

    tokenClient = window.google.accounts.oauth2.initTokenClient({
      client_id: config.google.client_id,
      scope: 'email profile openid',
      callback: async (response) => {
        if (response.error) {
          if (response.error !== 'popup_closed' && response.error !== 'user_cancelled') {
            emit('error', t('storefront.auth.googleError'));
          }
          processing.value = false;
          return;
        }
        if (response.access_token) {
          processing.value = true;
          try {
            await googleLogin.mutateAsync({ access_token: response.access_token });
            await redirectAfterLogin();
          }
          catch (err) {
            emit('error', getApiErrorMessage(err, t('storefront.auth.googleError')));
            processing.value = false;
          }
        }
      },
      error_callback: () => {
        processing.value = false;
      },
    });

    loading.value = false;
  }
  catch {
    loading.value = false;
    failed.value = true;
  }
});

function handleTrigger() {
  if (processing.value || !tokenClient) return;
  tokenClient.requestAccessToken({ prompt: 'select_account' });
}
</script>

<template>
  <button
    v-if="loading || failed"
    type="button"
    disabled
    class="relative flex h-11 w-full items-center justify-center gap-2.5 rounded-xl border border-gray-200 bg-white px-3 text-sm font-medium text-gray-400 opacity-70 cursor-not-allowed shadow-2xs"
  >
    <Icon v-if="loading" name="lucide:loader-2" class="h-4 w-4 animate-spin text-gray-400 shrink-0" />
    <span v-if="loading" class="whitespace-nowrap">{{ t('storefront.auth.googleSignIn') }}</span>
    <span v-else class="whitespace-nowrap">{{ t('storefront.auth.googleUnavailable') }}</span>
  </button>

  <button
    v-else
    type="button"
    class="relative flex h-11 w-full items-center justify-center gap-2.5 rounded-xl border border-gray-200 bg-white hover:bg-gray-50 px-3 text-sm font-medium text-gray-700 shadow-2xs transition active:scale-[0.99] cursor-pointer"
    :disabled="processing"
    @click="handleTrigger"
  >
    <Icon
      v-if="processing"
      name="lucide:loader-2"
      class="h-5 w-5 animate-spin text-gray-500 shrink-0"
    />
    <template v-else>
      <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24">
        <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
        <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
        <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" />
        <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" />
      </svg>
      <span class="whitespace-nowrap">{{ t('storefront.auth.googleSignIn') }}</span>
    </template>
  </button>
</template>
