<script setup lang="ts">
// Moderation of "Mijozlarimiz": customers' reviews wait here until approved;
// a review sent over Telegram/Instagram can be entered by hand (with the
// customer's consent) and goes live at once.
import { getApiErrorMessage } from '~/composables/useApi';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import { DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import type { Review, ReviewStatus } from '~/composables/queries/useReviews';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();

const MAX_PHOTOS = 6;
const PER_PAGE = 20;
const NO_PRODUCT = 'none';
const FILTERS = computed<{ value: ReviewStatus | null; label: string }[]>(() => [
  { value: 'pending', label: t('admin.reviews.filters.pending') },
  { value: 'approved', label: t('admin.reviews.filters.approved') },
  { value: 'rejected', label: t('admin.reviews.filters.rejected') },
  { value: null, label: t('admin.common.all') },
]);
const TONES = { pending: 'warn', approved: 'success', rejected: 'neutral' } as const;

const route = useRoute();
const router = useRouter();

const filter = ref<ReviewStatus | null>(
  route.query.filter === 'all' ? null : ((route.query.filter as ReviewStatus) || 'pending'),
);
const listQuery = useAdminReviews(filter);
const search = ref((route.query.search as string) || '');
const reviews = computed(() => {
  let list = listQuery.data.value ?? [];
  if (search.value.trim()) {
    const q = search.value.trim().toLowerCase();
    list = list.filter(r =>
      (r.name && r.name.toLowerCase().includes(q))
      || (r.text && r.text.toLowerCase().includes(q))
      || (r.product_name && r.product_name.toLowerCase().includes(q))
      || (r.city && r.city.toLowerCase().includes(q)),
    );
  }
  return list;
});
const page = ref(Number(route.query.page) || 1);
const totalPages = computed(() => Math.ceil(reviews.value.length / PER_PAGE) || 1);
const pageRows = computed(() => reviews.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE));

watch([filter, search, page], () => {
  const query: Record<string, string | undefined> = {};
  if (filter.value) query.filter = filter.value;
  else query.filter = 'all';
  if (search.value.trim()) query.search = search.value.trim();
  if (page.value > 1) query.page = String(page.value);
  router.replace({ query });
});

watch([filter, search], () => {
  page.value = 1;
});
function setFilter(value: string | number) {
  const option = FILTERS.value.find(f => (f.value ?? 'all') === value);
  if (option) filter.value = option.value;
}

const columns = computed<DataTableColumn[]>(() => [
  { key: 'customer', header: t('admin.reviews.columns.customer') },
  { key: 'city', header: t('admin.reviews.columns.city'), className: 'hidden 2xl:table-cell' },
  { key: 'rating', header: t('admin.reviews.columns.rating'), className: 'hidden sm:table-cell' },
  { key: 'text', header: t('admin.reviews.columns.text') },
  { key: 'photos', header: t('admin.reviews.columns.photos'), className: 'hidden lg:table-cell' },
  { key: 'product', header: t('admin.reviews.columns.product'), className: 'hidden lg:table-cell' },
  { key: 'order', header: t('admin.reviews.columns.order'), className: 'hidden xl:table-cell' },
  { key: 'date', header: t('admin.reviews.columns.date'), className: 'hidden md:table-cell' },
  { key: 'status', header: t('admin.reviews.columns.status') },
  { key: 'actions', header: '', className: 'text-right' },
]);
const actions = useAdminReviewActions();
const products = usePublicProducts();
const { upload } = useMediaUpload();

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

// ── New or edited review ──
const formOpen = ref(false);
const editing = ref<Review | null>(null);
const form = reactive({ name: '', city: '', rating: 5, text: '', product_slug: '' });
const photos = ref<{ id: string; url: string }[]>([]);
const uploading = ref(false);
const formError = ref<string | null>(null);

function openNew() {
  editing.value = null;
  Object.assign(form, { name: '', city: '', rating: 5, text: '', product_slug: '' });
  photos.value = [];
  formError.value = null;
  formOpen.value = true;
}

function openEdit(review: Review) {
  editing.value = review;
  Object.assign(form, { name: review.name, city: review.city, rating: review.rating, text: review.text, product_slug: review.product_slug });
  formError.value = null;
  formOpen.value = true;
}

async function addPhotos(picked: File[]) {
  const files = picked.slice(0, MAX_PHOTOS - photos.value.length);
  formError.value = null;
  const wrong = files.find(f => !MEDIA_IMAGE_TYPES.includes(f.type) || f.size > DESIGN_IMAGE_MAX_MB * 1024 * 1024);
  if (wrong) {
    formError.value = t('admin.reviews.errors.fileType', { name: wrong.name, mb: DESIGN_IMAGE_MAX_MB });
    return;
  }
  uploading.value = true;
  try {
    for (const file of files) {
      const media = await upload(file, 'design');
      photos.value.push({ id: media.id, url: media.url });
    }
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, t('admin.reviews.errors.upload'));
  }
  finally {
    uploading.value = false;
  }
}

async function save() {
  formError.value = null;
  const body = { name: form.name.trim(), city: form.city.trim(), rating: form.rating, text: form.text.trim() };
  try {
    if (editing.value) await actions.update(editing.value.id, body);
    else await actions.create({ ...body, product_slug: form.product_slug, photo_ids: photos.value.map(p => p.id) });
    formOpen.value = false;
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, t('admin.reviews.errors.save'));
  }
}

const deleting = ref<Review | null>(null);
const deleteOpen = computed({
  get: () => deleting.value !== null,
  set: (open: boolean) => { if (!open) deleting.value = null; },
});
async function confirmDelete() {
  const review = deleting.value;
  if (!review) return;
  await act(() => actions.remove(review.id), t('admin.reviews.errors.delete'));
  deleting.value = null;
}

const productModel = computed({
  get: () => form.product_slug || NO_PRODUCT,
  set: (value: string) => {
    form.product_slug = value === NO_PRODUCT ? '' : value;
  },
});
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      placeholder="Fikrlarni qidirish..."
    >
      <div class="max-w-full overflow-x-auto scrollbar-none">
        <UiTabs
          :model-value="filter ?? 'all'"
          @update:model-value="setFilter"
        >
          <UiTabsList class="h-10 w-max gap-1 rounded-xl border border-border bg-card p-1 shadow-2xs group-data-horizontal/tabs:h-10">
            <UiTabsTrigger
              v-for="f in FILTERS"
              :key="f.label"
              :value="f.value ?? 'all'"
              class="h-full flex-none rounded-lg px-3 text-muted-foreground hover:bg-primary/10 hover:text-primary data-active:bg-primary data-active:text-primary-foreground data-active:shadow-xs data-active:hover:bg-primary data-active:hover:text-primary-foreground"
            >
              {{ f.label }}
            </UiTabsTrigger>
          </UiTabsList>
        </UiTabs>
      </div>

      <template #actions>
        <UiButton
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          :title="t('admin.reviews.add')"
          @click="openNew"
        >
          <Icon
            name="lucide:message-square"
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
      {{ error ?? t('admin.reviews.errors.load') }}
    </UiAlert>

    <UiDataTable
      :columns="columns"
      :data="pageRows"
      :is-loading="listQuery.isLoading.value"
      :row-key="(row: Review) => row.id"
      :empty-text="filter === 'pending' ? t('admin.reviews.emptyPending') : t('admin.reviews.empty')"
      empty-icon="lucide:message-square"
      clickable
      @row-click="openEdit"
    >
      <template #cell-customer="{ row }">
        <span class="flex items-center gap-2 whitespace-nowrap">
          <span class="font-semibold text-foreground">{{ row.name }}</span>
          <UiTooltip v-if="!row.from_customer">
            <UiTooltipTrigger as-child>
              <Icon
                name="lucide:pen-line"
                class="text-sm text-muted-foreground"
                :aria-label="t('admin.reviews.manual')"
              />
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.reviews.manual') }}</UiTooltipContent>
          </UiTooltip>
        </span>
      </template>

      <template #cell-city="{ row }">
        <span class="text-sm text-muted-foreground">{{ row.city || '—' }}</span>
      </template>

      <template #cell-rating="{ row }">
        <StarRating
          :value="row.rating"
          class="h-3.5 w-3.5"
        />
      </template>

      <template #cell-text="{ row }">
        <p
          class="max-w-40 truncate text-sm text-foreground/80 sm:max-w-xs xl:max-w-sm"
          :title="row.text"
        >
          {{ row.text }}
        </p>
      </template>

      <template #cell-photos="{ row }">
        <div
          v-if="row.photos.length"
          class="flex gap-1.5"
        >
          <a
            v-for="url in row.photos.slice(0, 3)"
            :key="url"
            :href="url"
            target="_blank"
            rel="noopener"
            class="block rounded-lg outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
            @click.stop
          >
            <MediaThumb
              :src="url"
              class="size-9 rounded-lg border border-border"
            />
          </a>
          <span
            v-if="row.photos.length > 3"
            class="flex size-9 items-center justify-center rounded-lg bg-muted text-xs font-semibold text-muted-foreground"
          >+{{ row.photos.length - 3 }}</span>
        </div>
        <span
          v-else
          class="text-sm text-muted-foreground"
        >—</span>
      </template>

      <template #cell-product="{ row }">
        <span class="block max-w-48 truncate text-sm text-foreground">{{ row.product_name || '—' }}</span>
      </template>

      <template #cell-order="{ row }">
        <NuxtLink
          v-if="row.order_number"
          :to="localePath(`/admin/orders/${row.order_id}`)"
          class="font-mono text-xs text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
          @click.stop
        >
          {{ row.order_number }}
        </NuxtLink>
        <span
          v-else
          class="text-sm text-muted-foreground"
        >—</span>
      </template>

      <template #cell-date="{ row }">
        <span class="whitespace-nowrap text-sm text-muted-foreground">{{ formatDate(row.created_at) }}</span>
      </template>

      <template #cell-status="{ row }">
        <UiStatusBadge :tone="TONES[row.status]">
          {{ t(`admin.reviews.status.${row.status}`) }}
        </UiStatusBadge>
      </template>

      <template #cell-actions="{ row }">
        <div
          class="flex items-center justify-end gap-1"
          @click.stop
        >
          <UiTooltip v-if="row.status !== 'approved'">
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="outline"
                class="text-emerald-700 hover:bg-emerald-50 hover:text-emerald-700"
                :aria-label="t('admin.reviews.approve')"
                :disabled="actions.busy.value"
                @click="act(() => actions.update(row.id, { status: 'approved' }), t('admin.reviews.errors.approve'))"
              >
                <Icon
                  name="lucide:check"
                  class="text-base"
                />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.reviews.approveHint') }}</UiTooltipContent>
          </UiTooltip>
          <UiTooltip v-if="row.status !== 'rejected'">
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="ghost"
                :aria-label="row.status === 'approved' ? t('admin.reviews.unpublish') : t('admin.reviews.reject')"
                :disabled="actions.busy.value"
                @click="act(() => actions.update(row.id, { status: 'rejected' }), t('admin.reviews.errors.status'))"
              >
                <Icon
                  name="lucide:eye-off"
                  class="text-base"
                />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ row.status === 'approved' ? t('admin.reviews.unpublish') : t('admin.reviews.reject') }}</UiTooltipContent>
          </UiTooltip>
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="ghost"
                :aria-label="t('admin.common.edit')"
                @click="openEdit(row)"
              >
                <Icon
                  name="lucide:pencil"
                  class="text-base"
                />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.common.edit') }}</UiTooltipContent>
          </UiTooltip>
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="ghost"
                class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                :aria-label="t('admin.reviews.deleteTitle')"
                @click="deleting = row"
              >
                <Icon
                  name="lucide:trash-2"
                  class="text-base"
                />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.common.delete') }}</UiTooltipContent>
          </UiTooltip>
        </div>
      </template>
    </UiDataTable>

    <UiSimplePagination
      v-if="reviews.length > 0"
      v-model:page="page"
      :total-pages="totalPages"
      :total-count="reviews.length"
    />

    <UiDialog v-model:open="formOpen">
      <UiDialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
        <UiDialogHeader>
          <UiDialogTitle>
            {{ editing ? t('admin.reviews.editTitle') : t('admin.reviews.add') }}
          </UiDialogTitle>
        </UiDialogHeader>

        <form
          class="space-y-4"
          @submit.prevent="save"
        >
          <div class="grid gap-4 sm:grid-cols-2">
            <UiField
              :label="t('admin.reviews.form.name')"
              for="review-name"
            >
              <UiInput
                id="review-name"
                v-model="form.name"
                maxlength="80"
              />
            </UiField>
            <UiField
              :label="t('admin.reviews.columns.city')"
              for="review-city"
            >
              <UiInput
                id="review-city"
                v-model="form.city"
                maxlength="60"
              />
            </UiField>
          </div>
          <UiField :label="t('admin.reviews.columns.rating')">
            <StarRating
              v-model="form.rating"
              class="h-6 w-6"
            />
          </UiField>
          <UiField
            :label="t('admin.reviews.form.text')"
            for="review-text"
            :hint="t('admin.reviews.form.textHint', { count: form.text.trim().length })"
          >
            <UiTextarea
              id="review-text"
              v-model="form.text"
              maxlength="1000"
              class="min-h-28"
            />
          </UiField>
          <template v-if="!editing">
            <UiField
              :label="t('admin.reviews.columns.product')"
              for="review-product"
            >
              <UiSelect v-model="productModel">
                <UiSelectTrigger
                  id="review-product"
                  class="w-full"
                >
                  <UiSelectValue />
                </UiSelectTrigger>
                <UiSelectContent position="popper">
                  <UiSelectItem :value="NO_PRODUCT">
                    {{ t('admin.reviews.form.noProduct') }}
                  </UiSelectItem>
                  <UiSelectItem
                    v-for="p in products.data.value ?? []"
                    :key="p.slug"
                    :value="p.slug"
                  >
                    {{ p.name }}
                  </UiSelectItem>
                </UiSelectContent>
              </UiSelect>
            </UiField>
            <UiField :label="t('admin.reviews.form.photos', { count: photos.length, max: MAX_PHOTOS })">
              <div class="flex flex-wrap gap-2">
                <div
                  v-for="(p, i) in photos"
                  :key="p.id"
                  class="relative"
                >
                  <MediaThumb
                    :src="p.url"
                    class="size-16 border border-border"
                  />
                  <UiButton
                    type="button"
                    size="icon-xs"
                    :aria-label="t('admin.reviews.form.removePhoto')"
                    class="absolute -right-1.5 -top-1.5 size-5 rounded-full bg-foreground text-background hover:bg-foreground/80"
                    @click="photos.splice(i, 1)"
                  >
                    <Icon
                      name="lucide:x"
                      class="text-xs"
                    />
                  </UiButton>
                </div>
                <UiFileInput
                  v-if="photos.length < MAX_PHOTOS"
                  accept="image/png,image/jpeg,image/webp"
                  multiple
                  :disabled="uploading"
                  class="size-16 p-0"
                  :aria-label="t('admin.reviews.form.addPhoto')"
                  @select="addPhotos"
                >
                  <Icon
                    :name="uploading ? 'lucide:loader-circle' : 'lucide:image-plus'"
                    class="text-xl"
                    :class="{ 'animate-spin': uploading }"
                  />
                </UiFileInput>
              </div>
            </UiField>
          </template>
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
              @click="formOpen = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="actions.busy.value || uploading || !form.name.trim() || form.text.trim().length < 10"
            >
              <Icon
                v-if="actions.busy.value"
                name="lucide:loader-2"
                class="animate-spin text-base"
              />
              {{ t('admin.common.save') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>

    <UiAlertDialog v-model:open="deleteOpen">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.reviews.deleteTitle') }}</UiAlertDialogTitle>
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
