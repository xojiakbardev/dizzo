<script setup lang="ts">
// What the customer sees: choose a type and a colour as in the app, and the
// gallery shows exactly the pictures the app shows for them, each marked
// with the list it comes from.
import { galleryFor, liveColors, liveVariants, type PictureSource } from '~/lib/catalogPictures';
import { PICTURES_KEY } from '~/composables/useProductPictures';
import type { AdminCatalogProduct } from '~/types/catalog';

const props = defineProps<{ product: AdminCatalogProduct }>();
const variantId = defineModel<number | null>('variant', { required: true });
const colorId = defineModel<number | null>('color', { required: true });

const { t } = useI18n();
const store = inject(PICTURES_KEY)!;
const variants = computed(() => liveVariants(props.product));
const variant = computed(() => variants.value.find(v => v.id === variantId.value) ?? null);
const colors = computed(() => (variant.value ? liveColors(variant.value) : []));
const color = computed(() => colors.value.find(c => c.id === colorId.value) ?? null);
const shown = computed(() => galleryFor(store.images, variant.value, color.value));

const active = ref(0);
watch(shown, (list, old) => {
  if (list[0]?.url !== old?.[0]?.url || active.value >= list.length) active.value = 0;
});

const SOURCE_TONE: Record<PictureSource, string> = {
  color: 'bg-primary text-primary-foreground',
  variant: 'bg-sky-600 text-white',
  product: 'bg-slate-600 text-white',
  cover: 'bg-slate-400 text-white',
};
// A picture whose source is the type is now its base shot, and nothing else:
// the type's older shared gallery no longer reaches the customer.
const sourceLabel = (source: PictureSource) =>
  (source === 'variant' ? t('admin.images.variantMain') : t(`admin.images.source.${source}`));

const colourCount = computed(() => (color.value ? store.images(`c:${color.value.id}`).length : 0));
</script>

<template>
  <UiCard class="gap-0 py-0">
    <UiCardHeader class="border-b py-3">
      <UiCardTitle class="flex items-center gap-2 font-semibold">
        <Icon
          name="lucide:smartphone"
          class="text-base text-muted-foreground"
        />
        {{ t('admin.images.customerSees') }}
      </UiCardTitle>
    </UiCardHeader>
    <UiCardContent class="space-y-3 py-4">
      <!-- The gallery -->
      <div class="relative mx-auto aspect-square w-full max-w-80 overflow-hidden rounded-2xl border border-border bg-muted/40">
        <template v-if="shown.length">
          <MediaThumb
            :key="shown[active]?.url"
            :src="shown[active]?.url"
            fit="contain"
            class="size-full rounded-none bg-transparent"
          />
          <span
            class="absolute left-2 top-2 rounded-md px-1.5 py-0.5 text-[11px] font-semibold"
            :class="SOURCE_TONE[shown[active]!.source]"
          >{{ sourceLabel(shown[active]!.source) }}</span>
          <span class="absolute bottom-2 right-2 rounded-md bg-foreground/70 px-1.5 py-0.5 text-[11px] font-medium tabular-nums text-background">
            {{ active + 1 }} / {{ shown.length }}
          </span>
        </template>
        <div
          v-else
          class="flex size-full flex-col items-center justify-center gap-2 text-sm font-medium text-amber-700 dark:text-amber-400"
        >
          <Icon
            name="lucide:image-off"
            class="text-3xl"
          />
          {{ t('admin.images.noPicture') }}
        </div>
      </div>
      <div
        v-if="shown.length > 1"
        class="flex gap-1.5 overflow-x-auto pb-1 scrollbar-none"
      >
        <button
          v-for="(pic, i) in shown"
          :key="pic.url"
          type="button"
          class="relative size-12 shrink-0 overflow-hidden rounded-lg border-2 transition"
          :class="i === active ? 'border-primary' : 'border-transparent opacity-70 hover:opacity-100'"
          :aria-label="t('admin.images.pictureN', { n: i + 1 })"
          @click="active = i"
        >
          <MediaThumb
            :src="pic.url"
            fit="contain"
            class="size-full rounded-md"
          />
          <span
            class="absolute inset-x-0 bottom-0 h-1"
            :class="SOURCE_TONE[pic.source]"
          />
        </button>
      </div>

      <!-- The choices, as the app offers them -->
      <div class="space-y-1.5">
        <p class="text-xs font-medium text-muted-foreground">
          {{ t('admin.images.source.variant') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="v in variants"
            :key="v.id"
            type="button"
            class="rounded-lg border px-2.5 py-1 text-sm transition"
            :class="v.id === variantId ? 'border-primary bg-primary/10 font-medium text-primary' : 'border-border hover:border-primary/50'"
            :aria-pressed="v.id === variantId"
            @click="variantId = v.id; colorId = liveColors(v)[0]?.id ?? null"
          >
            {{ v.name }}
          </button>
        </div>
      </div>
      <div
        v-if="colors.length"
        class="space-y-1.5"
      >
        <p class="text-xs font-medium text-muted-foreground">
          {{ t('admin.images.source.color') }}<span v-if="color">: <span class="text-foreground">{{ color.name }}</span></span>
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="c in colors"
            :key="c.id"
            type="button"
            class="relative size-8 rounded-full border-2 transition"
            :class="c.id === colorId ? 'border-primary ring-2 ring-primary/30' : 'border-border'"
            :style="{ backgroundColor: c.hex }"
            :title="c.name"
            :aria-label="c.name"
            :aria-pressed="c.id === colorId"
            @click="colorId = c.id"
          >
            <span
              v-if="!store.images(`c:${c.id}`).length"
              class="absolute -right-1 -top-1 size-3 rounded-full border-2 border-card bg-amber-400"
            />
          </button>
        </div>
      </div>

      <!-- Where the pictures come from -->
      <ul
        v-if="variant"
        class="space-y-1 rounded-xl bg-muted/50 p-2.5 text-xs"
      >
        <li
          v-if="color"
          class="flex items-center gap-2"
        >
          <span class="size-2 rounded-full bg-primary" />
          {{ t('admin.images.colorPictures') }}
          <span
            class="ml-auto font-medium tabular-nums"
            :class="colourCount ? '' : 'text-amber-700 dark:text-amber-400'"
          >{{ colourCount || t('admin.images.noPicture') }}</span>
        </li>
        <li class="flex items-center gap-2">
          <span class="size-2 rounded-full bg-slate-500" />
          {{ t('admin.images.productAndCover') }}
          <span class="ml-auto font-medium tabular-nums">{{ store.images('product').length + store.images('cover').length }}</span>
        </li>
      </ul>
    </UiCardContent>
  </UiCard>
</template>
