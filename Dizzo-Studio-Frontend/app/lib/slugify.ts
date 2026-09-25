// Uzbek-aware slug: o‘/g‘ and apostrophes collapse, everything else -> "-".
export function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[‘’ʻʼ'`]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
