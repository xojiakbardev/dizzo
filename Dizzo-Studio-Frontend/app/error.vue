<script setup lang="ts">
// The one error page: 404 (unknown address, a product that is gone) and
// everything else (500). Standalone — no navbar, no queries — so it renders
// the same on the server and the client whatever broke. The way out is the
// home page or the products; clearError() drops the error on the way.
import type { NuxtError } from '#app';

const props = defineProps<{ error: NuxtError }>();
const { t } = useI18n();
const localePath = useLocalePath();

const notFound = computed(() => props.error.statusCode === 404);
const title = computed(() => (notFound.value ? t('storefront.error.notFoundTitle') : t('storefront.error.failedTitle')));
const text = computed(() => (notFound.value
  ? t('storefront.error.notFoundText')
  : t('storefront.error.failedText')));

useHead({
  title: () => `${title.value} · Dizzo`,
  meta: [{ name: 'robots', content: 'noindex' }],
});

const go = (to: string) => clearError({ redirect: localePath(to) });
const retry = () => reloadNuxtApp({ persistState: false });
</script>

<template>
  <div class="flex min-h-screen flex-col bg-white text-ink">
    <header class="mx-auto flex w-full max-w-7xl items-center px-4 py-4 sm:px-6 lg:px-8">
      <a
        :href="localePath('/')"
        class="flex items-center gap-1.5"
        :aria-label="t('storefront.nav.homeAria')"
        @click.prevent="go('/')"
      >
        <img
          src="/brand/dizzo-mark-144.png"
          width="144"
          height="144"
          alt=""
          class="h-9 w-9 object-contain"
        >
        <span class="font-brand text-[1.4rem] font-black tracking-tight text-dizzo">Dizzo</span>
      </a>
    </header>

    <main class="flex flex-1 items-center justify-center px-4 pb-16">
      <div class="w-full max-w-lg text-center">
        <p
          class="text-[5.5rem] font-extrabold leading-none tracking-[-0.04em] text-dizzo sm:text-[7rem]"
          aria-hidden="true"
        >
          {{ error.statusCode || 500 }}
        </p>
        <h1 class="mt-4 text-2xl font-extrabold tracking-[-0.02em] sm:text-3xl">
          {{ title }}
        </h1>
        <p class="mx-auto mt-3 max-w-md text-base leading-7 text-slate-600">
          {{ text }}
        </p>

        <div class="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
          <button
            type="button"
            class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-cta px-6 text-sm font-semibold text-white transition-colors hover:bg-cta-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
            @click="go('/')"
          >
            <Icon name="lucide:house" />
            {{ t('storefront.common.home') }}
          </button>
          <button
            type="button"
            class="inline-flex h-11 items-center justify-center gap-2 rounded-xl border border-line bg-white px-6 text-sm font-semibold text-ink transition-colors hover:bg-plate focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
            @click="notFound ? go('/catalog') : retry()"
          >
            <Icon
              v-if="notFound"
              name="lucide:shopping-bag"
            />
            <Icon
              v-else
              name="lucide:rotate-cw"
            />
            {{ notFound ? t('storefront.common.products') : t('storefront.common.retry') }}
          </button>
        </div>
      </div>
    </main>
  </div>
</template>
