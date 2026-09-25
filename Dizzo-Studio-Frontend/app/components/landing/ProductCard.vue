<script setup lang="ts">
// The storefront's product card (landing and catalog): photo, name, and the
// backend's "from" price with "Batafsil" across from it; the whole card is
// the link to its page (/products/<slug>, where "Dizayn qilish" opens the
// Studio), so it is one large target on a phone. The photo sits on white —
// the 3D renders are shot on a light backdrop and must not read as a grey
// box on the card.
import type { PublicProductCard } from '~/types/catalog';

defineProps<{ product: PublicProductCard }>();
const { t } = useI18n();
const localePath = useLocalePath();
const price = (value: string) => formatMoney(value).replace('UZS', 'uzs');
</script>

<template>
  <NuxtLink
    :to="localePath(`/products/${product.slug}`)"
    class="group flex h-full flex-col overflow-hidden rounded-2xl border border-line bg-white transition hover:border-slate-300 hover:shadow-[0_8px_24px_-12px_rgb(15_23_42/0.18)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
  >
    <span class="flex aspect-[5/4] items-center justify-center overflow-hidden bg-plate">
      <img
        v-if="product.cover_url"
        v-bind="thumbAttrs(product.cover_url, '(min-width: 1024px) 25vw, 50vw')"
        :alt="product.name"
        class="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
        loading="lazy"
      >
      <Icon
        v-else
        name="lucide:package"
        class="text-4xl text-slate-400"
      />
    </span>
    <span class="flex flex-1 flex-col border-t border-line px-3.5 pb-3.5 pt-3 sm:px-4 sm:pb-4">
      <span class="line-clamp-2 text-[15px] font-semibold leading-snug text-ink sm:text-base">{{ product.name }}</span>
      <span class="mt-auto flex items-center justify-between gap-2 pt-1.5">
        <!-- "…dan": this is the cheapest basket, not the price of every
             basket, and a bare number reads as a promise. -->
        <span class="truncate text-[15px] font-bold text-ink">{{ t('storefront.picker.fromPrice', { price: price(product.from_price) }) }}</span>
        <span class="inline-flex shrink-0 items-center gap-1 text-sm font-semibold text-cta">
          <span class="max-sm:hidden">{{ t('storefront.productCard.details') }}</span>
          <Icon
            name="lucide:arrow-right"
            class="text-base transition-transform duration-200 group-hover:translate-x-0.5"
          />
        </span>
      </span>
    </span>
  </NuxtLink>
</template>
