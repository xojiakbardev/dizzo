// The Studio's text-layer fonts are declared in their own stylesheet
// (assets/css/design-fonts.css), loaded the first time a design is drawn or
// the editor opens — not on every storefront page. Canvas text doesn't
// trigger font loading by itself, so anything that measures or paints a
// text layer goes through loadFontFace().

let stylesheet: Promise<unknown> | null = null;

/** Adds the design fonts' @font-face rules to the page (once). */
export function loadDesignFonts(): Promise<unknown> {
  if (import.meta.server) return Promise.resolve();
  stylesheet ??= import('~/assets/css/design-fonts.css').catch((error) => {
    stylesheet = null;
    console.error('[design] fonts stylesheet failed to load', error);
  });
  return stylesheet;
}

/** document.fonts.load() for a canvas font string, after the rules are there. */
export async function loadFontFace(font: string, sample: string): Promise<void> {
  await loadDesignFonts();
  await document.fonts.load(font, sample);
}
