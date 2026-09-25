<script setup lang="ts">
// A product before its Studio (the mobile app's flow): pictures of the
// chosen type and colour, the types, colours, sizes, print methods and
// specs, the price, and "Dizayn qilish". The choice lives in the URL
// (?variant=&color=&size=), so a link shows the same thing and the Studio
// opens with it.
import type { PublicColor, PublicVariant, CatalogMethod } from '~/types/catalog';
import { METHOD_INFO, METHOD_LABELS } from '~/types/catalog';
import { ApiError } from '~/composables/useApi';
import { asLang, breadcrumbLd, ldJson, plainText, productPageSeo, withSiteName } from '#shared/seo';

const route = useRoute();
const router = useRouter();
const config = useRuntimeConfig();
const { t, locale } = useI18n();
const seoLang = computed(() => asLang(locale.value));
const localePath = useLocalePath();
const slug = computed(() => String(route.params.slug ?? ''));
const query = useProductDetail(slug);
const product = computed(() => query.data.value ?? null);

const notFound = computed(() => query.error.value instanceof ApiError && query.error.value.status === 404);
if (import.meta.server) {
  await query.suspense().catch(() => {});
  if (notFound.value) throw createError({ statusCode: 404, statusMessage: t('storefront.product.notFound'), fatal: true });
}
watch(notFound, (missing) => {
  if (missing) showError(createError({ statusCode: 404, statusMessage: t('storefront.product.notFound'), fatal: true }));
}, { immediate: true });

// ── The choice, read from and written to the URL ──
const num = (v: unknown) => {
  if (typeof v === 'number' && !Number.isNaN(v)) return v;
  if (typeof v === 'string' && /^\d+$/.test(v.trim())) return Number(v.trim());
  if (Array.isArray(v) && v.length > 0 && typeof v[0] === 'string' && /^\d+$/.test(v[0].trim())) return Number(v[0].trim());
  return null;
};
const variant = computed<PublicVariant | null>(() => {
  const list = product.value?.variants ?? [];
  const wanted = num(route.query.variant);
  return list.find(v => v.id === wanted) ?? list[0] ?? null;
});
const color = computed<PublicColor | null>(() => {
  const colors = variant.value?.colors ?? [];
  const wanted = num(route.query.color);
  if (wanted === null) return null;
  return colors.find(c => c.id === wanted) ?? null;
});
const sizes = computed(() => variant.value?.sizes ?? []);
const size = computed(() => {
  const wanted = typeof route.query.size === 'string' ? route.query.size : null;
  return sizes.value.find(s => s.label === wanted && s.is_available) ?? null;
});
// A choice the customer made (a bare link shows the "from" price).
const chosen = computed(() => route.query.variant !== undefined || route.query.color !== undefined || route.query.size !== undefined);

function choose(patch: { variant?: number; color?: number | null; size?: string | null }) {
  const next: Record<string, string> = {};
  const v = patch.variant ?? variant.value?.id;
  if (v !== undefined) next.variant = String(v);
  const c = 'color' in patch ? patch.color : color.value?.id;
  if (c !== null && c !== undefined) next.color = String(c);
  const s = 'size' in patch ? patch.size : size.value?.label;
  if (s) next.size = s;
  void router.replace({ query: next });
}
function pickVariant(id: number) {
  if (id === variant.value?.id) return;
  const next = product.value?.variants.find(v => v.id === id);
  // Keep the colour (by name) and the size where the new type has them.
  const sameColor = next?.colors.find(c => c.name === color.value?.name)?.id ?? null;
  const sameSize = next?.sizes.find(s => s.label === size.value?.label && s.is_available)?.label ?? null;
  choose({ variant: id, color: sameColor, size: sameSize });
}

// ── The pictures: the type's plain base shot first, then the chosen
// colour's, then the ones that hold for the whole product. Picking another
// colour swaps only the middle block, so the first picture stays where the
// customer left it — and the gallery, which jumps back to index 0 when the
// set changes, lands on that same plain shot every time. ──
const cover = computed(() => (product.value?.cover_url ? [product.value.cover_url] : []));
function imagesOf(v: PublicVariant | null, c: PublicColor | null): string[] {
  if (c && c.images && c.images.length) {
    const out = [...c.images, ...(product.value?.images ?? [])].filter((u): u is string => Boolean(u));
    return [...new Set(out)];
  }
  const allColorImages = (v?.colors ?? []).flatMap(col => col.images ?? []);
  const out = [...cover.value, ...allColorImages, ...(product.value?.images ?? [])].filter((u): u is string => Boolean(u));
  return out.length ? [...new Set(out)] : cover.value;
}
const images = computed(() => imagesOf(variant.value, color.value));
const hovered = ref<number | null>(null);
// Next likely sets: the other colours of this type, and the whole set of a type under the pointer.
const preload = computed(() => {
  const v = variant.value;
  const out = (v?.colors ?? []).flatMap(c => c.images);
  (product.value?.variants ?? []).forEach((o) => {
    if (o.id === hovered.value) out.push(...imagesOf(o, o.colors[0] ?? null));
  });
  return [...new Set(out)];
});

// ── 3D ──
const shape = computed(() => product.value?.shapes.find(s => s.id === variant.value?.shape_id) ?? null);
const canShow3d = computed(() => Boolean(shape.value && (shape.value.kind !== 'model' || shape.value.model_url)));
const show3d = ref(false);

// ── Price ──
const price = computed(() => {
  if (!variant.value) return 0;
  return Number(variant.value.base_price) + Number(color.value?.surcharge ?? 0) + Number(size.value?.surcharge ?? 0);
});

const studioLink = computed(() => {
  const activeColor = color.value ?? variant.value?.colors[0] ?? null;
  return localePath({
    path: `/studio/${slug.value}`,
    query: {
      ...(variant.value ? { variant: String(variant.value.id) } : {}),
      ...(activeColor ? { color: String(activeColor.id) } : {}),
      ...(size.value ? { size: size.value.label } : {}),
    },
  });
});
const needsSize = computed(() => sizes.value.length > 0);
const sizeMissing = computed(() => needsSize.value && !size.value);

// ── Shelf name for the breadcrumb ──
const shelvesQuery = useCategories();
const shelves = shelvesQuery.data;
const catalogProducts = usePublicProducts();
if (import.meta.server) {
  await Promise.all([shelvesQuery.suspense(), catalogProducts.suspense()]).catch(() => {});
}
const shelf = computed(() => {
  const cat = catalogProducts.data.value?.find(p => p.slug === slug.value)?.category;
  return cat ? shelves.value?.find(s => s.slug === cat) ?? null : null;
});

// ── SEO ──
const seoText = computed(() => {
  const v = variant.value;
  const about = plainText(v?.description, 170) || plainText(v?.short_description, 170) || plainText(product.value?.description, 170);
  return productPageSeo(product.value?.name ?? t('storefront.product.fallbackName'), about, seoLang.value);
});
const seoTitle = computed(() => withSiteName(seoText.value.title));
const seoDescription = computed(() => seoText.value.description);
// `from_price` is the cheapest basket a customer can actually leave with —
// base + cheapest colour + cheapest size + the print every order carries.
// A raw `base_price` is a number nobody is ever charged, and this one goes
// into the price Google shows.
const lowPrice = computed(() => Number(product.value?.from_price ?? 0));
const siteUrl = (config.public.siteUrl ?? '').replace(/\/+$/, '');
const pageUrl = computed(() => `${siteUrl}${localePath(`/products/${slug.value}`)}`);
// The cover first: it is the one picture composed on a background, and a
// cut-out shared to a chat window has nothing behind it.
const ogImage = computed(() => product.value?.cover_url ?? images.value[0] ?? `${siteUrl}/brand/og-image.jpg`);

useSeoMeta({
  title: () => seoTitle.value,
  description: () => seoDescription.value,
  ogTitle: () => seoTitle.value,
  ogDescription: () => seoDescription.value,
  ogImage: () => ogImage.value,
  ogImageAlt: () => product.value?.name ?? 'Dizzo',
  ogUrl: () => pageUrl.value,
  ogType: 'product' as never,
  twitterTitle: () => seoTitle.value,
  twitterDescription: () => seoDescription.value,
  twitterImage: () => ogImage.value,
  twitterImageAlt: () => product.value?.name ?? 'Dizzo',
});
useHead({
  link: [{ rel: 'canonical', href: () => pageUrl.value }],
  meta: [
    { property: 'product:brand', content: 'Dizzo' },
    { property: 'product:availability', content: () => (product.value?.variants.length ? 'in stock' : 'out of stock') },
    { property: 'product:price:amount', content: () => (lowPrice.value ? String(lowPrice.value) : undefined) },
    { property: 'product:price:currency', content: 'UZS' },
  ],
});
useHead({
  script: [{
    type: 'application/ld+json',
    key: 'product-ld',
    innerHTML: () => {
      const p = product.value;
      if (!p) return '';
      // The dearest realistic basket: the priciest type with its priciest
      // colour and size. It can only be at or above the "from" price.
      const dearest = p.variants.map(v => Number(v.base_price)
        + Math.max(0, ...(v.colors ?? []).map(c => Number(c.surcharge ?? 0)))
        + Math.max(0, ...(v.sizes ?? []).map(s => Number(s.surcharge ?? 0))));
      const item = {
        '@context': 'https://schema.org',
        '@type': 'Product',
        'name': p.name,
        'description': seoDescription.value,
        'image': images.value.length ? images.value : undefined,
        'url': pageUrl.value,
        'brand': { '@type': 'Brand', 'name': 'Dizzo' },
        'category': shelf.value?.name,
        'sku': p.slug,
        'offers': {
          '@type': 'AggregateOffer',
          'priceCurrency': 'UZS',
          'lowPrice': String(lowPrice.value),
          'highPrice': String(Math.max(lowPrice.value, ...(dearest.length ? dearest : [lowPrice.value]))),
          'offerCount': p.variants.length,
          'availability': p.variants.length ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
        },
      };
      // breadcrumbLd adds the language prefix itself.
      const trail = [{ name: t('storefront.common.products'), path: '/catalog' }];
      if (shelf.value) trail.push({ name: shelf.value.name, path: `/catalog?c=${shelf.value.slug}` });
      trail.push({ name: p.name, path: `/products/${encodeURIComponent(p.slug)}` });
      return ldJson([item, breadcrumbLd(siteUrl, trail, seoLang.value)]);
    },
  }],
});

const label = 'mb-2.5 text-[13px] font-semibold text-foreground';
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 pb-32 pt-4 sm:px-6 sm:pb-28 sm:pt-6 lg:px-8 lg:pb-14">
    <nav
      :aria-label="t('storefront.product.breadcrumb')"
      class="mb-4 flex min-w-0 items-center gap-1.5 text-sm text-slate-500"
    >
      <NuxtLink
        :to="localePath('/catalog')"
        class="shrink-0 hover:text-ink"
      >{{ t('storefront.common.products') }}</NuxtLink>
      <template v-if="shelf">
        <Icon
          name="lucide:chevron-right"
          class="shrink-0 text-xs"
        />
        <NuxtLink
          :to="localePath({ path: '/catalog', query: { c: shelf.slug } })"
          class="shrink-0 hover:text-ink"
        >{{ shelf.name }}</NuxtLink>
      </template>
      <template v-if="product">
        <Icon
          name="lucide:chevron-right"
          class="shrink-0 text-xs"
        />
        <span
          class="truncate font-medium text-ink"
          aria-current="page"
        >{{ product.name }}</span>
      </template>
    </nav>

    <ProductDetailSkeleton v-if="!product && !query.isError.value" />

    <UiEmpty
      v-else-if="!product"
      class="rounded-2xl border border-line bg-white py-14"
    >
      <p class="text-base font-semibold text-ink">
        {{ t('storefront.product.loadError') }}
      </p>
      <UiButton
        variant="outline"
        class="mt-3"
        @click="query.refetch()"
      >
        <Icon name="lucide:rotate-cw" />
        {{ t('storefront.common.retry') }}
      </UiButton>
    </UiEmpty>

    <div
      v-else
      class="lg:grid lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)] lg:items-start lg:gap-10"
    >
      <div class="space-y-4 sm:space-y-6">
        <ProductGallery
          :images="images"
          :alt="variant ? `${product.name} — ${variant.name}` : product.name"
          :preload="preload"
        >
          <template #actions>
            <UiButton
              v-if="canShow3d"
              type="button"
              variant="outline"
              size="sm"
              class="rounded-full bg-white/90 font-semibold shadow-xs"
              @click="show3d = true"
            >
              <Icon name="lucide:rotate-3d" />
              3D
            </UiButton>
          </template>
        </ProductGallery>

        <!-- Variants under the image -->
        <section
          v-if="product.variants.length > 1"
          aria-labelledby="product-types"
        >
          <h2
            id="product-types"
            :class="label"
          >
            {{ t('storefront.product.variant') }}<span class="font-normal text-muted-foreground">: {{ variant?.name }}</span>
          </h2>
          <ProductVariantCards
            :variants="product.variants"
            :selected-id="variant?.id ?? null"
            :selected-color="color?.name || color?.hex"
            @select="pickVariant"
            @hover="hovered = $event"
          />
        </section>
      </div>

      <div class="mt-4 space-y-4 sm:mt-6 sm:space-y-5 lg:sticky lg:top-20 lg:mt-0">
        <header>
          <h1 class="text-2xl font-extrabold leading-tight tracking-[-0.02em] text-ink sm:text-[1.75rem] sm:text-3xl">
            {{ product.name }}
          </h1>
          <p class="mt-3 text-[15px] text-slate-600">
            <template v-if="chosen && variant">
              <span class="text-2xl font-extrabold text-ink">{{ formatMoney(price) }}</span>
            </template>
            <i18n-t
              v-else
              keypath="storefront.picker.fromPrice"
              scope="global"
            >
              <template #price>
                <span class="text-2xl font-extrabold text-ink">{{ formatMoney(product.from_price) }}</span>
              </template>
            </i18n-t>
          </p>
        </header>


        <!-- The chosen type's own words: the one-liner the admin writes,
             then its full description. -->
        <p
          v-if="variant?.short_description"
          class="text-[15px] leading-relaxed text-slate-600"
        >
          {{ variant.short_description }}
        </p>

        <RichText
          v-if="variant?.description"
          :html="variant.description"
        />

        <section v-if="variant && variant.colors.length">
          <h2 :class="label">
            {{ t('storefront.product.color') }}<span v-if="color" class="font-normal text-muted-foreground">: {{ color.name }}</span>
          </h2>
          <div class="scrollbar-none -mx-1 flex snap-x snap-mandatory items-start gap-2 overflow-x-auto overflow-y-hidden scroll-px-1 p-1 pb-2">
            <button
              v-for="c in variant.colors"
              :key="c.id"
              type="button"
              class="group flex shrink-0 snap-start flex-col items-center gap-1.5 rounded-lg p-0.5 outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
              :title="Number(c.surcharge) > 0 ? `${c.name} (+${formatMoney(c.surcharge)})` : c.name"
              :aria-pressed="c.id === color?.id"
              @click="choose({ color: c.id === color?.id ? null : c.id })"
            >
              <span
                class="size-14 sm:size-16 rounded-full border border-black/15 shadow-sm transition overflow-hidden flex items-center justify-center"
                :class="c.id === color?.id ? 'ring-2 ring-primary ring-offset-2' : ''"
                :style="!c.images?.[0] ? { background: c.hex } : undefined"
              >
                <img
                  v-if="c.images?.[0]"
                  :src="c.images[0]"
                  :alt="c.name"
                  class="size-full object-cover"
                >
              </span>
              <span
                class="w-14 sm:w-16 truncate text-center text-[11px] sm:text-[12px] leading-tight"
                :class="c.id === color?.id ? 'font-semibold text-primary' : 'text-muted-foreground'"
              >{{ c.name }}</span>
            </button>
          </div>
        </section>

        <section v-if="needsSize">
          <h2 :class="label">
            {{ t('storefront.product.size') }}<span class="font-normal text-muted-foreground">: {{ size?.label ?? t('storefront.product.sizeNotChosen') }}</span>
          </h2>
          <div class="flex flex-wrap items-center gap-2">
            <UiButton
              v-for="s in sizes"
              :key="s.label"
              variant="outline"
              class="h-11 min-w-11 px-3 font-semibold text-foreground"
              :class="s.label === size?.label ? 'border-primary bg-primary/10 ring-1 ring-primary' : ''"
              :disabled="!s.is_available"
              :title="!s.is_available ? t('storefront.product.soldOut', { size: s.label }) : Number(s.surcharge) > 0 ? `${s.label} (+${formatMoney(s.surcharge)})` : s.label"
              :aria-pressed="s.label === size?.label"
              @click="choose({ size: s.label === size?.label ? null : s.label })"
            >
              {{ s.label }}
            </UiButton>
          </div>
        </section>

        <section v-if="variant && variant.methods.length" class="flex flex-wrap items-center gap-2.5">
          <h2 class="text-[13px] font-semibold text-foreground shrink-0">
            {{ t('storefront.product.printMethod') }}:
          </h2>
          <div class="flex flex-wrap items-center gap-2">
            <span
              v-for="m in variant.methods"
              :key="m"
              class="inline-flex items-center gap-2 rounded-xl border border-border/80 bg-slate-50/80 px-3 py-1.5 text-xs text-foreground shadow-2xs"
            >
              <span class="flex size-5 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
                <Icon :name="METHOD_INFO[m].icon" class="text-xs" />
              </span>
              <span class="font-semibold">{{ METHOD_LABELS[m] }}</span>
              <span v-if="METHOD_INFO[m]?.short" class="text-[11.5px] text-muted-foreground">({{ METHOD_INFO[m].short }})</span>
            </span>
          </div>
        </section>

        <!-- desktop CTA; phones get the sticky bar below -->
        <div class="hidden lg:block">
          <UiButton
            as-child
            size="lg"
            class="w-full rounded-xl"
          >
            <NuxtLink :to="studioLink">
              {{ t('storefront.product.design') }}
              <Icon name="lucide:arrow-right" />
            </NuxtLink>
          </UiButton>
          <p
            v-if="sizeMissing"
            class="mt-2 text-center text-xs text-muted-foreground"
          >
            {{ t('storefront.product.sizeLater') }}
          </p>
        </div>

        <section
          v-if="variant && variant.specs.length"
          class="overflow-hidden rounded-xl border border-border/70 bg-white"
        >
          <div class="border-b border-border/70 px-3.5 py-2.5">
            <h2 class="text-[13px] font-semibold text-foreground">
              {{ t('storefront.product.specs') }}
            </h2>
          </div>
          <dl class="divide-y divide-border/70 text-[13px]">
            <div
              v-for="(s, i) in variant.specs"
              :key="i"
              class="flex justify-between gap-3 px-3.5 py-2"
            >
              <dt class="text-muted-foreground">
                {{ s.label }}
              </dt>
              <dd class="text-right font-semibold text-foreground">
                {{ s.value }}
              </dd>
            </div>
          </dl>
        </section>
      </div>
    </div>

    <!-- phones and tablets: the action stays in reach -->
    <div
      v-if="product"
      class="fixed inset-x-0 bottom-0 z-40 border-t border-line bg-white/95 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 backdrop-blur-md sm:px-6 lg:hidden"
    >
      <div class="mx-auto flex max-w-7xl items-center gap-3">
        <div class="min-w-0 flex-1 leading-tight">
          <p class="truncate text-xs text-muted-foreground">
            {{ variant ? `${variant.name}${color && variant.colors.length > 1 ? ` · ${color.name}` : ''}${size ? ` · ${size.label}` : ''}` : product.name }}
          </p>
          <p class="truncate text-base font-extrabold text-ink">
            {{ chosen && variant ? formatMoney(price) : t('storefront.picker.fromPrice', { price: formatMoney(product.from_price) }) }}
          </p>
        </div>
        <UiButton
          as-child
          size="lg"
          class="shrink-0 rounded-xl"
        >
          <NuxtLink :to="studioLink">
            {{ t('storefront.product.design') }}
            <Icon name="lucide:arrow-right" />
          </NuxtLink>
        </UiButton>
      </div>
    </div>

    <ProductModelView
      v-if="shape && variant && canShow3d"
      v-model:open="show3d"
      :shape="shape"
      :material="variant.material"
      :color-hex="color?.hex ?? null"
      :title="product?.name ?? ''"
    />
  </div>
</template>
