<script setup lang="ts">
// The gallery's designs (templates) — the admin's "Galereya" page and, with
// `product`, the product's own "Galereya" tab (the same list, only that
// product's designs). A design is a ready start for customers: in the
// Studio and, when shown, on /gallery with its pictures, in this order.
// New designs are made in the Studio; the page asks for the product first.
import { getApiErrorMessage } from '~/composables/useApi';
import { DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import type { AdminTemplate, PublicProductDetail } from '~/types/catalog';
import type { TextTranslations } from '~/lib/admin/translations';
import { isTranslated, textTranslations, trimTranslations } from '~/lib/admin/translations';

const props = defineProps<{ product?: { id: number; slug: string }; search?: string; hideHeader?: boolean }>();
watch(() => props.search, (val) => {
  if (val !== undefined) search.value = val;
}, { immediate: true });

defineExpose({
  add,
});

const MAX_IMAGES = 5;
const { t } = useI18n();
const localePath = useLocalePath();

const listQuery = useAdminGalleryDesigns();
const all = computed(() => listQuery.data.value ?? []);
const items = computed(() => (props.product ? all.value.filter(i => i.product_id === props.product!.id) : all.value));
const actions = useAdminGalleryActions();
const productsQuery = useCatalogAdminList();
const products = computed(() => (productsQuery.data.value ?? []).filter(p => !p.archived));
const { upload } = useMediaUpload();
const api = useApi();

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

const studioEdit = (item: AdminTemplate) => localePath(`/studio/${item.product_slug}?template=${item.id}`);
const pictureOf = (item: AdminTemplate) => item.images[0]?.url ?? item.preview_url;

// Search over everything a row shows; dragging waits until the search is
// cleared (the order is the whole list's).
const search = ref('');
const searching = computed(() => search.value.trim() !== '');
const fold = (text: string) => text.toLowerCase().replace(/[‘’ʻʼ`']/g, '\'');
function matches(item: AdminTemplate): boolean {
  const q = fold(search.value.trim());
  if (!q) return true;
  return [item.name, item.product_name, formatDate(item.updated_at), item.in_gallery ? t('admin.gallery.published') : t('admin.gallery.publish')]
    .some(v => v != null && fold(String(v)).includes(q));
}
const noMatch = computed(() => searching.value && !items.value.some(matches));

// Insert-style drag for the table; the new order saves at once.
// On a product's tab the product's designs keep their places among the rest.
const drag = useInsertDragSort((from, to) => {
  const shown = moved(items.value.map(i => i.id), from, to);
  const mine = new Set(shown);
  let next = 0;
  const ids = all.value.map(i => (mine.has(i.id) ? shown[next++]! : i.id));
  void act(() => actions.reorder(ids), t('admin.gallery.errors.order'));
});

function togglePublished(item: AdminTemplate, value: boolean) {
  void act(() => actions.update(item.id, { in_gallery: value }), t('admin.gallery.errors.status'));
}

// ── A new design: made in the Studio ──
const newOpen = ref(false);
const newProduct = ref('');
function startNew() {
  const p = products.value.find(x => String(x.id) === newProduct.value);
  if (p) void navigateTo(localePath(`/studio/${p.slug}?as=template`), { external: true });
}
/** On a product's tab the product is known: straight to the Studio. */
function add() {
  if (props.product) void navigateTo(localePath(`/studio/${props.product.slug}?as=template`), { external: true });
  else newOpen.value = true;
}

// ── Lightbox for images ──
const lightboxItem = ref<AdminTemplate | null>(null);

/** Return the hex colour for a color_id by looking it up in the loaded colours list. */
function colourHex(colorId: number | null | undefined): string | undefined {
  if (!colorId) return undefined;
  return colours.value.find(c => c.id === colorId)?.hex;
}

// ── Editing a design's gallery card ──
const formOpen = ref(false);
const editing = ref<AdminTemplate | null>(null);
const form = reactive({ name: '', color_id: '', in_gallery: true });
const tr = ref<TextTranslations>(textTranslations(null, ['name']));
const images = ref<{ media_id: string; url: string }[]>([]);
const colours = ref<{ id: number; name: string; hex: string; variant: string }[]>([]);
const uploading = ref(false);
const show3d = ref(false); // the design turned in 3D, in the colour chosen here
const formError = ref<string | null>(null);

async function openEdit(item: AdminTemplate) {
  editing.value = item;
  Object.assign(form, { name: item.name, color_id: item.color_id ? String(item.color_id) : '', in_gallery: item.in_gallery });
  tr.value = textTranslations(item.translations, ['name']);
  images.value = item.images.map(i => ({ ...i }));
  formError.value = null;
  show3d.value = false;
  colours.value = [];
  formOpen.value = true;
  try {
    const detail = await api.get<PublicProductDetail>(`/catalog/products/${encodeURIComponent(item.product_slug)}/`);
    colours.value = detail.variants
      .filter(v => item.variant_ids.includes(v.id))
      .flatMap(v => v.colors.map(c => ({ id: c.id, name: c.name, hex: c.hex, variant: v.name })));
  }
  catch {
    // Without the list the colour stays as it is.
  }
}

function formatColourLabel(c: { name: string; variant?: string }) {
  if (!c.variant || c.variant.trim().toLowerCase() === c.name.trim().toLowerCase()) {
    return c.name;
  }
  const uniqueVariants = new Set(colours.value.map(x => x.variant?.trim().toLowerCase()).filter(Boolean));
  if (uniqueVariants.size <= 1) {
    return c.name;
  }
  return `${c.variant} · ${c.name}`;
}

async function addImages(picked: File[]) {
  const files = picked.slice(0, MAX_IMAGES - images.value.length);
  formError.value = null;
  const wrong = files.find(f => !MEDIA_IMAGE_TYPES.includes(f.type) || f.size > DESIGN_IMAGE_MAX_MB * 1024 * 1024);
  if (wrong) {
    formError.value = t('admin.gallery.errors.fileType', { name: wrong.name, mb: DESIGN_IMAGE_MAX_MB });
    return;
  }
  uploading.value = true;
  try {
    for (const file of files) {
      const blob = await resizeImageToBlob(file, 1600, 0.88, 'image/webp');
      const media = await upload(blob, 'catalog');
      images.value.push({ media_id: media.id, url: media.url });
    }
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, e instanceof Error ? e.message : t('admin.gallery.errors.upload'));
  }
  finally {
    uploading.value = false;
  }
}

// The pictures in the form, dragged into order (the first is the main one).
const imageDrag = useDragSort((from, to) => {
  images.value = moved(images.value, from, to);
});

const canSave = computed(() => !actions.busy.value && !uploading.value && form.name.trim() !== '' && isTranslated(tr.value, 'name'));

async function save() {
  if (!canSave.value || !editing.value) return;
  formError.value = null;
  try {
    await actions.update(editing.value.id, {
      name: form.name.trim(),
      translations: trimTranslations(tr.value),
      images: images.value.map(i => i.media_id),
      in_gallery: form.in_gallery,
      ...(colours.value.length ? { color_id: form.color_id ? Number(form.color_id) : null } : {}),
    });
    formOpen.value = false;
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, t('admin.gallery.errors.save'));
  }
}

const deleting = ref<AdminTemplate | null>(null);
const deleteOpen = computed({
  get: () => deleting.value !== null,
  set: (open: boolean) => {
    if (!open) deleting.value = null;
  },
});
async function confirmDelete() {
  const item = deleting.value;
  if (!item) return;
  await act(() => actions.remove(item.id), t('admin.gallery.errors.delete'));
  deleting.value = null;
}
</script>

<template>
  <div class="space-y-4">
    <AdminPageHeader
      v-if="!hideHeader"
      v-model:search="search"
      :placeholder="t('admin.gallery.searchPlaceholder')"
      :refreshing="listQuery.isFetching.value"
      @refresh="listQuery.refetch()"
    >
      <template #actions>
        <UiButton
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          :title="t('admin.gallery.add')"
          @click="add"
        >
          <Icon
            name="lucide:image"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiAlert
      v-if="error || listQuery.isError.value"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ error ?? t('admin.gallery.errors.load') }}
    </UiAlert>

    <!-- ── Loading skeleton ── -->
    <div
      v-if="listQuery.isLoading.value"
      class="w-full rounded-2xl border border-border bg-card shadow-xs [overflow:visible]"
    >
      <div class="flex h-11 items-center border-b border-border bg-muted/30 px-4 gap-4">
        <UiSkeleton class="h-3 w-8" />
        <UiSkeleton class="h-3 w-40" />
        <UiSkeleton class="ml-auto h-3 w-24" />
        <UiSkeleton class="h-3 w-20" />
      </div>
      <div
        v-for="i in 5"
        :key="i"
        class="flex items-center gap-4 border-b border-border px-4 py-3 last:border-b-0"
      >
        <UiSkeleton class="size-4 rounded" />
        <UiSkeleton class="size-10 rounded-lg shrink-0" />
        <div class="flex-1 space-y-1.5">
          <UiSkeleton class="h-3.5 w-1/3" />
          <UiSkeleton class="h-3 w-1/5" />
        </div>
        <UiSkeleton class="h-3 w-16" />
        <UiSkeleton class="h-3 w-12" />
        <UiSkeleton class="h-5 w-9 rounded-full" />
        <UiSkeleton class="size-7 rounded-md" />
      </div>
    </div>

    <!-- ── Empty state ── -->
    <EmptyState
      v-else-if="!items.length && !listQuery.isError.value"
      icon="lucide:images"
      :title="t('admin.gallery.empty')"
    >
      <UiButton @click="add">
        <Icon name="lucide:plus" />
        {{ t('admin.gallery.add') }}
      </UiButton>
    </EmptyState>

    <!-- ── Table ── -->
    <div
      v-else-if="items.length"
      class="w-full rounded-2xl border border-border bg-card shadow-xs [overflow:visible]"
    >
      <!-- header -->
      <div class="grid items-center border-b border-border bg-muted/30 rounded-t-2xl"
           style="grid-template-columns: 28px 48px 1fr 80px 80px 64px 80px">
        <div />
        <div />
        <div class="px-4 py-2.5 text-xs font-semibold text-foreground">{{ t('admin.gallery.col.design') }}</div>
        <div class="px-2 py-2.5 text-xs font-semibold text-foreground hidden sm:block">{{ t('admin.gallery.col.images') }}</div>
        <div class="px-2 py-2.5 text-xs font-semibold text-foreground hidden md:block">{{ t('admin.gallery.col.colour') }}</div>
        <div class="px-2 py-2.5 text-xs font-semibold text-foreground">{{ t('admin.gallery.col.status') }}</div>
        <div class="px-2 py-2.5 text-xs font-semibold text-foreground" />
      </div>

      <!-- rows -->
      <div
        v-for="(item, i) in items"
        :key="item.id"
        v-show="matches(item)"
        :ref="drag.register(i)"
        class="grid items-center border-b border-border last:border-b-0 transition-colors hover:bg-muted/40"
        :class="drag.rowClass(i)"
        :style="drag.rowStyle(i)"
        style="grid-template-columns: 28px 48px 1fr 80px 80px 64px 80px"
      >
        <!-- drag handle -->
        <button
          type="button"
          class="flex h-full w-full cursor-grab touch-none items-center justify-center text-muted-foreground hover:text-foreground active:cursor-grabbing disabled:opacity-30"
          :aria-label="t('admin.gallery.dragToSort')"
          :disabled="actions.busy.value || searching"
          @pointerdown="drag.start($event, i)"
        >
          <Icon name="lucide:grip-vertical" class="size-4" />
        </button>

        <!-- thumbnail (click → lightbox) -->
        <button
          type="button"
          class="flex items-center justify-center py-2 pl-1 pr-2"
          :aria-label="t('admin.gallery.viewImages')"
          @click="lightboxItem = item"
        >
          <span class="relative">
            <MediaThumb
              :src="pictureOf(item)"
              :alt="item.name"
              class="size-10 rounded-lg border border-border"
            />
            <span
              v-if="item.images.length > 1"
              class="absolute -bottom-1 -right-1 rounded bg-foreground px-1 text-[10px] font-semibold leading-4 text-background tabular-nums"
            >{{ item.images.length }}</span>
          </span>
        </button>

        <!-- name + product (click → edit) -->
        <button
          type="button"
          class="flex min-w-0 flex-col items-start justify-center gap-0.5 px-4 py-3 text-left cursor-pointer"
          @click="openEdit(item)"
        >
          <span class="block truncate w-full font-semibold text-sm text-foreground">{{ item.name }}</span>
          <span class="block truncate w-full text-xs text-muted-foreground">{{ item.product_name }}</span>
        </button>

        <!-- image count -->
        <div class="hidden sm:flex items-center px-2 py-3">
          <span class="inline-flex items-center gap-1 rounded-md bg-muted px-2 py-0.5 text-xs text-muted-foreground">
            <Icon name="lucide:images" class="size-3 shrink-0" />
            {{ item.images.length }}
          </span>
        </div>

        <!-- colour dot -->
        <div class="hidden md:flex items-center px-2 py-3">
          <span
            v-if="item.color_id"
            class="size-4 rounded-full border border-border shrink-0"
            :style="{ backgroundColor: colourHex(item.color_id) }"
          />
          <span v-else class="text-xs text-muted-foreground">—</span>
        </div>

        <!-- published toggle -->
        <div
          class="flex items-center px-2 py-3"
          @click.stop
        >
          <UiSwitch
            :model-value="item.in_gallery"
            :disabled="actions.busy.value"
            @update:model-value="togglePublished(item, $event)"
          />
        </div>

        <!-- actions -->
        <div
          class="flex items-center justify-end gap-0.5 px-2 py-3"
          @click.stop
        >
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton as-child size="icon-sm" variant="ghost">
                <a :href="studioEdit(item)" :aria-label="t('admin.gallery.editInStudio')">
                  <Icon name="lucide:palette" class="text-base" />
                </a>
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.gallery.editInStudio') }}</UiTooltipContent>
          </UiTooltip>
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="ghost"
                class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                :aria-label="t('admin.common.delete')"
                @click="deleting = item"
              >
                <Icon name="lucide:trash-2" class="text-base" />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.common.delete') }}</UiTooltipContent>
          </UiTooltip>
        </div>
      </div>
    </div>

    <p
      v-if="noMatch"
      class="rounded-2xl border border-dashed border-border p-6 text-center text-sm text-muted-foreground"
    >
      {{ t('admin.gallery.noMatch') }}
    </p>

    <!-- ── Image lightbox ── -->
    <UiDialog :open="!!lightboxItem" @update:open="(v) => { if (!v) lightboxItem = null; }">
      <UiDialogContent class="max-h-[92dvh] overflow-y-auto sm:max-w-xl">
        <UiDialogHeader>
          <UiDialogTitle>{{ lightboxItem?.name }}</UiDialogTitle>
        </UiDialogHeader>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <div
            v-for="(img, idx) in lightboxItem?.images ?? []"
            :key="img.media_id"
            class="relative aspect-square overflow-hidden rounded-xl border border-border"
          >
            <MediaThumb :src="img.url" class="size-full object-cover" />
            <span
              v-if="idx === 0"
              class="absolute left-1.5 top-1.5 rounded bg-primary px-1.5 text-[10px] font-semibold leading-4 text-primary-foreground"
            >{{ t('admin.gallery.main') }}</span>
          </div>
        </div>
        <UiDialogFooter class="mt-2">
          <UiButton variant="outline" @click="lightboxItem = null">{{ t('admin.common.close') }}</UiButton>
          <UiButton v-if="lightboxItem" @click="openEdit(lightboxItem); lightboxItem = null">
            <Icon name="lucide:pencil" />
            {{ t('admin.common.edit') }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>

    <UiDialog v-model:open="formOpen">

      <UiDialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
        <UiDialogHeader>
          <UiDialogTitle>
            {{ editing?.name || t('admin.gallery.design') }}
          </UiDialogTitle>
        </UiDialogHeader>

        <form
          class="space-y-4"
          @submit.prevent="save"
        >

          <div
            v-if="editing"
            class="relative aspect-square w-full overflow-hidden rounded-xl border border-border bg-white"
          >
            <ClientOnly v-if="show3d">
              <GalleryModel
                :slug="editing.product_slug"
                :variant-id="editing.variant_ids[0] ?? null"
                :color-id="form.color_id ? Number(form.color_id) : null"
                :document="editing.document"
              />
            </ClientOnly>
            <MediaThumb
              v-else
              :src="images[0]?.url ?? editing.preview_url"
              class="size-full"
            />
            <UiButton
              type="button"
              :variant="show3d ? 'default' : 'outline'"
              size="sm"
              class="absolute bottom-2 right-2 z-10"
              :aria-pressed="show3d"
              @click="show3d = !show3d"
            >
              <Icon :name="show3d ? 'lucide:image' : 'lucide:rotate-3d'" />
              {{ show3d ? t('admin.gallery.picture') : '3D' }}
            </UiButton>
          </div>

          <UiField :label="t('admin.gallery.pictures', { count: images.length, max: MAX_IMAGES })">
            <div class="grid grid-cols-5 gap-2">
              <div
                v-for="(img, i) in images"
                :key="img.media_id"
                :ref="imageDrag.register(i)"
                class="group relative aspect-square cursor-grab touch-none rounded-lg transition-shadow active:cursor-grabbing"
                :class="imageDrag.itemClass(i)"
                :style="imageDrag.itemStyle(i)"
                @pointerdown="imageDrag.start($event, i)"
              >
                <MediaThumb
                  :src="img.url"
                  class="pointer-events-none size-full border border-border"
                />
                <span
                  v-if="i === 0"
                  class="absolute left-1 top-1 rounded bg-primary px-1 text-[10px] font-semibold leading-4 text-primary-foreground"
                >{{ t('admin.gallery.main') }}</span>
                <UiButton
                  type="button"
                  size="icon-xs"
                  :aria-label="t('admin.gallery.removePicture')"
                  class="absolute right-1 top-1 size-5 rounded-full bg-foreground text-background hover:bg-foreground/80"
                  @click="images.splice(i, 1)"
                >
                  <Icon
                    name="lucide:x"
                    class="text-xs"
                  />
                </UiButton>
              </div>
              <UiFileInput
                v-if="images.length < MAX_IMAGES"
                accept="image/png,image/jpeg,image/webp"
                multiple
                :disabled="uploading"
                class="aspect-square size-auto w-full p-0"
                :aria-label="t('admin.gallery.addPicture')"
                @select="addImages"
              >
                <Icon
                  :name="uploading ? 'lucide:loader-circle' : 'lucide:image-plus'"
                  class="text-xl"
                  :class="{ 'animate-spin': uploading }"
                />
              </UiFileInput>
            </div>
          </UiField>

          <TranslatableInput
            id="design-name"
            v-model="form.name"
            v-model:translations="tr"
            field="name"
            :label="t('admin.common.name')"
            maxlength="120"
            required
          />

          <UiField
            v-if="colours.length"
            :label="t('admin.gallery.shownColour')"
            for="design-colour"
          >
            <UiSelect v-model="form.color_id">
              <UiSelectTrigger
                id="design-colour"
                class="w-full"
              >
                <UiSelectValue :placeholder="t('admin.gallery.firstColour')" />
              </UiSelectTrigger>
              <UiSelectContent position="popper">
                <UiSelectItem
                  v-for="c in colours"
                  :key="c.id"
                  :value="String(c.id)"
                >
                  <span class="flex items-center gap-2">
                    <span
                      class="size-4 rounded-full border border-border"
                      :style="{ backgroundColor: c.hex }"
                    />
                    {{ formatColourLabel(c) }}
                  </span>
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <label class="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-border p-3 text-sm font-medium">
            {{ t('admin.gallery.publish') }}
            <UiSwitch v-model="form.in_gallery" />
          </label>

          <UiAlert
            v-if="formError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ formError }}
          </UiAlert>
          <UiDialogFooter class="sm:justify-between">
            <UiButton
              v-if="editing"
              as-child
              variant="ghost"
            >
              <a :href="studioEdit(editing)">
                <Icon
                  name="lucide:palette"
                  class="text-base"
                />
                {{ t('admin.gallery.editDesign') }}
              </a>
            </UiButton>
            <div class="flex gap-2">
              <UiButton
                type="button"
                variant="outline"
                @click="formOpen = false"
              >
                {{ t('admin.common.cancel') }}
              </UiButton>
              <UiButton
                type="submit"
                :disabled="!canSave"
              >
                <Icon
                  v-if="actions.busy.value"
                  name="lucide:loader-2"
                  class="animate-spin text-base"
                />
                {{ t('admin.common.save') }}
              </UiButton>
            </div>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>

    <UiDialog v-model:open="newOpen">
      <UiDialogContent class="sm:max-w-sm">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.gallery.add') }}</UiDialogTitle>
        </UiDialogHeader>
        <UiField
          :label="t('admin.gallery.product')"
          for="new-design-product"
        >
          <UiSelect v-model="newProduct">
            <UiSelectTrigger
              id="new-design-product"
              class="w-full"
            >
              <UiSelectValue :placeholder="t('admin.gallery.chooseProduct')" />
            </UiSelectTrigger>
            <UiSelectContent position="popper">
              <UiSelectItem
                v-for="p in products"
                :key="p.id"
                :value="String(p.id)"
              >
                {{ p.name }}
              </UiSelectItem>
            </UiSelectContent>
          </UiSelect>
        </UiField>
        <UiDialogFooter>
          <UiButton
            :disabled="!newProduct"
            @click="startNew"
          >
            <Icon
              name="lucide:palette"
              class="text-base"
            />
            {{ t('admin.gallery.createInStudio') }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>

    <UiAlertDialog v-model:open="deleteOpen">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.gallery.deleteTitle') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>
            {{ t('admin.common.cancel') }}
          </UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="actions.busy.value"
            @click="confirmDelete"
          >
            <Icon
              v-if="actions.busy.value"
              name="lucide:loader-2"
              class="animate-spin text-base"
            />
            {{ t('admin.common.delete') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
