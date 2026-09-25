<script setup lang="ts">
// Only links that lead somewhere and contacts that answer. A phone number
// or e-mail goes in `contacts` once there is one.
const year = new Date().getFullYear();
const { t } = useI18n();
const localePath = useLocalePath();

const FOOTER_PRODUCTS = 3;
const { list } = useStorefrontProducts();
const productLinks = computed(() => list.value.slice(0, FOOTER_PRODUCTS).map(p => ({ label: p.name, to: localePath(`/studio/${p.slug}`) })));

const helpLinks = computed(() => [
  { label: t('storefront.nav.tutorials'), to: localePath({ path: '/', hash: '#tutorials' }) },
  { label: t('storefront.footer.faq'), to: localePath({ path: '/', hash: '#faq' }) },
  { label: t('storefront.nav.gallery'), to: localePath('/gallery') },
  { label: t('storefront.footer.myOrders'), to: localePath('/user/orders') },
]);

const contacts = [
  { icon: 'lucide:send', href: 'https://t.me/dizzo_uz', label: 'Telegram' },
  { icon: 'lucide:instagram', href: 'https://instagram.com/dizzo_uz', label: 'Instagram' },
];
</script>

<template>
  <footer class="border-t border-line bg-white">
    <div class="mx-auto max-w-7xl px-4 pb-8 pt-10 sm:px-6 lg:px-8 lg:pt-12">
      <div class="grid grid-cols-2 gap-x-6 gap-y-9 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <NuxtLink
          :to="localePath('/')"
          class="col-span-2 inline-flex items-center gap-1 self-start justify-self-start rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cta md:col-span-1"
          :aria-label="t('storefront.nav.homeAria')"
        >
          <img
            src="/brand/dizzo-mark-144.png"
            alt=""
            class="h-9 w-9 object-contain"
            loading="lazy"
          >
          <span class="font-brand text-xl font-black tracking-tight text-dizzo">Dizzo</span>
        </NuxtLink>

        <nav aria-labelledby="footer-products">
          <h2
            id="footer-products"
            class="text-base font-bold text-ink"
          >
            {{ t('storefront.nav.products') }}
          </h2>
          <ul class="mt-3 space-y-2.5 text-[15px] text-slate-700">
            <li
              v-for="link in productLinks"
              :key="link.to"
            >
              <NuxtLink
                :to="link.to"
                class="transition hover:text-ink"
              >
                {{ link.label }}
              </NuxtLink>
            </li>
            <li>
              <NuxtLink
                :to="localePath('/catalog')"
                class="font-semibold text-ink transition hover:text-cta"
              >
                {{ t('storefront.footer.allProducts') }}
              </NuxtLink>
            </li>
          </ul>
        </nav>

        <nav aria-labelledby="footer-help">
          <h2
            id="footer-help"
            class="text-base font-bold text-ink"
          >
            {{ t('storefront.footer.help') }}
          </h2>
          <ul class="mt-3 space-y-2.5 text-[15px] text-slate-700">
            <li
              v-for="link in helpLinks"
              :key="link.to"
            >
              <NuxtLink
                :to="link.to"
                class="transition hover:text-ink"
              >
                {{ link.label }}
              </NuxtLink>
            </li>
          </ul>
        </nav>

        <div>
          <h2 class="text-base font-bold text-ink">
            {{ t('storefront.footer.contact') }}
          </h2>
          <ul class="mt-3 space-y-2.5 text-[15px] text-slate-700">
            <li
              v-for="contact in contacts"
              :key="contact.href"
            >
              <a
                :href="contact.href"
                target="_blank"
                rel="noopener"
                class="inline-flex items-center gap-2.5 transition hover:text-ink"
              >
                <Icon
                  :name="contact.icon"
                  class="h-[18px] w-[18px] shrink-0 text-slate-500"
                />
                {{ contact.label }}
              </a>
            </li>
          </ul>
        </div>
      </div>

      <div class="mt-10 flex flex-wrap items-center justify-between gap-x-6 gap-y-2 border-t border-line pt-6 text-sm text-slate-600">
        <p>&copy; {{ year }} Dizzo. {{ t('storefront.footer.rights') }}</p>
        <LanguageSwitcher align="start" />
        <NuxtLink
          :to="localePath('/privacy')"
          class="text-xs text-slate-500 transition hover:text-slate-700 hover:underline"
        >
          {{ t('storefront.footer.privacy') }}
        </NuxtLink>
        <NuxtLink
          :to="localePath('/litsenziyalar')"
          class="text-xs text-slate-500 transition hover:text-slate-700 hover:underline"
        >
          {{ t('storefront.licenses.title') }}
        </NuxtLink>
      </div>
    </div>
  </footer>
</template>
