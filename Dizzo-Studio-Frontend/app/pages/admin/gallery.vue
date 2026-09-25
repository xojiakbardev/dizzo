<script setup lang="ts">
import GalleryDesigns from '~/components/admin/GalleryDesigns.vue';
import GalleryAssetsAdmin from '~/components/admin/GalleryAssetsAdmin.vue';
import TutorialsAdmin from '~/components/admin/TutorialsAdmin.vue';
import GallerySubmit from '~/components/admin/GallerySubmit.vue';
import { useDesignAssetsMeta } from '~/composables/queries/useDesignAssets';

definePageMeta({ layout: 'admin' });

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const roles = useCurrentUserRoles();
const isHqGallery = computed(() => roles.value.isGlobalStaff);

type AdminGalleryTab = 'templates' | 'icons' | 'tutorials';

const activeTab = computed<AdminGalleryTab>({
  get: () => {
    const t = route.query.tab as string;
    if (t === 'icons' || t === 'tutorials') return t;
    return 'templates';
  },
  set: (val) => {
    const query = { ...route.query, tab: val === 'templates' ? undefined : val };
    router.replace({ query });
  },
});

const TABS: Array<{ key: AdminGalleryTab; label: string; icon: string }> = [
  { key: 'templates', label: 'Shablonlar', icon: 'lucide:layout-grid' },
  { key: 'icons', label: 'Rasmlar', icon: 'lucide:image' },
  { key: 'tutorials', label: 'Video darslar', icon: 'lucide:clapperboard' },
];

const searchQuery = ref((route.query.search as string) || '');
watch(searchQuery, (val) => {
  const query = { ...route.query, search: val.trim() || undefined };
  router.replace({ query });
});

const searchPlaceholder = computed(() => {
  if (!isHqGallery.value) return t('admin.gallery.searchPlaceholder');
  if (activeTab.value === 'icons') return 'Rasmlarni qidiring...';
  if (activeTab.value === 'tutorials') return t('admin.tutorials.searchPlaceholder');
  return t('admin.gallery.searchPlaceholder');
});

// ── Asset types for the select dropdown next to search input ──
const selectedAssetType = ref('all');
const metaQuery = useDesignAssetsMeta();
const assetTypes = computed(() => {
  const list = metaQuery.data.value?.types ?? [];
  return [
    { key: 'all', label: 'Barcha turlar' },
    ...list.map(tp => ({
      key: tp.key,
      label: (tp.label as Record<string, string>)[locale.value] || (tp.label as Record<string, string>).uz || (tp.label as Record<string, string>).en || tp.key,
    })),
  ];
});

const designsRef = ref<InstanceType<typeof GalleryDesigns> | null>(null);
const assetsRef = ref<InstanceType<typeof GalleryAssetsAdmin> | null>(null);
const tutorialsRef = ref<InstanceType<typeof TutorialsAdmin> | null>(null);
const submitRef = ref<InstanceType<typeof GallerySubmit> | null>(null);
</script>

<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center gap-3">
      <div
        v-if="isHqGallery"
        class="flex h-10 w-max items-center gap-1 rounded-xl border border-border bg-card p-1 shadow-2xs shrink-0"
      >
        <button
          v-for="tab in TABS"
          :key="tab.key"
          type="button"
          class="inline-flex h-full flex-none items-center gap-2 rounded-lg px-3 text-xs font-semibold transition cursor-pointer"
          :class="[
            activeTab === tab.key
              ? 'bg-primary text-primary-foreground shadow-xs'
              : 'text-muted-foreground hover:bg-primary/10 hover:text-primary',
          ]"
          @click="activeTab = tab.key"
        >
          <Icon
            :name="tab.icon"
            class="h-4 w-4"
          />
          {{ tab.label }}
        </button>
      </div>

      <div class="relative min-w-[200px] flex-1">
        <Icon
          name="lucide:search"
          class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
        />
        <UiInput
          v-model="searchQuery"
          type="search"
          class="h-10 bg-card pl-10"
          :placeholder="searchPlaceholder"
        />
      </div>

      <UiSelect
        v-if="isHqGallery && activeTab === 'icons'"
        v-model="selectedAssetType"
      >
        <UiSelectTrigger
          class="h-10 w-full bg-card sm:w-44 rounded-xl shrink-0"
          aria-label="Tur"
        >
          <UiSelectValue placeholder="Barcha turlar" />
        </UiSelectTrigger>
        <UiSelectContent position="popper">
          <UiSelectItem
            v-for="tp in assetTypes"
            :key="tp.key"
            :value="tp.key"
          >
            {{ tp.label }}
          </UiSelectItem>
        </UiSelectContent>
      </UiSelect>

      <div class="ml-auto flex shrink-0 items-center gap-2">
        <UiButton
          v-if="!isHqGallery"
          size="sm"
          class="h-10 px-3 gap-2 flex items-center justify-center rounded-xl shadow-xs"
          :title="t('admin.gallery.submit')"
          @click="submitRef?.add()"
        >
          <Icon
            name="lucide:image"
            class="size-5 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
        <UiButton
          v-else-if="activeTab === 'templates'"
          size="sm"
          class="h-10 px-3 gap-2 flex items-center justify-center rounded-xl shadow-xs"
          :title="t('admin.gallery.add')"
          @click="designsRef?.add()"
        >
          <Icon
            name="lucide:image"
            class="size-5 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
        <UiButton
          v-else-if="activeTab === 'icons'"
          size="sm"
          class="h-10 px-3 gap-2 flex items-center justify-center rounded-xl shadow-xs"
          title="Rasm yuklash"
          @click="assetsRef?.openBulkModal()"
        >
          <Icon
            name="lucide:image"
            class="size-5 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
        <UiButton
          v-else-if="activeTab === 'tutorials'"
          size="sm"
          class="h-10 px-3 gap-2 flex items-center justify-center rounded-xl shadow-xs"
          :title="t('admin.tutorials.add')"
          @click="tutorialsRef?.openNew()"
        >
          <Icon
            name="lucide:video"
            class="size-5 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </div>
    </div>

    <GallerySubmit
      v-if="!isHqGallery"
      ref="submitRef"
      :search="searchQuery"
    />
    <div v-else>
      <section v-show="activeTab === 'templates'">
        <GalleryDesigns
          ref="designsRef"
          :search="searchQuery"
          hide-header
        />
      </section>
      <section v-show="activeTab === 'icons'">
        <GalleryAssetsAdmin
          ref="assetsRef"
          :search="searchQuery"
          v-model:selected-type="selectedAssetType"
        />
      </section>
      <section v-show="activeTab === 'tutorials'">
        <TutorialsAdmin
          ref="tutorialsRef"
          :search="searchQuery"
          hide-header
        />
      </section>
    </div>
  </div>
</template>
