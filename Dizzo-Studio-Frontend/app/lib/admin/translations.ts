// Trilingual content in the admin. Uzbek stays in the resource's own fields
// (name, description, …); Russian and English travel next to them as
// `translations: { ru: { name: … }, en: { name: … } }`. The backend merges a
// PATCH per language, and an empty value means "not translated" (the site
// falls back to Uzbek). A PATCH replaces a sent language's whole block:
// always send every translated field of the resource (a missing one is
// deleted); leave `translations` out to keep them as they are.
import type { SpecItem, TranslationLang, Translations, VariantSize } from '~/types/catalog';
import { defaultPrintScale } from '~/types/catalog';

export const TRANSLATION_LANGS = ['ru', 'en'] as const satisfies readonly TranslationLang[];
export const CONTENT_LANGS = ['uz', ...TRANSLATION_LANGS] as const;
export type ContentLang = typeof CONTENT_LANGS[number];

/** A string map per language, always with both languages present, so
 *  `v-model` can write into it. */
export type TextTranslations = Record<TranslationLang, Record<string, string>>;

/** Editable copy of a resource's translations: only its string fields. */
export function textTranslations(source: Translations<object> | null | undefined, fields: readonly string[]): TextTranslations {
  const out = { ru: {}, en: {} } as TextTranslations;
  for (const lang of TRANSLATION_LANGS) {
    const values = (source?.[lang] ?? {}) as Record<string, unknown>;
    for (const field of fields) {
      const value = values[field];
      out[lang][field] = typeof value === 'string' ? value : '';
    }
  }
  return out;
}

/** Trimmed copy for a request body. */
export function trimTranslations(source: TextTranslations): TextTranslations {
  const out = { ru: {}, en: {} } as TextTranslations;
  for (const lang of TRANSLATION_LANGS) {
    for (const [field, value] of Object.entries(source[lang])) out[lang][field] = value.trim();
  }
  return out;
}

export const sameTranslations = (a: TextTranslations, b: TextTranslations) =>
  JSON.stringify(trimTranslations(a)) === JSON.stringify(trimTranslations(b));

/** The languages whose `field` is still empty. */
export function missingLangs(source: TextTranslations | null | undefined, field: string): TranslationLang[] {
  return TRANSLATION_LANGS.filter(lang => !source?.[lang]?.[field]?.trim());
}

export const isTranslated = (source: TextTranslations | null | undefined, ...fields: string[]) =>
  fields.every(field => missingLangs(source, field).length === 0);

// ── Lists: a variant's specs and sizes are translated as whole lists ──

/** A spec row with its label and value in every language. */
export interface SpecRow extends SpecItem { tr: TextTranslations }

export function specRows(specs: SpecItem[], translations: Translations<{ specs: SpecItem[] }> | null | undefined): SpecRow[] {
  return specs.map((spec, index) => ({
    ...spec,
    tr: textTranslations({
      ru: translations?.ru?.specs?.[index],
      en: translations?.en?.specs?.[index],
    }, ['label', 'value']),
  }));
}

export const newSpecRow = (): SpecRow => ({ label: '', value: '', tr: textTranslations(null, ['label', 'value']) });

/** Rows filled in Uzbek, split back into the Uzbek list and the translated ones. */
export function splitSpecRows(rows: SpecRow[]) {
  const kept = rows.filter(r => r.label.trim() && r.value.trim());
  const specs = kept.map(r => ({ label: r.label.trim(), value: r.value.trim() }));
  const translated = (lang: TranslationLang) => kept.map(r => ({
    label: r.tr[lang].label?.trim() ?? '',
    value: r.tr[lang].value?.trim() ?? '',
  }));
  return { specs, ru: translated('ru'), en: translated('en') };
}

/** A size row with its name in every language. */
export interface SizeRow extends VariantSize { tr: TextTranslations }

/** A translated size name: `label` is the Uzbek label it belongs to. */
export interface SizeName { label: string; name: string }

/** A code such as "XL" or "42" reads the same in every language and is never translated. */
export const isSizeCode = (label: string) => /^[\dA-Z\s.,/×x+–-]*$/.test(label.trim());

export function sizeRows(sizes: VariantSize[], translations: Translations<{ sizes: SizeName[] }> | null | undefined): SizeRow[] {
  const name = (lang: TranslationLang, label: string) =>
    translations?.[lang]?.sizes?.find(s => s.label === label)?.name ?? '';
  return sizes.map(size => ({ ...size, tr: { ru: { label: name('ru', size.label) }, en: { label: name('en', size.label) } } }));
}

export const newSizeRow = (label: string, surcharge = '0', print_scale = defaultPrintScale(label)): SizeRow =>
  ({ label, surcharge, is_available: true, print_scale, tr: { ru: { label: '' }, en: { label: '' } } });

/** The Uzbek list, and per language only the word labels' names
 *  (`[{ label: 'Katta', name: 'Большой' }]`); codes are left out. */
export function splitSizeRows(rows: SizeRow[]) {
  const kept = rows.filter(r => r.label.trim());
  const sizes: VariantSize[] = kept.map(r => ({
    label: r.label.trim(), surcharge: r.surcharge || '0', is_available: r.is_available,
    // How much of the print area this size may use (VariantSize.print_scale).
    print_scale: r.print_scale || defaultPrintScale(r.label),
  }));
  const translated = (lang: TranslationLang): SizeName[] => kept
    .map(r => ({ label: r.label.trim(), name: r.tr[lang].label?.trim() ?? '' }))
    .filter(s => !isSizeCode(s.label) && s.name);
  return { sizes, ru: translated('ru'), en: translated('en') };
}
