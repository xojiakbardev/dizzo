<script setup lang="ts">
// The promise, the one action and a picture of what comes out of it. No
// paragraphs: a title, one line, two buttons, three plain benefits.
const { start } = useProductPicker();
const { t } = useI18n();
const localePath = useLocalePath();

const heroSizes = '(max-width: 767px) 34rem, (max-width: 1279px) 50vw, 600px';
const heroSrcset = (ext: 'avif' | 'webp') =>
  [640, 960, 1280].map(w => `/generated/adventure-composite-${w}.${ext} ${w}w`).join(', ');

const benefits = computed(() => [
  { icon: 'lucide:rotate-3d', label: t('storefront.hero.benefitPreview') },
  { icon: 'lucide:printer', label: t('storefront.hero.benefitPrint') },
  { icon: 'lucide:truck', label: t('storefront.hero.benefitDelivery') },
]);
</script>

<template>
  <section
    aria-labelledby="hero-title"
    class="relative overflow-hidden"
  >
    <div class="mx-auto grid max-w-7xl items-center gap-8 px-4 pb-10 pt-8 sm:px-6 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] md:gap-6 md:pb-12 md:pt-10 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)] lg:px-8 lg:pb-14 lg:pt-12">
      <div>
        <h1
          id="hero-title"
          class="text-[2.1rem] font-extrabold leading-[1.08] tracking-[-0.03em] text-ink sm:text-[2.6rem] lg:text-[3.25rem] xl:text-[3.6rem]"
        >
          {{ t('storefront.hero.title') }}
        </h1>
        <p class="mt-4 max-w-md text-lg leading-7 text-slate-700">
          {{ t('storefront.hero.subtitle') }}
        </p>

        <div class="mt-7 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
          <UiButton
            size="lg"
            class="rounded-xl"
            @click="start"
          >
            {{ t('storefront.nav.startDesign') }}
            <Icon name="lucide:arrow-right" />
          </UiButton>
          <UiButton
            as-child
            variant="outline"
            size="lg"
            class="rounded-xl"
          >
            <NuxtLink :to="localePath('/catalog')">
              {{ t('storefront.hero.browseProducts') }}
            </NuxtLink>
          </UiButton>
        </div>

        <ul class="mt-8 grid grid-cols-3 gap-3 sm:flex sm:flex-wrap sm:gap-x-7 sm:gap-y-3">
          <li
            v-for="b in benefits"
            :key="b.icon"
            class="flex flex-col items-center gap-2 text-center text-[15px] font-semibold text-ink sm:flex-row sm:text-left"
          >
            <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-secondary-50 text-cta">
              <Icon
                :name="b.icon"
                class="text-xl"
              />
            </span>
            {{ b.label }}
          </li>
        </ul>
      </div>

      <!-- phones skip the picture: the products right below say it better -->
      <div class="relative mx-auto hidden w-full max-w-[34rem] sm:block md:max-w-none">
        <!-- a soft warm shape behind the products, slowly changing shape -->
        <div
          class="hero-blob absolute inset-x-[6%] inset-y-[8%] bg-secondary-100/70"
          aria-hidden="true"
        />
        <!-- The LCP picture on tablets and up. Static AVIF/WebP at three
             widths (no image service on Workers); phones match the empty
             source first, so they download nothing for a hidden picture. -->
        <picture>
          <source
            media="(max-width: 639px)"
            srcset="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="
          >
          <source
            type="image/avif"
            :srcset="heroSrcset('avif')"
            :sizes="heroSizes"
          >
          <source
            type="image/webp"
            :srcset="heroSrcset('webp')"
            :sizes="heroSizes"
          >
          <img
            src="/generated/adventure-composite-960.webp"
            :alt="t('storefront.hero.imageAlt')"
            width="1536"
            height="1024"
            class="relative w-full"
            loading="eager"
            fetchpriority="high"
            decoding="async"
          >
        </picture>
      </div>
    </div>
  </section>
</template>

<style scoped>
.hero-blob {
  border-radius: 45% 55% 48% 52% / 55% 45% 55% 45%;
  animation: hero-blob 14s ease-in-out infinite;
  will-change: border-radius, transform;
}
@keyframes hero-blob {
  0%, 100% { border-radius: 45% 55% 48% 52% / 55% 45% 55% 45%; transform: translate(0, 0) rotate(0deg) scale(1); }
  25% { border-radius: 58% 42% 55% 45% / 45% 58% 42% 55%; transform: translate(2%, -2%) rotate(4deg) scale(1.03); }
  50% { border-radius: 40% 60% 42% 58% / 60% 40% 60% 40%; transform: translate(-1%, 2%) rotate(-3deg) scale(.98); }
  75% { border-radius: 55% 45% 60% 40% / 42% 55% 45% 58%; transform: translate(-2%, -1%) rotate(2deg) scale(1.02); }
}
@media (prefers-reduced-motion: reduce) {
  .hero-blob { animation: none; }
}
</style>
