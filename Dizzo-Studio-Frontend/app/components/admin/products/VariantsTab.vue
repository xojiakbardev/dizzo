<script setup lang="ts">
// The product's variants as cards; adding and editing a variant are pages.
// The add button sits in the page's tab row (#product-tab-actions).
import type { AdminCatalogProduct, Variant } from '~/types/catalog';
import { METHOD_LABELS } from '~/types/catalog';
import ShapePicture from '~/components/admin/products/ShapePicture.vue';

const props = defineProps<{ product: AdminCatalogProduct }>();
const { t } = useI18n();
const { run, busy } = useCatalogAdminActions();

const variants = computed(() => props.product.variants.filter(v => !v.archived));
const readyShapes = computed(() => props.product.shapes.filter(s => !s.archived && s.replaces_id === null && s.status === 'ready'));
const shapeOf = (v: Variant) => props.product.shapes.find(s => s.id === v.shape_id) ?? null;
const colorsOf = (v: Variant) => v.colors.filter(c => !c.archived);
/** Clothing sizes, in the admin's order; empty on products without them. */
const sizesOf = (v: Variant) => v.sizes;
/** Its first colour's photo, else its own photo; else the shape is drawn. */
const photoOf = (v: Variant) => (colorsOf(v).find(c => c.images[0])?.images[0] ?? v.images[0])?.url ?? null;
const pageOf = (v: Variant) => `/admin/products/${props.product.id}/types/${v.id}`;
const newPage = computed(() => `/admin/products/${props.product.id}/types/new`);

async function setAvailable(variant: Variant, value: boolean) {
  await run('patch', `/admin/catalog/variants/${variant.id}/`, { is_available: value });
}
</script>

<template>
  <div>
    <Teleport
      defer
      to="#product-tab-actions"
    >
      <UiButton
        v-if="readyShapes.length"
        as-child
      >
        <NuxtLinkLocale :to="newPage">
          <Icon
            name="lucide:plus"
            class="text-base"
          />
          {{ t('admin.variants.add') }}
        </NuxtLinkLocale>
      </UiButton>
      <UiTooltip v-else>
        <UiTooltipTrigger as-child>
          <span tabindex="0">
            <UiButton disabled>
              <Icon
                name="lucide:plus"
                class="text-base"
              />
              {{ t('admin.variants.add') }}
            </UiButton>
          </span>
        </UiTooltipTrigger>
        <UiTooltipContent>{{ t('admin.variants.needShapeTip') }}</UiTooltipContent>
      </UiTooltip>
    </Teleport>

    <EmptyState
      v-if="!variants.length"
      :title="readyShapes.length ? t('admin.variants.empty') : t('admin.variants.needShape')"
      :description="readyShapes.length
        ? t('admin.variants.emptyHint')
        : t('admin.variants.needShapeHint')"
      :icon="readyShapes.length ? 'lucide:layers' : 'lucide:box'"
    >
      <UiButton
        as-child
        variant="outline"
        size="sm"
      >
        <NuxtLinkLocale
          v-if="readyShapes.length"
          :to="newPage"
        >
          <Icon
            name="lucide:plus"
            class="text-sm"
          />
          {{ t('admin.variants.add') }}
        </NuxtLinkLocale>
        <NuxtLink
          v-else
          :to="{ query: { tab: 'shapes' } }"
        >
          {{ t('admin.variants.toShapes') }}
        </NuxtLink>
      </UiButton>
    </EmptyState>
    <div
      v-else
      class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"
    >
      <UiCard
        v-for="v in variants"
        :key="v.id"
        class="gap-3 p-3 transition-shadow hover:shadow-md"
      >
        <NuxtLinkLocale
          :to="pageOf(v)"
          class="relative block rounded-xl outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
          :aria-label="v.name"
        >
          <MediaThumb
            v-if="photoOf(v) || !shapeOf(v)"
            :src="photoOf(v)"
            :alt="v.name"
            :class="v.is_available ? 'aspect-square w-full' : 'aspect-square w-full opacity-50 grayscale'"
          />
          <ShapePicture
            v-else
            :shape="shapeOf(v)!"
            :size="360"
            :class="v.is_available ? '' : 'opacity-50 grayscale'"
          />
          <div
            v-if="v.methods.length"
            class="pointer-events-none absolute right-2 top-2 flex flex-col items-end gap-1"
          >
            <UiBadge
              v-for="m in v.methods"
              :key="m"
              variant="outline"
              class="h-5 rounded-md border-border/70 bg-card/90 px-1.5 text-[10px] font-semibold text-foreground shadow-xs backdrop-blur-sm"
            >
              {{ METHOD_LABELS[m] }}
            </UiBadge>
          </div>
        </NuxtLinkLocale>
        <div class="min-w-0 space-y-1">
          <div class="flex items-baseline justify-between gap-2">
            <p class="truncate font-semibold text-foreground">
              {{ v.name }}
            </p>
            <p class="shrink-0 text-sm font-semibold text-foreground tabular-nums">
              {{ formatMoney(v.base_price) }}
            </p>
          </div>
          <p class="truncate text-xs text-muted-foreground">
            {{ shapeOf(v)?.name ?? '—' }}
          </p>
        </div>
        <div class="flex min-h-4 flex-wrap items-center gap-1">
          <UiTooltip
            v-for="c in colorsOf(v)"
            :key="c.id"
          >
            <UiTooltipTrigger as-child>
              <span
                class="size-4 rounded-full border border-black/10"
                :class="c.is_available ? '' : 'opacity-40'"
                :style="{ background: c.hex }"
                :aria-label="c.name"
              />
            </UiTooltipTrigger>
            <UiTooltipContent>{{ c.name }}</UiTooltipContent>
          </UiTooltip>
          <span
            v-if="!colorsOf(v).length"
            class="text-xs leading-4 text-muted-foreground"
          >{{ t('admin.variants.noColors') }}</span>
        </div>
        <div
          v-if="sizesOf(v).length"
          class="flex flex-wrap items-center gap-1"
        >
          <UiBadge
            v-for="s in sizesOf(v)"
            :key="s.label"
            variant="outline"
            class="h-5 rounded-md px-1.5 text-[10px] font-semibold"
            :class="s.is_available ? '' : 'text-muted-foreground line-through'"
          >
            {{ s.label }}
          </UiBadge>
        </div>
        <div class="mt-auto flex items-center gap-2 border-t pt-3">
          <UiLabel class="flex cursor-pointer items-center gap-2 text-xs font-normal text-foreground">
            <UiSwitch
              :model-value="v.is_available"
              :disabled="busy"
              @update:model-value="(value: boolean) => setAvailable(v, value)"
            />
            {{ t('admin.common.onSale') }}
          </UiLabel>
          <UiButton
            as-child
            size="sm"
            variant="outline"
            class="ml-auto"
          >
            <NuxtLinkLocale :to="pageOf(v)">
              <Icon
                name="lucide:pencil"
                class="text-sm"
              />
              {{ t('admin.common.edit') }}
            </NuxtLinkLocale>
          </UiButton>
        </div>
      </UiCard>
    </div>
  </div>
</template>
