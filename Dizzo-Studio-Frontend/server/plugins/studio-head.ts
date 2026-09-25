// The Studio's pages are a SPA shell, so link previews that don't run JS
// would see the site-wide title. Put the product's title, description and
// image into that shell (the product was loaded by
// middleware/studio-product.ts). The editor itself is not a page for search
// engines: noindex (also sent as X-Robots-Tag, see nuxt.config.ts), and no
// canonical/hreflang links that would contradict it.
import { localizedPath, OG_IMAGE_PATH, OG_LOCALE, productSeo } from '#shared/seo';
import type { ServerProduct } from '../utils/catalog';

const HTML_ESCAPES: Record<string, string> = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' };
const escapeHtml = (s: string) => s.replace(/[<>&"]/g, c => HTML_ESCAPES[c]!);

// The site-wide versions of what the product replaces.
const SITE_WIDE = /<title>[\s\S]*?<\/title>|<meta[^>]+(?:name="(?:description|twitter:title|twitter:description|twitter:image)"|property="og:(?:title|description|url|image)")[^>]*>|<meta[^>]+name="robots"[^>]*>|<link[^>]+rel="(?:canonical|alternate)"[^>]*hreflang[^>]*>|<link[^>]+rel="canonical"[^>]*>/g;

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
      '<meta name="robots" content="noindex, follow">',
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
