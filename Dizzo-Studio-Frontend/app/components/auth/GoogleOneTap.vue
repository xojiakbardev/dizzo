<script setup lang="ts">
// Google's "One Tap" floating popover
const route = useRoute();
const { ensureReady } = useGoogleGis();
const authState = useAuthState();

const isExcludedPage = computed(() => {
  const p = route.path.replace(/^\/(ru|en)(?=\/|$)/, '');
  return p.startsWith('/login') || p.startsWith('/register') || p.startsWith('/admin');
});

async function tryPrompt() {
  if (isExcludedPage.value || isAuthenticated()) return;
  try {
    const ready = await ensureReady();
    if (!ready || !window.google?.accounts?.id) return;
    window.google.accounts.id.prompt();
  }
  catch {
    // Silent
  }
}

onMounted(() => {
  tryPrompt();

  watch([authState, () => route.path], () => {
    if (!authState.value && !isExcludedPage.value) {
      tryPrompt();
    }
  });
});
</script>

<template>
  <ClientOnly>
    <div />
  </ClientOnly>
</template>
