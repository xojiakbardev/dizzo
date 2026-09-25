<script setup lang="ts">
// One order: the header row (number, status, date; refresh and the button
// for the next step on the right), the ordered items in the main column and,
// beside them, the customer, the delivery, the money, the way through
// production and the staff's own notes. AdminOrderSkeleton mirrors the layout.
import { getApiErrorMessage } from '~/composables/useApi';
import { getOrderStatusMeta } from '~/lib/orderStatus';
import type { DeliveryMethod, OrderStatus } from '~/types/commerce';
import { orderCoords, orderMapHref, orderPickupPlace } from '~/utils/orderPlace';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();

/** The step after `status`: pickup orders wait to be picked up, the rest to be delivered. */
function getNextStep(status: OrderStatus, deliveryMethod: DeliveryMethod): { status: OrderStatus; label: string; icon: string } | null {
  switch (status) {
    case 'NEW':
    case 'PAYMENT_PENDING':
      return { status: 'PAID', label: t('admin.orders.next.markPaid'), icon: 'lucide:banknote' };
    case 'PAID':
      return { status: 'MODERATED', label: t('admin.orders.next.moderate'), icon: 'lucide:shield-check' };
    case 'MODERATED':
      return { status: 'READY_FOR_PRODUCTION', label: t('admin.orders.next.sendToProduction'), icon: 'lucide:send' };
    case 'READY_FOR_PRODUCTION':
      return { status: 'IN_PRODUCTION', label: t('admin.orders.next.startProduction'), icon: 'lucide:play' };
    case 'IN_PRODUCTION':
      return { status: 'QUALITY_CHECK', label: t('admin.orders.next.qualityCheck'), icon: 'lucide:clipboard-check' };
    case 'QUALITY_CHECK':
      return deliveryMethod === 'PICKUP'
        ? { status: 'READY_FOR_PICKUP', label: t('admin.orders.next.readyForPickup'), icon: 'lucide:package-check' }
        : { status: 'READY_FOR_DELIVERY', label: t('admin.orders.next.readyForDelivery'), icon: 'lucide:package-check' };
    case 'READY_FOR_PICKUP':
    case 'READY_FOR_DELIVERY':
      return { status: 'COMPLETED', label: t('admin.orders.next.complete'), icon: 'lucide:circle-check' };
    default:
      return null;
  }
}

// How far along each status is on the "Jarayon" steps (cancelled: nowhere).
const STEP_OF: Partial<Record<OrderStatus, number>> = {
  NEW: 0, PAYMENT_PENDING: 0, PAID: 1, MODERATED: 2, READY_FOR_PRODUCTION: 3, IN_PRODUCTION: 4,
  QUALITY_CHECK: 5, READY_FOR_PICKUP: 6, READY_FOR_DELIVERY: 6, COMPLETED: 7,
};

const route = useRoute();
const orderId = computed(() => Number(route.params.id));

const orderQuery = useAdminOrder(orderId.value);
const order = computed(() => orderQuery.data.value ?? null);
useAdminCrumbs(() => (order.value ? [{ label: order.value.order_number }] : []));

const updateOrderMutation = useUpdateAdminOrder();
const productionMutation = useUpdateOrderProductionStatus();
const error = ref<string | null>(null);

const status = computed(() => (order.value ? getOrderStatusMeta(order.value.status) : null));
const nextStep = computed(() => (order.value ? getNextStep(order.value.status, order.value.delivery_method) : null));
const isPickup = computed(() => order.value?.delivery_method === 'PICKUP');
const pieces = computed(() => order.value?.items.reduce((sum, item) => sum + item.quantity, 0) ?? 0);
const pickup = computed(() => orderPickupPlace(order.value));
const mapPoint = computed(() => orderCoords(order.value));

const steps = computed<OrderStatus[]>(() => [
  'NEW', 'PAID', 'MODERATED', 'READY_FOR_PRODUCTION', 'IN_PRODUCTION', 'QUALITY_CHECK',
  isPickup.value ? 'READY_FOR_PICKUP' : 'READY_FOR_DELIVERY', 'COMPLETED',
]);
const currentStep = computed(() => (order.value ? STEP_OF[order.value.status] ?? -1 : -1));
/** The current step reads as the order's own status ("To‘lov kutilmoqda" on the first one). */
const stepLabel = (key: OrderStatus, i: number) => getOrderStatusMeta(i === currentStep.value ? order.value!.status : key).label;

// Cancellation modal state
const canCancel = computed(() => Boolean(order.value) && order.value?.status !== 'COMPLETED' && order.value?.status !== 'CANCELLED');
const cancelDialogOpen = ref(false);
const cancelling = ref(false);
const selectedReason = ref('');
const cancelCustomNote = ref('');

const cancelReasonOptions = computed(() => [
  { value: t('admin.orders.detail.reasonModerationFailed'), label: t('admin.orders.detail.reasonModerationFailed'), isModeration: true },
  { value: t('admin.orders.detail.reasonCustomerRequest'), label: t('admin.orders.detail.reasonCustomerRequest'), isModeration: false },
  { value: t('admin.orders.detail.reasonPaymentExpired'), label: t('admin.orders.detail.reasonPaymentExpired'), isModeration: false },
  { value: t('admin.orders.detail.reasonOther'), label: t('admin.orders.detail.reasonOther'), isModeration: false },
]);

function openCancelDialog() {
  selectedReason.value = t('admin.orders.detail.reasonModerationFailed');
  cancelCustomNote.value = '';
  cancelDialogOpen.value = true;
}

async function handleConfirmCancel() {
  if (!order.value) return;
  error.value = null;
  cancelling.value = true;
  try {
    const reasonText = cancelCustomNote.value.trim()
      ? `${selectedReason.value} (${cancelCustomNote.value.trim()})`
      : selectedReason.value;

    const prefix = `[${t('admin.orders.detail.cancelReason')}: ${reasonText}]`;
    const updatedNotes = order.value.admin_notes
      ? `${order.value.admin_notes}\n${prefix}`.trim()
      : prefix;

    await updateOrderMutation.mutateAsync({
      id: order.value.id,
      payload: {
        status: 'CANCELLED',
        admin_notes: updatedNotes,
      },
    });
    cancelDialogOpen.value = false;
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.orders.detail.statusFailed'));
  }
  finally {
    cancelling.value = false;
  }
}

const extractedCancelReason = computed(() => {
  if (!order.value) return null;
  const notes = order.value.admin_notes || '';
  const match = notes.match(/\[(?:Bekor qilish sababi|Причина отмены|Cancellation reason|Reason):\s*([^\]]+)\]/i);
  if (match) return match[1];
  if (notes.includes('Moderatsiyadan o\'tmadi') || notes.includes('Не прошло модерацию') || notes.includes('Did not pass moderation')) {
    return t('admin.orders.detail.reasonModerationFailed');
  }
  return null;
});

// Contact: what the customer typed at checkout, the account's own as a fallback.
const contactName = computed(() => order.value?.shipping_name || order.value?.customer.full_name || '');
const contactPhone = computed(() => order.value?.shipping_phone || order.value?.customer.phone_number || '');
const contactEmail = computed(() => order.value?.shipping_email || order.value?.customer.email || '');
const cityLine = computed(() => (order.value
  ? [order.value.shipping_city, order.value.shipping_state, order.value.shipping_postal_code, order.value.shipping_country].filter(Boolean).join(', ')
  : ''));

async function handleAdvance() {
  if (!order.value || !nextStep.value) return;
  error.value = null;
  try {
    await productionMutation.mutateAsync({ orderId: order.value.id, status: nextStep.value.status });
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.orders.detail.statusFailed'));
  }
}

// Staff notes: kept while being edited even if the order refetches meanwhile.
const NOTE_FIELDS = ['admin_notes', 'tracking_number', 'carrier'] as const;
const fromOrder = () => ({
  admin_notes: order.value?.admin_notes ?? '',
  tracking_number: order.value?.tracking_number ?? '',
  carrier: order.value?.carrier ?? '',
});
const notesForm = reactive(fromOrder());
const notesDirty = computed(() => Boolean(order.value) && NOTE_FIELDS.some(k => notesForm[k] !== (order.value?.[k] ?? '')));
const notesSaved = ref(false);
watch(order, (next, prev) => {
  if (next && (!prev || !notesDirty.value)) Object.assign(notesForm, fromOrder());
}, { immediate: true });
watch(notesForm, () => {
  notesSaved.value = false;
});

async function handleSaveNotes() {
  if (!order.value || !notesDirty.value) return;
  error.value = null;
  try {
    await updateOrderMutation.mutateAsync({ id: order.value.id, payload: { ...notesForm } });
    notesSaved.value = true;
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.common.saveFailed'));
  }
}
</script>

<template>
  <div>
    <AdminOrderSkeleton v-if="orderQuery.isLoading.value" />

    <EmptyState
      v-else-if="!order"
      :title="orderQuery.isError.value ? t('admin.orders.detail.loadFailed') : t('admin.orders.detail.notFound')"
      :description="orderQuery.isError.value ? t('admin.common.checkConnection') : t('admin.orders.detail.notFoundHint')"
      :icon="orderQuery.isError.value ? 'lucide:circle-alert' : 'lucide:clipboard-x'"
      :tone="orderQuery.isError.value ? 'destructive' : 'default'"
    >
      <div class="flex flex-wrap justify-center gap-2">
        <UiButton
          v-if="orderQuery.isError.value"
          variant="outline"
          size="sm"
          @click="orderQuery.refetch()"
        >
          <Icon
            name="lucide:refresh-cw"
            class="text-sm"
          />
          {{ t('admin.common.retry') }}
        </UiButton>
        <UiButton
          as-child
          variant="outline"
          size="sm"
        >
          <NuxtLink :to="localePath('/admin/orders')">
            <Icon
              name="lucide:arrow-left"
              class="text-sm"
            />
            {{ t('admin.orders.detail.orders') }}
          </NuxtLink>
        </UiButton>
      </div>
    </EmptyState>

    <div
      v-else
      class="space-y-4"
    >
      <AdminPageHeader
        :refreshing="orderQuery.isFetching.value"
        @refresh="orderQuery.refetch()"
      >
        <UiButton
          as-child
          variant="ghost"
          size="icon-sm"
        >
          <NuxtLink
            :to="localePath('/admin/orders')"
            :aria-label="t('admin.orders.detail.backToOrders')"
          >
            <Icon
              name="lucide:arrow-left"
              class="size-4"
            />
          </NuxtLink>
        </UiButton>
        <h1 class="text-xl font-bold leading-7 tabular-nums text-foreground">
          № {{ order.order_number }}
        </h1>
        <UiStatusBadge :tone="status!.tone">
          {{ status!.label }}
        </UiStatusBadge>
        <span class="text-sm text-muted-foreground">{{ formatDateTime(order.created_at) }}</span>
        <template #actions>
          <div class="flex items-center gap-2">
            <UiButton
              v-if="canCancel"
              variant="outline"
              size="sm"
              class="border-destructive/30 text-destructive hover:bg-destructive/10 hover:border-destructive/50"
              :disabled="productionMutation.isPending.value || cancelling"
              @click="openCancelDialog"
            >
              <Icon
                name="lucide:ban"
                class="size-4 mr-1.5"
              />
              {{ t('admin.orders.detail.cancelOrder') }}
            </UiButton>

            <UiButton
              v-if="nextStep"
              size="sm"
              :disabled="productionMutation.isPending.value || cancelling"
              @click="handleAdvance"
            >
              <Icon
                :name="productionMutation.isPending.value ? 'lucide:loader-2' : nextStep.icon"
                class="text-base"
                :class="productionMutation.isPending.value ? 'animate-spin' : ''"
              />
              {{ nextStep.label }}
            </UiButton>
          </div>
        </template>
      </AdminPageHeader>

      <UiAlert
        v-if="error"
        variant="destructive"
      >
        <Icon name="lucide:circle-alert" />
        {{ error }}
      </UiAlert>

      <div class="space-y-4">
        <!-- Jarayon is intentionally full width: all production steps remain legible. -->
        <UiCard class="gap-0 py-0">
          <UiCardHeader class="border-b py-3.5">
            <UiCardTitle class="font-semibold">
              {{ t('admin.orders.detail.progress') }}
            </UiCardTitle>
          </UiCardHeader>
          <UiCardContent class="space-y-4 py-4 text-sm">
            <UiAlert
              v-if="order.status === 'CANCELLED'"
              variant="destructive"
            >
              <Icon name="lucide:circle-x" />
              <div class="space-y-0.5">
                <div class="font-semibold">
                  {{ t('admin.orders.detail.cancelled') }}
                </div>
                <div
                  v-if="extractedCancelReason"
                  class="text-xs font-normal opacity-90"
                >
                  {{ t('admin.orders.detail.cancelReasonLabel') }}: {{ extractedCancelReason }}
                </div>
              </div>
            </UiAlert>

            <!-- Horizontal icon-based tracker -->
            <ol
              class="grid gap-y-4"
              :style="`grid-template-columns: repeat(${steps.length}, minmax(0, 1fr))`"
            >
              <li
                v-for="(key, i) in steps"
                :key="key"
                class="relative flex flex-col items-center gap-1.5 text-center"
                :aria-current="i === currentStep ? 'step' : undefined"
              >
                <!-- connecting line to the next step -->
                <span
                  v-if="i < steps.length - 1"
                  aria-hidden="true"
                  class="absolute top-[20px] left-[calc(50%+20px)] right-[calc(-50%+20px)] h-0.5 rounded-full transition-colors duration-300"
                  :class="i < currentStep ? 'bg-emerald-500' : 'bg-border/60'"
                />

                <!-- step icon circle -->
                <span
                  class="relative z-10 flex size-10 items-center justify-center rounded-full transition-all duration-300 select-none"
                  :class="[
                    i < currentStep
                      ? 'bg-emerald-500 text-white shadow-xs'
                      : i === currentStep
                        ? 'bg-primary text-primary-foreground shadow-md ring-4 ring-primary/25 scale-110'
                        : 'bg-muted/70 text-muted-foreground/60 border border-border/80',
                  ]"
                >
                  <Icon
                    :name="i < currentStep
                      ? 'lucide:check'
                      : key === 'NEW' ? 'lucide:shopping-bag'
                        : key === 'PAID' ? 'lucide:credit-card'
                          : key === 'MODERATED' ? 'lucide:shield-check'
                            : key === 'READY_FOR_PRODUCTION' ? 'lucide:send'
                              : key === 'IN_PRODUCTION' ? 'lucide:printer'
                                : key === 'QUALITY_CHECK' ? 'lucide:clipboard-check'
                                  : (key === 'READY_FOR_PICKUP' || key === 'READY_FOR_DELIVERY') ? 'lucide:package-check'
                                    : 'lucide:badge-check'
                    "
                    :class="i < currentStep ? 'size-5 stroke-[2.6]' : 'size-4.5 stroke-[2]'"
                  />
                </span>

                <!-- step label -->
                <span
                  class="text-[11px] sm:text-xs leading-tight transition-colors px-0.5"
                  :class="[
                    i === currentStep
                      ? 'font-bold text-foreground'
                      : i < currentStep
                        ? 'font-medium text-foreground/80'
                        : 'font-normal text-muted-foreground',
                  ]"
                >
                  {{ stepLabel(key, i) }}
                </span>
              </li>
            </ol>

            <div class="flex items-center gap-1.5 border-t pt-3 text-xs">
              <span class="shrink-0 text-muted-foreground">{{ t('admin.orders.detail.lastChange') }}:</span>
              <span class="truncate text-foreground">{{ formatDateTime(order.updated_at) }}</span>
            </div>
          </UiCardContent>
        </UiCard>

        <div class="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_20rem] xl:grid-cols-[minmax(0,1fr)_24rem]">
          <div class="min-w-0 space-y-4">
            <AdminOrderItem
              v-for="item in order.items"
              :key="item.id"
              :order-id="order.id"
              :item="item"
            />
          </div>

          <div class="min-w-0 space-y-4">
            <UiCard class="gap-0 py-0">
              <UiCardHeader class="border-b py-4">
                <UiCardTitle class="font-semibold">
                  {{ t('admin.orders.detail.customer') }}
                </UiCardTitle>
              </UiCardHeader>
              <UiCardContent class="space-y-4 py-4 text-sm">
                <dl class="space-y-2.5">
                  <div class="flex h-5 items-center gap-1.5">
                    <dt class="shrink-0 text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.name') }}
                    </dt>
                    <dd
                      class="truncate font-medium text-foreground"
                      :title="contactName"
                    >
                      {{ contactName || '—' }}
                    </dd>
                  </div>
                  <div
                    v-if="order.shipping_name && order.customer.full_name && order.shipping_name !== order.customer.full_name"
                    class="flex h-5 items-center gap-1.5"
                  >
                    <dt class="shrink-0 text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.accountOwner') }}
                    </dt>
                    <dd class="truncate text-foreground">
                      {{ order.customer.full_name }}
                    </dd>
                  </div>
                  <div class="flex h-5 items-center gap-1.5">
                    <dt class="shrink-0 text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.phone') }}
                    </dt>
                    <dd class="truncate font-medium text-foreground">
                      <a
                        v-if="contactPhone"
                        :href="`tel:${contactPhone.replace(/[^\d+]/g, '')}`"
                        class="hover:underline"
                      >{{ contactPhone }}</a>
                      <span
                        v-else
                        class="text-muted-foreground"
                      >{{ t('admin.orders.detail.notProvided') }}</span>
                    </dd>
                  </div>
                  <div
                    v-if="contactEmail"
                    class="flex h-5 items-center gap-1.5"
                  >
                    <dt class="shrink-0 text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.email') }}
                    </dt>
                    <dd class="min-w-0 truncate text-foreground">
                      <a
                        :href="`mailto:${contactEmail}`"
                        class="hover:underline"
                        :title="contactEmail"
                      >{{ contactEmail }}</a>
                    </dd>
                  </div>
                </dl>
                <div
                  v-if="order.customer_notes"
                  class="space-y-1 rounded-lg bg-muted/50 p-3"
                >
                  <p class="text-xs font-semibold text-muted-foreground">
                    {{ t('admin.orders.detail.customerNote') }}
                  </p>
                  <p class="whitespace-pre-line text-foreground">
                    {{ order.customer_notes }}
                  </p>
                </div>
              </UiCardContent>
            </UiCard>

            <UiCard class="gap-0 py-0">
              <UiCardHeader class="border-b py-4">
                <UiCardTitle class="font-semibold">
                  {{ t(`admin.orders.delivery.${isPickup ? 'PICKUP' : 'DELIVERY'}`) }}
                </UiCardTitle>
              </UiCardHeader>
              <UiCardContent class="space-y-3 py-4 text-sm">
                <div class="flex gap-2.5">
                  <Icon
                    :name="isPickup ? 'lucide:store' : 'lucide:map-pin'"
                    class="mt-0.5 shrink-0 text-base text-muted-foreground"
                  />
                  <div
                    v-if="isPickup"
                    class="min-w-0 space-y-0.5"
                  >
                    <p class="font-medium text-foreground">
                      {{ pickup.name }}
                    </p>
                    <p class="text-muted-foreground">
                      {{ pickup.address }}
                    </p>
                    <p
                      v-if="pickup.hours"
                      class="text-muted-foreground"
                    >
                      {{ pickup.hours }}
                    </p>
                  </div>
                  <div
                    v-else
                    class="min-w-0 space-y-0.5"
                  >
                    <p class="font-medium text-foreground">
                      {{ order.shipping_address || t('admin.orders.detail.noAddress') }}
                    </p>
                    <p
                      v-if="cityLine"
                      class="text-muted-foreground"
                    >
                      {{ cityLine }}
                    </p>
                  </div>
                </div>
                <UiButton
                  v-if="mapPoint"
                  as-child
                  variant="outline"
                  size="sm"
                  class="w-full"
                >
                  <a
                    :href="orderMapHref(mapPoint.lat, mapPoint.lon)"
                    target="_blank"
                    rel="noreferrer"
                  >
                    <Icon
                      name="lucide:map"
                      class="text-base"
                    />
                    {{ t('admin.orders.detail.viewOnMap') }}
                  </a>
                </UiButton>
              </UiCardContent>
            </UiCard>

            <UiCard class="gap-0 py-0">
              <UiCardHeader class="border-b py-4">
                <UiCardTitle class="font-semibold">
                  {{ t('admin.orders.detail.payment') }}
                </UiCardTitle>
              </UiCardHeader>
              <UiCardContent class="py-4 text-sm">
                <dl class="space-y-2.5">
                  <div class="flex h-5 items-center gap-1.5">
                    <dt class="text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.itemsPieces', { n: pieces }) }}
                    </dt>
                    <dd class="font-mono text-foreground">
                      {{ formatMoney(order.subtotal) }}
                    </dd>
                  </div>
                  <div class="flex h-5 items-center gap-1.5">
                    <dt class="text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.shipping') }}
                    </dt>
                    <dd class="font-mono text-foreground">
                      {{ formatMoney(order.shipping_cost) }}
                    </dd>
                  </div>
                  <div
                    v-if="Number(order.discount_amount) > 0"
                    class="flex h-5 items-center gap-1.5"
                  >
                    <dt class="text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.discount') }}
                    </dt>
                    <dd class="font-mono text-foreground">
                      −{{ formatMoney(order.discount_amount) }}
                    </dd>
                  </div>
                  <div
                    v-if="Number(order.tax_amount) > 0"
                    class="flex h-5 items-center gap-1.5"
                  >
                    <dt class="text-muted-foreground after:content-[':']">
                      {{ t('admin.orders.detail.tax') }}
                    </dt>
                    <dd class="font-mono text-foreground">
                      {{ formatMoney(order.tax_amount) }}
                    </dd>
                  </div>
                </dl>
                <UiSeparator class="my-3" />
                <div class="flex h-6 items-center gap-1.5">
                  <span class="font-semibold text-foreground after:content-[':']">{{ t('admin.orders.detail.total') }}</span>
                  <span class="font-mono text-base font-bold text-foreground">{{ formatMoney(order.total_amount) }}</span>
                </div>
              </UiCardContent>
            </UiCard>

            <UiCard class="gap-0 py-0">
              <UiCardHeader class="border-b py-4">
                <UiCardTitle class="font-semibold">
                  {{ t('admin.orders.detail.notesTitle') }}
                </UiCardTitle>
              </UiCardHeader>
              <UiCardContent class="py-4">
                <form
                  class="space-y-3"
                  @submit.prevent="handleSaveNotes"
                >
                  <UiField
                    :label="t('admin.orders.detail.internalNote')"
                    for="order-admin-notes"
                  >
                    <UiTextarea
                      id="order-admin-notes"
                      v-model="notesForm.admin_notes"
                      class="min-h-24"
                      :placeholder="t('admin.orders.detail.internalNoteHint')"
                    />
                  </UiField>
                  <UiField
                    :label="t('admin.orders.detail.carrier')"
                    for="order-carrier"
                  >
                    <UiInput
                      id="order-carrier"
                      v-model="notesForm.carrier"
                      :placeholder="t('admin.orders.detail.carrierExample')"
                    />
                  </UiField>
                  <UiField
                    :label="t('admin.orders.detail.tracking')"
                    for="order-tracking"
                  >
                    <UiInput
                      id="order-tracking"
                      v-model="notesForm.tracking_number"
                      :placeholder="t('admin.orders.detail.trackingExample')"
                    />
                  </UiField>
                  <UiButton
                    type="submit"
                    class="w-full"
                    :disabled="updateOrderMutation.isPending.value || !notesDirty"
                  >
                    <Icon
                      :name="updateOrderMutation.isPending.value ? 'lucide:loader-2' : notesSaved && !notesDirty ? 'lucide:check' : 'lucide:save'"
                      class="text-base"
                      :class="updateOrderMutation.isPending.value ? 'animate-spin' : ''"
                    />
                    {{ notesSaved && !notesDirty ? t('admin.common.saved') : t('admin.common.save') }}
                  </UiButton>
                </form>
              </UiCardContent>
            </UiCard>
          </div>
        </div>
      </div>

      <!-- Cancel order dialog -->
      <UiDialog v-model:open="cancelDialogOpen">
        <UiDialogContent class="sm:max-w-md">
          <UiDialogHeader>
            <UiDialogTitle class="flex items-center gap-2 text-destructive">
              <Icon
                name="lucide:alert-triangle"
                class="size-5"
              />
              <span>{{ t('admin.orders.detail.cancelOrder') }}</span>
            </UiDialogTitle>
            <UiDialogDescription>
              {{ t('admin.orders.detail.cancelConfirm') }}
            </UiDialogDescription>
          </UiDialogHeader>

          <div class="space-y-4 py-2">
            <div class="space-y-2">
              <label class="text-xs font-semibold text-foreground">
                {{ t('admin.orders.detail.cancelReason') }}
              </label>
              <div class="grid grid-cols-1 gap-2">
                <button
                  v-for="r in cancelReasonOptions"
                  :key="r.value"
                  type="button"
                  class="flex items-center justify-between rounded-xl border p-3 text-left text-xs font-medium transition outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  :class="selectedReason === r.value ? 'border-destructive bg-destructive/5 text-destructive ring-1 ring-destructive' : 'border-border hover:bg-muted text-foreground'"
                  @click="selectedReason = r.value"
                >
                  <div class="flex items-center gap-2.5">
                    <Icon
                      :name="selectedReason === r.value ? 'lucide:check-circle-2' : 'lucide:circle'"
                      class="size-4 shrink-0"
                      :class="selectedReason === r.value ? 'text-destructive' : 'text-muted-foreground'"
                    />
                    <span>{{ r.label }}</span>
                  </div>
                  <span
                    v-if="r.isModeration"
                    class="rounded-md bg-amber-500/15 text-amber-700 dark:text-amber-400 px-1.5 py-0.5 text-[10px] font-semibold"
                  >
                    Tavsiya
                  </span>
                </button>
              </div>
            </div>

            <div class="space-y-1.5">
              <label class="text-xs font-medium text-muted-foreground">
                {{ t('admin.orders.detail.cancelReasonPlaceholder') }}
              </label>
              <UiTextarea
                v-model="cancelCustomNote"
                rows="2"
                :placeholder="t('admin.orders.detail.cancelReasonPlaceholder')"
                class="text-xs"
              />
            </div>
          </div>

          <UiDialogFooter class="gap-2 sm:gap-0">
            <UiButton
              variant="outline"
              @click="cancelDialogOpen = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              variant="destructive"
              :disabled="cancelling"
              @click="handleConfirmCancel"
            >
              <Icon
                v-if="cancelling"
                name="lucide:loader-2"
                class="size-4 mr-1.5 animate-spin"
              />
              {{ t('admin.orders.detail.cancelSubmit') }}
            </UiButton>
          </UiDialogFooter>
        </UiDialogContent>
      </UiDialog>
    </div>
  </div>
</template>
