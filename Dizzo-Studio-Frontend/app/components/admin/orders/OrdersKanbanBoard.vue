<script setup lang="ts">
import { useUpdateAdminOrder } from '~/composables/queries/useAdminOrders';
import { getOrderStatusMeta } from '~/lib/orderStatus';
import type { OrderStatus, OrderSummary } from '~/types/commerce';

const props = defineProps<{
  orders: OrderSummary[];
  isLoading?: boolean;
}>();

const emit = defineEmits<{
  'refresh': [];
}>();

const localePath = useLocalePath();
const updateOrderMutation = useUpdateAdminOrder();

interface KanbanColumn {
  key: string;
  title: string;
  icon: string;
  colorClass: string;
  badgeClass: string;
  targetStatus: OrderStatus | ((order: OrderSummary) => OrderStatus);
  statuses: OrderStatus[];
}

const columns: KanbanColumn[] = [
  {
    key: 'new',
    title: 'Yangi buyurtmalar',
    icon: 'lucide:inbox',
    colorClass: 'border-blue-500/30 bg-blue-500/5',
    badgeClass: 'bg-blue-500/15 text-blue-600 dark:text-blue-400',
    targetStatus: 'READY_FOR_PRODUCTION',
    statuses: ['NEW', 'PAYMENT_PENDING', 'PAID', 'MODERATED', 'READY_FOR_PRODUCTION'],
  },
  {
    key: 'in_production',
    title: 'Ishlab chiqarishda',
    icon: 'lucide:printer',
    colorClass: 'border-amber-500/30 bg-amber-500/5',
    badgeClass: 'bg-amber-500/15 text-amber-600 dark:text-amber-400',
    targetStatus: 'IN_PRODUCTION',
    statuses: ['IN_PRODUCTION'],
  },
  {
    key: 'quality_check',
    title: 'Sifat nazorati',
    icon: 'lucide:check-circle',
    colorClass: 'border-purple-500/30 bg-purple-500/5',
    badgeClass: 'bg-purple-500/15 text-purple-600 dark:text-purple-400',
    targetStatus: 'QUALITY_CHECK',
    statuses: ['QUALITY_CHECK'],
  },
  {
    key: 'ready',
    title: 'Tayyor / Olib ketish',
    icon: 'lucide:package-check',
    colorClass: 'border-emerald-500/30 bg-emerald-500/5',
    badgeClass: 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400',
    targetStatus: (o: OrderSummary) => o.delivery_method === 'PICKUP' ? 'READY_FOR_PICKUP' : 'READY_FOR_DELIVERY',
    statuses: ['READY_FOR_PICKUP', 'READY_FOR_DELIVERY'],
  },
  {
    key: 'completed',
    title: 'Yakunlangan',
    icon: 'lucide:archive',
    colorClass: 'border-zinc-500/30 bg-zinc-500/5',
    badgeClass: 'bg-zinc-500/15 text-zinc-600 dark:text-zinc-400',
    targetStatus: 'COMPLETED',
    statuses: ['COMPLETED'],
  },
];

// Map orders into columns
const ordersByColumn = computed(() => {
  const map: Record<string, OrderSummary[]> = {
    new: [],
    in_production: [],
    quality_check: [],
    ready: [],
    completed: [],
  };

  props.orders.forEach((order) => {
    const col = columns.find(c => c.statuses.includes(order.status));
    if (col) {
      map[col.key]?.push(order);
    } else {
      map.new?.push(order);
    }
  });

  return map;
});

// Drag and drop state
const draggedOrder = ref<OrderSummary | null>(null);
const dragOverColumn = ref<string | null>(null);
const errorMessage = ref<string | null>(null);

function handleDragStart(event: DragEvent, order: OrderSummary) {
  draggedOrder.value = order;
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', String(order.id));
  }
}

function handleDragEnd() {
  draggedOrder.value = null;
  dragOverColumn.value = null;
}

function handleDragOver(event: DragEvent, colKey: string) {
  event.preventDefault();
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move';
  }
  dragOverColumn.value = colKey;
}

function handleDragLeave(_event: DragEvent, colKey: string) {
  if (dragOverColumn.value === colKey) {
    dragOverColumn.value = null;
  }
}

async function moveOrderToStatus(order: OrderSummary, targetStatus: OrderStatus) {
  if (order.status === targetStatus) return;
  errorMessage.value = null;
  try {
    await updateOrderMutation.mutateAsync({
      id: order.id,
      payload: { status: targetStatus },
    });
    emit('refresh');
  } catch (err: any) {
    errorMessage.value = err?.data?.detail || 'Buyurtma holatini o\'zgartirishda xatolik yuz berdi';
    setTimeout(() => {
      errorMessage.value = null;
    }, 4000);
  }
}

async function handleDrop(event: DragEvent, col: KanbanColumn) {
  event.preventDefault();
  dragOverColumn.value = null;
  const order = draggedOrder.value;
  if (!order) return;

  const targetStatus = typeof col.targetStatus === 'function' ? col.targetStatus(order) : col.targetStatus;
  await moveOrderToStatus(order, targetStatus);
  draggedOrder.value = null;
}

function formatPrice(amount: string | number) {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  if (isNaN(num)) return '0';
  return num.toLocaleString('uz-UZ') + ' so\'m';
}

function formatTime(dateStr: string) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Next / Prev step helper for 1-click move
function getAdjacentStatus(currentStatus: OrderStatus, direction: 'next' | 'prev', order: OrderSummary): OrderStatus | null {
  const currentIdx = columns.findIndex(c => c.statuses.includes(currentStatus));
  if (currentIdx === -1) return null;
  const targetIdx = direction === 'next' ? currentIdx + 1 : currentIdx - 1;
  if (targetIdx < 0 || targetIdx >= columns.length) return null;
  const targetCol = columns[targetIdx];
  if (!targetCol) return null;
  return typeof targetCol.targetStatus === 'function' ? targetCol.targetStatus(order) : targetCol.targetStatus;
}
</script>

<template>
  <div class="space-y-4">
    <!-- Error notification banner -->
    <transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 -translate-y-2"
      enter-to-class="opacity-100 translate-y-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100 translate-y-0"
      leave-to-class="opacity-0 -translate-y-2"
    >
      <div
        v-if="errorMessage"
        class="flex items-center gap-3 rounded-2xl border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive shadow-sm"
      >
        <Icon
          name="lucide:circle-alert"
          class="size-5 shrink-0"
        />
        <p class="flex-1 font-medium">{{ errorMessage }}</p>
        <button
          class="rounded-lg p-1 hover:bg-destructive/20"
          @click="errorMessage = null"
        >
          <Icon
            name="lucide:x"
            class="size-4"
          />
        </button>
      </div>
    </transition>

    <!-- Kanban Columns Grid -->
    <div class="flex gap-4 overflow-x-auto pb-4 pt-1 snap-x">
      <div
        v-for="col in columns"
        :key="col.key"
        class="flex w-80 shrink-0 flex-col rounded-2xl border bg-muted/40 transition-all duration-200 snap-start"
        :class="[
          dragOverColumn === col.key
            ? 'border-primary ring-2 ring-primary/40 bg-primary/5 scale-[1.01]'
            : 'border-border/70',
        ]"
        @dragover="handleDragOver($event, col.key)"
        @dragenter.prevent="dragOverColumn = col.key"
        @dragleave="handleDragLeave($event, col.key)"
        @drop="handleDrop($event, col)"
      >
        <!-- Column Header -->
        <div class="flex items-center justify-between border-b border-border/60 px-4 py-3">
          <div class="flex items-center gap-2">
            <div
              class="flex size-7 items-center justify-center rounded-lg"
              :class="col.badgeClass"
            >
              <Icon
                name="lucide:clipboard-list"
                class="size-4"
              />
            </div>
            <h3 class="text-sm font-semibold text-foreground">
              {{ col.title }}
            </h3>
          </div>
          <span
            class="rounded-full px-2 py-0.5 text-xs font-bold"
            :class="col.badgeClass"
          >
            {{ ordersByColumn[col.key]?.length || 0 }}
          </span>
        </div>

        <!-- Cards List -->
        <div class="flex flex-1 flex-col gap-3 p-3 min-h-[500px] overflow-y-auto max-h-[calc(100vh-280px)]">
          <div
            v-if="!ordersByColumn[col.key]?.length"
            class="flex flex-1 flex-col items-center justify-center rounded-xl border border-dashed border-border/60 p-6 text-center text-xs text-muted-foreground"
          >
            <Icon
              name="lucide:inbox"
              class="size-8 opacity-40 mb-1.5"
            />
            <p>Hozircha buyurtma yo'q</p>
            <p class="text-[11px] opacity-75 mt-0.5">Ushbu ustunga buyurtmani surib o'tkazishingiz mumkin</p>
          </div>

          <div
            v-for="order in ordersByColumn[col.key]"
            :key="order.id"
            draggable="true"
            class="group relative flex flex-col gap-2.5 rounded-xl border border-border/80 bg-white dark:bg-card p-3.5 shadow-xs transition-all duration-200 hover:shadow-md hover:border-primary/50 cursor-grab active:cursor-grabbing"
            :class="[
              draggedOrder?.id === order.id ? 'opacity-50 scale-95 border-primary ring-2 ring-primary/30' : '',
            ]"
            @dragstart="handleDragStart($event, order)"
            @dragend="handleDragEnd"
          >
            <!-- Card Header: Order Number & Delivery Badge -->
            <div class="flex items-center justify-between gap-2">
              <NuxtLink
                :to="localePath(`/admin/orders/${order.id}`)"
                class="font-mono text-xs font-bold text-primary hover:underline"
              >
                #{{ order.order_number }}
              </NuxtLink>

              <span
                v-if="order.delivery_method === 'PICKUP'"
                class="flex items-center gap-1 rounded-md bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-amber-600 dark:text-amber-400"
              >
                <Icon
                  name="lucide:store"
                  class="size-3"
                />
                Olib ketish
              </span>
              <span
                v-else
                class="flex items-center gap-1 rounded-md bg-blue-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-blue-600 dark:text-blue-400"
              >
                <Icon
                  name="lucide:truck"
                  class="size-3"
                />
                Yetkazish
              </span>
            </div>

            <!-- Customer Details -->
            <div class="flex items-center gap-1.5 text-xs text-foreground font-medium">
              <Icon
                name="lucide:user"
                class="size-3.5 text-muted-foreground shrink-0"
              />
              <span class="truncate">{{ order.customer_name || 'Mijoz' }}</span>
            </div>

            <!-- Items count / preview -->
            <div class="flex items-center justify-between rounded-lg bg-muted/40 px-2.5 py-1.5 text-xs text-muted-foreground">
              <span class="flex items-center gap-1">
                <Icon
                  name="lucide:package"
                  class="size-3.5 text-foreground/60"
                />
                {{ order.item_count || 1 }} ta mahsulot
              </span>
              <span class="font-semibold text-foreground">
                {{ formatPrice(order.total_amount) }}
              </span>
            </div>

            <!-- Card Footer: Time & Quick Move Actions -->
            <div class="flex items-center justify-between border-t border-border/50 pt-2 text-[11px] text-muted-foreground">
              <span class="flex items-center gap-1">
                <Icon
                  name="lucide:clock"
                  class="size-3"
                />
                {{ formatTime(order.created_at) }}
              </span>

              <div class="flex items-center gap-1 opacity-80 group-hover:opacity-100 transition-opacity">
                <!-- Move back button -->
                <button
                  v-if="getAdjacentStatus(order.status, 'prev', order)"
                  type="button"
                  title="Oldingi bosqichga qaytarish"
                  class="flex size-6 items-center justify-center rounded-md border border-border bg-background text-muted-foreground hover:text-foreground hover:bg-muted"
                  @click.stop="moveOrderToStatus(order, getAdjacentStatus(order.status, 'prev', order)!)"
                >
                  <Icon
                    name="lucide:chevron-left"
                    class="size-3.5"
                  />
                </button>

                <!-- Move next button -->
                <button
                  v-if="getAdjacentStatus(order.status, 'next', order)"
                  type="button"
                  title="Keyingi bosqichga o'tkazish"
                  class="flex items-center gap-1 rounded-md bg-primary/10 px-2 py-0.5 text-[11px] font-semibold text-primary hover:bg-primary/20"
                  @click.stop="moveOrderToStatus(order, getAdjacentStatus(order.status, 'next', order)!)"
                >
                  Oldinga
                  <Icon
                    name="lucide:chevron-right"
                    class="size-3"
                  />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
