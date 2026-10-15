<script setup lang="ts">
// Email + password sign-in, shared by /login and the sign-in modal.
import { getApiErrorMessage } from '~/composables/useApi';
import type { CurrentUser } from '~/types/commerce';

const emit = defineEmits<{ done: [user: CurrentUser] }>();

const loginMutation = useLogin();
const { t } = useI18n();
const form = reactive({ email: '', password: '' });
const error = ref<string | null>(null);
const id = useId();

async function handleLogin() {
  error.value = null;
  try {
    emit('done', await loginMutation.mutateAsync({ email: form.email, password: form.password }));
  }
  catch (authError) {
    error.value = getApiErrorMessage(authError, t('storefront.auth.loginError'));
  }
}

const showForgotHint = ref(false);
</script>

<template>
  <form
    class="space-y-3 text-left"
    @submit.prevent="handleLogin"
  >
    <p
      v-if="error"
      class="rounded-xl border border-rose-200 bg-rose-50 px-3.5 py-2 text-xs text-rose-700"
    >
      {{ error }}
    </p>

    <div>
      <label
        :for="`${id}-email`"
        class="mb-1 block text-xs font-semibold text-gray-700"
      >{{ t('storefront.auth.emailLabel') }}</label>
      <input
        :id="`${id}-email`"
        v-model="form.email"
        type="email"
        :placeholder="t('storefront.auth.emailPlaceholder')"
        autocomplete="email"
        required
        class="w-full rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-[#ed5123] focus:ring-1 focus:ring-[#ed5123] outline-hidden transition"
      >
    </div>

    <div>
      <label
        :for="`${id}-password`"
        class="mb-1 block text-xs font-semibold text-gray-700"
      >{{ t('storefront.auth.passwordLabel') }}</label>
      <input
        :id="`${id}-password`"
        v-model="form.password"
        type="password"
        :placeholder="t('storefront.auth.passwordPlaceholder')"
        autocomplete="current-password"
        required
        class="w-full rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-[#ed5123] focus:ring-1 focus:ring-[#ed5123] outline-hidden transition"
      >
    </div>

    <!-- No password reset by email yet: the link used to go nowhere, so it
         says how to get back in instead. -->
    <div class="pt-0.5 pb-1 text-xs">
      <div class="flex justify-end">
        <button
          type="button"
          class="font-semibold text-[#ed5123] hover:underline"
          :aria-expanded="showForgotHint"
          @click="showForgotHint = !showForgotHint"
        >
          {{ t('storefront.auth.forgotPassword') }}
        </button>
      </div>
      <p
        v-if="showForgotHint"
        class="mt-1.5 rounded-lg bg-orange-50 px-3 py-2 text-gray-700"
      >
        {{ t('storefront.auth.forgotPasswordHint') }}
      </p>
    </div>

    <button
      type="submit"
      :disabled="loginMutation.isPending.value"
      class="flex h-11 w-full items-center justify-center rounded-xl bg-cta px-4 text-sm font-semibold text-white shadow-md shadow-cta/25 hover:bg-cta-hover active:scale-[0.99] transition disabled:cursor-not-allowed disabled:opacity-60"
    >
      {{ loginMutation.isPending.value ? t('storefront.auth.checking') : t('storefront.auth.signInLink') }}
    </button>
  </form>
</template>
