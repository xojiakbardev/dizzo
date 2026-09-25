<script setup lang="ts">
import { useCurrentUserRoles } from '~/composables/queries/useAuth';
import {
  useBranches,
  useBranchProducts,
  useUpdateBranchProductAvailability,
} from '~/composables/queries/useBranches';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { BranchProduct } from '~/types/commerce';

definePageMeta({
  layout: 'admin',
});

const roles = useCurrentUserRoles();
const route = useRoute();
const router = useRouter();

const selectedBranchId = ref<number | null>(route.query.branch ? Number(route.query.branch) : null);

const { data: branches, isLoading: branchesLoading } = useBranches(true);

// If user is a branch manager, lock to their branch
watch(
  [roles, branches],
  ([r, bList]) => {
    if (r.branchId) {
      selectedBranchId.value = r.branchId;
    } else if (!selectedBranchId.value && bList && bList.length > 0 && bList[0]) {
      selectedBranchId.value = bList[0].id;
    }
  },
  { immediate: true },
);

const { data: products, isLoading: productsLoading, refetch } = useBranchProducts(selectedBranchId);
const updateAvailabilityMutation = useUpdateBranchProductAvailability(selectedBranchId);

const search = ref((route.query.search as string) || '');
const statusFilter = ref<'all' | 'available' | 'unavailable'>((route.query.status as any) || 'all');
const page = ref(Number(route.query.page) || 1);
const PER_PAGE = 20;

// URL query synchronization
watch([selectedBranchId, search, statusFilter, page], () => {
  const query: Record<string, string | undefined> = {};
  if (selectedBranchId.value) query.branch = String(selectedBranchId.value);
  if (search.value.trim()) query.search = search.value.trim();
  if (statusFilter.value !== 'all') query.status = statusFilter.value;
  if (page.value > 1) query.page = String(page.value);
  router.replace({ query });
});

const FILTERS = [
  { value: 'all', label: 'Barchasi' },
  { value: 'available', label: 'Sotuvda mavjud' },
  { value: 'unavailable', label: 'Tugagan / Nosoz' },
] as const;

const filteredProducts = computed(() => {
  if (!products.value) return [];
  let list = products.value;

  if (statusFilter.value === 'available') {
    list = list.filter(p => p.is_available);
  } else if (statusFilter.value === 'unavailable') {
    list = list.filter(p => !p.is_available);
  }

  const q = search.value.trim().toLowerCase();
  if (!q) return list;

  return list.filter(
    p =>
      p.product_name.toLowerCase().includes(q) ||
      (p.category_name && p.category_name.toLowerCase().includes(q)),
  );
});

const totalPages = computed(() => Math.ceil(filteredProducts.value.length / PER_PAGE) || 1);
const pageRows = computed(() =>
  filteredProducts.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE),
);

watch([search, statusFilter], () => {
  page.value = 1;
});

const canToggle = computed(() => roles.value.isGlobalStaff || roles.value.isBranchManager);

const columns = computed<DataTableColumn[]>(() => {
  const cols: DataTableColumn[] = [
    { key: 'product_name', header: 'Mahsulot nomi' },
    { key: 'category_name', header: 'Kategoriya', className: 'hidden md:table-cell' },
    { key: 'base_price', header: 'Narxi', className: 'hidden sm:table-cell' },
    { key: 'is_available', header: 'Holati' },
  ];
  if (canToggle.value) {
    cols.push({ key: 'actions', header: '', className: 'text-right' });
  }
  return cols;
});

const pendingProductId = ref<number | null>(null);

async function handleToggle(product: BranchProduct) {
  pendingProductId.value = product.product_id;
  try {
    await updateAvailabilityMutation.mutateAsync({
      productId: product.product_id,
      isAvailable: !product.is_available,
      reason: !product.is_available ? null : product.reason,
    });
  } finally {
    pendingProductId.value = null;
  }
}

function formatPrice(val: number | undefined) {
  if (!val) return '0';
  return val.toLocaleString('uz-UZ') + ' so\'m';
}
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      placeholder="Mahsulotlarni qidirish..."
      :refreshing="productsLoading"
      @refresh="refetch()"
    >
      <div class="flex items-center gap-2">
        <!-- Branch selector if multiple -->
        <div
          v-if="roles.isGlobalStaff && branches && branches.length > 1"
          class="flex items-center gap-1.5"
        >
          <span class="text-xs font-medium text-muted-foreground whitespace-nowrap">Filial:</span>
          <select
            v-model="selectedBranchId"
            class="h-9 rounded-xl border border-input bg-card px-2.5 py-1 text-xs shadow-xs focus:ring-2 focus:ring-primary"
          >
            <option
              v-for="b in branches"
              :key="b.id"
              :value="b.id"
            >
              {{ b.name }}
            </option>
          </select>
        </div>

        <div class="max-w-full overflow-x-auto scrollbar-none">
          <UiTabs
            :model-value="statusFilter"
            @update:model-value="statusFilter = ($event as any)"
          >
            <UiTabsList class="h-9 w-max gap-1 rounded-xl border border-border bg-card p-1 shadow-2xs group-data-horizontal/tabs:h-9">
              <UiTabsTrigger
                v-for="f in FILTERS"
                :key="f.value"
                :value="f.value"
                class="h-full flex-none rounded-lg px-2.5 text-xs text-muted-foreground hover:bg-primary/10 hover:text-primary data-active:bg-primary data-active:text-primary-foreground data-active:shadow-xs data-active:hover:bg-primary data-active:hover:text-primary-foreground"
              >
                {{ f.label }}
              </UiTabsTrigger>
            </UiTabsList>
          </UiTabs>
        </div>
      </div>
    </AdminPageHeader>

    <UiDataTable
      :columns="columns"
      :data="pageRows"
      :is-loading="productsLoading || branchesLoading"
      :row-key="(row: BranchProduct) => row.product_id"
      empty-text="Mahsulotlar topilmadi"
      empty-icon="lucide:boxes"
    >
      <template #cell-product_name="{ row }">
        <div class="flex items-center gap-2.5 whitespace-nowrap">
          <div class="flex size-7 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-border bg-muted/20">
            <img
              v-if="row.image_url"
              :src="row.image_url"
              :alt="row.product_name"
              class="size-full object-cover"
            >
            <Icon
              v-else
              name="lucide:box"
              class="size-4 text-muted-foreground/50"
            />
          </div>
          <span class="font-semibold text-foreground truncate max-w-xs">{{ row.product_name }}</span>
        </div>
      </template>

      <template #cell-category_name="{ row }">
        <span class="whitespace-nowrap text-sm text-muted-foreground">{{ row.category_name || '—' }}</span>
      </template>

      <template #cell-base_price="{ row }">
        <span class="whitespace-nowrap font-mono text-xs text-foreground">{{ formatPrice(row.base_price) }}</span>
      </template>

      <template #cell-is_available="{ row }">
        <UiStatusBadge :tone="row.is_available ? 'success' : 'danger'">
          {{ row.is_available ? 'Sotuvda mavjud' : 'Tugagan / Nosoz' }}
        </UiStatusBadge>
      </template>

      <template
        v-if="canToggle"
        #cell-actions="{ row }"
      >
        <div class="flex items-center justify-end">
          <UiButton
            size="sm"
            :variant="row.is_available ? 'outline' : 'default'"
            :disabled="pendingProductId === row.product_id"
            class="h-8 text-xs font-semibold"
            @click="handleToggle(row)"
          >
            <Icon
              v-if="pendingProductId === row.product_id"
              name="lucide:loader-2"
              class="mr-1.5 size-3.5 animate-spin"
            />
            <Icon
              v-else
              :name="row.is_available ? 'lucide:ban' : 'lucide:check'"
              class="mr-1.5 size-3.5"
            />
            {{ row.is_available ? 'O\'chirish' : 'Yoqish' }}
          </UiButton>
        </div>
      </template>
    </UiDataTable>

    <UiSimplePagination
      v-if="filteredProducts.length > PER_PAGE"
      v-model:page="page"
      :total-pages="totalPages"
      :total-count="filteredProducts.length"
    />
  </div>
</template>
