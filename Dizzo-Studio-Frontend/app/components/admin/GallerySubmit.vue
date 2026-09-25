<script setup lang="ts">
import { getApiErrorMessage } from '~/composables/useApi';
import { useBranchProducts } from '~/composables/queries/useBranches';
import { useAdminShowcases, useSubmitShowcase, type GalleryShowcase } from '~/composables/queries/useAdminShowcases';
import { DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES, useMediaUpload } from '~/composables/useMediaUpload';
import { resizeImageToBlob } from '~/composables/useImageResize';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';

const MAX_IMAGES = 5;

const props = defineProps<{ search?: string }>();

const { t } = useI18n();
const roles = useCurrentUserRoles();
const branchId = computed(() => roles.value.branchId);
const { data: items, isLoading, isError, refetch } = useAdminShowcases();
const { data: products } = useBranchProducts(branchId);
const submitMutation = useSubmitShowcase();
const { upload } = useMediaUpload();

const filtered = computed(() => {
  const rows = items.value ?? [];
  const q = (props.search ?? '').trim().toLowerCase();
  if (!q) return rows;
  return rows.filter(row =>
    [row.title, row.product_name, row.customer_name, row.status].some(v => (v || '').toLowerCase().includes(q)),
  );
});

const columns = computed<DataTableColumn[]>(() => [
  { key: 'item', header: t('admin.gallery.col.design') },
  { key: 'product', header: t('admin.gallery.product'), className: 'hidden sm:table-cell' },
  { key: 'status', header: t('admin.gallery.col.status') },
]);

function statusMeta(status: string) {
  if (status === 'APPROVED') return { label: t('admin.gallery.approved'), tone: 'success' as const };
  if (status === 'REJECTED') return { label: t('admin.gallery.rejected'), tone: 'danger' as const };
  return { label: t('admin.gallery.pending'), tone: 'warn' as const };
}

const dialogOpen = ref(false);
const formError = ref<string | null>(null);
const uploading = ref(false);
const productId = ref('');
const title = ref('');
const customerName = ref('');
const images = ref<Array<{ media_id: string; url: string }>>([]);

function openNew() {
  productId.value = products.value?.[0] ? String(products.value[0].product_id) : '';
  title.value = '';
  customerName.value = '';
  images.value = [];
  formError.value = null;
  dialogOpen.value = true;
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
    formError.value = getApiErrorMessage(e, t('admin.gallery.errors.upload'));
  }
  finally {
    uploading.value = false;
  }
}

const canSend = computed(() => Boolean(productId.value) && images.value.length >= 1 && !uploading.value && !submitMutation.isPending.value);

async function send() {
  if (!canSend.value) return;
  formError.value = null;
  try {
    await submitMutation.mutateAsync({
      product_id: Number(productId.value),
      media_ids: images.value.map(i => i.media_id),
      title: title.value.trim() || null,
      customer_name: customerName.value.trim() || null,
    });
    dialogOpen.value = false;
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, t('admin.gallery.submitFailed'));
  }
}

defineExpose({ add: openNew });
</script>

<template>
  <div class="space-y-4">
    <EmptyState
      v-if="isError && !items"
      :title="t('admin.gallery.errors.load')"
      icon="lucide:circle-alert"
      tone="destructive"
    >
      <UiButton
        variant="outline"
        size="sm"
        @click="refetch()"
      >
        {{ t('admin.common.retry') }}
      </UiButton>
    </EmptyState>

    <template v-else>
      <UiDataTable
        :columns="columns"
        :data="filtered"
        :is-loading="isLoading"
        :row-key="(row: GalleryShowcase) => row.id"
        :empty-text="props.search ? t('admin.gallery.noMatch') : t('admin.gallery.emptySubmit')"
        empty-icon="lucide:images"
      >
        <template #cell-item="{ row }">
          <div class="flex items-center gap-2.5">
            <div class="flex size-10 shrink-0 overflow-hidden rounded-lg border border-border bg-muted/20">
              <img
                v-if="row.images[0]"
                :src="row.images[0].url"
                alt=""
                class="size-full object-cover"
              >
            </div>
            <div class="min-w-0">
              <div class="truncate font-semibold text-foreground">
                {{ row.title || row.product_name }}
              </div>
              <div
                v-if="row.customer_name"
                class="truncate text-xs text-muted-foreground"
              >
                {{ row.customer_name }}
              </div>
            </div>
          </div>
        </template>
        <template #cell-product="{ row }">
          <span class="text-sm text-muted-foreground">{{ row.product_name }}</span>
        </template>
        <template #cell-status="{ row }">
          <div class="space-y-1">
            <UiStatusBadge :tone="statusMeta(row.status).tone">
              {{ statusMeta(row.status).label }}
            </UiStatusBadge>
            <p
              v-if="row.status === 'REJECTED' && row.rejection_reason"
              class="max-w-xs text-xs text-destructive"
            >
              {{ row.rejection_reason }}
            </p>
          </div>
        </template>
      </UiDataTable>
    </template>

    <UiDialog v-model:open="dialogOpen">
      <UiDialogContent class="sm:max-w-lg">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.gallery.submitTitle') }}</UiDialogTitle>
        </UiDialogHeader>
        <p class="text-sm text-muted-foreground">
          {{ t('admin.gallery.submitHint') }}
        </p>
        <form
          class="space-y-4"
          @submit.prevent="send"
        >
          <UiField :label="t('admin.gallery.product')">
            <UiSelect v-model="productId">
              <UiSelectTrigger>
                <UiSelectValue :placeholder="t('admin.gallery.chooseProduct')" />
              </UiSelectTrigger>
              <UiSelectContent>
                <UiSelectItem
                  v-for="p in products ?? []"
                  :key="p.product_id"
                  :value="String(p.product_id)"
                >
                  {{ p.product_name }}
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <UiField :label="t('admin.gallery.submitCaption')">
            <UiInput
              v-model="title"
              :placeholder="t('admin.gallery.submitCaptionPlaceholder')"
            />
          </UiField>

          <UiField :label="t('admin.gallery.customerName')">
            <UiInput
              v-model="customerName"
              :placeholder="t('admin.gallery.customerNamePlaceholder')"
            />
          </UiField>

          <UiField :label="t('admin.gallery.pictures', { count: images.length, max: MAX_IMAGES })">
            <div class="flex flex-wrap gap-2">
              <div
                v-for="(img, index) in images"
                :key="img.media_id"
                class="relative size-16 overflow-hidden rounded-lg border border-border"
              >
                <img
                  :src="img.url"
                  alt=""
                  class="size-full object-cover"
                >
                <button
                  type="button"
                  class="absolute right-0.5 top-0.5 rounded-md bg-black/60 p-0.5 text-white"
                  :aria-label="t('admin.gallery.removePicture')"
                  @click="images.splice(index, 1)"
                >
                  <Icon
                    name="lucide:x"
                    class="size-3"
                  />
                </button>
              </div>
              <label
                v-if="images.length < MAX_IMAGES"
                class="flex size-16 cursor-pointer items-center justify-center rounded-lg border border-dashed border-border text-muted-foreground hover:bg-muted/40"
              >
                <Icon
                  v-if="uploading"
                  name="lucide:loader-2"
                  class="size-5 animate-spin"
                />
                <Icon
                  v-else
                  name="lucide:plus"
                  class="size-5"
                />
                <input
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  multiple
                  class="hidden"
                  :disabled="uploading"
                  @change="addImages(Array.from(($event.target as HTMLInputElement).files ?? [])); ($event.target as HTMLInputElement).value = ''"
                >
              </label>
            </div>
          </UiField>

          <UiAlert
            v-if="formError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            <UiAlertDescription>{{ formError }}</UiAlertDescription>
          </UiAlert>

          <UiDialogFooter>
            <UiButton
              type="button"
              variant="outline"
              @click="dialogOpen = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="!canSend"
            >
              <Icon
                v-if="submitMutation.isPending.value"
                name="lucide:loader-2"
                class="mr-2 size-4 animate-spin"
              />
              {{ t('admin.gallery.submit') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
