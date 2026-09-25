// Translation helpers for plain .ts code (label maps, composables,
// middleware): they look the language up when called, never at import time.

/** `t(key)` in the page's language; the key itself outside a Nuxt context. */
export function i18nT(key: string, named?: Record<string, unknown>, plural?: number): string {
  try {
    const { t } = useNuxtApp().$i18n;
    if (plural !== undefined) return t(key, named ?? {}, plural);
    return named ? t(key, named) : t(key);
  }
  catch {
    return key;
  }
}

const LOCALE_PREFIX_RE = /^\/(ru|en)(?=\/|$)/;

/** `/ru/user/cart` → `/user/cart`; unprefixed (Uzbek) paths stay as they are. */
export function stripLocalePrefix(path: string): string {
  return path.replace(LOCALE_PREFIX_RE, '') || '/';
}

/** A path in the page's language (`/studio/x` → `/ru/studio/x`). */
export function localizedPath(path: string): string {
  try {
    return useLocalePath()(path) || path;
  }
  catch {
    return path;
  }
}
