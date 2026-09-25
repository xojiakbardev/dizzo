<script setup lang="ts">
// The customer's orders: four figures in a strip (how many, waiting for
// payment, in production, spent) and the orders in a table like the admin's
// "Buyurtmalar" — number, date, items, status and total, a row opening its
// page. No search or filters. The skeleton mirrors both, cell for cell.
import { getOrderStatusMeta } from '~/lib/orderStatus';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { OrderSummary } from '~/types/commerce';

definePageMeta({ layout: 'cabinet' });

const { t } = useI18n();
const localePath = useLocalePath();

const PER_PAGE = 20;
const SKELETON_ROWS = [1, 2, 3, 4, 5];

const { start: startDesign } = useProductPicker();
const ordersQuery = useOrders();
const statsQuery = useOrderStats();

const orders = computed(() => ordersQuery.data.value ?? []);
const stats = computed(() => statsQuery.data.value ?? null);
const loading = computed(() => ordersQuery.isLoading.value || statsQuery.isLoading.value);
const error = computed(() => (ordersQuery.isError.value || statsQuery.isError.value ? t('user.orders.loadError') : null));

const page = ref(1);
const totalPages = computed(() => Math.ceil(orders.value.length / PER_PAGE) || 1);
const pageRows = computed(() => orders.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE));
watch(totalPages, (pages) => {
  if (page.value > pages) page.value = pages;
});

// Every column stays on phones: the table scrolls sideways in its own box.
const columns = computed<DataTableColumn[]>(() => [
  { key: 'order_number', header: t('user.orders.colNumber') },
  { key: 'created_at', header: t('user.common.date') },
  { key: 'item_count', header: t('user.common.products'), className: 'text-center' },
  { key: 'status', header: t('user.orders.colStatus') },
  { key: 'total_amount', header: t('user.common.total'), className: 'text-right' },
  { key: 'actions', header: '', width: '50px' },
]);

// On phones the three counts share a row and the money takes the next one.
const CELL = [
  'border-b sm:border-b-0',
  'border-b border-l sm:border-b-0',
  'border-b border-l sm:border-b-0',
  'col-span-3 sm:col-span-1 sm:border-l',
];
const figures = computed(() => (stats.value
  ? [
      { label: t('user.orders.totalOrders'), icon: 'lucide:boxes', value: String(stats.value.total_orders) },
      { label: t('user.orders.paymentPending'), icon: 'lucide:hourglass', value: String(stats.value.payment_pending_orders) },
      { label: t('user.orders.inProduction'), icon: 'lucide:factory', value: String(stats.value.in_production_orders) },
      { label: t('user.orders.totalSpent'), icon: 'lucide:wallet', value: formatMoney(stats.value.total_spent || 0) },
    ]
  : []));
</script>

<template>
  <div>
    <!-- loading: the figures strip and the table with grey cells -->
    <div
      v-if="loading"
      aria-busy="true"
    >
      <UiCard class="gap-0 py-0 shadow-xs">
        <div class="grid grid-cols-3 sm:grid-cols-4">
          <div
            v-for="(cell, i) in CELL"
            :key="i"
            class="flex flex-col justify-between gap-1.5 border-border p-3.5 sm:p-5"
            :class="cell"
          >
            <div class="flex h-4 items-center">
              <UiSkeleton class="h-3 w-20 max-w-full" />
            </div>
            <div class="flex h-lh items-center text-lg sm:text-xl">
              <UiSkeleton
                class="h-5"
                :class="i === 3 ? 'w-32' : 'w-10'"
              />
            </div>
          </div>
        </div>
      </UiCard>

      <UiDataTable
        :columns="columns"
        :data="SKELETON_ROWS"
        class="mt-4 [&_tbody_tr:hover]:bg-transparent"
      >
        <template #cell-order_number>
          <div class="flex h-5 items-center">
            <UiSkeleton class="h-3.5 w-16" />
          </div>
        </template>
        <template #cell-created_at>
          <div class="flex h-5 items-center">
            <UiSkeleton class="h-3.5 w-28" />
          </div>
        </template>
        <template #cell-item_count>
          <UiSkeleton class="mx-auto h-5 w-10 rounded-4xl" />
        </template>
        <template #cell-status>
          <UiSkeleton class="h-6 w-28 rounded-4xl" />
        </template>
        <template #cell-total_amount>
          <div class="flex h-4 items-center justify-end">
            <UiSkeleton class="h-3 w-24" />
          </div>
        </template>
        <template #cell-actions>
          <div class="flex size-8.5 items-center justify-center">
            <UiSkeleton class="size-4 rounded" />
          </div>
        </template>
      </UiDataTable>

      <!-- the pages footer: two small buttons and "1 / 1-sahifa · jami N ta" -->
      <div class="mt-2 flex flex-wrap items-center justify-between gap-3 pt-2">
        <div class="flex items-center gap-2">
          <UiSkeleton class="h-8.5 w-22 rounded-lg" />
          <UiSkeleton class="h-8.5 w-22 rounded-lg" />
        </div>
        <div class="ml-auto flex h-5 items-center">
          <UiSkeleton class="h-3.5 w-36" />
        </div>
      </div>
    </div>

    <template v-else>
      <UiAlert
        v-if="error"
        variant="destructive"
        class="mb-4"
      >
        <Icon name="lucide:circle-alert" />
        <UiAlertDescription>{{ error }}</UiAlertDescription>
      </UiAlert>

      <UiCard
        v-if="stats"
        class="mb-4 gap-0 py-0 shadow-xs"
      >
        <dl class="grid grid-cols-3 sm:grid-cols-4">
          <div
            v-for="(f, i) in figures"
            :key="f.icon"
            class="flex flex-col justify-between gap-1.5 border-border p-3.5 sm:p-5"
            :class="CELL[i]"
          >
            <dt class="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
              <Icon
                :name="f.icon"
                class="hidden shrink-0 text-sm sm:inline"
              />
              {{ f.label }}
            </dt>
            <dd class="truncate text-lg font-bold tabular-nums text-foreground sm:text-xl">
              {{ f.value }}
            </dd>
          </div>
        </dl>
      </UiCard>

      <EmptyState
        v-if="!error && orders.length === 0"
        icon="lucide:package-open"
        :title="t('user.orders.empty')"
      >
        <UiButton @click="startDesign()">
          <Icon
            name="lucide:sparkles"
            class="text-base"
          />
          {{ t('user.common.startDesign') }}
        </UiButton>
      </EmptyState>

      <template v-else-if="orders.length">
        <UiDataTable
          :columns="columns"
          :data="pageRows"
          :row-key="(row: OrderSummary) => row.order_number"
          clickable
          @row-click="(row: OrderSummary) => navigateTo(localePath(`/user/orders/${row.order_number}`))"
        >
          <template #cell-order_number="{ row }">
            <span class="font-semibold text-foreground">{{ row.order_number }}</span>
          </template>

          <template #cell-created_at="{ row }">
            <span class="whitespace-nowrap text-sm text-muted-foreground">{{ formatDateTime(row.created_at) }}</span>
          </template>

          <template #cell-item_count="{ row }">
            <UiBadge
              variant="secondary"
              class="font-mono"
            >
              {{ t('user.common.units', row.item_count ?? 0) }}
            </UiBadge>
          </template>

          <template #cell-status="{ row }">
            <UiStatusBadge :tone="getOrderStatusMeta(row.status).tone">
              {{ getOrderStatusMeta(row.status).label }}
            </UiStatusBadge>
          </template>

          <template #cell-total_amount="{ row }">
            <span class="font-mono text-xs font-bold text-foreground">
              {{ formatMoney(row.total_amount) }}
            </span>
          </template>

          <template #cell-actions="{ row }">
            <UiButton
              as-child
              variant="ghost"
              size="icon-sm"
            >
              <NuxtLink
                :to="localePath(`/user/orders/${row.order_number}`)"
                :aria-label="t('user.common.open')"
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
          v-model:page="page"
          :total-pages="totalPages"
          :total-count="orders.length"
          class="mt-2"
        />
      </template>
    </template>
  </div>
</template>
