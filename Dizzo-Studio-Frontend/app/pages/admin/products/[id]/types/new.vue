<script setup lang="ts">
// A new variant: name, shape and price; created, it opens for the rest.
import VariantForm from '~/components/admin/products/VariantForm.vue';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();

const route = useRoute();
const productId = computed(() => Number(route.params.id));
const productQuery = useCatalogAdminProduct(productId);
const product = computed(() => productQuery.data.value ?? null);

const back = localePath(`/admin/products/${productId.value}?tab=variants`);
useAdminCrumbs(() => (product.value ? [{ label: product.value.name, to: back }, { label: t('admin.variants.new') }] : []));

const opened = (id: number) => navigateTo(localePath(`/admin/products/${productId.value}/types/${id}`), { replace: true });
</script>

<template>
  <div>
    <UiSkeleton
      v-if="productQuery.isLoading.value"
      class="h-80 rounded-xl"
    />
    <EmptyState
      v-else-if="!product"
      :title="productQuery.isError.value ? t('admin.products.loadFailed') : t('admin.products.notFound')"
      :icon="productQuery.isError.value ? 'lucide:circle-alert' : 'lucide:package-x'"
      :tone="productQuery.isError.value ? 'destructive' : 'default'"
    >
      <UiButton
        as-child
        variant="outline"
        size="sm"
      >
        <NuxtLinkLocale to="/admin/products">
          <Icon
            name="lucide:arrow-left"
            class="h-4 w-4"
          />
          {{ t('admin.products.list') }}
        </NuxtLinkLocale>
      </UiButton>
    </EmptyState>
    <VariantForm
      v-else
      :product="product"
      :variant="null"
      @created="opened"
    />
  </div>
</template>
