<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const route = useRoute();
const { t } = useI18n();
const localePath = useLocalePath();

const redirectTo = computed(() => {
  const value = route.query.redirect;
  return typeof value === 'string' && value.startsWith('/') ? value : '/';
});
// A redirect taken from route.fullPath already carries its /ru or /en prefix.
const redirectTarget = computed(() => (/^\/(ru|en)(\/|\?|$)/.test(redirectTo.value) ? redirectTo.value : localePath(redirectTo.value)));
</script>

<template>
  <div class="mx-auto flex w-full max-w-[540px] flex-col justify-center px-4 py-2">
    <div class="text-center">
      <div class="mx-auto mb-2 flex items-center justify-center">
        <img
          src="/brand/dizzo-mark-144.png"
          width="144"
          height="144"
          alt="Dizzo Studio"
          class="h-12 w-12 object-contain"
        >
      </div>
      <h1 class="text-2xl font-bold tracking-tight text-gray-900">
        {{ t('storefront.auth.registerTitle') }}
      </h1>
      <p class="mt-0.5 text-sm text-gray-500">
        {{ t('storefront.auth.registerSubtitle') }}
      </p>
    </div>

    <AuthOAuthButtons class="mt-4" />

    <div class="my-3.5 flex items-center gap-3 text-xs font-normal text-gray-400">
      <span class="h-px flex-1 bg-gray-200" />
      {{ t('storefront.auth.orEmail') }}
      <span class="h-px flex-1 bg-gray-200" />
    </div>

    <AuthRegisterForm @done="navigateTo(redirectTarget)" />

    <p class="mt-4 text-center text-sm text-gray-500">
      {{ t('storefront.auth.haveAccount') }}
      <NuxtLink
        :to="localePath({ path: '/login', query: redirectTo !== '/' ? { redirect: redirectTo } : {} })"
        class="font-bold text-[#ed5123] hover:underline ml-1"
      >
        {{ t('storefront.auth.signInLink') }}
      </NuxtLink>
    </p>
  </div>
</template>
