import { localizedPath } from '~/lib/i18n';
// "Dizayn yaratishni boshlash" on the landing: every such button calls
// start(). With exactly one product on sale there is nothing to choose, so
// it goes straight to that product's Studio; otherwise the picker dialog
// (ProductPicker, mounted once on the page) opens.
export function useProductPicker() {
  const open = useState('product-picker-open', () => false);
  const { list } = useStorefrontProducts();

  function start() {
    const only = list.value.length === 1 ? list.value[0] : null;
    if (only) return navigateTo(localizedPath(`/studio/${only.slug}`));
    open.value = true;
  }

  function choose(slug: string) {
    open.value = false;
    return navigateTo(localizedPath(`/studio/${slug}`));
  }

  return { open, start, choose };
}
