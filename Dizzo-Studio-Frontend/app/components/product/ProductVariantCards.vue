<script setup lang="ts">
// The product's types as cards (the Studio's "Boshqa variantlar" look):
// picture and name.
import type { PublicVariant } from '~/types/catalog';

const props = defineProps<{
  variants: PublicVariant[];
  selectedId: number | null;
  selectedColor?: string | null;
}>();
const emit = defineEmits<{ select: [id: number]; hover: [id: number] }>();

/** The card's picture: the chosen colour's primary (first) gallery picture where
 * this type has that colour; otherwise the first available colour's primary picture. */
const photo = (v: PublicVariant) => {
  if (props.selectedColor) {
    const target = props.selectedColor.trim().toLowerCase();
    const matching = v.colors.find(c =>
      (c.name && c.name.trim().toLowerCase() === target)
      || (c.hex && c.hex.trim().toLowerCase() === target),
    );
    if (matching?.images?.[0]) return matching.images[0];
    if (matching?.card_image_url) return matching.card_image_url;
  }
  const firstWithImage = v.colors.find(c => c.images && c.images.length > 0);
  if (firstWithImage?.images?.[0]) return firstWithImage.images[0];
  return v.colors.find(c => c.card_image_url)?.card_image_url ?? v.main_image_url ?? v.variant_main_image ?? v.images[0] ?? null;
};
</script>

<template>
  <div class="scrollbar-none -mx-1 flex snap-x snap-mandatory items-start gap-2.5 overflow-x-auto overflow-y-hidden scroll-px-1 p-1">
    <UiButton
      v-for="v in variants"
      :key="v.id"
      variant="ghost"
      class="group h-auto w-24 shrink-0 snap-start flex-col items-stretch justify-start gap-1.5 self-start p-0 hover:bg-transparent sm:w-28"
      :title="v.name"
      :aria-pressed="v.id === selectedId"
      @click="emit('select', v.id)"
      @pointerenter="emit('hover', v.id)"
      @focus="emit('hover', v.id)"
    >
      <span
        class="relative block aspect-square overflow-hidden rounded-xl border-2 bg-plate transition"
        :class="v.id === selectedId ? 'border-primary' : 'border-border/70 group-hover:border-slate-300'"
      >
        <!-- A cut-out is shown whole, not cropped to the tile. -->
        <img
          v-if="photo(v)"
          v-bind="thumbSmall(photo(v))"
          :alt="v.name"
          loading="lazy"
          class="h-full w-full object-contain p-1"
        >
        <span
          v-else
          class="block h-full w-full"
          :style="{ background: v.colors[0]?.hex ?? '#eee' }"
        />
        <span
          v-if="v.id === selectedId"
          class="absolute right-1.5 top-1.5 flex size-5 items-center justify-center rounded-full bg-primary text-xs text-primary-foreground"
        >
          <Icon name="lucide:check" />
        </span>
      </span>
      <span
        class="whitespace-normal break-words text-center text-xs leading-tight"
        :class="v.id === selectedId ? 'font-semibold text-primary' : 'font-medium text-foreground'"
      >{{ v.name }}</span>
    </UiButton>
  </div>
</template>
