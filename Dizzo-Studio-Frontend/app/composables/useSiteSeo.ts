// Site-wide head (called once, from app.vue), in the page's language: the "· Dizzo" title suffix,
// the canonical link, Open Graph/Twitter tags, the meta description and the
// structured data — from pageSeo() for the storefront pages, from the shelf
// on /catalog?c= and /gallery?c=, from the piece on /gallery?p= and from the
// product on /studio/<slug> (a page's own tags win: /products/<slug> sets
// its own). The data comes from the queries the pages load on the server
// (read here from the same cache keys), so a shared link's preview shows
// the real picture and name. Private areas (/admin, /user, /embed) are
// noindex.
import { useQuery } from '@tanstack/vue-query';
import type { InfiniteData } from '@tanstack/vue-query';
import {
  asLang, breadcrumbLd, crumbNames, defaultSeo, galleryPieceSeo, galleryShelfSeo, ldJson, localizedPath, NOINDEX_PATH,
  OG_IMAGE_PATH, OG_IMAGE_SIZE, OG_LOCALE, organizationLd, pageSeo, PRIVATE_PATH, productSeo, shelfSeo, splitLocale,
  withSiteName,
} from '#shared/seo';
import type { GalleryItem } from '~/composables/queries/useGallery';
import type { PublicCategory, PublicProductCard, PublicProductDetail } from '~/types/catalog';

/** A cache entry some page fetches; never fetched from here. */
function cached<T>(key: () => readonly unknown[]) {
  return useQuery<T>({ queryKey: computed(key), enabled: false });
}

export function useSiteSeo() {
  const route = useRoute();
  const siteUrl = (useRuntimeConfig().public.siteUrl || '').replace(/\/$/, '');
  const { locale } = useI18n();
  const lang = computed(() => asLang(locale.value));
  // The page without its /ru or /en prefix.
  const path = computed(() => splitLocale(route.path.replace(/(.)\/$/, '$1')).path);
  const param = (name: string) => {
    const v = route.query[name];
    return typeof v === 'string' && /^[a-z0-9-]{1,40}$/.test(v) ? v : null;
  };
  const shelfSlug = computed(() => (path.value === '/catalog' || path.value === '/gallery' ? param('c') : null));
  const pieceId = computed(() => (path.value === '/gallery' ? param('p') : null));

  const productSlug = computed(() => {
    const match = /^\/studio\/([^/]+)$/.exec(path.value);
    return match ? decodeURIComponent(match[1]!) : null;
  });
  const product = cached<PublicProductDetail>(() => ['catalog', 'product', productSlug.value ?? '']);
  const categories = cached<PublicCategory[]>(() => ['catalog', 'categories']);
  // The catalog page's first page (its search is empty on a shared link) and its shelf counts.
  const productFeed = cached<InfiniteData<PublicProductCard[]>>(() => ['catalog', 'feed', shelfSlug.value, '']);
  const productCounts = cached<{ total: number; counts: Record<string, number> }>(() => ['catalog', 'shelves']);
  const shelfCounts = cached<{ total: number; counts: Record<string, number> }>(() => ['gallery', 'shelves']);
  const feed = cached<InfiniteData<GalleryItem[]>>(() => ['gallery', 'feed', shelfSlug.value]);
  const piece = cached<GalleryItem>(() => ['gallery', 'item', pieceId.value ?? '']);

  const shelf = computed(() => categories.data.value?.find(c => c.slug === shelfSlug.value) ?? null);
  const shelfProducts = computed(() => productFeed.data.value?.pages?.flat() ?? []);
  const shelfProductCount = computed(() => {
    const c = productCounts.data.value;
    return shelf.value ? c?.counts[shelf.value.slug] ?? shelfProducts.value.length : c?.total ?? shelfProducts.value.length;
  });
  const feedItems = computed(() => feed.data.value?.pages?.flat() ?? []);

  const seo = computed<{ title: string; description: string; image: string | null; alt?: string } | null>(() => {
    if (productSlug.value) {
      const p = product.data.value;
      return p ? { ...productSeo(p, lang.value), alt: p.name } : null;
    }
    if (path.value === '/catalog' && shelf.value) {
      const s = shelfSeo(shelf.value.name, shelfProductCount.value, lang.value);
      return { ...s, title: withSiteName(s.title), image: shelfProducts.value.find(p => p.cover_url)?.cover_url ?? null, alt: shelf.value.name };
    }
    if (path.value === '/gallery' && piece.data.value) {
      const it = piece.data.value;
      const s = galleryPieceSeo(it, lang.value);
      return { ...s, title: withSiteName(s.title), image: it.preview_image_url, alt: it.title || it.product_name };
    }
    if (path.value === '/gallery' && shelf.value) {
      const s = galleryShelfSeo(shelf.value.name, shelfCounts.data.value?.counts[shelf.value.slug], lang.value);
      return { ...s, title: withSiteName(s.title), image: feedItems.value[0]?.preview_image_url ?? null, alt: s.title };
    }
    const page = pageSeo(path.value, lang.value);
    if (!page) return null;
    // A page of pictures shows its first one.
    const image = path.value === '/gallery'
      ? feedItems.value[0]?.preview_image_url ?? null
      : null;
    return { ...page, title: withSiteName(page.title), image, alt: page.title };
  });

  const title = computed(() => seo.value?.title ?? defaultSeo(lang.value).title);
  const description = computed(() => seo.value?.description ?? defaultSeo(lang.value).description);
  const ownImage = computed(() => seo.value?.image || null);
  const image = computed(() => ownImage.value || `${siteUrl}${OG_IMAGE_PATH}`);
  // The shelf and the piece are pages of their own; search and page numbers are not.
  const url = computed(() => {
    const query = pieceId.value ? `?p=${pieceId.value}` : shelf.value ? `?c=${shelf.value.slug}` : '';
    return `${siteUrl}${localizedPath(path.value, lang.value)}${query}`;
  });
  const isPrivate = computed(() => PRIVATE_PATH.test(path.value));
  // The product page writes its own title, preview and structured data.
  const ownHead = computed(() => /^\/products\/[^/]+$/.test(path.value));
  const mine = <T>(value: T) => (ownHead.value ? undefined : value);
  // The Studio is a client-only editor: link previews yes, search results no.
  const isStudio = computed(() => /^\/studio(\/|$)/.test(path.value));
  const robots = computed(() => {
    if (isPrivate.value) return 'noindex, nofollow';
    if (isStudio.value || NOINDEX_PATH.test(path.value)) return 'noindex, follow';
    return 'index, follow, max-image-preview:large, max-snippet:-1';
  });

  // Structured data: the shop on the home page; a breadcrumb and the list
  // shown on the catalog and the gallery.
  const structured = computed(() => {
    if (isPrivate.value) return [];
    const names = crumbNames(lang.value);
    if (path.value === '/') return organizationLd(siteUrl, lang.value);
    if (path.value === '/catalog') {
      const trail = [{ name: names.catalog, path: '/catalog' }];
      if (shelf.value) trail.push({ name: shelf.value.name, path: `/catalog?c=${shelf.value.slug}` });
      return [
        breadcrumbLd(siteUrl, trail, lang.value),
        {
          '@context': 'https://schema.org',
          '@type': 'CollectionPage',
          'name': title.value,
          'description': description.value,
          'url': url.value,
          'inLanguage': lang.value,
          'mainEntity': {
            '@type': 'ItemList',
            'numberOfItems': shelfProductCount.value,
            'itemListElement': shelfProducts.value.slice(0, 30).map((p, i) => ({
              '@type': 'ListItem',
              'position': i + 1,
              'url': `${siteUrl}${localizedPath(`/products/${encodeURIComponent(p.slug)}`, lang.value)}`,
              'name': p.name,
              ...(p.cover_url ? { image: p.cover_url } : {}),
            })),
          },
        },
      ];
    }
    if (path.value === '/gallery') {
      const trail = [{ name: names.gallery, path: '/gallery' }];
      if (shelf.value) trail.push({ name: shelf.value.name, path: `/gallery?c=${shelf.value.slug}` });
      const it = piece.data.value;
      const work = (g: GalleryItem) => ({
        '@type': 'ImageObject',
        'contentUrl': g.preview_image_url,
        'name': g.title || g.product_name,
        'caption': g.title ? `${g.title} — ${g.product_name}` : g.product_name,
        'url': `${siteUrl}${localizedPath('/gallery', lang.value)}?p=${g.id ?? ''}`,
        'uploadDate': g.created_at,
      });
      if (it) {
        trail.push({ name: it.title || it.product_name, path: `/gallery?p=${it.id ?? ''}` });
        return [breadcrumbLd(siteUrl, trail, lang.value), { '@context': 'https://schema.org', ...work(it), 'description': description.value }];
      }
      return [
        breadcrumbLd(siteUrl, trail, lang.value),
        {
          '@context': 'https://schema.org',
          '@type': 'ImageGallery',
          'name': title.value,
          'description': description.value,
          'url': url.value,
          'inLanguage': lang.value,
          'image': feedItems.value.slice(0, 24).map(work),
        },
      ];
    }
    return [];
  });

  useHead({
    titleTemplate: t => withSiteName(t),
    // A storefront page without its own useHead title still gets its name.
    title: () => (productSlug.value || ownHead.value ? undefined : seo.value?.title),
    link: () => (isPrivate.value || isStudio.value || ownHead.value ? [] : [{ rel: 'canonical', href: url.value }]),
    script: () => structured.value.length
      ? [{ type: 'application/ld+json', key: 'site-ld', innerHTML: ldJson(structured.value) }]
      : [],
  });

  useSeoMeta({
    description: () => mine(description.value),
    ogSiteName: 'Dizzo',
    ogLocale: () => OG_LOCALE[lang.value],
    ogType: () => mine('website' as const),
    ogTitle: () => mine(title.value),
    ogDescription: () => mine(description.value),
    ogUrl: () => mine(url.value),
    ogImage: () => mine(image.value),
    ogImageAlt: () => mine(seo.value?.alt ?? 'Dizzo'),
    // The shop's own banner has a known size; a picture of a piece doesn't.
    ogImageWidth: () => (ownImage.value ? undefined : mine(OG_IMAGE_SIZE.width)),
    ogImageHeight: () => (ownImage.value ? undefined : mine(OG_IMAGE_SIZE.height)),
    twitterCard: 'summary_large_image',
    twitterTitle: () => mine(title.value),
    twitterDescription: () => mine(description.value),
    twitterImage: () => mine(image.value),
    twitterImageAlt: () => mine(seo.value?.alt ?? 'Dizzo'),
    robots: () => robots.value,
  });
}
