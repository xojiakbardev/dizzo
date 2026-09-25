<script setup lang="ts">
// An admin who signs in from the modal (on a shop page) goes to the panel,
// as the admin-lockout middleware sends them on every navigation.
import { stripLocalePrefix } from '~/lib/i18n';

const route = useRoute();
useSiteSeo();
// <html lang> and the page's twins in the other languages (hreflang); the
// canonical link is useSiteSeo's.
const localeHead = useLocaleHead({ seo: { canonicalQueries: ['c', 'p'] } });
useHead(() => ({
  htmlAttrs: { lang: localeHead.value.htmlAttrs?.lang },
  link: (localeHead.value.link ?? []).filter(l => l.rel !== 'canonical'),
  meta: localeHead.value.meta ?? [],
}));
const { data: currentUser } = useCurrentUser();


onMounted(() => {
  syncAuthState();
  if (typeof window !== 'undefined' && window.location.hash) {
    history.replaceState(null, '', window.location.pathname + window.location.search);
  }
});
</script>

<template>
  <div>
    <NuxtRouteAnnouncer />
    <NuxtLoadingIndicator
      color="#d24419"
      :height="3"
    />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
    <AuthModal />
  </div>
</template>
