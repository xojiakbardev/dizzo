<script setup lang="ts">
import type { DesignAsset } from '~/types/catalog';
import { getApiErrorMessage } from '~/composables/useApi';
import { DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import {
  useAdminDesignAssets,
  useAdminDesignAssetActions,
  useDesignAssetsMeta,
  type DesignAssetBulkItemIn,
} from '~/composables/queries/useDesignAssets';

const props = withDefaults(defineProps<{
  search?: string;
}>(), {
  search: '',
});

const selectedType = defineModel<string>('selectedType', { default: 'all' });

defineExpose({
  openBulkModal,
});

const { t, locale } = useI18n();
const { upload } = useMediaUpload();
const actions = useAdminDesignAssetActions();

// ── Meta from backend (Categories & Types in 3 languages: uz, ru, en) ──
const metaQuery = useDesignAssetsMeta();

const categories = computed(() => {
  const list = metaQuery.data.value?.categories ?? [];
  return list.map(c => ({
    key: c.key,
    label: c.label[locale.value] || c.label.uz || c.label.en || c.key,
    icon: c.icon || 'lucide:folder',
  }));
});

const types = computed(() => {
  const list = metaQuery.data.value?.types ?? [];
  return list.map(tp => ({
    key: tp.key,
    label: tp.label[locale.value] || tp.label.uz || tp.label.en || tp.key,
  }));
});

// Category helper for localized label
function getCategoryLabel(catKey: string): string {
  const found = categories.value.find(c => c.key === catKey);
  return found ? found.label : catKey.replace('-', ' ').toUpperCase();
}

function getTypeLabel(typeKey: string): string {
  const found = types.value.find(tp => tp.key === typeKey);
  return found ? found.label : typeKey.toUpperCase();
}

// ── Filter State ──
const selectedCategory = ref('all');
const localSearchQuery = ref('');

const effectiveSearch = computed(() => (props.search !== undefined && props.search !== '' ? props.search : localSearchQuery.value));

const listQuery = useAdminDesignAssets(selectedCategory, selectedType);
const allAssets = computed(() => listQuery.data.value ?? []);

const filteredAssets = computed(() => {
  let list = allAssets.value;
  const q = effectiveSearch.value.toLowerCase().trim();
  if (q) {
    list = list.filter(a => a.name.toLowerCase().includes(q) || a.category.toLowerCase().includes(q));
  }
  return list;
});

const error = ref<string | null>(null);
async function act(action: () => Promise<unknown>, fallback: string) {
  error.value = null;
  try {
    await action();
  }
  catch (e) {
    error.value = getApiErrorMessage(e, fallback);
  }
}

// ── Item Detail & Edit Modal (Pinterest Click → Modal) ──
const detailModalOpen = ref(false);
const activeAsset = ref<DesignAsset | null>(null);
const editForm = reactive({
  name: '',
  category: 'fonlar',
  type: 'icon' as 'icon' | 'sticker' | 'photo',
  is_active: true,
});
const saving = ref(false);
const deleting = ref(false);
const showDeleteConfirm = ref(false);

function openDetailModal(asset: DesignAsset) {
  activeAsset.value = asset;
  editForm.name = asset.name;
  editForm.category = asset.category;
  editForm.type = asset.type;
  editForm.is_active = asset.is_active;
  showDeleteConfirm.value = false;
  detailModalOpen.value = true;
}

async function saveAssetChanges() {
  if (!activeAsset.value) return;
  saving.value = true;
  try {
    await actions.update(activeAsset.value.id, {
      name: editForm.name.trim(),
      category: editForm.category,
      type: editForm.type,
      is_active: editForm.is_active,
    });
    detailModalOpen.value = false;
  }
  catch (e) {
    error.value = getApiErrorMessage(e, 'O‘zgarishlarni saqlashda xatolik yuz berdi');
  }
  finally {
    saving.value = false;
  }
}

async function deleteActiveAsset() {
  if (!activeAsset.value) return;
  deleting.value = true;
  try {
    await actions.remove(activeAsset.value.id);
    detailModalOpen.value = false;
  }
  catch (e) {
    error.value = getApiErrorMessage(e, 'Assetni o‘chirishda xatolik yuz berdi');
  }
  finally {
    deleting.value = false;
    showDeleteConfirm.value = false;
  }
}

// ── Bulk Upload Modal ──
const bulkModalOpen = ref(false);
const bulkCategory = ref('fonlar');
const bulkType = ref<'icon' | 'sticker' | 'photo'>('sticker');
const bulkFiles = ref<Array<{ file: File; preview: string; name: string }>>([]);
const isUploading = ref(false);
const uploadProgress = ref(0);

function openBulkModal() {
  bulkCategory.value = selectedCategory.value !== 'all' ? selectedCategory.value : 'fonlar';
  bulkType.value = 'sticker';
  bulkFiles.value = [];
  uploadProgress.value = 0;
  bulkModalOpen.value = true;
}

function handleFilesSelected(event: Event) {
  const input = event.target as HTMLInputElement;
  if (!input.files?.length) return;

  const validFiles: Array<{ file: File; preview: string; name: string }> = [];
  for (const file of Array.from(input.files)) {
    if (MEDIA_IMAGE_TYPES.includes(file.type) && file.size <= DESIGN_IMAGE_MAX_MB * 1024 * 1024) {
      const cleanName = file.name
        .replace(/\.[^/.]+$/, '')
        .replace(/[-_]/g, ' ')
        .trim();
      validFiles.push({
        file,
        preview: URL.createObjectURL(file),
        name: cleanName,
      });
    }
  }
  bulkFiles.value = [...bulkFiles.value, ...validFiles];
  input.value = '';
}

function removeBulkFile(idx: number) {
  const item = bulkFiles.value[idx];
  if (item) URL.revokeObjectURL(item.preview);
  bulkFiles.value.splice(idx, 1);
}

async function startBulkUpload() {
  if (!bulkFiles.value.length) return;
  isUploading.value = true;
  uploadProgress.value = 0;

  try {
    const uploadedItems: DesignAssetBulkItemIn[] = [];
    const total = bulkFiles.value.length;

    for (let i = 0; i < total; i++) {
      const it = bulkFiles.value[i]!;
      const media = await upload(it.file, 'catalog');
      uploadedItems.push({
        media_id: media.id,
        name: it.name,
      });
      uploadProgress.value = Math.round(((i + 1) / total) * 100);
    }

    await actions.bulkCreate({
      category: bulkCategory.value,
      type: bulkType.value,
      items: uploadedItems,
    });

    for (const f of bulkFiles.value) URL.revokeObjectURL(f.preview);
    bulkFiles.value = [];
    bulkModalOpen.value = false;
  }
  catch (e) {
    error.value = getApiErrorMessage(e, 'Fayllarni yuklashda xatolik yuz berdi');
  }
  finally {
    isUploading.value = false;
  }
}
</script>

<template>
  <div class="space-y-4">
    <!-- Category Filter Tabs: Scroll Snap Pills -->
    <div class="-mx-3 min-w-0 overflow-x-auto px-3 scrollbar-none snap-x snap-mandatory sm:mx-0 sm:px-0">
      <div class="flex items-center gap-2 py-1">
        <button
          v-for="cat in categories"
          :key="cat.key"
          type="button"
          class="snap-start flex-none inline-flex items-center gap-2 rounded-full px-4 py-2 text-xs font-semibold transition-all border shadow-2xs cursor-pointer"
          :class="selectedCategory === cat.key
            ? 'bg-slate-950 text-white border-slate-950 dark:bg-foreground dark:text-background shadow-xs'
            : 'bg-card/90 border-border/70 text-foreground/80 hover:bg-muted/80 hover:text-foreground'"
          @click="selectedCategory = cat.key"
        >
          <Icon
            :name="cat.icon"
            class="h-3.5 w-3.5"
          />
          {{ cat.label }}
        </button>
      </div>
    </div>

    <!-- Error Alert -->
    <UiAlert
      v-if="error"
      variant="destructive"
      class="rounded-xl"
    >
      <Icon name="lucide:alert-circle" />
      <div class="text-xs sm:text-sm font-medium">{{ error }}</div>
    </UiAlert>

    <!-- Loading Skeleton (Masonry style) -->
    <div
      v-if="listQuery.isLoading.value"
      class="columns-2 sm:columns-3 md:columns-4 lg:columns-5 xl:columns-6 gap-4 space-y-4"
    >
      <div
        v-for="i in 12"
        :key="i"
        class="break-inside-avoid overflow-hidden rounded-2xl border border-border/50 bg-card p-2"
        :style="{ height: `${120 + (i % 3) * 60}px` }"
      >
        <UiSkeleton class="h-full w-full rounded-xl" />
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="filteredAssets.length === 0"
      class="flex flex-col items-center justify-center rounded-3xl border border-dashed border-border py-16 text-center"
    >
      <div class="mb-3 flex size-12 items-center justify-center rounded-2xl bg-muted/60 text-muted-foreground">
        <Icon
          name="lucide:image-off"
          class="size-6"
        />
      </div>
      <h3 class="text-sm font-semibold text-foreground">Hozircha hech qanday rasm yoki icon topilmadi</h3>
      <p class="mt-1 max-w-xs text-xs text-muted-foreground">
        Yuqoridagi "Rasm & Icon yuklash" tugmasi orqali yangilarini qo‘shishingiz mumkin
      </p>
      <UiButton
        variant="outline"
        class="mt-4 gap-2 rounded-xl text-xs"
        @click="openBulkModal"
      >
        <Icon
          name="lucide:upload"
          class="h-3.5 w-3.5"
        />
        Rasm yuklash
      </UiButton>
    </div>

    <!-- ── Pinterest Masonry Grid (Variable Height & Width, No badges, Absolute Dot status) ── -->
    <div
      v-else
      class="columns-2 sm:columns-3 md:columns-4 lg:columns-5 xl:columns-6 gap-4 space-y-4"
    >
      <div
        v-for="asset in filteredAssets"
        :key="asset.id"
        class="break-inside-avoid group relative cursor-pointer overflow-hidden rounded-2xl border border-border/60 bg-card/60 backdrop-blur-xs shadow-xs transition-all duration-300 hover:-translate-y-1 hover:border-primary/40 hover:shadow-xl"
        @click="openDetailModal(asset)"
      >
        <!-- The Image itself: adapts naturally to portrait, landscape or square -->
        <div class="relative w-full overflow-hidden bg-muted/20">
          <img
            :src="asset.url"
            :alt="asset.name"
            loading="lazy"
            decoding="async"
            class="h-auto w-full object-cover transition-transform duration-500 will-change-transform group-hover:scale-[1.04]"
          >
          <!-- Subtle Dark Gradient on Hover -->
          <div class="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
        </div>

        <!-- Status Indicator: Simple Absolute Dot (Green = Active / Red = Hidden) -->
        <div
          class="absolute top-2.5 right-2.5 flex items-center justify-center"
          :title="asset.is_active ? 'Ko‘rinadigan (Faol)' : 'Yashiringan (Nofaol)'"
        >
          <span
            class="relative flex size-3 rounded-full ring-2 ring-black/40 shadow-md"
            :class="asset.is_active ? 'bg-emerald-500 shadow-emerald-500/50' : 'bg-rose-500 shadow-rose-500/50'"
          >
            <span
              v-if="asset.is_active"
              class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-60"
            />
          </span>
        </div>

        <!-- Hover Overlay Icon hint -->
        <div class="pointer-events-none absolute bottom-2.5 right-2.5 flex size-7 items-center justify-center rounded-xl bg-black/60 text-white backdrop-blur-md opacity-0 transition-opacity duration-200 group-hover:opacity-100">
          <Icon
            name="lucide:sliders-horizontal"
            class="size-3.5"
          />
        </div>
      </div>
    </div>

    <!-- ── 1. Detail & Edit Modal (Opens smoothly like video tutorials) ── -->
    <UiDialog v-model:open="detailModalOpen">
      <UiDialogContent class="max-h-[92dvh] overflow-y-auto sm:max-w-lg rounded-3xl p-6">
        <UiDialogHeader>
          <UiDialogTitle class="flex items-center gap-2 text-base font-bold text-foreground">
            <Icon
              name="lucide:image"
              class="h-5 w-5 text-primary"
            />
            Rasm / Icon tafsilotlari
          </UiDialogTitle>
        </UiDialogHeader>

        <div
          v-if="activeAsset"
          class="space-y-5 pt-2"
        >
          <!-- Large Clean Preview -->
          <div class="relative flex min-h-[200px] max-h-[360px] items-center justify-center overflow-hidden rounded-2xl border border-border bg-muted/30 p-3">
            <img
              :src="activeAsset.url"
              :alt="activeAsset.name"
              class="max-h-[330px] w-auto max-w-full rounded-xl object-contain drop-shadow-md"
            >
            <!-- Status Badge in Preview -->
            <div class="absolute top-3 right-3 flex items-center gap-1.5 rounded-full bg-background/80 px-2.5 py-1 text-xs font-semibold backdrop-blur-md shadow-xs">
              <span
                class="size-2 rounded-full"
                :class="editForm.is_active ? 'bg-emerald-500' : 'bg-rose-500'"
              />
              {{ editForm.is_active ? 'Ko‘rinadigan' : 'Yashirilgan' }}
            </div>
          </div>

          <!-- Edit Form Fields -->
          <form
            class="space-y-4"
            @submit.prevent="saveAssetChanges"
          >
            <!-- Asset Name -->
            <UiField label="Nomi / Tavsifi">
              <UiInput
                v-model="editForm.name"
                type="text"
                class="rounded-xl"
                placeholder="Masalan: Qizil yurakli mushukcha"
                required
              />
            </UiField>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <!-- Category Selector (Localized 3 languages) -->
              <UiField label="Kategoriya">
                <select
                  v-model="editForm.category"
                  class="flex h-10 w-full rounded-xl border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                >
                  <option
                    v-for="cat in categories.filter(c => c.key !== 'all')"
                    :key="cat.key"
                    :value="cat.key"
                  >
                    {{ cat.label }}
                  </option>
                </select>
              </UiField>

              <!-- Type Selector (Localized) -->
              <UiField label="Turi">
                <select
                  v-model="editForm.type"
                  class="flex h-10 w-full rounded-xl border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                >
                  <option
                    v-for="tp in types.filter(t => t.key !== 'all')"
                    :key="tp.key"
                    :value="tp.key"
                  >
                    {{ tp.label }}
                  </option>
                </select>
              </UiField>
            </div>

            <!-- Active / Hidden Switch -->
            <label class="flex cursor-pointer items-center justify-between gap-3 rounded-2xl border border-border bg-card/40 p-3.5 transition-colors hover:bg-muted/40">
              <div class="space-y-0.5">
                <div class="text-xs sm:text-sm font-medium text-foreground">Mijozlarga ko‘rsatilsin</div>
                <div class="text-xs text-muted-foreground">O‘chirib qo‘yilsa, Studioda iconlar orasida ko‘rinmaydi</div>
              </div>
              <UiSwitch v-model="editForm.is_active" />
            </label>

            <!-- Delete Confirmation Area -->
            <div
              v-if="showDeleteConfirm"
              class="rounded-2xl border border-destructive/30 bg-destructive/10 p-3.5 text-xs text-destructive"
            >
              <div class="font-semibold">Haqiqatan ham ushbu elementni o‘chirmoqchimisiz?</div>
              <p class="mt-1 text-muted-foreground">Bu amalni ortga qaytarib bo‘lmaydi.</p>
              <div class="mt-3 flex items-center gap-2">
                <UiButton
                  type="button"
                  variant="destructive"
                  size="sm"
                  class="rounded-xl text-xs"
                  :disabled="deleting"
                  @click="deleteActiveAsset"
                >
                  <Icon
                    v-if="deleting"
                    name="lucide:loader-2"
                    class="size-3.5 animate-spin"
                  />
                  Ha, o‘chirilsin
                </UiButton>
                <UiButton
                  type="button"
                  variant="outline"
                  size="sm"
                  class="rounded-xl text-xs"
                  @click="showDeleteConfirm = false"
                >
                  Bekor qilish
                </UiButton>
              </div>
            </div>

            <!-- Footer Actions -->
            <UiDialogFooter class="flex flex-col-reverse sm:flex-row sm:items-center sm:justify-between gap-2 pt-2">
              <UiButton
                v-if="!showDeleteConfirm"
                type="button"
                variant="ghost"
                class="text-destructive hover:bg-destructive/10 hover:text-destructive rounded-xl text-xs"
                @click="showDeleteConfirm = true"
              >
                <Icon
                  name="lucide:trash-2"
                  class="mr-1.5 h-3.5 w-3.5"
                />
                O‘chirish
              </UiButton>
              <div v-else />

              <div class="flex items-center gap-2">
                <UiButton
                  type="button"
                  variant="outline"
                  class="rounded-xl text-xs"
                  @click="detailModalOpen = false"
                >
                  Yopish
                </UiButton>
                <UiButton
                  type="submit"
                  class="rounded-xl text-xs font-semibold"
                  :disabled="saving"
                >
                  <Icon
                    v-if="saving"
                    name="lucide:loader-2"
                    class="mr-1.5 h-3.5 w-3.5 animate-spin"
                  />
                  Saqlash
                </UiButton>
              </div>
            </UiDialogFooter>
          </form>
        </div>
      </UiDialogContent>
    </UiDialog>

    <!-- ── 2. Bulk Upload Modal ── -->
    <UiDialog v-model:open="bulkModalOpen">
      <UiDialogContent class="max-h-[92dvh] overflow-y-auto sm:max-w-2xl rounded-3xl p-6">
        <UiDialogHeader>
          <UiDialogTitle class="flex items-center gap-2 text-base font-bold text-foreground">
            <Icon
              name="lucide:upload-cloud"
              class="h-5 w-5 text-primary"
            />
            Rasm va Iconlarni ommaviy yuklash
          </UiDialogTitle>
        </UiDialogHeader>

        <div class="space-y-4 pt-2">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <!-- Target Category -->
            <UiField label="Yuklanadigan kategoriya">
              <select
                v-model="bulkCategory"
                class="flex h-10 w-full rounded-xl border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
              >
                <option
                  v-for="cat in categories.filter(c => c.key !== 'all')"
                  :key="cat.key"
                  :value="cat.key"
                >
                  {{ cat.label }}
                </option>
              </select>
            </UiField>

            <!-- Target Type -->
            <UiField label="Turi">
              <select
                v-model="bulkType"
                class="flex h-10 w-full rounded-xl border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
              >
                <option
                  v-for="tp in types.filter(t => t.key !== 'all')"
                  :key="tp.key"
                  :value="tp.key"
                >
                  {{ tp.label }}
                </option>
              </select>
            </UiField>
          </div>

          <!-- Drop Area -->
          <label class="flex flex-col items-center justify-center rounded-2xl border-2 border-dashed border-border/80 bg-muted/20 px-6 py-8 text-center transition-colors hover:border-primary/50 hover:bg-muted/40 cursor-pointer">
            <input
              type="file"
              multiple
              accept="image/png,image/jpeg,image/webp"
              class="hidden"
              :disabled="isUploading"
              @change="handleFilesSelected"
            >
            <div class="mb-3 flex size-12 items-center justify-center rounded-2xl bg-primary/10 text-primary">
              <Icon
                name="lucide:image-plus"
                class="size-6"
              />
            </div>
            <p class="text-sm font-semibold text-foreground">Bir nechta rasm yoki iconlarni tanlang</p>
            <p class="mt-1 text-xs text-muted-foreground">PNG, JPG yoki WEBP formatda. Bir vaqtning o‘zida o‘nlab fayllar</p>
          </label>

          <!-- Files Queue Grid -->
          <div
            v-if="bulkFiles.length > 0"
            class="space-y-2"
          >
            <div class="flex items-center justify-between text-xs font-semibold text-muted-foreground">
              <span>Tanlangan fayllar: {{ bulkFiles.length }} ta</span>
              <button
                type="button"
                class="text-destructive hover:underline"
                @click="bulkFiles = []"
              >
                Hammasini tozalash
              </button>
            </div>

            <div class="max-h-60 overflow-y-auto grid grid-cols-2 sm:grid-cols-4 gap-2.5 p-1 rounded-2xl border border-border/40 bg-muted/10">
              <div
                v-for="(item, idx) in bulkFiles"
                :key="idx"
                class="group relative flex flex-col items-center rounded-xl border border-border/60 bg-card p-2 shadow-2xs"
              >
                <div class="relative size-16 flex items-center justify-center overflow-hidden rounded-lg bg-muted/30">
                  <img
                    :src="item.preview"
                    class="h-full w-full object-contain"
                  >
                </div>
                <input
                  v-model="item.name"
                  type="text"
                  class="mt-1.5 w-full rounded border border-border/60 bg-background px-1 py-0.5 text-center text-[10px] text-foreground focus:border-primary"
                  placeholder="Nomi"
                >
                <button
                  type="button"
                  class="absolute -top-1.5 -right-1.5 flex size-5 items-center justify-center rounded-full bg-destructive text-white shadow-xs opacity-0 transition-opacity group-hover:opacity-100"
                  @click="removeBulkFile(idx)"
                >
                  <Icon
                    name="lucide:x"
                    class="size-3"
                  />
                </button>
              </div>
            </div>
          </div>

          <!-- Uploading Progress Bar -->
          <div
            v-if="isUploading"
            class="space-y-1.5 pt-2"
          >
            <div class="flex items-center justify-between text-xs text-muted-foreground">
              <span>Cloudflare R2 ga yuklanmoqda...</span>
              <span>{{ uploadProgress }}%</span>
            </div>
            <div class="h-2 w-full overflow-hidden rounded-full bg-muted">
              <div
                class="h-full bg-primary transition-all duration-300"
                :style="{ width: `${uploadProgress}%` }"
              />
            </div>
          </div>

          <!-- Dialog Footer -->
          <UiDialogFooter class="gap-2 pt-2">
            <UiButton
              type="button"
              variant="outline"
              class="rounded-xl text-xs"
              :disabled="isUploading"
              @click="bulkModalOpen = false"
            >
              Bekor qilish
            </UiButton>
            <UiButton
              type="button"
              class="rounded-xl text-xs font-semibold gap-1.5"
              :disabled="!bulkFiles.length || isUploading"
              @click="startBulkUpload"
            >
              <Icon
                v-if="isUploading"
                name="lucide:loader-2"
                class="h-3.5 w-3.5 animate-spin"
              />
              <Icon
                v-else
                name="lucide:check"
                class="h-3.5 w-3.5"
              />
              Hammasini saqlash ({{ bulkFiles.length }})
            </UiButton>
          </UiDialogFooter>
        </div>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
