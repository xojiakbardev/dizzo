// /studio/<slug> is rendered in the browser only, so without this every
// slug would answer 200. Ask the API (cached) first: an unknown product is
// a real 404 with the error page. If the API can't be reached, the page is
// served as usual and shows its own error.
import type { ServerProduct } from '../utils/catalog';

const NOT_FOUND = { uz: 'Mahsulot topilmadi', ru: 'Товар не найден', en: 'Product not found' } as const;

export default defineEventHandler(async (event) => {
  if (event.method !== 'GET' && event.method !== 'HEAD') return;
  const studio = studioSlug(event.path);
  if (!studio) return;

  let product: ServerProduct | null;
  try {
    product = await getProduct(studio.slug, studio.lang);
  }
  catch {
    return;
  }
  if (product === null) {
    throw createError({ statusCode: 404, statusMessage: NOT_FOUND[studio.lang] });
  }
  event.context.studioProduct = product;
});
