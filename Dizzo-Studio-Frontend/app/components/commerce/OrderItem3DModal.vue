<script setup lang="ts">
import StudioPreview from '~/components/studio/StudioPreview.vue';
import { useProductDetail } from '~/composables/queries/useCatalog';
import type { OrderItem } from '~/types/commerce';
import type { Material } from '~/types/catalog';

const props = defineProps<{
  modelValue: boolean;
  item: OrderItem;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const productSlug = computed(() => props.item.product_slug || '');
const productQuery = useProductDetail(productSlug);
const product = computed(() => productQuery.data.value ?? null);

// An order is a promise about one exact body. The catalog moves on — a
// revised shape is archived and drops out of the public detail, a type gets
// renamed — so the ordered shape may simply not be there any more. Standing
// in the product's first shape instead would re-project the design onto
// different geometry and show the customer a product nobody is making.
// Better to admit we cannot draw it: the template already has that state.
const shape = computed(() => {
  const shapes = product.value?.shapes ?? [];
  if (!shapes.length) return null;
  const ordered = props.item.shape?.id;
  if (ordered) return shapes.find(s => s.id === ordered) ?? null;
  // Older lines stored no shape; one shape is unambiguous, more is a guess.
  return shapes.length === 1 ? shapes[0]! : null;
});

// The material decides how the body is lit and how ink sits on it, and it
// lives on the type — so a type we cannot identify means we cannot draw the
// item honestly either.
const variant = computed(() => {
  const variants = product.value?.variants ?? [];
  if (!variants.length) return null;
  const ordered = props.item.variant_name;
  if (ordered) return variants.find(v => v.name === ordered) ?? null;
  return variants.length === 1 ? variants[0]! : null;
});

const material = computed<Material>(() => variant.value?.material ?? 'fabric');
const colorHex = computed(() => props.item.color_hex || '#ffffff');
const layers = computed(() => props.item.document?.layers ?? []);
const strips = computed(() => props.item.document?.strips);

const previewRef = ref<InstanceType<typeof StudioPreview> | null>(null);
const activeArea = ref<string | null>(null);

watch(shape, (s) => {
  if (s?.areas?.length && !activeArea.value) {
    activeArea.value = s.areas[0]?.key ?? null;
  }
}, { immediate: true });

function selectArea(key: string) {
  activeArea.value = key;
  nextTick(() => {
    previewRef.value?.resetView();
  });
}

function resetView() {
  previewRef.value?.resetView();
}
</script>

<template>
  <UiDialog
    :open="modelValue"
    @update:open="emit('update:modelValue', $event)"
  >
    <UiDialogContent class="sm:max-w-3xl md:max-w-4xl max-h-[92vh] h-[680px] p-0 flex flex-col overflow-hidden bg-background border border-border shadow-2xl">
      <UiDialogHeader class="px-5 py-3.5 border-b border-border shrink-0 flex flex-row items-center justify-between gap-4">
        <div class="min-w-0 pr-8">
          <UiDialogTitle class="text-base sm:text-lg font-bold truncate flex items-center gap-2">
            <span>{{ item.product_name }}</span>
            <span
              v-if="item.variant_name"
              class="text-xs font-normal text-muted-foreground"
            >· {{ item.variant_name }}</span>
          </UiDialogTitle>
          <UiDialogDescription class="text-xs text-muted-foreground flex flex-wrap items-center gap-2 mt-0.5">
            <span
              v-if="item.color_name"
              class="flex items-center gap-1 font-medium text-foreground"
            >
              <span
                class="size-2.5 rounded-full border border-black/15 shrink-0"
                :style="{ background: item.color_hex }"
              />
              {{ item.color_name }}
            </span>
            <span
              v-if="item.size"
              class="rounded bg-muted px-1.5 py-0.2 font-mono text-[11px] font-semibold text-foreground"
            >
              {{ item.size }}
            </span>
            <span
              v-if="item.shape"
              class="text-muted-foreground"
            >
              ({{ item.shape.name }})
            </span>
          </UiDialogDescription>
        </div>
      </UiDialogHeader>

      <div class="relative flex-1 min-h-0 bg-[#e9ebef] dark:bg-neutral-900 overflow-hidden">
        <!-- Loading state -->
        <div
          v-if="productQuery.isLoading.value"
          class="absolute inset-0 grid place-items-center"
        >
          <div class="flex flex-col items-center gap-3 text-muted-foreground">
            <Icon
              name="lucide:loader-2"
              class="size-8 animate-spin text-primary"
            />
            <span class="text-sm font-medium">3D model yuklanmoqda...</span>
          </div>
        </div>

        <!-- No shape/error fallback -->
        <div
          v-else-if="!shape"
          class="absolute inset-0 grid place-items-center p-6 text-center text-muted-foreground"
        >
          <div class="flex flex-col items-center gap-2">
            <Icon
              name="lucide:box"
              class="size-10 text-muted-foreground/40"
            />
            <p class="text-sm font-medium">
              Bu buyurtma qilingan shakl katalogda endi yo'q
            </p>
            <p class="max-w-xs text-xs">
              Buyurtmangiz o'zgarmadi — pastdagi rasmlar buyurtma berilgan paytdagi holatni ko'rsatadi.
            </p>
          </div>
        </div>

        <!-- 3D StudioPreview viewport -->
        <template v-else>
          <StudioPreview
            ref="previewRef"
            :shape="shape"
            :material="material"
            :color-hex="colorHex"
            :layers="layers"
            :strips="strips"
            :selected-area="activeArea"
            :editable="false"
          />

          <!-- Hint badge in top left -->
          <div class="absolute top-3 left-3 pointer-events-none hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-background/85 backdrop-blur-xs text-[11px] text-muted-foreground border border-border/50 shadow-xs">
            <Icon
              name="lucide:orbit"
              class="size-3.5 text-primary"
            />
            <span>360° aylantirish uchun suring</span>
          </div>

          <!-- Floating controls toolbar at the bottom -->
          <div
            v-if="shape.areas.length || previewRef"
            class="absolute bottom-3 left-1/2 -translate-x-1/2 z-10 flex flex-wrap items-center gap-1.5 p-1.5 rounded-xl bg-background/90 backdrop-blur-md border border-border shadow-lg max-w-[95%]"
          >
            <!-- Area snap buttons -->
            <button
              v-for="area in shape.areas"
              :key="area.key"
              type="button"
              class="px-2.5 py-1 text-xs font-semibold rounded-lg transition"
              :class="activeArea === area.key ? 'bg-primary text-primary-foreground shadow-xs' : 'text-muted-foreground hover:text-foreground hover:bg-muted'"
              @click="selectArea(area.key)"
            >
              {{ area.name }}
            </button>

            <div
              v-if="shape.areas.length"
              class="h-4 w-px bg-border my-auto mx-0.5"
            />

            <!-- Zoom in, Zoom out, Reset -->
            <UiButton
              variant="ghost"
              size="icon-xs"
              class="size-7 rounded-lg"
              title="Kattalashtirish"
              @click="previewRef?.zoomBy(1.2)"
            >
              <Icon
                name="lucide:zoom-in"
                class="size-3.5"
              />
            </UiButton>
            <UiButton
              variant="ghost"
              size="icon-xs"
              class="size-7 rounded-lg"
              title="Kichraytirish"
              @click="previewRef?.zoomBy(0.8)"
            >
              <Icon
                name="lucide:zoom-out"
                class="size-3.5"
              />
            </UiButton>
            <UiButton
              variant="ghost"
              size="icon-xs"
              class="size-7 rounded-lg"
              title="Qayta tiklash"
              @click="resetView"
            >
              <Icon
                name="lucide:rotate-ccw"
                class="size-3.5"
              />
            </UiButton>
          </div>
        </template>
      </div>
    </UiDialogContent>
  </UiDialog>
</template>
