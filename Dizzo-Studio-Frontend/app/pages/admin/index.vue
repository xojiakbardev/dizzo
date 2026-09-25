<script setup lang="ts">
// "Boshqaruv paneli": the shop's figures for the last 7 / 14 / 30 days
// (Tashkent time) against the period before, the day-by-day trend, what's
// in the works right now, and what sells. Everything comes from
// GET /admin/dashboard/ — nothing here is estimated.
import { getOrderStatusMeta } from '~/lib/orderStatus';
import type { AdminDashboard, PeriodPair } from '~/types/commerce';

definePageMeta({ layout: 'admin' });
const { t } = useI18n();
const localePath = useLocalePath();

const DAY_RANGE_OPTIONS = [7, 14, 30] as const;
type DayRange = (typeof DAY_RANGE_OPTIONS)[number];
const days = ref<DayRange>(14);
/** A toggle group can be cleared by clicking the chosen item — keep the range then. */
function setDays(value: unknown) {
  const option = DAY_RANGE_OPTIONS.find(o => o === value);
  if (option) days.value = option;
}

const query = useAdminDashboard(days);
const board = computed<AdminDashboard | null>(() => query.data.value ?? null);
const loading = computed(() => query.isLoading.value);
const switching = computed(() => query.isFetching.value && !query.isLoading.value);
const roles = useCurrentUserRoles();
watch(() => roles.value.isBranchWorker, (worker) => {
  if (worker) void navigateTo(localePath('/admin/orders'), { replace: true });
}, { immediate: true });
const view = computed<'shop' | 'lead'>(() => {
  if (roles.value.isBranchManager || board.value?.scope?.kind === 'branch') return 'lead';
  return 'shop';
});
const pageTitle = computed(() => (
  view.value === 'shop' ? t('admin.dashboard.title') : t('admin.dashboard.branchTitle')
));
useHead({ title: pageTitle });

const count = (n: number) => n.toLocaleString('ru-RU');
const pieces = (n: number) => t('admin.dashboard.pieces', { n: count(n) }, n);

/** Percent change, or null when there's nothing before to compare with. */
function change(pair: PeriodPair<number | string> | undefined) {
  if (!pair) return null;
  const now = Number(pair.current);
  const before = Number(pair.previous);
  return before > 0 ? ((now - before) / before) * 100 : null;
}

const kpis = computed(() => {
  const s = board.value?.summary;
  const c = board.value?.conversion;
  const rate = c && c.designers > 0 ? Math.round((c.buyers / c.designers) * 100) : null;
  const orders = {
    key: 'orders',
    title: t('admin.dashboard.orders'),
    icon: 'lucide:shopping-bag',
    value: s ? count(s.orders.current) : '',
    delta: change(s?.orders),
    previous: s ? count(s.orders.previous) : '',
    to: localePath('/admin/orders'),
  };
  const items = {
    key: 'items',
    title: t('admin.dashboard.itemsSold'),
    icon: 'lucide:package',
    value: s ? pieces(s.items_sold.current) : '',
    delta: change(s?.items_sold),
    previous: s ? pieces(s.items_sold.previous) : '',
  };
  const cancelled = {
    key: 'cancelled',
    title: t('admin.dashboard.cancelled'),
    icon: 'lucide:x-circle',
    value: s ? count(s.cancelled.current) : '',
    delta: change(s?.cancelled),
    previous: s ? count(s.cancelled.previous) : '',
  };
  const pickup = {
    key: 'pickup',
    title: t('admin.dashboard.pickupReady'),
    icon: 'lucide:package-check',
    value: board.value ? count(board.value.pickup_ready ?? 0) : '',
    to: localePath('/admin/orders'),
  };
  const revenue = {
    key: 'revenue',
    title: t('admin.dashboard.revenue'),
    icon: 'lucide:wallet',
    value: s?.revenue ? formatMoney(s.revenue.current) : '',
    delta: change(s?.revenue),
    previous: s?.revenue ? formatMoney(s.revenue.previous) : '',
  };
  const avg = {
    key: 'avg',
    title: t('admin.dashboard.avgOrder'),
    icon: 'lucide:receipt',
    value: s?.avg_order ? formatMoney(s.avg_order.current) : '',
    delta: change(s?.avg_order),
    previous: s?.avg_order ? formatMoney(s.avg_order.previous) : '',
  };
  const paid = {
    key: 'paid',
    title: t('admin.dashboard.paidOrders'),
    icon: 'lucide:badge-check',
    value: s?.paid_orders ? count(s.paid_orders.current) : '',
    delta: change(s?.paid_orders),
    previous: s?.paid_orders ? count(s.paid_orders.previous) : '',
  };
  if (view.value === 'lead') {
    return [
      revenue, orders, paid, avg, items, cancelled, pickup,
      {
        key: 'workers',
        title: t('admin.dashboard.workers'),
        icon: 'lucide:users-round',
        value: board.value ? count(board.value.branch?.workers ?? 0) : '',
        to: localePath('/admin/branches/workers'),
      },
      {
        key: 'unavailable',
        title: t('admin.dashboard.unavailableProducts'),
        icon: 'lucide:package-x',
        value: board.value ? count(board.value.branch?.unavailable_products ?? 0) : '',
        to: localePath('/admin/branches/inventory'),
      },
    ];
  }
  return [
    revenue, orders, avg, items,
    {
      key: 'customers',
      title: t('admin.dashboard.newCustomers'),
      icon: 'lucide:user-plus',
      value: s?.new_customers ? count(s.new_customers.current) : '',
      delta: change(s?.new_customers),
      previous: s?.new_customers ? count(s.new_customers.previous) : '',
    },
    {
      key: 'designs',
      title: t('admin.dashboard.savedDesigns'),
      icon: 'lucide:palette',
      value: s?.designs ? count(s.designs.current) : '',
      delta: change(s?.designs),
      previous: s?.designs ? count(s.designs.previous) : '',
    },
    {
      key: 'conversion',
      title: t('admin.dashboard.conversion'),
      icon: 'lucide:funnel',
      value: rate === null ? '—' : `${rate}%`,
      chip: c && c.designers > 0 ? `${c.buyers} / ${c.designers}` : undefined,
      chipTitle: c ? t('admin.dashboard.conversionHint', { designers: c.designers, buyers: c.buyers }) : undefined,
    },
    {
      key: 'reviews',
      title: t('admin.dashboard.pendingReviews'),
      icon: 'lucide:message-square',
      value: board.value ? count(board.value.reviews_pending ?? 0) : '',
      to: localePath('/admin/reviews'),
    },
  ];
});

// ── Trend ──
type Metric = 'revenue' | 'orders' | 'new_customers' | 'designs';
const METRICS = computed<Array<{ value: Metric; label: string }>>(() => {
  const rows: Array<{ value: Metric; label: string }> = [
    { value: 'revenue', label: t('admin.dashboard.revenue') },
    { value: 'orders', label: t('admin.dashboard.orders') },
  ];
  if (view.value === 'shop') {
    rows.push(
      { value: 'new_customers', label: t('admin.dashboard.newCustomers') },
      { value: 'designs', label: t('admin.dashboard.designs') },
    );
  }
  return rows;
});
const metric = ref<Metric>('revenue');
watch(METRICS, (list) => {
  if (!list.some(m => m.value === metric.value)) {
    metric.value = list[0]?.value ?? 'orders';
  }
}, { immediate: true });
function setMetric(value: unknown) {
  const option = METRICS.value.find(m => m.value === value);
  if (option) metric.value = option.value;
}
const metricLabel = computed(() => METRICS.value.find(m => m.value === metric.value)?.label ?? '');
const trendPoints = computed(() => (board.value?.by_day ?? []).map(d => ({ date: d.date, value: Number(d[metric.value] ?? 0) })));
const trendFormat = computed(() => (metric.value === 'revenue' ? (v: number) => formatMoney(v) : count));
function trendDetails(index: number) {
  const day = board.value?.by_day[index];
  if (!day) return [];
  const rows = [
    day.revenue != null ? { key: 'revenue', label: t('admin.dashboard.revenue'), value: formatMoney(day.revenue) } : null,
    { key: 'orders', label: t('admin.dashboard.orders'), value: count(day.orders) },
    day.new_customers != null ? { key: 'new_customers', label: t('admin.dashboard.newCustomers'), value: count(day.new_customers) } : null,
    day.designs != null ? { key: 'designs', label: t('admin.dashboard.designs'), value: count(day.designs) } : null,
  ].filter((r): r is { key: string; label: string; value: string } => r !== null);
  return rows.filter(r => r.key !== metric.value);
}

// ── Breakdowns ──
const pipelineTotal = computed(() => (board.value?.pipeline ?? []).reduce((sum, r) => sum + r.count, 0));
const pipelineData = computed(() => (board.value?.pipeline ?? [])
  .filter(r => r.count > 0)
  .map(r => ({ label: getOrderStatusMeta(r.status).label, value: r.count })));
const statusData = computed(() => (board.value?.orders_by_status ?? [])
  .filter(r => r.count > 0)
  .map(r => ({ label: getOrderStatusMeta(r.status).label, value: r.count })));
const topProducts = computed(() => (board.value?.top_products ?? []).map(p => ({
  label: p.product_name,
  value: p.units_sold,
  valueLabel: pieces(p.units_sold),
  hint: formatMoney(p.revenue),
})));
const topVariants = computed(() => (board.value?.top_variants ?? []).map(v => ({
  label: v.variant_name ? `${v.product_name} · ${v.variant_name}` : v.product_name,
  value: v.units_sold,
  valueLabel: pieces(v.units_sold),
  hint: formatMoney(v.revenue),
})));
const showDelivery = computed(() => true);
const showCarts = computed(() => view.value === 'shop');
const breakdowns = computed(() => [
  { key: 'status', title: t('admin.dashboard.byStatus'), data: statusData.value, empty: t('admin.dashboard.noOrders'), icon: 'lucide:clipboard-list' },
  { key: 'products', title: t('admin.dashboard.topProducts'), data: topProducts.value, empty: t('admin.dashboard.noSales'), icon: 'lucide:boxes' },
  { key: 'variants', title: t('admin.dashboard.topVariants'), data: topVariants.value, empty: t('admin.dashboard.noSales'), icon: 'lucide:layers' },
]);
const delivery = computed(() => {
  const rows = board.value?.orders_by_delivery_method ?? [];
  const total = rows.reduce((sum, r) => sum + r.count, 0);
  return rows.map(r => ({
    key: r.method,
    label: t(r.method === 'PICKUP' ? 'admin.dashboard.pickup' : 'admin.dashboard.courier'),
    icon: r.method === 'PICKUP' ? 'lucide:store' : 'lucide:truck',
    count: r.count,
    share: total ? Math.round((r.count / total) * 100) : 0,
  }));
});
</script>

<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="min-w-0">
        <h1 class="text-xl font-bold tracking-tight text-foreground">
          {{ pageTitle }}
        </h1>
        <p
          v-if="board?.scope?.kind === 'branch' && board.scope.branch_name"
          class="mt-0.5 truncate text-sm text-muted-foreground"
        >
          {{ board.scope.branch_name }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Icon
          v-if="switching"
          name="lucide:loader-2"
          class="animate-spin text-base text-muted-foreground"
        />
        <UiToggleGroup
          :model-value="days"
          :aria-label="t('admin.dashboard.period')"
          class="border border-border bg-card shadow-2xs"
          @update:model-value="setDays"
        >
          <UiToggleGroupItem
            v-for="option in DAY_RANGE_OPTIONS"
            :key="option"
            :value="option"
            class="h-7 px-2.5 text-xs font-semibold data-[state=off]:hover:bg-primary/10 data-[state=off]:hover:text-primary data-[state=on]:bg-primary data-[state=on]:text-primary-foreground data-[state=on]:hover:bg-primary data-[state=on]:hover:text-primary-foreground"
          >
            {{ t('admin.dashboard.days', { n: option }, option) }}
          </UiToggleGroupItem>
        </UiToggleGroup>
      </div>
    </div>

    <EmptyState
      v-if="query.isError.value && !board"
      :title="t('admin.dashboard.loadFailed')"
      icon="lucide:circle-alert"
      tone="destructive"
    >
      <UiButton
        variant="outline"
        size="sm"
        @click="query.refetch()"
      >
        <Icon
          name="lucide:refresh-cw"
          class="text-base"
        />
        {{ t('admin.common.retry') }}
      </UiButton>
    </EmptyState>

    <template v-else>
      <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <AdminKpi
          v-for="k in kpis"
          :key="k.key"
          :title="k.title"
          :icon="k.icon"
          :value="k.value"
          :delta="k.delta ?? null"
          :previous="k.previous"
          :chip="k.chip"
          :chip-title="k.chipTitle"
          :invert="k.key === 'cancelled'"
          :to="k.to"
          :loading="loading"
        />
      </div>

      <div class="grid gap-4 lg:grid-cols-3">
        <UiCard class="gap-3 lg:col-span-2">
          <UiCardHeader class="flex flex-wrap items-center justify-between gap-3">
            <UiCardTitle class="text-sm">
              {{ t('admin.dashboard.trend') }}
            </UiCardTitle>
            <div
              v-if="METRICS.length > 1"
              class="max-w-full overflow-x-auto scrollbar-none"
            >
              <UiToggleGroup
                :model-value="metric"
                :aria-label="t('admin.dashboard.metric')"
                class="border border-border bg-card shadow-2xs"
                @update:model-value="setMetric"
              >
                <UiToggleGroupItem
                  v-for="m in METRICS"
                  :key="m.value"
                  :value="m.value"
                  class="h-7 px-2.5 text-xs font-semibold whitespace-nowrap data-[state=off]:hover:bg-primary/10 data-[state=off]:hover:text-primary data-[state=on]:bg-primary data-[state=on]:text-primary-foreground data-[state=on]:hover:bg-primary data-[state=on]:hover:text-primary-foreground"
                >
                  {{ m.label }}
                </UiToggleGroupItem>
              </UiToggleGroup>
            </div>
          </UiCardHeader>
          <UiCardContent>
            <UiSkeleton
              v-if="loading"
              class="h-[260px] rounded-xl"
            />
            <TrendChart
              v-else
              :points="trendPoints"
              :kind="metric === 'revenue' ? 'line' : 'bar'"
              :label="metricLabel"
              :format="trendFormat"
              :compact="metric === 'revenue'"
              :details="trendDetails"
            />
          </UiCardContent>
        </UiCard>

        <UiCard class="gap-3">
          <UiCardHeader class="flex items-center justify-between gap-3">
            <UiCardTitle class="text-sm">
              {{ t('admin.dashboard.pipeline') }}
            </UiCardTitle>
            <UiSkeleton
              v-if="loading"
              class="h-5 w-8 rounded-md"
            />
            <span
              v-else
              class="text-lg font-bold text-foreground tabular-nums"
            >{{ count(pipelineTotal) }}</span>
          </UiCardHeader>
          <UiCardContent>
            <div
              v-if="loading"
              class="space-y-3.5"
            >
              <div
                v-for="i in 5"
                :key="i"
                class="space-y-1.5"
              >
                <UiSkeleton class="h-4 w-2/3 rounded-md" />
                <UiSkeleton class="h-2 w-full rounded-md" />
              </div>
            </div>
            <HorizontalBarChart
              v-else
              :data="pipelineData"
              :empty-message="t('admin.dashboard.pipelineEmpty')"
              empty-icon="lucide:clipboard-check"
            />
          </UiCardContent>
        </UiCard>
      </div>

      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <UiCard
          v-for="block in breakdowns"
          :key="block.key"
          class="gap-3"
        >
          <UiCardHeader>
            <UiCardTitle class="text-sm">
              {{ block.title }}
            </UiCardTitle>
          </UiCardHeader>
          <UiCardContent>
            <div
              v-if="loading"
              class="space-y-3.5"
            >
              <div
                v-for="i in 5"
                :key="i"
                class="space-y-1.5"
              >
                <UiSkeleton class="h-4 w-3/4 rounded-md" />
                <UiSkeleton class="h-2 w-full rounded-md" />
              </div>
            </div>
            <HorizontalBarChart
              v-else
              :data="block.data"
              :empty-message="block.empty"
              :empty-icon="block.icon"
            />
          </UiCardContent>
        </UiCard>
      </div>

      <div
        v-if="showDelivery || showCarts"
        class="grid gap-4 md:grid-cols-2"
      >
        <UiCard
          v-if="showDelivery"
          class="gap-3"
        >
          <UiCardHeader>
            <UiCardTitle class="text-sm">
              {{ t('admin.dashboard.deliveryMethod') }}
            </UiCardTitle>
          </UiCardHeader>
          <UiCardContent class="grid grid-cols-2 gap-3">
            <template v-if="loading">
              <UiSkeleton
                v-for="i in 2"
                :key="i"
                class="h-[76px] rounded-xl"
              />
            </template>
            <template v-else>
              <div
                v-for="d in delivery"
                :key="d.key"
                class="rounded-xl border border-border bg-muted/30 p-3"
              >
                <div class="flex items-center gap-2 text-xs text-muted-foreground">
                  <Icon
                    :name="d.icon"
                    class="text-sm"
                  />
                  {{ d.label }}
                </div>
                <div class="mt-2 flex items-baseline gap-2">
                  <span class="text-xl font-bold text-foreground">{{ count(d.count) }}</span>
                  <span class="text-xs font-medium text-muted-foreground tabular-nums">{{ d.share }}%</span>
                </div>
              </div>
            </template>
          </UiCardContent>
        </UiCard>

        <UiCard
          v-if="showCarts"
          class="gap-3"
        >
          <UiCardHeader>
            <UiCardTitle class="text-sm">
              {{ t('admin.dashboard.inCarts') }}
            </UiCardTitle>
          </UiCardHeader>
          <UiCardContent class="grid grid-cols-3 gap-3">
            <template v-if="loading">
              <UiSkeleton
                v-for="i in 3"
                :key="i"
                class="h-[76px] rounded-xl"
              />
            </template>
            <template v-else-if="board?.open_carts">
              <div
                v-for="c in [
                  { key: 'carts', label: t('admin.dashboard.carts'), icon: 'lucide:shopping-cart', value: count(board.open_carts.carts) },
                  { key: 'items', label: t('admin.dashboard.cartItems'), icon: 'lucide:package', value: count(board.open_carts.items) },
                  { key: 'value', label: t('admin.dashboard.cartValue'), icon: 'lucide:wallet', value: formatMoney(board.open_carts.value) },
                ]"
                :key="c.key"
                class="min-w-0 rounded-xl border border-border bg-muted/30 p-3"
              >
                <div class="flex items-center gap-2 text-xs text-muted-foreground">
                  <Icon
                    :name="c.icon"
                    class="text-sm"
                  />
                  <span class="truncate">{{ c.label }}</span>
                </div>
                <p class="mt-2 truncate text-base font-bold text-foreground sm:text-xl">
                  {{ c.value }}
                </p>
              </div>
            </template>
          </UiCardContent>
        </UiCard>
      </div>
    </template>
  </div>
</template>
