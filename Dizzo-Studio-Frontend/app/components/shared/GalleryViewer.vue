<script setup lang="ts">
// A gallery piece large (the gallery page and the landing's row): its other
// pictures, a 3D view for gallery designs, arrows through `items`, and the
// way into its product's Studio — empty ("Dizayn yaratish") or from the
// design ("Namuna sifatida foydalanish").
import type { GalleryItem } from '~/composables/queries/useGallery';
import { galleryImages } from '~/composables/queries/useGallery';

const props = defineProps<{ items: GalleryItem[] }>();
const open = defineModel<boolean>('open', { required: true });
const index = defineModel<number>('index', { required: true });

const { start: startDesign } = useProductPicker();
const { t } = useI18n();
const localePath = useLocalePath();

// The piece's product from the catalog: designs carry the slug; orders are
// matched on the name, ignoring case and the different Uzbek apostrophes.
const { list: catalog } = useStorefrontProducts();
const fold = (text: string) => text.toLowerCase().replace(/[‘’ʻʼ`']/g, '\'').trim();
const slugOf = (item: GalleryItem) => item.product_slug
  || catalog.value.find(p => fold(p.name) === fold(item.product_name))?.slug
  || null;

const current = computed<GalleryItem | null>(() => props.items[index.value] ?? null);
const currentSlug = computed(() => (current.value ? slugOf(current.value) : null));
const currentImages = computed(() => (current.value ? galleryImages(current.value) : []));
const picture = ref(0);
// A gallery design can be turned in 3D (the button on the picture).
const show3d = ref(false);
const can3d = computed(() => !!(current.value?.template_id && currentSlug.value));
watch(index, () => {
  picture.value = 0;
  show3d.value = false;
});
watch(open, (on) => {
  if (!on) show3d.value = false;
});

// Only the piece and the date: the gallery never names a customer.
const heading = (item: GalleryItem) => item.title || item.product_name;

function step(by: number) {
  const n = props.items.length;
  if (n > 1) index.value = (index.value + by + n) % n;
}
function studioLink(item: GalleryItem, slug: string, asSample = false) {
  const query: Record<string, string> = {};
  if (asSample && item.template_id) query.from = String(item.template_id);
  if (item.variant_id) query.variant = String(item.variant_id);
  if (item.color_id) query.color = String(item.color_id);
  return localePath({ path: `/studio/${slug}`, query });
}
function pickProduct() {
  open.value = false;
  void startDesign();
}
</script>

<template>
  <UiDialog v-model:open="open">
    <UiDialogContent
      v-if="current"
      class="gap-3 p-3 sm:max-w-xl"
      @keydown.left.prevent="step(-1)"
      @keydown.right.prevent="step(1)"
    >
      <UiDialogTitle class="truncate pr-10 pl-1 text-base font-bold text-ink">
        {{ heading(current) }}
      </UiDialogTitle>
      <UiDialogDescription class="sr-only">
        {{ heading(current) }}
      </UiDialogDescription>

      <div class="relative mx-auto aspect-square w-full max-w-[min(100%,60dvh)] overflow-hidden rounded-xl border border-line bg-white">
        <ClientOnly v-if="show3d && can3d">
          <GalleryModel
            :key="current.template_id!"
            :slug="currentSlug!"
            :variant-id="current.variant_id ?? null"
            :color-id="current.color_id ?? null"
            :template-id="current.template_id"
          />
        </ClientOnly>
        <img
          v-else
          v-bind="thumbAttrs(currentImages[picture] ?? current.preview_image_url, '(min-width: 640px) 576px, 100vw')"
          :alt="heading(current)"
          class="size-full object-contain"
        >
        <UiButton
          v-if="can3d"
          :variant="show3d ? 'default' : 'outline'"
          size="sm"
          class="absolute bottom-2 right-2 z-10"
          :aria-pressed="show3d"
          @click="show3d = !show3d"
        >
          <Icon :name="show3d ? 'lucide:image' : 'lucide:rotate-3d'" />
          {{ show3d ? t('storefront.viewer.picture') : '3D' }}
        </UiButton>
        <template v-if="items.length > 1">
          <UiButton
            variant="outline"
            size="icon-sm"
            class="absolute left-2 top-1/2 -translate-y-1/2"
            :aria-label="t('storefront.viewer.prev')"
            @click="step(-1)"
          >
            <Icon name="lucide:chevron-left" />
          </UiButton>
          <UiButton
            variant="outline"
            size="icon-sm"
            class="absolute right-2 top-1/2 -translate-y-1/2"
            :aria-label="t('storefront.viewer.next')"
            @click="step(1)"
          >
            <Icon name="lucide:chevron-right" />
          </UiButton>
        </template>
      </div>

      <div
        v-if="currentImages.length > 1"
        class="flex justify-center gap-2"
        role="group"
        :aria-label="t('storefront.viewer.pictures')"
      >
        <button
          v-for="(url, i) in currentImages"
          :key="url"
          type="button"
          class="size-12 cursor-pointer overflow-hidden rounded-lg border-2 bg-white transition sm:size-14"
          :class="i === picture && !show3d ? 'border-cta' : 'border-line opacity-70 hover:opacity-100'"
          :aria-label="t('storefront.product.imageN', { n: i + 1 })"
          :aria-pressed="i === picture && !show3d"
          @click="picture = i; show3d = false"
        >
          <img
            v-bind="thumbSmall(url)"
            alt=""
            class="size-full object-cover"
            loading="lazy"
          >
        </button>
      </div>

      <div class="flex items-center justify-between gap-3 px-1 text-sm text-slate-600">
        <span class="truncate">{{ current.title ? current.product_name : '' }}</span>
        <span class="shrink-0">{{ formatDate(current.created_at) }}</span>
      </div>

      <div
        v-if="currentSlug"
        class="flex flex-col gap-2 sm:flex-row"
      >
        <UiButton
          as-child
          size="lg"
          class="flex-1"
        >
          <NuxtLink :to="studioLink(current, currentSlug)">
            <Icon name="lucide:sparkles" />
            {{ t('storefront.common.createDesign') }}
          </NuxtLink>
        </UiButton>
        <UiButton
          v-if="current.template_id"
          as-child
          size="lg"
          variant="outline"
          class="flex-1"
        >
          <NuxtLink :to="studioLink(current, currentSlug, true)">
            <Icon name="lucide:copy" />
            {{ t('storefront.viewer.useAsSample') }}
          </NuxtLink>
        </UiButton>
      </div>
      <UiButton
        v-else
        size="lg"
        class="w-full"
        @click="pickProduct"
      >
        <Icon name="lucide:sparkles" />
        {{ t('storefront.common.createDesign') }}
      </UiButton>
    </UiDialogContent>
  </UiDialog>
</template>
