<script setup lang="ts">
import ProductInfoTab from '~/components/admin/products/ProductInfoTab.vue';
import ShapesTab from '~/components/admin/products/ShapesTab.vue';
import VariantsTab from '~/components/admin/products/VariantsTab.vue';
import PricesTab from '~/components/admin/products/PricesTab.vue';
import GalleryTab from '~/components/admin/products/GalleryTab.vue';
import ImagesTab from '~/components/admin/products/ImagesTab.vue';
import ProductTabSkeleton from '~/components/admin/products/ProductTabSkeleton.vue';
import ProductTabsList from '~/components/admin/products/ProductTabsList.vue';
import { PRODUCT_TABS, type ProductTabId } from '~/lib/admin/productTabs';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();

const route = useRoute();
const productId = computed(() => Number(route.params.id));
const productQuery = useCatalogAdminProduct(productId);
const product = computed(() => productQuery.data.value ?? null);

useAdminCrumbs(() => (product.value ? [{ label: product.value.name }] : []));

const PANES = {
  info: ProductInfoTab, shapes: ShapesTab, variants: VariantsTab, images: ImagesTab, prices: PricesTab, templates: GalleryTab,
} as const;
const TABS = PRODUCT_TABS.map(t => ({ ...t, pane: PANES[t.id] }));
const tab = computed<ProductTabId>(() => TABS.find(t => t.id === route.query.tab)?.id ?? 'info');
function setTab(t: string | number) {
  navigateTo({ query: { ...route.query, tab: String(t) } }, { replace: true });
}
</script>

<template>
  <div>
    <EmptyState
      v-if="!product && !productQuery.isLoading.value"
      :title="productQuery.isError.value ? t('admin.products.loadFailed') : t('admin.products.notFound')"
      :description="productQuery.isError.value ? t('admin.common.checkConnection') : t('admin.products.notFoundHint')"
      :icon="productQuery.isError.value ? 'lucide:circle-alert' : 'lucide:package-x'"
      :tone="productQuery.isError.value ? 'destructive' : 'default'"
    >
      <div class="flex flex-wrap justify-center gap-2">
        <UiButton
          v-if="productQuery.isError.value"
          variant="outline"
          size="sm"
          @click="productQuery.refetch()"
        >
          <Icon
            name="lucide:refresh-cw"
            class="text-sm"
          />
          {{ t('admin.common.retry') }}
        </UiButton>
        <UiButton
          as-child
          variant="outline"
          size="sm"
        >
          <NuxtLinkLocale to="/admin/products">
            <Icon
              name="lucide:arrow-left"
              class="text-sm"
            />
            {{ t('admin.products.list') }}
          </NuxtLinkLocale>
        </UiButton>
      </div>
    </EmptyState>

    <template v-else>
      <AdminDetailHeader
        :back="localePath('/admin/products')"
        :back-label="t('admin.products.backToList')"
        :title="product?.name ?? ''"
        class="mb-4"
      >
        <UiStatusBadge
          v-if="product"
          :tone="product.sellable ? 'success' : 'warn'"
        >
          {{ product.sellable ? t('admin.products.status.onSale') : t('admin.products.status.notReady') }}
        </UiStatusBadge>
        <template #actions>
          <UiButton
            v-if="product?.sellable"
            as-child
            variant="outline"
          >
            <a
              :href="localePath(`/studio/${product.slug}`)"
              target="_blank"
              rel="noopener"
              :aria-label="t('admin.products.openInStudio')"
            >
              <Icon
                name="lucide:external-link"
                class="text-sm"
              />
              <span class="hidden sm:inline">{{ t('admin.products.studio') }}</span>
            </a>
          </UiButton>
          <!-- The open tab's delete / cancel / save (the main tab's). -->
          <div
            id="product-detail-actions"
            class="contents"
          />
        </template>
      </AdminDetailHeader>

      <UiAlert
        v-if="product?.issues.length"
        variant="warning"
        class="mb-4"
      >
        <Icon name="lucide:triangle-alert" />
        <UiAlertTitle>{{ t('admin.products.issuesTitle') }}</UiAlertTitle>
        <UiAlertDescription>
          <ul class="list-disc space-y-0.5 pl-4">
            <li
              v-for="issue in product.issues"
              :key="issue"
            >
              {{ issue }}
            </li>
          </ul>
        </UiAlertDescription>
      </UiAlert>

      <UiTabs
        :model-value="tab"
        class="gap-4"
        @update:model-value="setTab"
      >
        <!-- The tabs, and the open tab's add button at the row's right end. -->
        <ProductTabsList :product="product">
          <UiSkeleton
            v-if="!product && TABS.find(t => t.id === tab)?.adds"
            class="h-10 w-40 rounded-xl"
          />
          <div
            id="product-tab-actions"
            class="contents"
          />
        </ProductTabsList>
        <UiTabsContent
          v-for="t in TABS"
          :key="t.id"
          :value="t.id"
        >
          <component
            :is="t.pane"
            v-if="product"
            :key="product.id"
            :product="product"
          />
          <ProductTabSkeleton
            v-else
            :tab="t.id"
          />
        </UiTabsContent>
      </UiTabs>
    </template>
  </div>
</template>
