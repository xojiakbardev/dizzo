// Small WebP copies of the catalog's pictures (the backend writes
// `<picture>.w480.webp` and `.w960.webp` next to every catalog upload), so a
// phone downloads ~30 KB instead of a 700 KB PNG for a card. An <img> using
// one carries `data-fallback` with the original: the head script in
// nuxt.config.ts swaps it in if a copy is missing.

const THUMBED = /^https:\/\/storage\.dizzo\.uz\/catalog\/[^/]+\.(?:png|jpe?g|webp)$/i;

export type ThumbWidth = 480 | 960;

export const hasThumbs = (url: string | null | undefined): url is string => !!url && THUMBED.test(url);

/** The picture's copy at `width`, or the picture itself when it has none. */
export function thumbUrl(url: string | null | undefined, width: ThumbWidth = 480): string {
  if (!url) return '';
  return hasThumbs(url) ? `${url}.w${width}.webp` : url;
}

/**
 * `src`/`srcset`/`sizes` and the fallback for an <img> showing `url`
 * (`v-bind="thumbAttrs(url, '(min-width: 1024px) 25vw, 50vw')"`): the
 * browser picks the 480 or 960 copy for the space the picture takes.
 */
export function thumbAttrs(url: string | null | undefined, sizes = '50vw') {
  if (!hasThumbs(url)) return { src: url ?? '' };
  return {
    'src': thumbUrl(url, 480),
    'srcset': `${thumbUrl(url, 480)} 480w, ${thumbUrl(url, 960)} 960w`,
    sizes,
    'data-fallback': url,
  };
}

/** A small picture (a thumbnail strip, an icon): the 480 copy only. */
export function thumbSmall(url: string | null | undefined) {
  if (!hasThumbs(url)) return { src: url ?? '' };
  return { 'src': thumbUrl(url, 480), 'data-fallback': url };
}
