<script setup lang="ts">
import { getApiErrorMessage } from '~/composables/useApi';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { AdminCatalogListItem } from '~/types/catalog';
import { isTranslated, textTranslations, trimTranslations } from '~/lib/admin/translations';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();
const route = useRoute();
const router = useRouter();
const PER_PAGE = 20;
const SLUG_MAX = 120;

const listQuery = useCatalogAdminList();
const products = computed(() => (listQuery.data.value ?? []).filter(p => !p.archived));
const search = ref((route.query.search as string) || '');
const page = ref(Number(route.query.page) || 1);

// URL query synchronization
watch([search, page], () => {
  const query: Record<string, string | undefined> = {};
  if (search.value.trim()) query.search = search.value.trim();
  if (page.value > 1) query.page = String(page.value);
  router.replace({ query });
});

const shown = computed(() => {
  const q = search.value.trim().toLowerCase();
  return q ? products.value.filter(p => p.name.toLowerCase().includes(q) || p.slug.includes(q)) : products.value;
});
const totalPages = computed(() => Math.ceil(shown.value.length / PER_PAGE) || 1);
const pageRows = computed(() => shown.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE));
watch(search, () => {
  page.value = 1;
});
const { run, busy } = useCatalogAdminActions();

/** On sale, switched off, or on but not ready to sell yet. */
function statusOf(p: AdminCatalogListItem) {
  if (!p.is_available) return { label: t('admin.products.status.off'), tone: 'neutral' as const };
  if (!p.sellable) return { label: t('admin.products.status.notReady'), tone: 'warn' as const };
  return { label: t('admin.products.status.onSale'), tone: 'success' as const };
}

const columns = computed<DataTableColumn[]>(() => [
  { key: 'name', header: t('admin.products.col.product') },
  { key: 'slug', header: t('admin.products.col.slug'), className: 'hidden lg:table-cell' },
  { key: 'shape_count', header: t('admin.products.col.shapes'), className: 'hidden text-center md:table-cell' },
  { key: 'variant_count', header: t('admin.products.col.variants'), className: 'hidden text-center md:table-cell' },
  { key: 'from_price', header: t('admin.products.col.price'), className: 'text-right' },
  { key: 'status', header: t('admin.products.col.status') },
  { key: 'is_featured', header: t('admin.products.col.featured'), className: 'hidden text-center xl:table-cell' },
  { key: 'actions', header: '', width: '50px' },
]);

const creating = ref(false);
const name = ref('');
const nameTr = ref(textTranslations(null, ['name']));
const error = ref<string | null>(null);
// Archived products keep their slug, so they count as taken too.
const { slug, onInput: onSlugInput, reset: resetSlug, save: saveWithSlug } = useSlugField({
  source: () => name.value,
  taken: () => (listQuery.data.value ?? []).map(p => p.slug),
  maxLength: SLUG_MAX,
});
watch(creating, () => {
  name.value = '';
  nameTr.value = textTranslations(null, ['name']);
  resetSlug();
  error.value = null;
});

async function create() {
  error.value = null;
  try {
    const product = await saveWithSlug(s => run('post', '/admin/catalog/products/', { name: name.value.trim(), slug: s, translations: trimTranslations(nameTr.value) }));
    creating.value = false;
    await navigateTo(localePath(`/admin/products/${product.id}`));
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.products.createFailed'));
  }
}
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      :placeholder="t('admin.products.searchPlaceholder')"
      :refreshing="listQuery.isFetching.value"
      @refresh="listQuery.refetch()"
    >
      <template #actions>
        <UiButton
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          :title="t('admin.products.add')"
          @click="creating = true"
        >
          <Icon
            name="lucide:package"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiAlert
      v-if="listQuery.isError.value"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ t('admin.products.listFailed') }}
    </UiAlert>

    <UiDataTable
      :columns="columns"
      :data="pageRows"
      :is-loading="listQuery.isLoading.value"
      :row-key="(row: AdminCatalogListItem) => row.id"
      :empty-text="search ? t('admin.products.nothingFound') : t('admin.products.empty')"
      empty-icon="lucide:boxes"
      clickable
      @row-click="(row: AdminCatalogListItem) => navigateTo(localePath(`/admin/products/${row.id}`))"
    >
      <template #cell-name="{ row }">
        <div class="flex min-w-0 items-center gap-3">
          <MediaThumb
            :src="row.cover_url"
            :alt="row.name"
            fit="contain"
            class="size-12 border border-border bg-muted/60"
            img-class="p-1"
          />
          <span class="min-w-0 truncate font-semibold text-foreground">{{ row.name }}</span>
        </div>
      </template>

      <template #cell-slug="{ row }">
        <span class="font-mono text-xs text-muted-foreground">{{ row.slug }}</span>
      </template>

      <template #cell-shape_count="{ row }">
        <UiBadge
          variant="secondary"
          class="font-mono"
        >
          {{ t('admin.products.count', { n: row.shape_count }) }}
        </UiBadge>
      </template>

      <template #cell-variant_count="{ row }">
        <UiBadge
          variant="secondary"
          class="font-mono"
        >
          {{ t('admin.products.count', { n: row.variant_count }) }}
        </UiBadge>
      </template>

      <template #cell-from_price="{ row }">
        <span class="font-mono text-xs font-bold text-foreground">
          {{ row.from_price === null ? '—' : t('admin.products.fromPrice', { price: formatMoney(row.from_price) }) }}
        </span>
      </template>

      <template #cell-status="{ row }">
        <UiStatusBadge :tone="statusOf(row).tone">
          {{ statusOf(row).label }}
        </UiStatusBadge>
      </template>

      <template #cell-is_featured="{ row }">
        <Icon
          :name="row.is_featured ? 'lucide:check' : 'lucide:minus'"
          :class="row.is_featured ? 'text-base text-emerald-600' : 'text-base text-muted-foreground/50'"
          :aria-label="row.is_featured ? t('admin.common.yes') : t('admin.common.no')"
        />
      </template>

      <template #cell-actions="{ row }">
        <UiButton
          as-child
          variant="ghost"
          size="icon-sm"
        >
          <NuxtLinkLocale
            :to="`/admin/products/${row.id}`"
            :aria-label="t('admin.products.open')"
            @click.stop
          >
            <Icon
              name="lucide:chevron-right"
              class="text-base"
            />
          </NuxtLinkLocale>
        </UiButton>
      </template>

      <template
        v-if="!search"
        #empty
      >
        <UiButton
          size="sm"
          @click="creating = true"
        >
          <Icon
            name="lucide:plus"
            class="text-base"
          />
          {{ t('admin.products.add') }}
        </UiButton>
      </template>
    </UiDataTable>

    <UiSimplePagination
      v-if="shown.length > 0"
      v-model:page="page"
      :total-pages="totalPages"
      :total-count="shown.length"
    />

    <UiDialog v-model:open="creating">
      <UiDialogContent class="sm:max-w-md">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.products.new') }}</UiDialogTitle>
        </UiDialogHeader>
        <form
          class="space-y-4"
          @submit.prevent="create"
        >
          <TranslatableInput
            id="new-product-name"
            v-model="name"
            v-model:translations="nameTr"
            field="name"
            :label="t('admin.common.name')"
            :placeholder="t('admin.products.namePlaceholder')"
            maxlength="150"
            required
          />
          <UiField
            :label="t('admin.products.col.slug')"
            for="new-product-slug"
            :error="error"
          >
            <UiInput
              id="new-product-slug"
              v-model="slug"
              placeholder="krujka"
              :maxlength="SLUG_MAX"
              class="font-mono"
              @input="onSlugInput"
            />
          </UiField>
          <UiDialogFooter>
            <UiButton
              variant="outline"
              type="button"
              @click="creating = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="busy || !name.trim() || !slug || !isTranslated(nameTr, 'name')"
            >
              <Icon
                v-if="busy"
                name="lucide:loader-2"
                class="animate-spin text-base"
              />
              {{ t('admin.products.create') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
