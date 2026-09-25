<script setup lang="ts">
// "Iconlar va Stikerlar":
// Pinterest masonry style dynamic Cloudflare R2 catalog assets (face parts, emojis, frames, backgrounds, stickers)
// along with built-in vector shapes and icons. Zero heavy JSON bundles.
import GraphicThumb from '~/components/studio/panels/GraphicThumb.vue';
import type { GraphicDef } from '~/lib/design/graphics';
import { graphicLabel, resolveGraphic, SHAPES } from '~/lib/design/graphics';
import { ICONS } from '~/lib/design/icon-set';
import type { ElementPick } from '~/lib/design/stickers';
import { usePublicDesignAssets, useDesignAssetsMeta } from '~/composables/queries/useDesignAssets';
import type { DesignAsset } from '~/types/catalog';

defineProps<{ disabled: boolean }>();
const emit = defineEmits<{
  add: [pick: ElementPick];
  'place-image': [image: { media_id: string; url: string; px_w: number; px_h: number }];
}>();

const { t, locale } = useI18n();

// Fetch Categories and Types from backend in 3 languages (uz, ru, en)
const metaQuery = useDesignAssetsMeta();
const tabs = computed(() => {
  const backendCats = (metaQuery.data.value?.categories ?? []).map(c => ({
    key: c.key === 'all' ? 'hammasi' : c.key,
    label: c.label[locale.value] || c.label.uz || c.label.en || c.key,
    icon: c.icon || 'lucide:folder',
  }));

  return [
    ...backendCats,
    { key: 'shakllar', label: t('studio.elements.groups.shakllar') || 'Shakllar', icon: 'lucide:shapes' },
    { key: 'ikonkalar', label: t('studio.elements.groups.ikonkalar') || 'Ikonkalar', icon: 'lucide:star' },
  ];
});

// Fetch R2 assets from backend
const assetsQuery = usePublicDesignAssets();
const assets = computed<DesignAsset[]>(() => assetsQuery.data.value ?? []);

// Built-in vector shapes and icons
interface VectorItem extends ElementPick {
  label: string;
  group: 'shakllar' | 'ikonkalar';
  def: GraphicDef;
}

const vectorItems = computed<VectorItem[]>(() => [
  ...SHAPES.map(s => ({
    library: 'shape' as const,
    name: s.name,
    w: s.width,
    h: s.height,
    label: graphicLabel({ library: 'shape', name: s.name }) ?? s.label,
    group: 'shakllar' as const,
    def: s,
  })),
  ...ICONS.map(icon => {
    const def = resolveGraphic({ library: 'icon', name: icon.name })!;
    return {
      library: 'icon' as const,
      name: icon.name,
      w: def.width,
      h: def.height,
      label: graphicLabel({ library: 'icon', name: icon.name }) ?? icon.label,
      group: 'ikonkalar' as const,
      def,
    };
  }),
]);

const tab = ref('hammasi');
const query = ref('');
const searched = refDebounced(query, 150);

// Filtered items
const filteredAssets = computed(() => {
  let list = assets.value;
  const q = searched.value.trim().toLowerCase();

  if (tab.value !== 'hammasi' && tab.value !== 'shakllar' && tab.value !== 'ikonkalar') {
    list = list.filter(a => a.category === tab.value);
  }

  if (q) {
    list = list.filter(a => a.name.toLowerCase().includes(q) || a.category.toLowerCase().includes(q));
  }

  return list;
});

const filteredVectors = computed(() => {
  let list = vectorItems.value;
  const q = searched.value.trim().toLowerCase();

  if (tab.value === 'shakllar' || tab.value === 'ikonkalar') {
    list = list.filter(v => v.group === tab.value);
  } else if (tab.value !== 'hammasi') {
    return [];
  }

  if (q) {
    list = list.filter(v => v.label.toLowerCase().includes(q) || v.name.toLowerCase().includes(q));
  }

  return list;
});

// Infinite scroll limit
const PAGE = 48;
const limit = ref(PAGE);
watch([tab, searched], () => (limit.value = PAGE));

const visibleAssets = computed(() => filteredAssets.value.slice(0, limit.value));
const visibleVectors = computed(() => filteredVectors.value.slice(0, limit.value));

const totalCount = computed(() => filteredAssets.value.length + filteredVectors.value.length);

const sentinel = ref<HTMLElement | null>(null);
let io: IntersectionObserver | null = null;
onMounted(() => {
  io = new IntersectionObserver((entries) => {
    if (entries.some(e => e.isIntersecting) && limit.value < totalCount.value) {
      limit.value += PAGE;
    }
  }, { rootMargin: '300px' });
  watch(sentinel, (el, old) => {
    if (old) io?.unobserve(old);
    if (el) io?.observe(el);
  }, { immediate: true });
});
onBeforeUnmount(() => io?.disconnect());

function pickAsset(asset: DesignAsset) {
  emit('place-image', {
    media_id: asset.media_id,
    url: asset.url,
    px_w: asset.px_w || 800,
    px_h: asset.px_h || 800,
  });
}

function pickVector(item: VectorItem) {
  emit('add', {
    library: item.library,
    name: item.name,
    w: item.w,
    h: item.h,
  });
}
</script>

<template>
  <div class="space-y-3">
    <!-- Search Bar -->
    <label class="relative block">
      <Icon
        name="lucide:search"
        class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
      />
      <UiInput
        v-model="query"
        type="search"
        class="pl-10 text-xs sm:text-sm"
        placeholder="Ko‘z, yuz, ramka, fon yoki stiker..."
        aria-label="Iconlarni qidirish"
      />
    </label>

    <!-- Navigation Tabs Pill Capsule (Horizontal Scroll) -->
    <UiTabs
      v-if="!query"
      v-model="tab"
    >
      <UiTabsList class="scrollbar-none -mx-1 flex h-auto w-[calc(100%+0.5rem)] snap-x snap-mandatory flex-nowrap justify-start gap-1.5 overflow-x-auto overflow-y-hidden scroll-px-1 bg-transparent p-1">
        <UiTabsTrigger
          v-for="t in tabs"
          :key="t.key"
          :value="t.key"
          class="h-auto flex-none snap-start rounded-lg border border-transparent px-2.5 py-1.5 text-xs text-foreground/70 hover:bg-primary/10 hover:text-primary data-active:border-primary/20 data-active:bg-primary/10 data-active:text-primary data-active:shadow-none"
        >
          <Icon
            :name="t.icon"
            class="text-sm"
          />
          {{ t.label }}
        </UiTabsTrigger>
      </UiTabsList>
    </UiTabs>

    <!-- Search Count Feedback -->
    <p
      v-else
      class="text-xs text-muted-foreground"
    >
      {{ totalCount ? `${totalCount} ta icon topildi` : 'Hech qanday icon topilmadi' }}
    </p>

    <!-- Loading Skeletons -->
    <div
      v-if="assetsQuery.isLoading.value"
      class="columns-3 gap-2 space-y-2"
      role="status"
    >
      <div
        v-for="i in 9"
        :key="i"
        class="break-inside-avoid rounded-xl border border-border/40 p-1"
        :style="{ height: `${70 + (i % 3) * 35}px` }"
      >
        <UiSkeleton class="h-full w-full rounded-lg" />
      </div>
    </div>

    <!-- Assets Grid (Pinterest Masonry Style) -->
    <div v-else>
      <div class="columns-3 gap-2 space-y-2">
        <!-- 1. Cloudflare R2 Database Assets (Variable height/width, clean Pinterest card) -->
        <div
          v-for="asset in visibleAssets"
          :key="asset.id"
          class="break-inside-avoid group relative cursor-pointer overflow-hidden rounded-xl border border-border/50 bg-card/50 p-1 backdrop-blur-2xs transition-all duration-200 hover:-translate-y-0.5 hover:border-primary/40 hover:bg-card hover:shadow-md active:scale-95"
          :title="asset.name"
          @click="pickAsset(asset)"
        >
          <img
            :src="asset.url"
            :alt="asset.name"
            loading="lazy"
            decoding="async"
            class="h-auto w-full rounded-lg object-contain transition-transform duration-300 group-hover:scale-105"
          >
        </div>

        <!-- 2. Built-in Vector Shapes & Icons -->
        <div
          v-for="vec in visibleVectors"
          :key="`${vec.library}:${vec.name}`"
          class="break-inside-avoid group relative aspect-square flex cursor-pointer items-center justify-center rounded-xl border border-border/50 bg-card/50 p-2 backdrop-blur-2xs transition-all duration-200 hover:-translate-y-0.5 hover:border-primary/40 hover:bg-card hover:shadow-md active:scale-95"
          :title="vec.label"
          @click="pickVector(vec)"
        >
          <span class="flex h-4/5 w-4/5 items-center justify-center text-foreground transition-transform duration-300 group-hover:scale-110">
            <GraphicThumb :def="vec.def" />
          </span>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-if="totalCount === 0"
        class="flex flex-col items-center justify-center py-10 text-center text-muted-foreground"
      >
        <Icon
          name="lucide:package-open"
          class="mb-2 h-8 w-8 text-muted-foreground/40"
        />
        <p class="text-xs">Bu bo‘limda hozircha iconlar yo‘q</p>
      </div>
    </div>

    <!-- Infinite scroll sentinel -->
    <div
      v-if="limit < totalCount"
      ref="sentinel"
      class="h-6"
      aria-hidden="true"
    />
  </div>
</template>
