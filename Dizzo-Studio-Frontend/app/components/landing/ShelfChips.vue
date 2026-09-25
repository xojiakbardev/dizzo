<script setup lang="ts">
// The shelves as one row of chips under a page title ("Barchasi" first,
// each with how many), scrolled sideways with snapping. The gallery shows
// it always; the catalog on phones, beside its side column on wide screens.
import type { ProductCategory, ShelfOption } from '~/types/catalog';

defineProps<{ categories: ShelfOption[]; counts: Record<string, number>; total: number }>();
const model = defineModel<ProductCategory | null>({ required: true });
const { t } = useI18n();

const chip = (active: boolean) => (active
  ? 'border-cta bg-cta text-white'
  : 'border-line bg-white text-ink hover:border-slate-300');
</script>

<template>
  <div
    class="-mx-4 flex snap-x snap-mandatory scroll-px-4 gap-2 overflow-x-auto px-4 pb-1 [scrollbar-width:none] sm:-mx-6 sm:scroll-px-6 sm:px-6 lg:mx-0 lg:scroll-px-0 lg:px-0 [&::-webkit-scrollbar]:hidden"
    role="group"
    :aria-label="t('storefront.shelves.label')"
  >
    <button
      type="button"
      class="flex h-10 shrink-0 cursor-pointer snap-start items-center gap-2 rounded-full border px-4 text-sm font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
      :class="chip(model === null)"
      :aria-pressed="model === null"
      @click="model = null"
    >
      {{ t('storefront.shelves.all') }}
      <span
        class="tabular-nums"
        :class="model === null ? 'text-white/75' : 'text-slate-500'"
      >{{ total }}</span>
    </button>
    <button
      v-for="c in categories"
      :key="c.value"
      type="button"
      class="flex h-10 shrink-0 cursor-pointer snap-start items-center gap-2 rounded-full border px-4 text-sm font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
      :class="chip(model === c.value)"
      :aria-pressed="model === c.value"
      @click="model = c.value"
    >
      <CategoryIcon
        :svg="c.icon_svg"
        :image="c.image_url"
      />
      {{ c.label }}
      <span
        class="tabular-nums"
        :class="model === c.value ? 'text-white/75' : 'text-slate-500'"
      >{{ counts[c.value] ?? 0 }}</span>
    </button>
  </div>
</template>
