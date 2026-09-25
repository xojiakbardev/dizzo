import tailwindcss from '@tailwindcss/vite';

// Fonts for text layers in the Studio. Kept in sync with FONTS in
// app/lib/design/document.ts and the backend's app/schemas/design.py:
// self-hosted at build time, Latin + Cyrillic. Not global: their @font-face
// rules go into app/assets/css/design-fonts.css, which app/lib/design/fonts.ts
// loads when a design is drawn (the Studio, 3D previews, the mobile engine),
// so storefront pages don't block on them.
const DESIGN_FONTS = [
  'Montserrat', 'Roboto', 'Open Sans', 'Rubik', 'Oswald', 'Lora', 'Playfair Display', 'PT Serif', 'Comfortaa',
  'Caveat', 'Lobster', 'Pacifico',
];

const siteUrl = process.env.NUXT_PUBLIC_SITE_URL;

// The site's languages (Uzbek is the default, at the bare paths).
const LOCALES = [
  { code: 'uz', language: 'uz-UZ', name: 'O‘zbekcha' },
  { code: 'ru', language: 'ru-RU', name: 'Русский' },
  { code: 'en', language: 'en-US', name: 'English' },
];
const I18N_AREAS = ['common', 'storefront', 'studio', 'user', 'admin'];
// A route rule for the bare path and its /ru and /en twins.
const everyLocale = <T>(path: string, rule: T): Record<string, T> =>
  Object.fromEntries(['', '/ru', '/en'].map(prefix => [`${prefix}${path}`, rule]));

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({

  modules: [
    '@nuxt/eslint',
    '@nuxt/fonts',
    '@nuxt/icon',
    '@nuxt/image',
    '@pinia/nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/i18n',
    // The engine's desktop test harness (/embed/harness) is for development
    // only; production builds don't have the page.
    (_options, nuxt) => {
      if (nuxt.options.dev) return;
      nuxt.hook('pages:extend', (pages) => {
        const at = pages.findIndex(page => page.path === '/embed/harness');
        if (at !== -1) pages.splice(at, 1);
      });
    },
  ],

  components: [
    '~/components',
    { path: '~/components/layout', pathPrefix: false },
    { path: '~/components/auth', pathPrefix: false },
    { path: '~/components/admin', pathPrefix: false },
    { path: '~/components/admin/charts', pathPrefix: false },
    { path: '~/components/shared', pathPrefix: false },
    { path: '~/components/ui', prefix: 'Ui', pattern: '**/*.vue' },
    { path: '~/components/landing', pathPrefix: false },
  ],

  imports: {
    // Nuxt only auto-scans the top level of `composables/` by default —
    // opt in to the `queries/` subfolder too so `useCart`, `useCurrentUser`
    // etc. stay auto-imported like everything else.
    dirs: ['composables/queries'],
  },

  devtools: { enabled: true },

  hooks: {
    // Lazy chunks (three.js, the draco decoder, the Studio) load when they
    // are needed, not as prefetches on every page: a slow phone's data and
    // CPU go to the page it opened.
    'build:manifest': (manifest) => {
      for (const chunk of Object.values(manifest)) chunk.dynamicImports = [];
    },
  },

  // Three languages: Uzbek at the bare paths, Russian and English under
  // /ru and /en (their own pages for search engines, with hreflang). Every
  // language has the same message files, one per area (i18n/locales/<lang>/).
  i18n: {
    strategy: 'prefix_except_default',
    defaultLocale: 'uz',
    baseUrl: siteUrl,
    locales: LOCALES.map(l => ({ ...l, files: I18N_AREAS.map(area => `${l.code}/${area}.json`) })),
    detectBrowserLanguage: {
      useCookie: true,
      cookieKey: 'dizzo_lang',
      redirectOn: 'root',
      alwaysRedirect: false,
      fallbackLocale: 'uz',
    },
    vueI18n: './i18n.config.ts',
  },

  app: {
    pageTransition: { name: 'page', mode: 'out-in' },
    head: {
      htmlAttrs: { lang: 'uz' },
      // Language-neutral: pages rendered in the browser set their own title.
      title: 'Dizzo',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'theme-color', content: '#ed5123' },
      ],
      script: [{
        // A catalog picture's small copy (app/utils/thumb.ts) that isn't
        // there yet: show the original instead. Runs before the body loads.
        innerHTML: 'document.addEventListener("error",function(e){var t=e.target;if(t&&t.tagName==="IMG"&&t.dataset.fallback&&t.getAttribute("src")!==t.dataset.fallback){t.removeAttribute("srcset");t.src=t.dataset.fallback}},true)',
      }],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/brand/favicon-32x32.png' },
        { rel: 'apple-touch-icon', sizes: '180x180', href: '/brand/apple-touch-icon.png' },
        { rel: 'manifest', href: '/site.webmanifest' },
      ],
    },
  },

  // leaflet.css used to be global here — pulled into every single page's
  // initial request burst (including ones with zero map usage, like
  // /login), which measurably increases how many concurrent module
  // requests the dev server has to serve on first load. Under load, Vite's
  // dev server has a real (reproducible outside any CDN/tunnel) bug where
  // concurrent requests' responses can get mixed up, serving a JS chunk's
  // content-type for a CSS request or vice versa — this doesn't fix that
  // bug, but scoping the import to just ProductionCenterMap.vue (the only
  // thing that needs it) shrinks the burst and the odds of hitting it.
  css: ['~/assets/css/main.css'],

  runtimeConfig: {
    public: {
      apiUrl: process.env.NUXT_PUBLIC_API_URL,
      siteUrl: process.env.NUXT_PUBLIC_SITE_URL,
      mediaUrl: process.env.NUXT_PUBLIC_MEDIA_URL,
      googleMapsApiKey: process.env.NUXT_PUBLIC_GOOGLE_MAPS_API_KEY,
      yandexMapsApiKey: process.env.NUXT_PUBLIC_YANDEX_MAPS_API_KEY,
    },
  },

  routeRules: {
    // The editor is canvas/WebGL only: an empty shell to a crawler, so kept
    // out of search (the product's page, /products/<slug>, is the one to index).
    ...everyLocale('/studio/**', { ssr: false, headers: { 'X-Robots-Tag': 'noindex, follow' } }),
    // The mobile app's rendering engine and its test harness
    // (docs/EMBED_ENGINE.md): WebGL only, never in search.
    ...everyLocale('/embed/**', { ssr: false, headers: { 'X-Robots-Tag': 'noindex, nofollow' } }),
    // "Katalog" was renamed "Mahsulotlar".
    '/admin/catalog': { redirect: '/admin/products' },
    '/admin/catalog/**': { redirect: '/admin/products/**' },
    // The customer's cabinet: the session lives in the browser, so rendering
    // it on the server would only produce a signed-out page to replace on
    // hydration.
    ...everyLocale('/user/**', { ssr: false }),
    '/user': { redirect: '/user/profile' },
    // The cabinet's pages before they moved under /user (Telegram order
    // messages and bookmarks still point there).
    '/cart': { redirect: '/user/cart' },
    '/checkout': { redirect: '/user/checkout' },
    '/orders': { redirect: '/user/orders' },
    '/orders/**': { redirect: '/user/orders/**' },
    '/feedback': { redirect: '/user/feedback' },
    '/designs': { redirect: '/user/designs' },
    '/profile': { redirect: '/user/profile' },
    // Long cache for files whose names change with their content; a day
    // (then revalidated in the background) for the plain public files.
    // Also written to .output/public/_headers for Cloudflare's static assets.
    // One path segment only (`:file`): /_nuxt/builds/** keeps Nuxt's own
    // short cache, and Cloudflare's _headers would merge overlapping rules.
    '/_nuxt/:file': { headers: { 'cache-control': 'public, max-age=31536000, immutable' } },
    '/_fonts/:file': { headers: { 'cache-control': 'public, max-age=31536000, immutable' } },
    '/brand/**': { headers: { 'cache-control': 'public, max-age=86400, stale-while-revalidate=604800' } },
    '/generated/**': { headers: { 'cache-control': 'public, max-age=86400, stale-while-revalidate=604800' } },
    '/stickers/**': { headers: { 'cache-control': 'public, max-age=86400, stale-while-revalidate=604800' } },
  },

  nitro: {
    // Deployed on Cloudflare Workers with Static Assets.
    preset: 'cloudflare_module',
    prerender: {
      autoSubfolderIndex: false,
      ignore: ['/studio', '/user', '/embed', '/ru', '/en'].flatMap(p => [p, `${p}/**`]),
    },
  },

  future: { compatibilityVersion: 4 },
  compatibilityDate: '2025-07-15',

  vite: {
    plugins: [tailwindcss()],
    server: {
      // Vite 5+ blocks unrecognized Host headers by default — the
      // cloudflared tunnel forwards requests with the tunnel's own
      // hostname, which otherwise gets rejected as "Blocked request".
      allowedHosts: ['dizzo.uz', 'api.dizzo.uz'],
    },
  },

  typescript: {
    strict: true,
    typeCheck: false,
  },

  eslint: {
    config: { stylistic: { indent: 2, quotes: 'single', semi: true } },
  },

  fonts: {
    families: [
      // The UI font everywhere (`--font-sans`), Latin + Latin Extended for o‘ and g‘.
      { name: 'Plus Jakarta Sans', provider: 'google', global: true, weights: [400, 500, 600, 700, 800], subsets: ['latin', 'latin-ext'] },
      // Its Cyrillic twin (Plus Jakarta Sans has no Cyrillic): Russian text.
      { name: 'Manrope', provider: 'google', global: true, weights: [400, 500, 600, 700, 800], subsets: ['cyrillic'] },
      // The Dizzo wordmark next to the logo (font-brand).
      { name: 'Nunito', provider: 'google', global: true, weights: [900], subsets: ['latin'] },
      ...DESIGN_FONTS.map(name => ({
        name, provider: 'google', global: false, preload: false,
        weights: [400, 700], styles: ['normal', 'italic'] as ('normal' | 'italic')[], subsets: ['latin', 'latin-ext', 'cyrillic'],
      })),
    ],
  },

  icon: {
    // Matches the lucide-react icon set used by the previous frontend, so
    // reference designs translate 1:1 by icon name (`i-lucide-<name>`).
    provider: 'iconify',
    serverBundle: { collections: ['lucide'] },
    // Every icon the source names is built into the client bundle, so none
    // pops in late from a request (@iconify-json/lucide is installed).
    clientBundle: { scan: true, sizeLimitKb: 512, icons: ['lucide:align-left', 'lucide:align-center', 'lucide:align-right'] },
  },

  image: {
    // Backend media/static hosts — extend as real image domains are known.
    // storage.dizzo.uz serves catalog, design and order images (R2).
    domains: ['localhost', 'dizzo.uz', 'api.dizzo.uz', 'media.dizzo.uz', 'storage.dizzo.uz'],
  },
});
