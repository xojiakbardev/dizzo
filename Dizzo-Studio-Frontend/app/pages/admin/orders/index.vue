<script setup lang="ts">
import { useCurrentUserRoles } from '~/composables/queries/useAuth';
import OrdersKanbanBoard from '~/components/admin/orders/OrdersKanbanBoard.vue';
import { getOrderStatusMeta } from '~/lib/orderStatus';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { OrderSummary } from '~/types/commerce';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();
const roles = useCurrentUserRoles();

const STATUSES = [
  'NEW', 'PAYMENT_PENDING', 'PAID', 'MODERATED', 'READY_FOR_PRODUCTION', 'IN_PRODUCTION', 'QUALITY_CHECK',
  'READY_FOR_PICKUP', 'READY_FOR_DELIVERY', 'COMPLETED', 'CANCELLED',
] as const;
const STATUS_OPTIONS = computed(() => [
  { value: 'ALL', label: t('admin.orders.list.allStatuses') },
  ...STATUSES.map(value => ({ value, label: t(`admin.orders.status.${value}`) })),
]);

const DELIVERY_OPTIONS = computed(() => [
  { value: 'ALL', label: t('admin.orders.list.allMethods') },
  { value: 'DELIVERY', label: t('admin.orders.delivery.DELIVERY') },
  { value: 'PICKUP', label: t('admin.orders.delivery.PICKUP') },
]);

const route = useRoute();
const router = useRouter();

const status = ref((route.query.status as string) || 'ALL');
const deliveryMethod = ref((route.query.delivery_method as string) || 'ALL');
const search = ref((route.query.search as string) || '');
const page = ref(Number(route.query.page) || 1);

// Default to kanban board for branch workers and branch managers, or from query
const viewMode = ref<'table' | 'kanban'>((route.query.view as 'table' | 'kanban') || 'table');
watch(roles, (r) => {
  if (!route.query.view && r && (r.isBranchWorker || r.isBranchManager)) {
    viewMode.value = 'kanban';
  }
}, { immediate: true });

// Sync to URL params
watch([status, deliveryMethod, search, page, viewMode], () => {
  const query: Record<string, string | undefined> = {};
  if (status.value !== 'ALL') query.status = status.value;
  if (deliveryMethod.value !== 'ALL') query.delivery_method = deliveryMethod.value;
  if (search.value.trim()) query.search = search.value.trim();
  if (page.value > 1) query.page = String(page.value);
  if (viewMode.value !== 'table') query.view = viewMode.value;
  router.replace({ query });
});

const filters = computed(() => ({
  status: viewMode.value === 'kanban' ? undefined : (status.value === 'ALL' ? undefined : status.value),
  delivery_method: (deliveryMethod.value === 'ALL' ? undefined : deliveryMethod.value) as 'DELIVERY' | 'PICKUP' | undefined,
  search: search.value || undefined,
  page: viewMode.value === 'kanban' ? 1 : page.value,
  limit: viewMode.value === 'kanban' ? 100 : 50,
}));

const ordersQuery = useAdminOrders(filters);

watch([status, deliveryMethod, search, viewMode], () => {
  page.value = 1;
});

const totalCount = computed(() => {
  const data = ordersQuery.data.value;
  if (!data) return 0;
  if (typeof data.count === 'number') return data.count;
  if (Array.isArray(data)) return data.length;
  if (Array.isArray(data.results)) return data.results.length;
  return 0;
});
const results = computed(() => {
  const data = ordersQuery.data.value;
  if (!data) return [];
  if (Array.isArray(data.results)) return data.results;
  if (Array.isArray(data)) return data;
  return [];
});
const totalPages = computed(() => Math.ceil(totalCount.value / 50) || 1);

function resetFilters() {
  status.value = 'ALL';
  deliveryMethod.value = 'ALL';
  search.value = '';
  page.value = 1;
}

const columns = computed<DataTableColumn[]>(() => [
  { key: 'order_number', header: t('admin.orders.list.col.number') },
  { key: 'created_at', header: t('admin.orders.list.col.date'), className: 'hidden md:table-cell' },
  { key: 'customer_name', header: t('admin.orders.list.col.customer') },
  { key: 'delivery_method', header: t('admin.orders.list.col.delivery'), className: 'hidden lg:table-cell' },
  { key: 'item_count', header: t('admin.orders.list.col.items'), className: 'hidden text-center sm:table-cell' },
  { key: 'total_amount', header: t('admin.orders.list.col.total'), className: 'text-right' },
  { key: 'status', header: t('admin.orders.list.col.status') },
  { key: 'actions', header: '', width: '50px' },
]);
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      :placeholder="t('admin.orders.list.searchPlaceholder')"
      :refreshing="ordersQuery.isFetching.value"
      @refresh="ordersQuery.refetch()"
    >
      <UiSelect v-model="status">
        <UiSelectTrigger
          class="w-full bg-card sm:w-56"
          :aria-label="t('admin.orders.list.col.status')"
        >
          <UiSelectValue />
        </UiSelectTrigger>
        <UiSelectContent position="popper">
          <UiSelectItem
            v-for="opt in STATUS_OPTIONS"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </UiSelectItem>
        </UiSelectContent>
      </UiSelect>

      <UiSelect v-model="deliveryMethod">
        <UiSelectTrigger
          class="w-full bg-card sm:w-48"
          :aria-label="t('admin.orders.list.deliveryMethod')"
        >
          <UiSelectValue />
        </UiSelectTrigger>
        <UiSelectContent position="popper">
          <UiSelectItem
            v-for="opt in DELIVERY_OPTIONS"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </UiSelectItem>
        </UiSelectContent>
      </UiSelect>

      <!-- View mode switch: Table vs Kanban -->
      <div class="flex items-center gap-2">
        <div class="flex items-center rounded-xl border border-border bg-muted/40 p-1">
          <button
            type="button"
            class="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition-all cursor-pointer"
            :class="viewMode === 'table' ? 'bg-background text-foreground shadow-xs' : 'text-muted-foreground hover:text-foreground'"
            @click="viewMode = 'table'"
          >
            <Icon
              name="lucide:table"
              class="size-3.5"
            />
            Ro'yxat
          </button>
          <button
            type="button"
            class="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition-all cursor-pointer"
            :class="viewMode === 'kanban' ? 'bg-background text-foreground shadow-xs' : 'text-muted-foreground hover:text-foreground'"
            @click="viewMode = 'kanban'"
          >
            <Icon
              name="lucide:kanban"
              class="size-3.5"
            />
            Kanban Board
          </button>
        </div>

        <NuxtLink
          v-if="viewMode === 'kanban'"
          :to="localePath('/admin/orders/board')"
          class="flex items-center gap-1.5 rounded-xl border border-border/80 bg-card px-3 py-2 text-xs font-semibold text-foreground hover:bg-muted hover:border-primary/50 transition-all shadow-2xs"
          title="To'liq ekranga o'tish"
        >
          <Icon
            name="lucide:maximize-2"
            class="size-3.5 text-primary"
          />
          <span class="hidden sm:inline">To'liq ekran</span>
        </NuxtLink>
      </div>

      <UiButton
        v-if="status !== 'ALL' || deliveryMethod !== 'ALL' || search"
        variant="ghost"
        class="text-destructive hover:bg-destructive/10"
        @click="resetFilters"
      >
        <Icon
          name="lucide:x"
          class="text-base"
        />
        {{ t('admin.orders.list.clear') }}
      </UiButton>
    </AdminPageHeader>

    <!-- Kanban View -->
    <OrdersKanbanBoard
      v-if="viewMode === 'kanban'"
      :orders="results"
      :is-loading="ordersQuery.isLoading.value"
      @refresh="ordersQuery.refetch()"
    />

    <!-- Table View -->
    <template v-else>
      <UiDataTable
        :columns="columns"
        :data="results"
        :is-loading="ordersQuery.isLoading.value"
      :row-key="(row: OrderSummary) => row.id"
      :empty-text="status !== 'ALL' || deliveryMethod !== 'ALL' || search ? t('admin.orders.list.nothingFound') : t('admin.orders.list.empty')"
      empty-icon="lucide:clipboard-list"
      clickable
      @row-click="(row: OrderSummary) => navigateTo(localePath(`/admin/orders/${row.id}`))"
    >
      <template #cell-order_number="{ row }">
        <span class="font-semibold text-foreground">{{ row.order_number }}</span>
      </template>

      <template #cell-created_at="{ row }">
        <span class="whitespace-nowrap text-sm text-muted-foreground">{{ formatDateTime(row.created_at) }}</span>
      </template>

      <template #cell-customer_name="{ row }">
        <span class="font-medium text-foreground">
          {{ row.customer_name || t('admin.orders.unknownCustomer') }}
        </span>
      </template>

      <template #cell-delivery_method="{ row }">
        <span class="inline-flex items-center gap-1.5 font-medium text-foreground">
          <Icon
            :name="row.delivery_method === 'PICKUP' ? 'lucide:store' : 'lucide:truck'"
            class="text-base text-muted-foreground"
          />
          {{ t(`admin.orders.delivery.${row.delivery_method === 'PICKUP' ? 'PICKUP' : 'DELIVERY'}`) }}
        </span>
      </template>

      <template #cell-item_count="{ row }">
        <UiBadge
          variant="secondary"
          class="font-mono"
        >
          {{ t('admin.orders.list.itemCount', { n: row.item_count }) }}
        </UiBadge>
      </template>

      <template #cell-total_amount="{ row }">
        <span class="font-mono text-xs font-bold text-foreground">
          {{ formatMoney(row.total_amount) }}
        </span>
      </template>

      <template #cell-status="{ row }">
        <UiStatusBadge :tone="getOrderStatusMeta(row.status).tone">
          {{ getOrderStatusMeta(row.status).label }}
        </UiStatusBadge>
      </template>

      <template #cell-actions="{ row }">
        <UiButton
          as-child
          variant="ghost"
          size="icon-sm"
        >
          <NuxtLink
            :to="localePath(`/admin/orders/${row.id}`)"
            :aria-label="t('admin.orders.list.open')"
            @click.stop
          >
            <Icon
              name="lucide:chevron-right"
              class="text-base"
            />
          </NuxtLink>
        </UiButton>
      </template>
    </UiDataTable>

      <UiSimplePagination
        v-if="totalCount > 0"
        v-model:page="page"
        :total-pages="totalPages"
        :total-count="totalCount"
      />
    </template>
  </div>
</template>
