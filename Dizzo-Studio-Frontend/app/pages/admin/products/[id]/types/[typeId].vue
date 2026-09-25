<script setup lang="ts">
// Editing a variant: everything about it and its colours. Delete and save sit in the form's header.
import VariantForm from '~/components/admin/products/VariantForm.vue';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();

const route = useRoute();
const productId = computed(() => Number(route.params.id));
const typeId = computed(() => Number(route.params.typeId));
const productQuery = useCatalogAdminProduct(productId);
const product = computed(() => productQuery.data.value ?? null);
const variant = computed(() => product.value?.variants.find(v => v.id === typeId.value && !v.archived) ?? null);

const back = localePath(`/admin/products/${productId.value}?tab=variants`);
useAdminCrumbs(() => (product.value && variant.value ? [{ label: product.value.name, to: back }, { label: variant.value.name }] : []));
const leave = () => navigateTo(back);
</script>

<template>
  <div>
    <UiSkeleton
      v-if="productQuery.isLoading.value"
      class="h-96 rounded-xl"
    />
    <EmptyState
      v-else-if="!product || !variant"
      :title="productQuery.isError.value ? t('admin.variants.loadFailed') : t('admin.variants.notFound')"
      :description="productQuery.isError.value ? t('admin.variants.tryAgain') : t('admin.variants.notFoundHint')"
      :icon="productQuery.isError.value ? 'lucide:circle-alert' : 'lucide:layers'"
      :tone="productQuery.isError.value ? 'destructive' : 'default'"
    >
      <UiButton
        as-child
        variant="outline"
        size="sm"
      >
        <NuxtLink :to="back">
          <Icon
            name="lucide:arrow-left"
            class="h-4 w-4"
          />
          {{ t('admin.variants.list') }}
        </NuxtLink>
      </UiButton>
    </EmptyState>
    <VariantForm
      v-else
      :key="variant.id"
      :product="product"
      :variant="variant"
      @saved="leave"
      @removed="leave"
    />
  </div>
</template>
