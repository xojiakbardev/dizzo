// What search engines and link previews read, in the page's language (uz,
// ru, en): the storefront pages' titles and descriptions, the same for a
// shelf (?c=), a gallery piece (?p=) and a product from the product itself,
// and the shop's structured data. Used by app.vue (useSiteSeo) and by the
// server (the Studio's SPA shell, the sitemap). Uzbek apostrophes: ‘ in
// o‘/g‘, ’ for the tutuq belgisi.

export type SeoLang = 'uz' | 'ru' | 'en';
export const SEO_LANGS: SeoLang[] = ['uz', 'ru', 'en'];
export const OG_LOCALE: Record<SeoLang, string> = { uz: 'uz_UZ', ru: 'ru_RU', en: 'en_US' };
export const asLang = (code: unknown): SeoLang => (code === 'ru' || code === 'en' ? code : 'uz');
/** "/catalog" in a language: Uzbek at the bare path, the others under /ru, /en. */
export const localizedPath = (path: string, lang: SeoLang) => (lang === 'uz' ? path : path === '/' ? `/${lang}` : `/${lang}${path}`);
/** The language of a path and the path without its prefix. */
export function splitLocale(path: string): { lang: SeoLang; path: string } {
  const match = /^\/(ru|en)(?=\/|$)/.exec(path);
  if (!match) return { lang: 'uz', path };
  return { lang: match[1] as SeoLang, path: path.slice(3) || '/' };
}

export const SITE_NAME = 'Dizzo';
export const OG_IMAGE_PATH = '/brand/og-image.jpg';
export const OG_IMAGE_SIZE = { width: 1200, height: 630 } as const;
export const LOGO_PATH = '/brand/icon-512.png';
export const THEME_COLOR = '#ed5123';
export const SAME_AS = ['https://t.me/dizzo_uz', 'https://instagram.com/dizzo_uz'];

export interface PageSeo { title: string; description: string }

const DEFAULTS: Record<SeoLang, PageSeo> = {
  uz: {
    title: 'Dizzo — o‘z dizayningizdagi futbolka, krujka va sovg‘alar',
    description: 'G‘oyangizni bir necha daqiqada mahsulotga aylantiring: rasm yuklang, 3D’da ko‘ring va buyurtma bering. Futbolka, hudi, krujka, kepka — butun O‘zbekiston bo‘ylab.',
  },
  ru: {
    title: 'Dizzo — футболки, кружки и подарки с вашим дизайном',
    description: 'Превратите идею в вещь за пару минут: загрузите фото, посмотрите в 3D и оформите заказ. Футболки, худи, кружки, кепки — с доставкой по всему Узбекистану.',
  },
  en: {
    title: 'Dizzo — custom T-shirts, mugs and gifts with your design',
    description: 'Turn your idea into a product in minutes: upload a photo, preview it in 3D and order. T-shirts, hoodies, mugs, caps — delivered across Uzbekistan.',
  },
};
export const DEFAULT_TITLE = DEFAULTS.uz.title;
export const DEFAULT_DESCRIPTION = DEFAULTS.uz.description;
export const defaultSeo = (lang: SeoLang) => DEFAULTS[lang];

const PAGES: Record<SeoLang, Record<string, PageSeo>> = {
  uz: {
    '/': DEFAULTS.uz,
    '/catalog': {
      title: 'Mahsulotlar — futbolka, hudi, krujka va sovg‘alar',
      description: 'Dizayn qilinadigan barcha mahsulotlar bir joyda: futbolka, hudi, krujka, kepka va sovg‘alar. Tanlang, o‘z rasmingiz yoki ismingizni qo‘ying, 3D’da ko‘ring va buyurtma bering.',
    },
    '/gallery': {
      title: 'Galereya — tayyor dizaynlar va ilhom',
      description: 'Haqiqiy buyurtmalar va tayyor dizaynlar: yoqqanini tanlang, bir bosishda o‘zingizga moslang va buyurtma bering. Sovg‘a g‘oyasi qidirayotgan bo‘lsangiz — shu yerdan boshlang.',
    },
    '/login': { title: 'Kirish', description: 'Dizzo hisobingizga kiring: dizaynlaringiz, savatingiz va buyurtmalaringiz bir joyda.' },
    '/register': { title: 'Ro‘yxatdan o‘tish', description: 'Dizzo’da hisob yarating: dizaynlarni saqlang, buyurtma bering va holatini kuzating.' },
    '/litsenziyalar': { title: 'Litsenziyalar', description: 'Dizzo ishlatadigan ochiq manbali dasturlar va shriftlar litsenziyalari.' },
    '/privacy': { title: 'Maxfiylik siyosati', description: 'Dizzo qanday ma’lumotlarni yig‘adi, nima uchun ishlatadi va hisobingizni qanday o‘chirish mumkin.' },
  },
  ru: {
    '/': DEFAULTS.ru,
    '/catalog': {
      title: 'Товары — футболки, худи, кружки и подарки',
      description: 'Все товары, которые можно оформить своим дизайном: футболки, худи, кружки, кепки и подарки. Выберите, добавьте фото или имя, посмотрите в 3D и закажите.',
    },
    '/gallery': {
      title: 'Галерея — готовые дизайны и идеи',
      description: 'Реальные заказы и готовые дизайны: выберите понравившийся, адаптируйте в один клик и закажите. Ищете идею подарка — начните отсюда.',
    },
    '/login': { title: 'Вход', description: 'Войдите в аккаунт Dizzo: ваши дизайны, корзина и заказы в одном месте.' },
    '/register': { title: 'Регистрация', description: 'Создайте аккаунт Dizzo: сохраняйте дизайны, оформляйте заказы и следите за их статусом.' },
    '/litsenziyalar': { title: 'Лицензии', description: 'Лицензии открытых программ и шрифтов, которые использует Dizzo.' },
    '/privacy': { title: 'Политика конфиденциальности', description: 'Какие данные собирает Dizzo, зачем они нужны и как удалить аккаунт.' },
  },
  en: {
    '/': DEFAULTS.en,
    '/catalog': {
      title: 'Products — T-shirts, hoodies, mugs and gifts',
      description: 'Every product you can make your own: T-shirts, hoodies, mugs, caps and gifts. Pick one, add your photo or name, preview it in 3D and order.',
    },
    '/gallery': {
      title: 'Gallery — ready-made designs and inspiration',
      description: 'Real orders and ready-made designs: pick one you love, make it yours in a click and order. Looking for a gift idea? Start here.',
    },
    '/login': { title: 'Sign in', description: 'Sign in to Dizzo: your designs, cart and orders in one place.' },
    '/register': { title: 'Create an account', description: 'Create a Dizzo account: save designs, place orders and track their status.' },
    '/litsenziyalar': { title: 'Licenses', description: 'Licenses of the open-source software and fonts Dizzo uses.' },
    '/privacy': { title: 'Privacy policy', description: 'What data Dizzo collects, why, and how to delete your account.' },
  },
};
export const pageSeo = (path: string, lang: SeoLang): PageSeo | undefined => PAGES[lang][path];

/** Indexed but thin: search engines follow their links, never list them. */
export const NOINDEX_PATH = /^\/(login|register|litsenziyalar)\/?$/;

/** "Title · Dizzo", unless the title already names Dizzo. */
export function withSiteName(title?: string | null): string {
  if (!title) return DEFAULT_TITLE;
  return title.includes(SITE_NAME) ? title : `${title} · ${SITE_NAME}`;
}

/** Plain text, whitespace folded, at most `max` characters (cut on a word). */
export function plainText(html: string | null | undefined, max = 160): string {
  const text = (html ?? '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, '’')
    .replace(/\s+/g, ' ')
    // Uzbek apostrophes as the site writes them: o‘/g‘, then the tutuq ’.
    .replace(/([OoGg])['`ʻʼ’]/g, '$1‘')
    .replace(/(\p{L})['`ʼ](\p{L})/gu, '$1’$2')
    .trim();
  if (text.length <= max) return text;
  const cut = text.slice(0, max - 1);
  return `${cut.slice(0, Math.max(cut.lastIndexOf(' '), max * 0.6)).trimEnd()}…`;
}

export interface ProductSeoSource { name: string; description?: string | null; cover_url?: string | null }

/** The Studio of a product (the server's SPA shell and the client). */
export function productSeo(product: ProductSeoSource, lang: SeoLang = 'uz'): PageSeo & { image: string | null } {
  const about = plainText(product.description, 110);
  const n = product.name;
  const text = {
    uz: {
      title: `${n} dizaynini yarating — Dizzo Studio`,
      with: `${about} Rasm yuklang, matn yozing va 3D’da ko‘ring.`,
      without: `${n}ni o‘z rasmingiz, ismingiz yoki logotipingiz bilan yarating: 3D’da ko‘ring va bir necha daqiqada buyurtma bering.`,
    },
    ru: {
      title: `Создайте дизайн: ${n} — Dizzo Studio`,
      with: `${about} Загрузите фото, добавьте текст и посмотрите в 3D.`,
      without: `${n} с вашим фото, именем или логотипом: посмотрите в 3D и закажите за пару минут.`,
    },
    en: {
      title: `Design your ${n} — Dizzo Studio`,
      with: `${about} Upload a photo, add text and preview it in 3D.`,
      without: `${n} with your photo, name or logo: preview it in 3D and order in minutes.`,
    },
  }[lang];
  return { title: text.title, description: about ? text.with : text.without, image: product.cover_url || null };
}

/** A product's own page. */
export function productPageSeo(name: string, about: string, lang: SeoLang = 'uz'): PageSeo {
  const text = {
    uz: {
      title: `${name} — o‘z dizayningiz bilan`,
      fallback: `${name}ni o‘z rasmingiz, ismingiz yoki logotipingiz bilan buyurtma qiling: 3D’da ko‘ring, narxi darhol ko‘rinadi, O‘zbekiston bo‘ylab yetkazamiz.`,
    },
    ru: {
      title: `${name} с вашим дизайном`,
      fallback: `${name} с вашим фото, именем или логотипом: посмотрите в 3D, цена видна сразу, доставим по всему Узбекистану.`,
    },
    en: {
      title: `Custom ${name} with your design`,
      fallback: `${name} with your photo, name or logo: preview it in 3D, see the price instantly, delivered across Uzbekistan.`,
    },
  }[lang];
  return { title: text.title, description: about || text.fallback };
}

/** /catalog?c=<shelf>. */
export function shelfSeo(name: string, count: number | null | undefined, lang: SeoLang = 'uz'): PageSeo {
  const n = count ?? 0;
  return {
    uz: {
      title: `${name} — o‘z dizayningiz bilan buyurtma`,
      description: `${name}: o‘z rasmingiz, ismingiz yoki logotipingiz bilan tayyorlaymiz. ${n ? `${n} xil mahsulot` : 'Har xil mahsulotlar'} — tanlang, 3D’da ko‘ring va bir necha daqiqada buyurtma bering.`,
    },
    ru: {
      title: `${name} с вашим дизайном — заказать`,
      description: `${name} с вашим фото, именем или логотипом. ${n ? `${n} ${ruPlural(n, 'товар', 'товара', 'товаров')}` : 'Разные товары'} — выберите, посмотрите в 3D и закажите за пару минут.`,
    },
    en: {
      title: `${name} with your design — order online`,
      description: `${name} made with your photo, name or logo. ${n ? `${n} product${n === 1 ? '' : 's'}` : 'Plenty of products'} — pick one, preview it in 3D and order in minutes.`,
    },
  }[lang];
}

/** /gallery?c=<shelf>. */
export function galleryShelfSeo(name: string, count: number | null | undefined, lang: SeoLang = 'uz'): PageSeo {
  const n = count ?? 0;
  return {
    uz: {
      title: `${name} dizaynlari — galereya`,
      description: `${name} uchun ${n ? `${n} ta ` : ''}tayyor dizayn va haqiqiy buyurtmalar: yoqqanini tanlang, matn va rasmni o‘zgartiring, 3D’da ko‘ring va buyurtma bering.`,
    },
    ru: {
      title: `${name}: дизайны — галерея`,
      description: `${n ? `${n} ${ruPlural(n, 'готовый дизайн', 'готовых дизайна', 'готовых дизайнов')}` : 'Готовые дизайны'} и реальные заказы — ${name.toLowerCase()}: выберите, поменяйте текст и фото, посмотрите в 3D и закажите.`,
    },
    en: {
      title: `${name} designs — gallery`,
      description: `${n ? `${n} ready-made design${n === 1 ? '' : 's'}` : 'Ready-made designs'} and real orders for ${name.toLowerCase()}: pick one, change the text and photo, preview it in 3D and order.`,
    },
  }[lang];
}

/** /gallery?p=<piece>. */
export function galleryPieceSeo(
  piece: { title?: string | null; product_name: string; template_id?: number | null },
  lang: SeoLang = 'uz',
): PageSeo {
  const name = piece.title || piece.product_name;
  const product = piece.product_name;
  const design = !!piece.template_id;
  return {
    uz: design
      ? {
          title: `“${name}” — ${product} dizayni`,
          description: `“${name}” dizayni ${product} uchun. Shu namunadan boshlang: matn va rasmni o‘zingizga moslang, 3D’da ko‘ring va bir necha daqiqada buyurtma bering.`,
        }
      : {
          title: `${product} — mijozimiz buyurtmasi`,
          description: `Dizzo’da tayyorlangan haqiqiy ${product}. Siz ham o‘z dizayningizni yarating: rasm yuklang, 3D’da ko‘ring va buyurtma bering.`,
        },
    ru: design
      ? {
          title: `«${name}» — дизайн: ${product}`,
          description: `Дизайн «${name}» — ${product}. Начните с этого образца: поменяйте текст и фото под себя, посмотрите в 3D и закажите за пару минут.`,
        }
      : {
          title: `${product} — заказ нашего клиента`,
          description: `Настоящий заказ, сделанный в Dizzo: ${product}. Создайте свой дизайн — загрузите фото, посмотрите в 3D и закажите.`,
        },
    en: design
      ? {
          title: `“${name}” — ${product} design`,
          description: `The “${name}” design for ${product}. Start from this sample: make the text and photo yours, preview it in 3D and order in minutes.`,
        }
      : {
          title: `${product} — a customer’s order`,
          description: `A real ${product} made at Dizzo. Create your own design: upload a photo, preview it in 3D and order.`,
        },
  }[lang];
}

/** Russian plural form for n. */
export function ruPlural(n: number, one: string, few: string, many: string): string {
  const tens = n % 100;
  const ones = n % 10;
  if (tens > 10 && tens < 20) return many;
  if (ones === 1) return one;
  if (ones >= 2 && ones <= 4) return few;
  return many;
}

const CRUMBS: Record<SeoLang, { home: string; catalog: string; gallery: string }> = {
  uz: { home: 'Bosh sahifa', catalog: 'Mahsulotlar', gallery: 'Galereya' },
  ru: { home: 'Главная', catalog: 'Товары', gallery: 'Галерея' },
  en: { home: 'Home', catalog: 'Products', gallery: 'Gallery' },
};
export const crumbNames = (lang: SeoLang) => CRUMBS[lang];

/** The shop itself (the home page's structured data). */
export function organizationLd(site: string, lang: SeoLang = 'uz') {
  const home = `${site}${localizedPath('/', lang)}`;
  return [
    {
      '@context': 'https://schema.org',
      '@type': 'Organization',
      '@id': `${site}/#organization`,
      'name': SITE_NAME,
      'url': `${site}/`,
      'logo': `${site}${LOGO_PATH}`,
      'image': `${site}${OG_IMAGE_PATH}`,
      'description': DEFAULTS[lang].description,
      'sameAs': SAME_AS,
      'address': { '@type': 'PostalAddress', 'addressLocality': 'Tashkent', 'addressRegion': 'Yunusobod', 'addressCountry': 'UZ' },
      'areaServed': { '@type': 'Country', 'name': 'Uzbekistan' },
      'contactPoint': { '@type': 'ContactPoint', 'contactType': 'customer support', 'url': SAME_AS[0], 'availableLanguage': ['uz', 'ru', 'en'] },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      '@id': `${site}/#website`,
      'name': SITE_NAME,
      'alternateName': 'Dizzo Studio',
      'url': home,
      'inLanguage': lang,
      'publisher': { '@id': `${site}/#organization` },
    },
  ];
}

export function breadcrumbLd(site: string, trail: { name: string; path: string }[], lang: SeoLang = 'uz') {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    'itemListElement': [{ name: CRUMBS[lang].home, path: '/' }, ...trail].map((t, i) => ({
      '@type': 'ListItem',
      'position': i + 1,
      'name': t.name,
      'item': `${site}${localizedPath(t.path, lang)}`,
    })),
  };
}

/** JSON for a <script type="application/ld+json">, safe inside HTML. */
export const ldJson = (data: unknown) => JSON.stringify(data).replace(/</g, '\\u003c');

/** Only these paths are canonical/indexable; the rest are private or tools. */
export const PRIVATE_PATH = /^\/(admin|user|embed)(\/|$)/;
