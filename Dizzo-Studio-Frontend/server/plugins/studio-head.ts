// The Studio's pages are a SPA shell, so crawlers and link previews that
// don't run JS would see the site-wide title. Put the product's title,
// description, image and canonical link into that shell (the product was
// loaded by middleware/studio-product.ts).
import { localizedPath, OG_IMAGE_PATH, OG_LOCALE, productSeo, SEO_LANGS } from '#shared/seo';
import type { ServerProduct } from '../utils/catalog';

const HTML_ESCAPES: Record<string, string> = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' };
const escapeHtml = (s: string) => s.replace(/[<>&"]/g, c => HTML_ESCAPES[c]!);

// The site-wide versions of what the product replaces.
const SITE_WIDE = /<title>[\s\S]*?<\/title>|<meta[^>]+(?:name="(?:description|twitter:title|twitter:description|twitter:image)"|property="og:(?:title|description|url|image)")[^>]*>|<link[^>]+rel="canonical"[^>]*>/g;

export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('render:html', (html, { event }) => {
    const product = event.context.studioProduct as ServerProduct | undefined;
    if (!product) return;
    const site = siteOrigin(event);
    const lang = product.lang ?? 'uz';
    const seo = productSeo(product, lang);
    const path = `/studio/${encodeURIComponent(product.slug)}`;
    const url = escapeHtml(`${site}${localizedPath(path, lang)}`);
    const title = escapeHtml(seo.title);
    const description = escapeHtml(seo.description);
    const image = escapeHtml(seo.image || `${site}${OG_IMAGE_PATH}`);

    html.head = html.head.map(chunk => chunk.replace(SITE_WIDE, ''));
    html.htmlAttrs = html.htmlAttrs.map(attrs => attrs.replace(/lang="[^"]*"/, `lang="${lang}"`));
    html.head.push([
      `<title>${title}</title>`,
      `<meta name="description" content="${description}">`,
      `<link rel="canonical" href="${url}">`,
      ...SEO_LANGS.map(l => `<link rel="alternate" hreflang="${l}" href="${escapeHtml(`${site}${localizedPath(path, l)}`)}">`),
      `<link rel="alternate" hreflang="x-default" href="${escapeHtml(`${site}${path}`)}">`,
      `<meta property="og:locale" content="${OG_LOCALE[lang]}">`,
      `<meta property="og:title" content="${title}">`,
      `<meta property="og:description" content="${description}">`,
      `<meta property="og:url" content="${url}">`,
      `<meta property="og:image" content="${image}">`,
      `<meta name="twitter:title" content="${title}">`,
      `<meta name="twitter:description" content="${description}">`,
      `<meta name="twitter:image" content="${image}">`,
    ].join('\n'));
  });
});
