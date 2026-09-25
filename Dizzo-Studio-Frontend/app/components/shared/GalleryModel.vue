<script setup lang="ts">
// A gallery design in 3D: loads its product (shape, material, colour) and,
// unless given, the design itself; the Dizzo loader shows until it is drawn.
import type { DesignDocument } from '~/lib/design/document';

const props = defineProps<{
  slug: string;
  variantId: number | null;
  colorId: number | null;
  templateId?: number | null;
  document?: DesignDocument | null;
}>();

const { t } = useI18n();
const slug = computed(() => props.slug);
const detail = useProductDetail(slug);
const templates = useProductTemplates(slug);

const variant = computed(() => {
  const list = detail.data.value?.variants ?? [];
  return list.find(v => v.id === props.variantId) ?? list[0] ?? null;
});
const shape = computed(() => detail.data.value?.shapes.find(s => s.id === variant.value?.shape_id) ?? null);
const colorHex = computed(() => {
  const colors = variant.value?.colors ?? [];
  return (colors.find(c => c.id === props.colorId) ?? colors[0])?.hex ?? null;
});
const doc = computed(() => props.document
  ?? templates.data.value?.find(t => t.id === props.templateId)?.document
  ?? null);
const failed = computed(() => detail.isError.value || (!detail.isLoading.value && !shape.value));
</script>

<template>
  <div class="relative size-full">
    <DesignModelView
      v-if="shape && variant && (document || !templateId || !templates.isLoading.value)"
      :shape="shape"
      :material="variant.material"
      :color-hex="colorHex"
      :document="doc"
    />
    <div
      v-else-if="failed"
      class="absolute inset-0 flex items-center justify-center text-sm text-muted-foreground"
    >
      {{ t('storefront.product.model3dError') }}
    </div>
    <StageLoader
      v-else
      show
      :text="t('storefront.product.view3dLoading')"
    />
  </div>
</template>
