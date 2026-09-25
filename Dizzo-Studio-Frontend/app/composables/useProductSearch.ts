import type { ProductCategory, PublicProductCard, ShelfOption } from '~/types/catalog';

// Search and shelf filter over the product list, shared by the landing and
// the catalog. Search matches the name, ignoring case
// and the different Uzbek apostrophes (o‘ o' oʻ o`). Shelves offered are
// only those that have products, in the admin's order of shelves.
const fold = (text: string) => text.toLowerCase().replace(/[‘’ʻʼ`']/g, '\'').trim();

export function useProductSearch(list: Ref<PublicProductCard[]>) {
  const search = ref('');
  const category = ref<ProductCategory | null>(null);

  const shelves = useCategories();
  const categories = computed<ShelfOption[]>(() => (shelves.data.value ?? [])
    .filter(c => list.value.some(p => p.category === c.slug))
    .map(c => ({ value: c.slug, label: c.name, icon_svg: c.icon_svg, image_url: c.image_url })));
  const results = computed(() => {
    const query = fold(search.value);
    return list.value.filter(p => (!category.value || p.category === category.value)
      && (!query || fold(p.name).includes(query)));
  });

  return { search, category, categories, results };
}
