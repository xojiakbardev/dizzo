// /sitemap.xml: the storefront pages, every shelf of the catalog and the
// gallery, every product's page and Studio, and every gallery piece — each
// in Uzbek, Russian and English (with hreflang links between the three) and
// with their pictures (Google's image sitemap), so the shop's work shows up
// in image search too.
import { localizedPath, SEO_LANGS } from '#shared/seo';
import type { SeoLang } from '#shared/seo';
import { listGalleryPieces, listProducts, listShelves } from '../utils/catalog';

const XML_ESCAPES: Record<string, string> = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '\'': '&apos;', '"': '&quot;' };
const escapeXml = (s: string) => s.replace(/[<>&'"]/g, c => XML_ESCAPES[c]!);

interface Page {
  path: string;
  query?: string;
  changefreq: string;
  priority: string;
  lastmod?: string;
  images?: (lang: SeoLang) => { url: string; title: string }[];
}

async function settle<T>(work: Promise<T>, fallback: T, what: string): Promise<T> {
  try {
    return await work;
  }
  catch (error) {
    console.error(`[sitemap] ${what} failed`, error);
    return fallback;
  }
}

export default defineCachedEventHandler(async (event) => {
  const site = siteOrigin(event);
  const load = <T>(fn: (lang: SeoLang) => Promise<T[]>, what: string) =>
    Promise.all(SEO_LANGS.map(lang => settle(fn(lang), [] as T[], `${what} (${lang})`)))
      .then(lists => Object.fromEntries(SEO_LANGS.map((lang, i) => [lang, lists[i]!])) as Record<SeoLang, T[]>);
  const [products, shelves, pieces] = await Promise.all([
    load(listProducts, 'products'),
    load(listShelves, 'shelves'),
    load(listGalleryPieces, 'gallery'),
  ]);
  const productShelves = new Set(products.uz.map(p => p.category));
  const galleryShelves = new Set(pieces.uz.map(p => p.category).filter(Boolean));
  const productIn = (lang: SeoLang, slug: string) => products[lang].find(p => p.slug === slug) ?? products.uz.find(p => p.slug === slug);
  const pieceIn = (lang: SeoLang, id: string) => pieces[lang].find(p => p.id === id) ?? pieces.uz.find(p => p.id === id);

  const pages: Page[] = [
    { path: '/', changefreq: 'daily', priority: '1.0', images: () => [{ url: `${site}/brand/og-image.jpg`, title: 'Dizzo' }] },
    {
      path: '/catalog', changefreq: 'daily', priority: '0.9',
      images: lang => products[lang].filter(p => p.cover_url).map(p => ({ url: p.cover_url!, title: p.name })),
    },
    ...shelves.uz.filter(s => productShelves.has(s.slug)).map(s => ({
      path: '/catalog', query: `?c=${encodeURIComponent(s.slug)}`, changefreq: 'weekly', priority: '0.8',
    })),
    { path: '/gallery', changefreq: 'daily', priority: '0.8' },
    { path: '/privacy', changefreq: 'yearly', priority: '0.3' },
    ...shelves.uz.filter(s => galleryShelves.has(s.slug)).map(s => ({
      path: '/gallery', query: `?c=${encodeURIComponent(s.slug)}`, changefreq: 'weekly', priority: '0.7',
    })),
    ...products.uz.flatMap(p => [
      {
        path: `/products/${encodeURIComponent(p.slug)}`, changefreq: 'weekly', priority: '0.9',
        images: (lang: SeoLang) => {
          const item = productIn(lang, p.slug)!;
          return item.cover_url ? [{ url: item.cover_url, title: item.name }] : [];
        },
      },
      { path: `/studio/${encodeURIComponent(p.slug)}`, changefreq: 'monthly', priority: '0.5' },
    ]),
    ...pieces.uz.map(g => ({
      path: '/gallery', query: `?p=${encodeURIComponent(g.id)}`, changefreq: 'monthly', priority: '0.6',
      lastmod: g.created_at.slice(0, 10),
      images: (lang: SeoLang) => {
        const item = pieceIn(lang, g.id)!;
        return item.image_urls.slice(0, 5).map(url => ({ url, title: item.title ? `${item.title} — ${item.product_name}` : item.product_name }));
      },
    })),
  ];

  const loc = (page: Page, lang: SeoLang) => `${site}${localizedPath(page.path, lang)}${page.query ?? ''}`;
  const entry = (page: Page, lang: SeoLang) => [
    '  <url>',
    `    <loc>${escapeXml(loc(page, lang))}</loc>`,
    ...SEO_LANGS.map(l => `    <xhtml:link rel="alternate" hreflang="${l}" href="${escapeXml(loc(page, l))}"/>`),
    `    <xhtml:link rel="alternate" hreflang="x-default" href="${escapeXml(loc(page, 'uz'))}"/>`,
    ...(page.lastmod ? [`    <lastmod>${page.lastmod}</lastmod>`] : []),
    `    <changefreq>${page.changefreq}</changefreq>`,
    `    <priority>${page.priority}</priority>`,
    ...(page.images?.(lang) ?? []).map(i =>
      `    <image:image><image:loc>${escapeXml(i.url)}</image:loc><image:title>${escapeXml(i.title)}</image:title></image:image>`),
    '  </url>',
  ].join('\n');

  setResponseHeader(event, 'content-type', 'application/xml; charset=utf-8');
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
    ...pages.flatMap(page => SEO_LANGS.map(lang => entry(page, lang))),
    '</urlset>',
    '',
  ].join('\n');
}, { name: 'sitemap', maxAge: 60 * 60, swr: true });
