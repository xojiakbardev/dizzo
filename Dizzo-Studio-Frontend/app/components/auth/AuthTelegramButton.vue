<script setup lang="ts">
declare global {
  interface Window {
    Telegram?: {
      Login: {
        init: (options: { client_id: string; request_access?: string[] }, callback: (result: unknown) => void) => void;
        auth: (options: { client_id: string; request_access?: string[] }, callback: (result: unknown) => void) => void;
        open: (callback?: (result: unknown) => void) => void;
      };
    };
  }
}

const emit = defineEmits<{ error: [message: string] }>();

const { ensureConfig, redirectAfterLogin } = useOAuth();
const telegramLogin = useTelegramOidcLogin();
const { t } = useI18n();

const loading = ref(true);
const failed = ref(false);
const processing = ref(false);
const botId = ref<string | null>(null);

const loadedScripts = new Set<string>();
function loadScript(src: string) {
  if (loadedScripts.has(src)) return Promise.resolve();
  return new Promise<void>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.onload = () => {
      loadedScripts.add(src);
      resolve();
    };
    script.onerror = () => reject(new Error('Telegram script failed to load'));
    document.head.appendChild(script);
  });
}

async function handleAuthResult(result: any) {
  if (result?.error) {
    if (result.error !== 'popup_closed') emit('error', t('storefront.auth.telegramError'));
    return;
  }
  if (!result?.id_token) return;
  processing.value = true;
  try {
    await telegramLogin.mutateAsync(result.id_token);
    await redirectAfterLogin();
  }
  catch {
    emit('error', t('storefront.auth.telegramError'));
    processing.value = false;
  }
}

onMounted(async () => {
  try {
    const config = await ensureConfig();
    if (!config.telegram.enabled || !config.telegram.bot_id) {
      failed.value = true;
      loading.value = false;
      return;
    }
    botId.value = config.telegram.bot_id;

    await loadScript('https://oauth.telegram.org/js/telegram-login.js?5');
    window.Telegram!.Login.init(
      { client_id: config.telegram.bot_id, request_access: ['write', 'phone'] },
      handleAuthResult,
    );
    loading.value = false;
  }
  catch {
    loading.value = false;
    failed.value = true;
  }
});

function handleTrigger() {
  if (!botId.value || processing.value) return;
  if (window.Telegram?.Login?.auth) {
    window.Telegram.Login.auth(
      { client_id: botId.value, request_access: ['write', 'phone'] },
      handleAuthResult,
    );
  }
  else if (window.Telegram?.Login?.open) {
    window.Telegram.Login.open(handleAuthResult);
  }
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
    <span v-if="loading" class="whitespace-nowrap">{{ t('storefront.auth.telegramSignIn') }}</span>
    <span v-else class="whitespace-nowrap">{{ t('storefront.auth.telegramUnavailable') }}</span>
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
      <svg class="h-6 w-6 text-[#24A1DE] shrink-0" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 0C5.37 0 0 5.37 0 12s5.37 12 12 12 12-5.37 12-12S18.63 0 12 0zm5.56 8.16l-1.97 9.28c-.15.67-.54.83-1.1.52l-3.02-2.23-1.46 1.4c-.16.16-.3.3-.61.3l.21-3.07 5.59-5.05c.24-.22-.05-.34-.37-.13l-6.91 4.35-2.98-.93c-.65-.2-.66-.65.14-.96l11.63-4.48c.54-.2 1.01.12.85.96z" />
      </svg>
      <span class="whitespace-nowrap">{{ t('storefront.auth.telegramSignIn') }}</span>
    </template>
  </button>
</template>
