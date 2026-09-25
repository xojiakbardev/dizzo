<script setup lang="ts">
// The catalog's shelves as one list: "Barchasi" plus every shelf that has
// products, each with how many. The same list is the side column on wide
// screens and the sheet a phone opens, so a shelf is always picked the same
// way and every row is a 48px target.
import type { ProductCategory, ShelfOption } from '~/types/catalog';

defineProps<{ categories: ShelfOption[]; counts: Record<string, number>; total: number }>();
const model = defineModel<ProductCategory | null>({ required: true });
const { t } = useI18n();
// The sheet closes on a pick; the side column ignores this.
const emit = defineEmits<{ select: [] }>();

function pick(value: ProductCategory | null) {
  model.value = value;
  emit('select');
}

const row = (active: boolean) => (active
  ? 'bg-cta text-white'
  : 'text-ink hover:bg-plate');
const count = (active: boolean) => (active ? 'text-white/75' : 'text-slate-500');
</script>

<template>
  <ul
    class="space-y-1 rounded-2xl border border-line bg-white p-2"
    :aria-label="t('storefront.shelves.label')"
  >
    <li>
      <button
        type="button"
        class="flex h-12 w-full cursor-pointer items-center justify-between gap-3 rounded-xl px-4 text-left text-base font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
        :class="row(model === null)"
        :aria-pressed="model === null"
        @click="pick(null)"
      >
        {{ t('storefront.shelves.all') }}
        <span
          class="text-sm font-medium tabular-nums"
          :class="count(model === null)"
        >{{ total }}</span>
      </button>
    </li>
    <li
      v-for="c in categories"
      :key="c.value"
    >
      <button
        type="button"
        class="flex h-12 w-full cursor-pointer items-center gap-3 rounded-xl px-4 text-left text-base font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
        :class="row(model === c.value)"
        :aria-pressed="model === c.value"
        @click="pick(c.value)"
      >
        <CategoryIcon
          :svg="c.icon_svg"
          :image="c.image_url"
        />
        <span class="min-w-0 flex-1 truncate">{{ c.label }}</span>
        <span
          class="text-sm font-medium tabular-nums"
          :class="count(model === c.value)"
        >{{ counts[c.value] ?? 0 }}</span>
      </button>
    </li>
  </ul>
</template>
