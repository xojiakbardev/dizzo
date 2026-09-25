// /sitemap.xml: only the canonical, indexable pages — the storefront pages
// and every product's page — each in Uzbek (bare paths), Russian (/ru) and
// English (/en), with hreflang links between the three, and with their
// pictures (Google's image sitemap), so the shop's work still shows up in
// image search: the products' covers on /catalog, the gallery's pieces on
// /gallery. Left out on purpose: /catalog?c= and /gallery?c= (they
// canonicalize to /catalog and /gallery), /gallery?p= (a piece opened in the
// gallery, not a page of its own) and /studio/* (a client-only editor,
// noindex).
import { localizedPath, SEO_LANGS } from '#shared/seo';
import type { SeoLang } from '#shared/seo';
import { listGalleryPieces, listProducts } from '../utils/catalog';

const XML_ESCAPES: Record<string, string> = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '\'': '&apos;', '"': '&quot;' };
const escapeXml = (s: string) => s.replace(/[<>&'"]/g, c => XML_ESCAPES[c]!);

interface Page {
  path: string;
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
  const [products, pieces] = await Promise.all([
    load(listProducts, 'products'),
    load(listGalleryPieces, 'gallery'),
  ]);
  const productIn = (lang: SeoLang, slug: string) => products[lang].find(p => p.slug === slug) ?? products.uz.find(p => p.slug === slug);
  const newest = (list: { created_at: string }[]) => list.reduce<string | undefined>((max, p) => (!max || p.created_at > max ? p.created_at : max), undefined)?.slice(0, 10);

  const pages: Page[] = [
    { path: '/', changefreq: 'daily', priority: '1.0', images: () => [{ url: `${site}/brand/og-image.jpg`, title: 'Dizzo' }] },
    {
      path: '/catalog', changefreq: 'daily', priority: '0.9',
      images: lang => products[lang].filter(p => p.cover_url).map(p => ({ url: p.cover_url!, title: p.name })),
    },
    {
      // Every piece's first picture (Google reads at most 1000 per page).
      path: '/gallery', changefreq: 'daily', priority: '0.8', lastmod: newest(pieces.uz),
      images: lang => (pieces[lang].length ? pieces[lang] : pieces.uz).flatMap(g => g.image_urls.slice(0, 1).map(url => ({
        url, title: g.title ? `${g.title} — ${g.product_name}` : g.product_name,
      }))).slice(0, 1000),
    },
    { path: '/privacy', changefreq: 'yearly', priority: '0.3' },
    ...products.uz.map(p => ({
      path: `/products/${encodeURIComponent(p.slug)}`, changefreq: 'weekly', priority: '0.9',
      images: (lang: SeoLang) => {
        const item = productIn(lang, p.slug)!;
        return item.cover_url ? [{ url: item.cover_url, title: item.name }] : [];
      },
    })),
  ];

  const loc = (page: Page, lang: SeoLang) => `${site}${localizedPath(page.path, lang)}`;
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
