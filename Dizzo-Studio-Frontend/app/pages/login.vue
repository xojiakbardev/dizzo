<script setup lang="ts">
import type { CurrentUser } from '~/types/commerce';

definePageMeta({ layout: 'auth' });

const route = useRoute();
const { t } = useI18n();
const localePath = useLocalePath();

const explicitRedirect = computed(() => {
  const value = route.query.redirect;
  return typeof value === 'string' && value.startsWith('/') ? value : null;
});

async function onSignedIn(user: CurrentUser) {
  // A redirect taken from route.fullPath already carries its /ru or /en prefix.
  if (explicitRedirect.value) await navigateTo(/^\/(ru|en)(\/|\?|$)/.test(explicitRedirect.value) ? explicitRedirect.value : localePath(explicitRedirect.value));
  else if (isAdminUser(user)) await navigateTo(localePath(adminHomePath(user)));
  else await navigateTo(localePath('/'));
}
</script>

<template>
  <div class="mx-auto flex w-full max-w-[540px] flex-col justify-center px-4 py-2">
    <div class="text-center">
      <div class="mx-auto mb-2 flex items-center justify-center">
        <img
          src="/brand/dizzo-mark-96.webp"
          width="48"
          height="48"
          alt="Dizzo"
          class="h-12 w-12 object-contain"
        >
      </div>
      <h1 class="text-2xl font-bold tracking-tight text-gray-900">
        {{ t('storefront.auth.loginTitle') }}
      </h1>
      <p class="mt-0.5 text-sm text-gray-500">
        {{ t('storefront.auth.loginSubtitle') }}
      </p>
    </div>

    <AuthOAuthButtons class="mt-4" />

    <div class="my-3.5 flex items-center gap-3 text-xs font-normal text-gray-400">
      <span class="h-px flex-1 bg-gray-200" />
      {{ t('storefront.auth.orEmail') }}
      <span class="h-px flex-1 bg-gray-200" />
    </div>

    <AuthLoginForm @done="onSignedIn" />

    <p class="mt-4 text-center text-sm text-gray-500">
      {{ t('storefront.auth.noAccount') }}
      <NuxtLink
        :to="localePath({ path: '/register', query: explicitRedirect ? { redirect: explicitRedirect } : {} })"
        class="font-bold text-[#ed5123] hover:underline ml-1"
      >
        {{ t('storefront.auth.signUpLink') }}
      </NuxtLink>
    </p>
  </div>
</template>
