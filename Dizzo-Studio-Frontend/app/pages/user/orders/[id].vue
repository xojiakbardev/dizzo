<script setup lang="ts">
// One of the customer's orders, kept short: the number, date and status;
// a small tracker with the next step and what can be done now (a review,
// Telegram, cancelling while nobody has confirmed it); the items; beside
// them the money and the delivery. The app's order screen has the same
// sections in the same order.
import { ApiError, getApiErrorMessage } from '~/composables/useApi';
import {
  getOrderStatusMeta, orderNextStep, orderPaymentMeta, orderShowsProduction, PRODUCTION_LABELS, SUPPORT_TELEGRAM_URL,
} from '~/lib/orderStatus';
import { METHOD_INFO } from '~/types/catalog';
import type { OrderItem } from '~/types/commerce';
import { orderCoords, orderCustomerAddress, orderMapHref, orderPickupPlace } from '~/utils/orderPlace';

const PRODUCTION_TONES = { PENDING: 'neutral', PRINTING: 'brand', PRINTED: 'info', PACKED: 'success' } as const satisfies Record<OrderItem['production_status'], string>;

definePageMeta({ layout: 'cabinet' });

const { t } = useI18n();
const localePath = useLocalePath();
const route = useRoute();
const orderLookup = computed(() => String(route.params.id));

const orderQuery = useOrder(orderLookup.value);
const cancelMutation = useCancelOrder();
const reviewsQuery = useMyReviews();

const order = computed(() => orderQuery.data.value ?? null);
const loading = computed(() => orderQuery.isLoading.value);
const notFound = computed(() => orderQuery.error.value instanceof ApiError && orderQuery.error.value.status === 404);
useAdminCrumbs(() => [{ label: `№${order.value?.order_number ?? orderLookup.value}` }]);

const statusMeta = computed(() => getOrderStatusMeta(order.value?.status || 'NEW'));
const payment = computed(() => (order.value ? orderPaymentMeta(order.value.status) : null));
const nextStep = computed(() => (order.value ? orderNextStep(order.value.status) : null));
const isPickup = computed(() => order.value?.delivery_method === 'PICKUP');
const isCompleted = computed(() => order.value?.status === 'COMPLETED');
const isCancelled = computed(() => order.value?.status === 'CANCELLED');
const inProgress = computed(() => Boolean(order.value) && !isCompleted.value && !isCancelled.value);
// Only an order nobody has confirmed yet can be cancelled by the customer.
const canCancel = computed(() => order.value?.status === 'NEW');
const pieces = computed(() => order.value?.items.reduce((sum, item) => sum + item.quantity, 0) ?? 0);
const review = computed(() => reviewsQuery.data.value?.find(r => r.order_id === order.value?.id) ?? null);
const canReview = computed(() => isCompleted.value && reviewsQuery.isSuccess.value && !review.value);
const showProduction = computed(() => (order.value ? orderShowsProduction(order.value.status) : false));

const extractedCancelReason = computed(() => {
  if (!order.value) return null;
  const notes = order.value.admin_notes || order.value.customer_notes || '';
  const match = notes.match(/\[(?:Bekor qilish sababi|Причина отмены|Cancellation reason|Reason):\s*([^\]]+)\]/i);
  if (match) return match[1];
  if (notes.includes("Moderatsiyadan o'tmadi") || notes.includes("Не прошло модерацию") || notes.includes("Did not pass moderation")) {
    return "Moderatsiyadan o'tmadi";
  }
  return null;
});

const pickup = computed(() => orderPickupPlace(order.value));
const address = computed(() => {
  if (!order.value) return '';
  if (isPickup.value) return [pickup.value.name, pickup.value.address].filter(Boolean).join(', ');
  return orderCustomerAddress(order.value);
});
const point = computed(() => orderCoords(order.value));
const addressOpen = ref(false);
const notesOpen = ref(false);

const confirmCancel = ref(false);
const reviewOpen = ref(false);
const actionError = ref<string | null>(null);

const isPaymentSuccessNotice = computed(() => route.query.payment === 'success');
const canPayWithClick = computed(() => {
  const s = order.value?.status;
  return s === 'NEW' || s === 'PAYMENT_PENDING';
});
const clickPaymentMutation = useClickPaymentUrl();
const isPaying = computed(() => clickPaymentMutation.isPending.value);

async function handlePayWithClick() {
  if (!order.value || isPaying.value) return;
  actionError.value = null;
  try {
    const res = await clickPaymentMutation.mutateAsync(order.value.order_number);
    if (res?.payment_url) {
      window.location.href = res.payment_url;
    }
  }
  catch (paymentError) {
    actionError.value = getApiErrorMessage(paymentError, t('user.checkout.submitError'));
  }
}

async function handleCancel() {
  if (!order.value) return;
  actionError.value = null;
  try {
    await cancelMutation.mutateAsync(order.value.id);
    await orderQuery.refetch();
  }
  catch (cancelError) {
    actionError.value = getApiErrorMessage(cancelError, t('user.order.cancelError'));
  }
  finally {
    confirmCancel.value = false;
  }
}
</script>

<template>
  <div>
    <!-- loading: the same cards in grey -->
    <div
      v-if="loading"
      aria-busy="true"
    >
      <div class="flex items-center gap-3">
        <div class="size-8 rounded-lg bg-muted shrink-0" />
        <div class="space-y-1.5 min-w-0 flex-1">
          <UiSkeleton class="h-6 w-44 sm:w-56" />
          <UiSkeleton class="h-3.5 w-36" />
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <UiSkeleton class="h-6 w-24 rounded-4xl" />
          <UiSkeleton class="size-8 rounded-lg" />
        </div>
      </div>
      <div class="mt-4 space-y-4">
        <UiCard class="gap-4 py-5 shadow-xs">
          <UiCardContent class="space-y-4 px-5">
            <CommerceOrderTracker
              skeleton
              spacious
            />
            <UiSkeleton class="h-12 w-full rounded-xl" />
          </UiCardContent>
        </UiCard>
        <div class="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_26rem] xl:grid-cols-[minmax(0,1fr)_28rem] lg:gap-6">
          <div class="min-w-0 space-y-4">
          <UiCard class="gap-4 py-5 shadow-xs">
            <UiCardContent class="space-y-4 px-5">
              <UiSkeleton class="h-4 w-28" />
              <div
                v-for="i in 2"
                :key="i"
                class="flex gap-3"
              >
                <CommerceMockupGallery
                  layout="swipe"
                  skeleton
                  class="w-24 shrink-0 sm:w-28"
                />
                <div class="flex-1 space-y-2">
                  <UiSkeleton class="h-4 w-40 max-w-full" />
                  <div class="flex gap-1.5">
                    <UiSkeleton class="h-5 w-14 rounded-4xl" />
                    <UiSkeleton class="h-5 w-16 rounded-4xl" />
                  </div>
                  <UiSkeleton class="h-4 w-24" />
                </div>
              </div>
            </UiCardContent>
          </UiCard>
        </div>
        <div class="space-y-4">
          <UiCard
            v-for="i in 2"
            :key="i"
            class="gap-3 py-5 shadow-xs"
          >
            <UiCardContent class="space-y-3 px-5">
              <UiSkeleton class="h-4 w-24" />
              <UiSkeleton class="h-3.5 w-full" />
              <UiSkeleton class="h-3.5 w-2/3" />
            </UiCardContent>
          </UiCard>
        </div>
      </div>
      </div>
    </div>

    <EmptyState
      v-else-if="notFound || (!order && !orderQuery.isError.value)"
      icon="lucide:search-x"
      :title="t('user.order.notFound')"
    >
      <UiButton
        as-child
        variant="outline"
      >
        <NuxtLink :to="localePath('/user/orders')">
          {{ t('user.common.allOrders') }}
        </NuxtLink>
      </UiButton>
    </EmptyState>

    <EmptyState
      v-else-if="!order"
      icon="lucide:cloud-alert"
      tone="destructive"
      :title="t('user.order.loadError')"
    >
      <UiButton
        variant="outline"
        :disabled="orderQuery.isFetching.value"
        @click="orderQuery.refetch()"
      >
        <Icon
          name="lucide:refresh-cw"
          class="text-base"
          :class="orderQuery.isFetching.value ? 'animate-spin' : ''"
        />
        {{ t('user.order.retry') }}
      </UiButton>
    </EmptyState>

    <template v-else>
      <header class="flex items-center gap-3">
        <UiButton
          as-child
          variant="ghost"
          size="icon-sm"
          class="shrink-0 -ml-1"
          :aria-label="t('user.common.allOrders')"
        >
          <NuxtLink :to="localePath('/user/orders')">
            <Icon
              name="lucide:arrow-left"
              class="size-4"
            />
          </NuxtLink>
        </UiButton>
        <div class="flex min-w-0 flex-1 flex-col gap-0.5">
          <h1 class="text-xl font-bold leading-7 text-foreground sm:text-2xl truncate">
            {{ t('user.order.title') }} <span class="font-mono">№{{ order.order_number }}</span>
          </h1>
          <span class="text-xs sm:text-sm text-muted-foreground">
            {{ formatDateTimeShort(order.created_at) }}
          </span>
        </div>

        <div class="ml-auto flex shrink-0 items-center gap-2">
          <UiStatusBadge
            :tone="statusMeta.tone"
            class="px-2.5 py-1 text-xs font-semibold shadow-2xs"
          >
            {{ statusMeta.label }}
          </UiStatusBadge>

          <UiDropdownMenu>
            <UiDropdownMenuTrigger as-child>
              <UiButton
                variant="outline"
                size="icon-sm"
                class="size-8 rounded-lg shadow-2xs"
                :aria-label="t('user.order.more')"
                :disabled="cancelMutation.isPending.value || isPaying"
              >
                <Icon
                  :name="cancelMutation.isPending.value || isPaying ? 'lucide:loader-2' : 'lucide:ellipsis'"
                  class="size-4"
                  :class="cancelMutation.isPending.value || isPaying ? 'animate-spin' : ''"
                />
              </UiButton>
            </UiDropdownMenuTrigger>
            <UiDropdownMenuContent
              align="end"
              class="w-56"
            >
              <UiDropdownMenuItem
                v-if="canPayWithClick"
                :disabled="isPaying"
                class="cursor-pointer font-medium text-[#0073FF] focus:text-[#0073FF]"
                @select="handlePayWithClick"
              >
                <Icon
                  name="lucide:credit-card"
                  class="mr-2 size-4 text-[#0073FF]"
                />
                <span>{{ t('user.order.payWithClick') }}</span>
              </UiDropdownMenuItem>

              <UiDropdownMenuItem as-child>
                <a
                  :href="SUPPORT_TELEGRAM_URL"
                  target="_blank"
                  rel="noopener"
                  class="flex items-center cursor-pointer"
                >
                  <Icon
                    name="lucide:send"
                    class="mr-2 size-4"
                  />
                  <span>{{ t('user.order.telegram') }}</span>
                </a>
              </UiDropdownMenuItem>

              <UiDropdownMenuItem
                v-if="canReview"
                class="cursor-pointer"
                @select="reviewOpen = true"
              >
                <Icon
                  name="lucide:message-square-heart"
                  class="mr-2 size-4"
                />
                <span>{{ t('user.order.leaveReview') }}</span>
              </UiDropdownMenuItem>

              <UiDropdownMenuSeparator v-if="canCancel" />

              <UiDropdownMenuItem
                v-if="canCancel"
                variant="destructive"
                class="cursor-pointer items-start"
                @select="confirmCancel = true"
              >
                <Icon
                  name="lucide:x-circle"
                  class="mr-2 mt-0.5 size-4"
                />
                <span class="flex flex-col">
                  {{ t('user.common.cancel') }}
                  <span class="text-xs text-muted-foreground">{{ t('user.order.onlyNew') }}</span>
                </span>
              </UiDropdownMenuItem>
            </UiDropdownMenuContent>
          </UiDropdownMenu>
        </div>
      </header>

      <UiAlert
        v-if="isPaymentSuccessNotice"
        class="mt-4 border-emerald-500/30 bg-emerald-500/10 text-emerald-800 dark:text-emerald-300"
      >
        <Icon
          name="lucide:check-circle-2"
          class="text-lg text-emerald-600 dark:text-emerald-400"
        />
        <UiAlertDescription class="font-medium">
          {{ t('user.order.clickPaymentSuccess') }}
        </UiAlertDescription>
      </UiAlert>

      <div class="mt-4 space-y-4">
        <!-- where it is now and what can be done: it spans the entire row. -->
        <UiCard class="gap-4 py-5 shadow-xs">
          <UiCardContent class="space-y-4 px-5">
              <div
                v-if="isCancelled"
                class="flex items-center gap-3 rounded-xl bg-destructive/8 px-4 py-3 text-destructive"
              >
                <Icon
                  name="lucide:circle-x"
                  class="shrink-0 text-xl"
                />
                <div class="space-y-0.5">
                  <div class="font-semibold">{{ t('user.order.cancelled') }}</div>
                  <div
                    v-if="extractedCancelReason"
                    class="text-xs font-normal opacity-90"
                  >
                    {{ t('user.order.cancelledReason', { reason: extractedCancelReason }) }}
                  </div>
                </div>
              </div>
              <CommerceOrderTracker
                v-else
                :status="order.status"
                spacious
              />

              <div
                v-if="nextStep"
                class="flex items-center gap-3 rounded-xl border border-primary/20 bg-primary/5 px-3.5 py-2.5 sm:px-4 sm:py-3 text-sm text-foreground shadow-2xs"
              >
                <div class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <Icon
                    :name="order.status === 'READY_FOR_PICKUP' ? 'lucide:store' : order.status === 'READY_FOR_DELIVERY' ? 'lucide:truck' : order.status === 'MODERATED' ? 'lucide:shield-check' : 'lucide:clock'"
                    class="size-4.5"
                  />
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-xs sm:text-sm font-medium text-foreground leading-snug">
                    {{ nextStep }}
                  </p>
                </div>
              </div>

              <!-- the review, once written -->
              <div
                v-if="review"
                class="rounded-xl border border-border p-3"
              >
                <div class="flex items-center justify-between gap-2">
                  <span class="text-sm font-semibold text-foreground">{{ t('user.order.yourReview') }}</span>
                  <UiStatusBadge :tone="review.status === 'approved' ? 'success' : review.status === 'pending' ? 'warn' : 'neutral'">
                    {{ t(`user.reviewStatus.${review.status}`) }}
                  </UiStatusBadge>
                </div>
                <StarRating
                  :value="review.rating"
                  class="mt-1.5 h-4 w-4"
                />
                <p class="mt-1.5 line-clamp-2 text-sm text-muted-foreground">
                  {{ review.text }}
                </p>
                <div
                  v-if="review.photos.length"
                  class="mt-2 flex flex-wrap gap-1.5"
                >
                  <MediaThumb
                    v-for="url in review.photos"
                    :key="url"
                    :src="url"
                    class="size-12 rounded-lg"
                  />
                </div>
              </div>

              <UiAlert
                v-if="actionError"
                variant="destructive"
              >
                <Icon name="lucide:circle-alert" />
                <UiAlertDescription>{{ actionError }}</UiAlertDescription>
              </UiAlert>
          </UiCardContent>
        </UiCard>

        <div class="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_26rem] xl:grid-cols-[minmax(0,1fr)_28rem] lg:gap-6">
          <div class="min-w-0">
          <!-- the items -->
          <!-- the items: rich detailed cards with 3D simulation -->
          <div class="space-y-3">
            <div class="flex items-center justify-between px-1">
              <h2 class="text-base sm:text-lg font-bold text-foreground">
                {{ t('user.common.products') }}
              </h2>
              <span class="text-sm tabular-nums text-muted-foreground">{{ t('user.common.pieces', pieces) }}</span>
            </div>

            <div class="space-y-4">
              <CommerceUserOrderItem
                v-for="item in order.items"
                :key="item.id"
                :item="item"
                :show-production="showProduction"
              />
            </div>
          </div>
          </div>

          <aside class="space-y-4 lg:sticky lg:top-4">
          <!-- the money -->
          <UiCard class="gap-3 py-5 shadow-xs">
            <UiCardHeader class="px-5">
              <UiCardTitle class="font-semibold">
                {{ t('user.order.payment') }}
              </UiCardTitle>
              <UiCardAction v-if="payment">
                <UiStatusBadge :tone="payment.tone">
                  {{ payment.label }}
                </UiStatusBadge>
              </UiCardAction>
            </UiCardHeader>
            <UiCardContent class="space-y-2 px-5 text-sm">
              <div class="flex justify-between gap-3">
                <span class="text-muted-foreground">{{ t('user.common.products') }}</span>
                <span class="tabular-nums text-foreground">{{ formatMoney(order.subtotal) }}</span>
              </div>
              <div class="flex justify-between gap-3">
                <span class="text-muted-foreground">{{ t('user.common.deliveryShort') }}</span>
                <span
                  v-if="Number.parseFloat(order.shipping_cost) > 0"
                  class="tabular-nums text-foreground"
                >{{ formatMoney(order.shipping_cost) }}</span>
                <span
                  v-else
                  class="text-foreground"
                >{{ isPickup ? t('user.common.free') : t('user.order.negotiated') }}</span>
              </div>
              <div
                v-if="Number.parseFloat(order.discount_amount) > 0"
                class="flex justify-between gap-3"
              >
                <span class="text-muted-foreground">{{ t('user.order.discount') }}</span>
                <span class="tabular-nums text-emerald-700">−{{ formatMoney(order.discount_amount) }}</span>
              </div>
              <UiSeparator class="my-3" />
              <div class="flex items-center justify-between gap-3">
                <span class="font-semibold text-foreground">{{ t('user.common.total') }}</span>
                <span class="text-xl font-bold tabular-nums text-foreground">{{ formatMoney(order.total_amount) }}</span>
              </div>

              <!-- Payment transactions if any -->
              <div
                v-if="order.payments && order.payments.length"
                class="mt-4 space-y-2 border-t border-border/80 pt-3"
              >
                <div class="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                  {{ t('user.order.paymentHistory') }}
                </div>
                <div
                  v-for="p in order.payments"
                  :key="p.id"
                  class="flex items-center justify-between rounded-xl bg-muted/40 px-3 py-2 text-xs"
                >
                  <div class="min-w-0">
                    <span class="font-medium text-foreground">{{ p.provider }}</span>
                    <span
                      v-if="p.provider_trans_id"
                      class="block font-mono text-[10px] text-muted-foreground"
                    >№{{ p.provider_trans_id }}</span>
                  </div>
                  <div class="text-right">
                    <span class="font-semibold tabular-nums text-foreground">{{ formatMoney(p.amount) }}</span>
                    <div class="mt-0.5">
                      <UiStatusBadge
                        :tone="p.status === 'PAID' ? 'success' : p.status === 'CANCELLED' ? 'destructive' : 'neutral'"
                        class="px-1.5 py-0 text-[10px]"
                      >
                        {{ p.status }}
                      </UiStatusBadge>
                    </div>
                  </div>
                </div>
              </div>
            </UiCardContent>
            <UiCardFooter
              v-if="canPayWithClick"
              class="p-5"
            >
              <UiButton
                class="w-full bg-[#0065FF] hover:bg-[#0052cc] text-white font-semibold shadow-sm"
                size="lg"
                :disabled="isPaying"
                @click="handlePayWithClick"
              >
                <Icon
                  v-if="isPaying"
                  name="lucide:loader-2"
                  class="animate-spin text-lg"
                />
                <BrandClickMark
                  v-else
                  class="size-5 text-white mr-1.5"
                />
                {{ t('user.order.payWithClick') }}
              </UiButton>
            </UiCardFooter>
          </UiCard>

          <!-- the delivery -->
          <UiCard class="gap-3 py-5 shadow-xs">
            <UiCardHeader class="px-5">
              <UiCardTitle class="flex items-center gap-2 font-semibold">
                <Icon
                  :name="isPickup ? 'lucide:store' : 'lucide:truck'"
                  class="text-base text-muted-foreground"
                />
                {{ isPickup ? t('user.common.pickup') : t('user.common.deliveryShort') }}
              </UiCardTitle>
            </UiCardHeader>
            <UiCardContent class="space-y-1 px-5 text-sm">
              <a
                v-if="address && point"
                :href="orderMapHref(point.lat, point.lon)"
                target="_blank"
                rel="noopener"
                class="flex w-full items-start gap-2.5 rounded-md py-1 text-left text-foreground"
              >
                <Icon
                  name="lucide:map-pin"
                  class="mt-0.5 shrink-0 text-muted-foreground"
                />
                <span>{{ address }}</span>
              </a>
              <button
                v-else-if="address"
                type="button"
                class="flex w-full items-start gap-2.5 rounded-md py-1 text-left text-foreground"
                :aria-expanded="addressOpen"
                @click="addressOpen = !addressOpen"
              >
                <Icon
                  name="lucide:map-pin"
                  class="mt-0.5 shrink-0 text-muted-foreground"
                />
                <span :class="addressOpen ? '' : 'line-clamp-1'">{{ address }}</span>
              </button>
              <p
                v-if="isPickup && pickup.hours"
                class="flex items-center gap-2.5 py-1 text-foreground"
              >
                <Icon
                  name="lucide:clock"
                  class="shrink-0 text-muted-foreground"
                />
                {{ pickup.hours }}
              </p>
              <p
                v-if="order.tracking_number"
                class="flex items-center gap-2.5 py-1 text-foreground"
              >
                <Icon
                  name="lucide:package-search"
                  class="shrink-0 text-muted-foreground"
                />
                <span class="truncate">{{ [order.carrier, order.tracking_number].filter(Boolean).join(' · ') }}</span>
              </p>
              <button
                v-if="order.customer_notes"
                type="button"
                class="flex w-full items-start gap-2.5 rounded-md py-1 text-left text-muted-foreground"
                :aria-expanded="notesOpen"
                @click="notesOpen = !notesOpen"
              >
                <Icon
                  name="lucide:message-square"
                  class="mt-0.5 shrink-0"
                />
                <span :class="notesOpen ? 'whitespace-pre-line' : 'line-clamp-1'">{{ order.customer_notes }}</span>
              </button>
              <CommerceOrderMapPreview
                v-if="point"
                :lat="point.lat"
                :lon="point.lon"
                class="!mt-3"
              />
            </UiCardContent>
          </UiCard>
          </aside>
        </div>
      </div>

      <UiAlertDialog v-model:open="confirmCancel">
        <UiAlertDialogContent>
          <UiAlertDialogHeader>
            <UiAlertDialogTitle>{{ t('user.order.cancelConfirm') }}</UiAlertDialogTitle>
          </UiAlertDialogHeader>
          <UiAlertDialogFooter>
            <UiAlertDialogCancel>{{ t('user.order.no') }}</UiAlertDialogCancel>
            <UiButton
              variant="destructive"
              :disabled="cancelMutation.isPending.value"
              @click="handleCancel"
            >
              <Icon
                v-if="cancelMutation.isPending.value"
                name="lucide:loader-2"
                class="animate-spin text-base"
              />
              {{ t('user.common.cancel') }}
            </UiButton>
          </UiAlertDialogFooter>
        </UiAlertDialogContent>
      </UiAlertDialog>

      <UiDialog v-model:open="reviewOpen">
        <UiDialogScrollContent class="sm:max-w-md">
          <UiDialogHeader>
            <UiDialogTitle>{{ t('user.order.leaveReview') }}</UiDialogTitle>
            <UiDialogDescription class="sr-only">
              {{ t('user.order.reviewDescription') }}
            </UiDialogDescription>
          </UiDialogHeader>
          <OrderReview
            :order-id="order.id"
            @sent="reviewOpen = false"
          />
        </UiDialogScrollContent>
      </UiDialog>
    </template>
  </div>
</template>
