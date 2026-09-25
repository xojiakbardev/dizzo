<script setup lang="ts">
// Account creation, shared by /register and the sign-in modal.
import { getApiErrorMessage } from '~/composables/useApi';
import type { CurrentUser } from '~/types/commerce';

const emit = defineEmits<{ done: [user: CurrentUser] }>();

const registerMutation = useRegister();
const { t } = useI18n();
const form = reactive({ full_name: '', phone_number: '', email: '', password: '' });
const error = ref<string | null>(null);

async function handleRegister() {
  error.value = null;
  try {
    const nameParts = form.full_name.trim().split(/\s+/).filter(Boolean);
    const firstName = nameParts.shift() ?? '';
    emit('done', await registerMutation.mutateAsync({
      first_name: firstName,
      last_name: nameParts.join(' '),
      phone_number: form.phone_number,
      email: form.email,
      password: form.password,
    }));
  }
  catch (authError) {
    error.value = getApiErrorMessage(authError, t('storefront.auth.registerError'), ['email', 'password']);
  }
}
</script>

<template>
  <form
    class="space-y-3 text-left"
    @submit.prevent="handleRegister"
  >
    <p
      v-if="error"
      class="rounded-xl border border-rose-200 bg-rose-50 px-3.5 py-2 text-xs text-rose-700"
    >
      {{ error }}
    </p>

    <div>
      <label class="mb-1 block text-xs font-semibold text-gray-700">{{ t('storefront.auth.fullNameLabel') }}</label>
      <input
        v-model="form.full_name"
        :placeholder="t('storefront.auth.fullNamePlaceholder')"
        autocomplete="name"
        required
        class="w-full rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-[#ed5123] focus:ring-1 focus:ring-[#ed5123] outline-hidden transition"
      >
    </div>

    <div>
      <label class="mb-1 block text-xs font-semibold text-gray-700">{{ t('storefront.auth.phoneLabel') }}</label>
      <input
        v-model="form.phone_number"
        type="tel"
        placeholder="+998 90 123 45 67"
        autocomplete="tel"
        required
        class="w-full rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-[#ed5123] focus:ring-1 focus:ring-[#ed5123] outline-hidden transition"
      >
    </div>

    <div>
      <label class="mb-1 block text-xs font-semibold text-gray-700">{{ t('storefront.auth.emailLabel') }}</label>
      <input
        v-model="form.email"
        type="email"
        :placeholder="t('storefront.auth.emailPlaceholder')"
        autocomplete="email"
        required
        class="w-full rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-[#ed5123] focus:ring-1 focus:ring-[#ed5123] outline-hidden transition"
      >
    </div>

    <div>
      <label class="mb-1 block text-xs font-semibold text-gray-700">{{ t('storefront.auth.passwordLabel') }}</label>
      <input
        v-model="form.password"
        type="password"
        :placeholder="t('storefront.auth.newPasswordPlaceholder')"
        minlength="8"
        autocomplete="new-password"
        required
        class="w-full rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-[#ed5123] focus:ring-1 focus:ring-[#ed5123] outline-hidden transition"
      >
    </div>

    <button
      type="submit"
      :disabled="registerMutation.isPending.value"
      class="flex h-11 w-full items-center justify-center rounded-xl bg-cta px-4 text-sm font-semibold text-white shadow-md shadow-cta/25 hover:bg-cta-hover active:scale-[0.99] transition disabled:cursor-not-allowed disabled:opacity-60"
    >
      {{ registerMutation.isPending.value ? t('storefront.auth.creating') : t('storefront.auth.register') }}
    </button>
  </form>
</template>
