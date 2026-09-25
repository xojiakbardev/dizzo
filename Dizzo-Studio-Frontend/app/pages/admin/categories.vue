<script setup lang="ts">
// Storefront shelves ("Idish-tovoq", "Kiyim"…): name, an SVG icon or a
// picture, the order they're listed in, and whether they show. Products
// pick their shelf on their "Asosiy" tab.
import { getApiErrorMessage } from '~/composables/useApi';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { CategoryForm } from '~/composables/queries/useCatalogAdmin';
import type { AdminCategory } from '~/types/catalog';
import { isTranslated, textTranslations, trimTranslations } from '~/lib/admin/translations';

definePageMeta({ layout: 'admin' });
const { t } = useI18n();
useHead({ title: () => t('admin.categories.title') });

const SLUG_MAX = 40;

const route = useRoute();
const router = useRouter();

const shelves = useAdminCategories();
const { create, update, remove, busy } = useAdminCategoryActions();
const { upload } = useMediaUpload();

const search = ref((route.query.search as string) || '');
watch(search, (val) => {
  const query: Record<string, string | undefined> = {};
  if (val.trim()) query.search = val.trim();
  router.replace({ query });
});
const rows = computed(() => {
  const q = search.value.trim().toLowerCase();
  return (shelves.data.value ?? []).filter(c => !q || `${c.name} ${c.slug}`.toLowerCase().includes(q));
});

const columns = computed<DataTableColumn[]>(() => [
  { key: 'icon', header: '', width: '64px' },
  { key: 'name', header: t('admin.categories.col.category') },
  { key: 'slug', header: t('admin.categories.col.slug'), className: 'hidden md:table-cell' },
  { key: 'products', header: t('admin.categories.col.products'), className: 'hidden sm:table-cell', width: '130px' },
  { key: 'order', header: t('admin.categories.col.order'), className: 'hidden lg:table-cell', width: '90px' },
  { key: 'status', header: t('admin.categories.col.visible'), width: '100px' },
  { key: 'actions', header: '', width: '96px' },
]);

// ── Create / edit ──
const open = ref(false);
const editing = ref<AdminCategory | null>(null);
const form = reactive<Omit<CategoryForm, 'slug' | 'translations'>>({ name: '', icon_svg: '', image_media_id: null, sort_order: 0, is_active: true });
// The name in Russian and English; Uzbek is form.name.
const nameTr = ref(textTranslations(null, ['name']));
const { slug, onInput: onSlugInput, reset: resetSlug, save: saveWithSlug } = useSlugField({
  source: () => form.name,
  taken: () => (shelves.data.value ?? []).filter(c => c.id !== editing.value?.id).map(c => c.slug),
  maxLength: SLUG_MAX,
});
const imageUrl = ref<string | null>(null);
const formError = ref<string | null>(null);
const uploading = ref(false);
const picker = ref<{ open: () => void } | null>(null);

/** What the tile shows: the picture wins over the icon, as on the storefront. */
const visual = computed(() => (imageUrl.value ? 'image' : form.icon_svg.trim() ? 'svg' : null));

function startCreate() {
  editing.value = null;
  Object.assign(form, {
    name: '', icon_svg: '', image_media_id: null, is_active: true,
    sort_order: Math.max(0, ...(shelves.data.value ?? []).map(c => c.sort_order)) + 10,
  });
  nameTr.value = textTranslations(null, ['name']);
  resetSlug();
  imageUrl.value = null;
  formError.value = null;
  open.value = true;
}

function startEdit(c: AdminCategory) {
  editing.value = c;
  Object.assign(form, {
    name: c.name, icon_svg: c.icon_svg, image_media_id: c.image_media_id, sort_order: c.sort_order, is_active: c.is_active,
  });
  nameTr.value = textTranslations(c.translations, ['name']);
  resetSlug(c.slug);
  imageUrl.value = c.image_url;
  formError.value = null;
  open.value = true;
}

/** An .svg becomes the icon; any other picture is uploaded. Either replaces the other. */
async function pickFile(files: File[]) {
  const file = files[0];
  if (!file) return;
  formError.value = null;
  if (file.type === 'image/svg+xml' || file.name.toLowerCase().endsWith('.svg')) {
    const text = await file.text();
    if (!/<svg[\s>]/i.test(text)) {
      formError.value = t('admin.categories.notSvg');
      return;
    }
    form.icon_svg = text.replace(/<\?xml[^>]*>/i, '').replace(/<!--[\s\S]*?-->/g, '').trim();
    form.image_media_id = null;
    imageUrl.value = null;
    return;
  }
  uploading.value = true;
  try {
    const media = await upload(file, 'catalog');
    form.image_media_id = media.id;
    imageUrl.value = media.url;
    form.icon_svg = '';
  }
  catch (err) {
    formError.value = getApiErrorMessage(err, t('admin.categories.uploadFailed'));
  }
  finally {
    uploading.value = false;
  }
}

function clearVisual() {
  form.image_media_id = null;
  form.icon_svg = '';
  imageUrl.value = null;
}

async function save() {
  formError.value = null;
  if (!form.name.trim() || !slug.value) {
    formError.value = t('admin.categories.needNameSlug');
    return;
  }
  if (!isTranslated(nameTr.value, 'name')) {
    formError.value = t('admin.translate.required.both');
    return;
  }
  try {
    const body = { ...form, name: form.name.trim(), sort_order: Number(form.sort_order) || 0, translations: trimTranslations(nameTr.value) };
    if (editing.value) await update(editing.value.id, { ...body, slug: slug.value });
    else await saveWithSlug(s => create({ ...body, slug: s }));
    open.value = false;
  }
  catch (err) {
    formError.value = getApiErrorMessage(err, t('admin.common.saveFailed'));
  }
}

async function toggleActive(c: AdminCategory, on: boolean) {
  try {
    await update(c.id, { is_active: on });
  }
  catch (err) {
    listError.value = getApiErrorMessage(err, t('admin.categories.toggleFailed'));
  }
}

// ── Delete ──
const deleting = ref<AdminCategory | null>(null);
const listError = ref<string | null>(null);
async function confirmDelete() {
  const c = deleting.value;
  if (!c) return;
  listError.value = null;
  try {
    await remove(c.id);
    deleting.value = null;
  }
  catch (err) {
    deleting.value = null;
    listError.value = getApiErrorMessage(err, t('admin.common.deleteFailed'));
  }
}
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      :placeholder="t('admin.categories.searchPlaceholder')"
      :refreshing="shelves.isFetching.value"
      @refresh="shelves.refetch()"
    >
      <template #actions>
        <UiButton
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          :title="t('admin.categories.new')"
          @click="startCreate"
        >
          <Icon
            name="lucide:folder"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiAlert
      v-if="listError || shelves.isError.value"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ listError ?? t('admin.categories.listFailed') }}
    </UiAlert>

    <UiDataTable
      :columns="columns"
      :data="rows"
      :is-loading="shelves.isLoading.value"
      :row-key="(row: AdminCategory) => row.id"
      clickable
      :empty-text="search ? t('admin.products.nothingFound') : t('admin.categories.empty')"
      empty-icon="lucide:folder-tree"
      @row-click="startEdit"
    >
      <template #cell-icon="{ row }">
        <span class="flex size-10 items-center justify-center rounded-xl bg-muted text-xl text-foreground">
          <CategoryIcon
            :svg="row.icon_svg"
            :image="row.image_url"
          />
        </span>
      </template>
      <template #cell-name="{ row }">
        <span class="font-semibold text-foreground">{{ row.name }}</span>
      </template>
      <template #cell-slug="{ row }">
        <span class="font-mono text-xs text-muted-foreground">{{ row.slug }}</span>
      </template>
      <template #cell-products="{ row }">
        <span class="text-sm tabular-nums text-muted-foreground">{{ t('admin.products.count', { n: row.product_count }) }}</span>
      </template>
      <template #cell-order="{ row }">
        <span class="text-sm tabular-nums text-muted-foreground">{{ row.sort_order }}</span>
      </template>
      <template #cell-status="{ row }">
        <div
          class="flex items-center"
          @click.stop
        >
          <UiSwitch
            :model-value="row.is_active"
            :disabled="busy"
            :aria-label="t('admin.categories.showInStore', { name: row.name })"
            @update:model-value="(on: boolean) => toggleActive(row, on)"
          />
        </div>
      </template>
      <template #cell-actions="{ row }">
        <div
          class="flex justify-end gap-1"
          @click.stop
        >
          <UiButton
            variant="ghost"
            size="icon-sm"
            class="text-destructive hover:bg-destructive/10 hover:text-destructive"
            :aria-label="t('admin.categories.deleteNamed', { name: row.name })"
            @click="deleting = row"
          >
            <Icon name="lucide:trash-2" />
          </UiButton>
        </div>
      </template>
    </UiDataTable>

    <UiDialog v-model:open="open">
      <UiDialogContent class="sm:max-w-lg">
        <UiDialogHeader>
          <UiDialogTitle>{{ editing ? t('admin.categories.edit') : t('admin.categories.new') }}</UiDialogTitle>
          <UiDialogDescription class="sr-only">
            {{ t('admin.categories.dialogDescription') }}
          </UiDialogDescription>
        </UiDialogHeader>
        <form
          class="grid gap-4"
          @submit.prevent="save"
        >
          <TranslatableInput
            id="cat-name"
            v-model="form.name"
            v-model:translations="nameTr"
            field="name"
            :label="t('admin.common.name')"
            :placeholder="t('admin.categories.namePlaceholder')"
            maxlength="80"
            required
          />
          <div class="grid gap-4 sm:grid-cols-2">
            <UiField
              :label="t('admin.categories.col.slug')"
              for="cat-slug"
            >
              <UiInput
                id="cat-slug"
                v-model="slug"
                placeholder="idish-tovoq"
                :maxlength="SLUG_MAX"
                class="font-mono"
                @input="onSlugInput"
              />
            </UiField>
            <UiField
              :label="t('admin.categories.col.order')"
              for="cat-order"
            >
              <UiInput
                id="cat-order"
                v-model.number="form.sort_order"
                type="number"
                min="0"
              />
            </UiField>
          </div>

          <UiField :label="t('admin.categories.visual')">
            <div class="flex items-center gap-4">
              <UiFileInput
                ref="picker"
                accept=".svg,image/svg+xml,image/png,image/jpeg,image/webp"
                class="size-20 shrink-0 rounded-2xl p-0 text-4xl text-foreground"
                :disabled="uploading"
                :aria-label="t('admin.categories.pickVisual')"
                @select="pickFile"
              >
                <Icon
                  v-if="uploading"
                  name="lucide:loader-circle"
                  class="animate-spin text-xl text-muted-foreground"
                />
                <CategoryIcon
                  v-else-if="visual"
                  :svg="form.icon_svg"
                  :image="imageUrl"
                />
                <Icon
                  v-else
                  name="lucide:image-up"
                  class="text-xl text-muted-foreground"
                />
              </UiFileInput>
              <div class="flex min-w-0 flex-col gap-2">
                <span class="text-sm font-medium text-foreground">
                  {{ uploading ? t('admin.categories.uploading') : visual === 'svg' ? t('admin.categories.svgIcon') : visual === 'image' ? t('admin.categories.image') : t('admin.categories.formats') }}
                </span>
                <div class="flex flex-wrap gap-2">
                  <UiButton
                    type="button"
                    variant="outline"
                    size="sm"
                    :disabled="uploading"
                    @click="picker?.open()"
                  >
                    <Icon
                      :name="visual ? 'lucide:replace' : 'lucide:upload'"
                      class="text-sm"
                    />
                    {{ visual ? t('admin.categories.replace') : t('admin.categories.upload') }}
                  </UiButton>
                  <UiButton
                    v-if="visual"
                    type="button"
                    variant="ghost"
                    size="sm"
                    class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                    :disabled="uploading"
                    @click="clearVisual"
                  >
                    <Icon
                      name="lucide:trash-2"
                      class="text-sm"
                    />
                    {{ t('admin.common.delete') }}
                  </UiButton>
                </div>
              </div>
            </div>
          </UiField>

          <UiLabel class="flex items-center justify-between gap-3 rounded-xl border border-border px-4 py-2.5 text-sm font-medium">
            {{ t('admin.categories.visibleInStore') }}
            <UiSwitch v-model="form.is_active" />
          </UiLabel>

          <UiAlert
            v-if="formError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ formError }}
          </UiAlert>

          <UiDialogFooter>
            <UiButton
              type="button"
              variant="outline"
              @click="open = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="busy || uploading"
            >
              {{ busy ? t('admin.categories.saving') : t('admin.common.save') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>

    <UiAlertDialog
      :open="deleting !== null"
      @update:open="(v: boolean) => { if (!v) deleting = null; }"
    >
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.categories.deleteConfirm', { name: deleting?.name ?? '' }) }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>{{ t('admin.common.cancel') }}</UiAlertDialogCancel>
          <UiAlertDialogAction
            :disabled="busy || Boolean(deleting?.product_count)"
            @click="confirmDelete"
          >
            {{ t('admin.common.delete') }}
          </UiAlertDialogAction>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
