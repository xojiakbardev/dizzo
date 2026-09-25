<script setup lang="ts">
// Checkout: the contact, how the order is received (delivered to a pin on
// the map, or picked up at Dizzo) and a note — beside them the order's
// items with their pictures, the total and the button. Order is created
// directly without operator confirmation. After it, the order number and
// where to follow it or pay directly via Click.
import { ApiError, getApiErrorMessage } from '~/composables/useApi';
import BranchPickupMap from '~/components/checkout/BranchPickupMap.vue';
import { getOrderStatusMeta } from '~/lib/orderStatus';
import { useDeliveryConfig, useCalculateDelivery } from '~/composables/queries/useDelivery';
import type { Branch, CheckoutResult, DeliveryMethod, DeliveryQuote } from '~/types/commerce';

definePageMeta({ layout: 'cabinet' });
const { t } = useI18n();
const localePath = useLocalePath();
useAdminCrumbs(() => [{ label: t('user.checkout.crumb') }]);

const route = useRoute();

const methods = computed<Array<{ value: DeliveryMethod; label: string; hint: string; icon: string }>>(() => [
  { value: 'DELIVERY', label: t('user.common.delivery'), hint: t('user.checkout.deliveryHint'), icon: 'lucide:truck' },
  { value: 'PICKUP', label: t('user.checkout.pickupLabel'), hint: 'O\'zingizga yaqin filialdan olib ketish', icon: 'lucide:store' },
]);

const paymentMethods = computed<Array<{ value: 'CLICK'; label: string; hint: string; icon: string }>>(() => [
  {
    value: 'CLICK',
    label: t('user.checkout.payClick'),
    hint: t('user.checkout.payClickHint'),
    icon: 'brand:click',
  },
]);

const cartQuery = useCart();
const userQuery = useCurrentUser();
const checkoutMutation = useCheckout();
const deliveryConfigQuery = useDeliveryConfig();
const calculateDeliveryMutation = useCalculateDelivery();

const submitError = ref<string | null>(null);
const result = ref<CheckoutResult | null>(null);

const form = reactive({
  contact_name: '',
  contact_email: '',
  contact_phone: '',
  delivery_method: 'DELIVERY' as DeliveryMethod,
  payment_method: 'CLICK' as const,
  shipping_address: '',
  shipping_city: 'Toshkent',
  customer_notes: '',
});

// Delivery carrier & real-time calculation
const selectedCarrier = ref<'YANDEX' | 'BTS'>('YANDEX');
const deliveryCost = ref<number>(35000);
const deliveryQuote = ref<DeliveryQuote | null>(null);
const isCalculatingDelivery = ref(false);

const estimatedDeliveryDays = computed(() => {
  if (deliveryQuote.value?.estimated_days) return deliveryQuote.value.estimated_days;
  const providers = deliveryConfigQuery.data.value?.providers;
  if (selectedCarrier.value === 'YANDEX') return providers?.YANDEX?.estimated_days || '2–3 kun';
  return providers?.BTS?.estimated_days || '3–4 kun';
});

// Delivery address coordinates from pin drop
const deliveryLatitude = ref<number | null>(null);
const deliveryLongitude = ref<number | null>(null);

// Pickup branch selection
const selectedBranchId = ref<number | null>(null);
const selectedBranch = ref<Branch | null>(null);

let calcDebounceTimer: ReturnType<typeof setTimeout> | null = null;
async function fetchDeliveryPrice() {
  if (form.delivery_method !== 'DELIVERY') return;
  isCalculatingDelivery.value = true;
  try {
    const quote = await calculateDeliveryMutation.mutateAsync({
      provider: selectedCarrier.value,
      city: form.shipping_city || 'Toshkent',
      address: form.shipping_address || undefined,
      latitude: deliveryLatitude.value ?? undefined,
      longitude: deliveryLongitude.value ?? undefined,
    });
    deliveryQuote.value = quote;
    deliveryCost.value = quote.price;
  } catch {
    deliveryCost.value = selectedCarrier.value === 'YANDEX' ? 35000 : 25000;
  } finally {
    isCalculatingDelivery.value = false;
  }
}

function queueDeliveryPriceCalculation() {
  if (calcDebounceTimer) clearTimeout(calcDebounceTimer);
  calcDebounceTimer = setTimeout(() => {
    void fetchDeliveryPrice();
  }, 350);
}

watch(
  [selectedCarrier, deliveryLatitude, deliveryLongitude, () => form.shipping_city, () => form.shipping_address, () => form.delivery_method],
  () => {
    if (form.delivery_method === 'DELIVERY') {
      queueDeliveryPriceCalculation();
    }
  },
  { immediate: true },
);

watch(userQuery.data, (user) => {
  if (!user) return;
  const fullName = user.full_name || `${user.first_name || ''} ${user.last_name || ''}`.trim();
  form.contact_name ||= fullName;
  form.contact_email ||= user.email || '';
  form.contact_phone ||= user.phone_number || '';
}, { immediate: true });

watch(() => route.query, (query) => {
  const selectedAddress = typeof query.selected_address === 'string' ? query.selected_address : '';
  const selectedCity = typeof query.selected_city === 'string' ? query.selected_city : '';
  const latValue = typeof query.lat === 'string' ? Number(query.lat) : null;
  const lonValue = typeof query.lon === 'string' ? Number(query.lon) : null;

  if (selectedAddress) form.shipping_address = selectedAddress;
  if (selectedCity) form.shipping_city = selectedCity;
  if (Number.isFinite(latValue)) deliveryLatitude.value = latValue;
  if (Number.isFinite(lonValue)) deliveryLongitude.value = lonValue;
}, { immediate: true });

function openMapPicker() {
  void navigateTo({
    path: localePath('/user/location-picker'),
    query: {
      return: '/user/checkout',
      address: form.shipping_address || undefined,
      city: form.shipping_city || undefined,
      lat: deliveryLatitude.value ?? undefined,
      lon: deliveryLongitude.value ?? undefined,
    },
  });
}

const cart = computed(() => (result.value ? null : (cartQuery.data.value ?? null)));
const loading = computed(() => cartQuery.isLoading.value || userQuery.isLoading.value);
const submitting = computed(() => checkoutMutation.isPending.value);
const error = computed(() => submitError.value
  ?? (cartQuery.isError.value ? getApiErrorMessage(cartQuery.error.value, t('user.checkout.loadError')) : null));

const checkoutTotal = computed(() => {
  const subtotal = Number(cart.value?.subtotal || 0);
  return subtotal + (form.delivery_method === 'DELIVERY' ? deliveryCost.value : 0);
});

// What still has to be filled in before the order can go (shown under the button).
const missing = computed(() => [
  !form.contact_name && t('user.checkout.missingName'),
  !form.contact_phone && t('user.checkout.missingPhone'),
  form.delivery_method === 'DELIVERY' && !form.shipping_address && deliveryLatitude.value == null && t('user.checkout.missingAddress'),
  form.delivery_method === 'PICKUP' && !selectedBranchId.value && 'Olib ketish uchun filialni tanlang',
].filter(Boolean) as string[]);

const canSubmit = computed(() => Boolean(
  cart.value
  && !cart.value.is_empty
  && !cart.value.blocked
  && missing.value.length === 0,
));

// One key per checkout attempt: kept when the request may have gone through
// (no answer, a server error) so pressing the button again can't place the
// order twice; dropped once the order is placed or the backend definitely
// refused it (the form or cart may change before the next try).
let idempotencyKey: string | null = null;

async function handleSubmit() {
  if (!canSubmit.value || submitting.value) return;
  submitError.value = null;
  idempotencyKey ??= crypto.randomUUID();

  try {
    result.value = await checkoutMutation.mutateAsync({
      idempotencyKey,
      input: {
        contact_name: form.contact_name,
        contact_email: form.contact_email,
        contact_phone: form.contact_phone,
        delivery_method: form.delivery_method,
        branch_id: form.delivery_method === 'PICKUP' ? selectedBranchId.value : undefined,
        carrier: form.delivery_method === 'DELIVERY' ? selectedCarrier.value : undefined,
        shipping_cost: form.delivery_method === 'DELIVERY' ? deliveryCost.value : 0,
        shipping_address: form.delivery_method === 'PICKUP'
          ? (selectedBranch.value ? `${selectedBranch.value.name}, ${selectedBranch.value.address}` : '')
          : form.shipping_address,
        shipping_city: form.delivery_method === 'PICKUP' ? (selectedBranch.value?.city || form.shipping_city) : form.shipping_city,
        latitude: form.delivery_method === 'DELIVERY' ? deliveryLatitude.value : (selectedBranch.value?.latitude ?? null),
        longitude: form.delivery_method === 'DELIVERY' ? deliveryLongitude.value : (selectedBranch.value?.longitude ?? null),
        customer_notes: form.customer_notes,
      },
    });
    idempotencyKey = null;
    document.getElementById('main-content')?.scrollTo({ top: 0 });
  }
  catch (checkoutError) {
    if (checkoutError instanceof ApiError && checkoutError.status >= 400 && checkoutError.status < 500) idempotencyKey = null;
    submitError.value = getApiErrorMessage(checkoutError, t('user.checkout.submitError'));
    // Prices changed or something went off sale: show the updated cart.
    if (checkoutError instanceof ApiError && checkoutError.status === 409) await cartQuery.refetch();
  }
}
</script>

<template>
  <div>
    <!-- placed: the order number, the total, the status and what happens next -->
    <UiCard
      v-if="result"
      class="mx-auto max-w-2xl gap-0 py-0 shadow-xs"
    >
      <div class="flex flex-col items-center px-5 pt-8 pb-6 text-center sm:px-8">
        <span class="flex size-14 items-center justify-center rounded-full bg-emerald-50 text-emerald-600 ring-8 ring-emerald-50/50">
          <Icon
            name="lucide:check"
            class="text-3xl"
          />
        </span>
        <h1 class="mt-5 text-2xl font-bold tracking-tight text-foreground">
          {{ t('user.checkout.placedTitle') }}
        </h1>
        <p class="mt-2 max-w-md text-sm leading-relaxed text-muted-foreground">
          {{ t('user.checkout.placedText') }}
        </p>

        <div
          v-if="result.order.items.length"
          class="mt-5 flex flex-wrap justify-center gap-2"
        >
          <MediaThumb
            v-for="item in result.order.items"
            :key="item.id"
            :src="item.mockups[0]"
            :alt="item.product_name"
            class="size-16 rounded-xl ring-1 ring-inset ring-foreground/10"
          />
        </div>

        <dl class="mt-6 grid w-full gap-2 text-left sm:grid-cols-3">
          <div class="rounded-xl bg-muted/60 px-4 py-3">
            <dt class="text-xs text-muted-foreground">
              {{ t('user.common.orderNumber') }}
            </dt>
            <dd class="mt-1 font-mono text-base font-bold text-foreground">
              {{ result.order_number }}
            </dd>
          </div>
          <div class="rounded-xl bg-muted/60 px-4 py-3">
            <dt class="text-xs text-muted-foreground">
              {{ t('user.checkout.totalAmount') }}
            </dt>
            <dd class="mt-1 text-base font-bold tabular-nums text-foreground">
              {{ formatMoney(result.total_amount) }}
            </dd>
          </div>
          <div class="rounded-xl bg-muted/60 px-4 py-3">
            <dt class="text-xs text-muted-foreground">
              {{ t('user.common.status') }}
            </dt>
            <dd class="mt-1">
              <UiStatusBadge :tone="getOrderStatusMeta(result.status).tone">
                {{ getOrderStatusMeta(result.status).label }}
              </UiStatusBadge>
            </dd>
          </div>
        </dl>

        <!-- Click Payment Card -->
        <div
          v-if="result.payment_url"
          class="mt-6 w-full rounded-2xl border border-[#0065FF]/30 bg-gradient-to-br from-[#0065FF]/10 via-background to-[#0065FF]/5 p-5 text-left shadow-xs ring-1 ring-[#0065FF]/15"
        >
          <div class="flex items-start gap-3.5">
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-[#0065FF] text-white shadow-sm ring-1 ring-[#0065FF]/30">
              <BrandClickMark class="size-6 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <h3 class="font-bold text-foreground text-base">{{ t('user.checkout.payClick') }}</h3>
              </div>
              <p class="mt-1 text-xs text-muted-foreground leading-relaxed">
                {{ t('user.checkout.payClickHint') }}
              </p>
            </div>
          </div>
          <div class="mt-4 flex flex-col sm:flex-row gap-2.5">
            <UiButton
              as-child
              size="lg"
              class="flex-1 bg-[#0065FF] hover:bg-[#0052cc] text-white font-semibold shadow-sm"
            >
              <a :href="result.payment_url">
                <BrandClickMark class="size-5 text-white mr-1.5" />
                {{ t('user.checkout.payWithClick') }}
                <Icon name="lucide:arrow-up-right" class="text-base ml-1" />
              </a>
            </UiButton>
          </div>
        </div>

        <UiAlert
          v-else
          class="mt-4 border-emerald-500/30 bg-emerald-500/10 text-emerald-900 dark:text-emerald-200"
        >
          <Icon name="lucide:check-circle-2" class="text-emerald-600 dark:text-emerald-400" />
          <UiAlertDescription class="font-medium">
            {{ t('user.checkout.placedNote') }}
          </UiAlertDescription>
        </UiAlert>
      </div>
      <UiCardFooter class="flex-wrap justify-center gap-2">
        <UiButton
          v-if="result.payment_url"
          as-child
          class="bg-[#0065FF] hover:bg-[#0052cc] text-white font-medium"
        >
          <a :href="result.payment_url">
            <BrandClickMark class="size-4 text-white mr-1.5" />
            {{ t('user.checkout.payWithClick') }}
          </a>
        </UiButton>
        <UiButton
          as-child
          :variant="result.payment_url ? 'outline' : 'default'"
        >
          <NuxtLink :to="localePath(`/user/orders/${result.order_number}`)">
            {{ t('user.checkout.orderDetails') }}
            <Icon
              name="lucide:arrow-right"
              class="text-base"
            />
          </NuxtLink>
        </UiButton>
        <UiButton
          as-child
          variant="outline"
        >
          <NuxtLink :to="localePath('/user/orders')">
            {{ t('user.common.allOrders') }}
          </NuxtLink>
        </UiButton>
      </UiCardFooter>
    </UiCard>

    <template v-else>
      <!-- loading: the three form cards (delivery with its map) and the
           summary in grey, at the sizes they load in -->
      <div
        v-if="loading"
        class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_24rem]"
        aria-busy="true"
      >
        <div class="space-y-4">
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <div class="flex h-lh items-center gap-2.5 text-base">
                <UiSkeleton class="size-6 rounded-full" />
                <UiSkeleton class="h-4 w-40" />
              </div>
            </UiCardHeader>
            <UiCardContent class="grid gap-4 sm:grid-cols-2">
              <div
                v-for="i in 2"
                :key="i"
                class="grid gap-1.5"
              >
                <UiSkeleton class="h-3 w-28" />
                <UiSkeleton class="h-10 rounded-xl" />
              </div>
            </UiCardContent>
          </UiCard>

          <UiCard class="shadow-xs">
            <UiCardHeader>
              <div class="flex h-lh items-center gap-2.5 text-base">
                <UiSkeleton class="size-6 rounded-full" />
                <UiSkeleton class="h-4 w-36" />
              </div>
            </UiCardHeader>
            <UiCardContent class="space-y-4">
              <div class="grid gap-2.5 sm:grid-cols-2">
                <UiSkeleton
                  v-for="i in 2"
                  :key="i"
                  class="h-[4.5rem] rounded-xl"
                />
              </div>
              <div class="space-y-2.5">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <div class="flex h-4 min-w-0 flex-1 basis-56 items-center">
                    <UiSkeleton class="h-3 w-64 max-w-full" />
                  </div>
                  <UiSkeleton class="h-8.5 w-44 rounded-lg" />
                </div>
                <UiSkeleton class="h-72 rounded-xl sm:h-80" />
              </div>
              <div class="grid gap-1.5">
                <UiSkeleton class="h-3 w-20" />
                <UiSkeleton class="h-10 rounded-xl" />
                <div class="flex h-4 items-center">
                  <UiSkeleton class="h-3 w-56 max-w-full" />
                </div>
              </div>
            </UiCardContent>
          </UiCard>

          <UiCard class="shadow-xs">
            <UiCardHeader>
              <div class="flex h-lh items-center gap-2.5 text-base">
                <UiSkeleton class="size-6 rounded-full" />
                <UiSkeleton class="h-4 w-28" />
              </div>
            </UiCardHeader>
            <UiCardContent>
              <UiSkeleton class="h-20 rounded-xl" />
            </UiCardContent>
          </UiCard>
        </div>

        <UiCard class="shadow-xs">
          <UiCardHeader>
            <div class="flex h-lh items-center text-base leading-snug">
              <UiSkeleton class="h-4 w-36" />
            </div>
          </UiCardHeader>
          <UiCardContent class="text-sm">
            <div class="divide-y divide-border">
              <div
                v-for="i in 2"
                :key="i"
                class="py-3 first:pt-0"
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0 flex-1">
                    <div class="flex h-lh items-center">
                      <UiSkeleton class="h-3.5 w-32" />
                    </div>
                    <div class="mt-0.5 flex h-lh items-center text-xs">
                      <UiSkeleton class="h-3 w-40" />
                    </div>
                  </div>
                  <div class="flex h-lh items-center">
                    <UiSkeleton class="h-3.5 w-20" />
                  </div>
                </div>
                <CommerceMockupGallery
                  skeleton
                  layout="row"
                  tile-class="size-11"
                  class="mt-2.5"
                />
              </div>
            </div>
            <UiSeparator class="mb-3" />
            <div class="space-y-3">
              <div
                v-for="i in 2"
                :key="i"
                class="flex h-lh items-center justify-between"
              >
                <UiSkeleton class="h-3.5 w-24" />
                <UiSkeleton class="h-3.5 w-20" />
              </div>
              <UiSeparator />
              <div class="flex h-7 items-center justify-between">
                <UiSkeleton class="h-3.5 w-12" />
                <UiSkeleton class="h-6 w-32" />
              </div>
            </div>
          </UiCardContent>
          <UiCardFooter class="flex-col items-stretch gap-3">
            <UiSkeleton class="h-12 rounded-2xl" />
            <div class="flex h-4 items-center justify-center">
              <UiSkeleton class="h-3 w-48" />
            </div>
          </UiCardFooter>
        </UiCard>
      </div>

      <template v-else-if="!cart || cart.is_empty">
        <UiAlert
          v-if="error"
          variant="destructive"
          class="mb-4"
        >
          <Icon name="lucide:circle-alert" />
          <UiAlertDescription>{{ error }}</UiAlertDescription>
        </UiAlert>
        <EmptyState
          icon="lucide:shopping-cart"
          :title="t('user.checkout.emptyCart')"
        >
          <UiButton
            as-child
            variant="outline"
          >
            <NuxtLink :to="localePath('/user/cart')">
              {{ t('user.checkout.backToCart') }}
            </NuxtLink>
          </UiButton>
        </EmptyState>
      </template>

      <div
        v-else
        class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_24rem]"
      >
        <form
          id="checkout-form"
          class="min-w-0 space-y-4"
          @submit.prevent="handleSubmit"
        >
          <UiAlert
            v-if="error"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            <UiAlertDescription>{{ error }}</UiAlertDescription>
          </UiAlert>
          <UiAlert
            v-if="cart.blocked"
            variant="warning"
          >
            <Icon name="lucide:triangle-alert" />
            <UiAlertDescription>
              {{ t('user.checkout.blocked') }}
            </UiAlertDescription>
          </UiAlert>

          <!-- 1. Contact -->
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <UiCardTitle class="flex items-center gap-2.5 font-semibold">
                <span class="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">1</span>
                {{ t('user.checkout.contact') }}
              </UiCardTitle>
            </UiCardHeader>
            <UiCardContent class="grid gap-4 sm:grid-cols-2">
              <UiField
                :label="t('user.checkout.fullName')"
                for="checkout-name"
              >
                <UiInput
                  id="checkout-name"
                  v-model="form.contact_name"
                  required
                  autocomplete="name"
                  :placeholder="t('user.checkout.fullNamePlaceholder')"
                />
              </UiField>
              <UiField
                :label="t('user.checkout.phone')"
                for="checkout-phone"
              >
                <UiInput
                  id="checkout-phone"
                  v-model="form.contact_phone"
                  required
                  type="tel"
                  inputmode="tel"
                  autocomplete="tel"
                  placeholder="+998 90 123 45 67"
                />
              </UiField>
            </UiCardContent>
          </UiCard>

          <!-- 2. Delivery or pickup -->
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <UiCardTitle class="flex items-center gap-2.5 font-semibold">
                <span class="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">2</span>
                {{ t('user.checkout.receiveMethod') }}
              </UiCardTitle>
            </UiCardHeader>
            <UiCardContent class="space-y-4">
              <div
                class="grid gap-2.5 sm:grid-cols-2"
                role="radiogroup"
                :aria-label="t('user.checkout.receiveMethod')"
              >
                <button
                  v-for="m in methods"
                  :key="m.value"
                  type="button"
                  role="radio"
                  :aria-checked="form.delivery_method === m.value"
                  class="flex h-[4.5rem] items-center gap-3 rounded-xl border px-3.5 text-left outline-none transition focus-visible:ring-3 focus-visible:ring-ring/50"
                  :class="form.delivery_method === m.value ? 'border-primary bg-secondary ring-1 ring-primary' : 'border-border bg-background hover:bg-muted'"
                  @click="form.delivery_method = m.value"
                >
                  <span
                    class="flex size-9 shrink-0 items-center justify-center rounded-lg"
                    :class="form.delivery_method === m.value ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'"
                  >
                    <Icon
                      :name="m.icon"
                      class="text-lg"
                    />
                  </span>
                  <span class="min-w-0">
                    <span class="block text-sm font-semibold text-foreground">{{ m.label }}</span>
                    <span class="mt-0.5 line-clamp-2 block text-xs text-muted-foreground">{{ m.hint }}</span>
                  </span>
                </button>
              </div>

              <template v-if="form.delivery_method === 'DELIVERY'">
                <div class="rounded-2xl border border-dashed border-border bg-muted/40 p-4">
                  <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                      <p class="text-sm font-semibold text-foreground">{{ t('user.checkout.address') }}</p>
                      <p class="mt-1 text-xs text-muted-foreground">
                        {{ form.shipping_address || t('user.checkout.addressHint') }}
                      </p>
                    </div>
                    <UiButton
                      type="button"
                      variant="outline"
                      size="sm"
                      @click="openMapPicker"
                    >
                      <Icon name="lucide:map-pin" class="size-4" />
                      Xaritada tanlash
                    </UiButton>
                  </div>

                  <div
                    v-if="deliveryLatitude != null && deliveryLongitude != null"
                    class="mt-3 inline-flex items-center gap-1.5 rounded-full bg-background px-2.5 py-1 text-[11px] font-mono text-muted-foreground ring-1 ring-border"
                  >
                    <Icon name="lucide:crosshair" class="size-3.5 text-primary" />
                    {{ deliveryLatitude.toFixed(5) }}, {{ deliveryLongitude.toFixed(5) }}
                  </div>
                </div>

                <UiField
                  :label="t('user.checkout.address')"
                  for="checkout-address"
                  :hint="form.shipping_address ? t('user.checkout.addressFromMap') : t('user.checkout.addressHint')"
                >
                  <UiInput
                    id="checkout-address"
                    v-model="form.shipping_address"
                    autocomplete="street-address"
                    :placeholder="t('user.checkout.addressPlaceholder')"
                  />
                </UiField>

                <!-- Delivery Provider (Carrier) Selection -->
                <div class="space-y-2 pt-1">
                  <label class="text-xs font-semibold text-foreground">
                    Yetkazib berish xizmati
                  </label>
                  <div
                    class="grid gap-2.5 sm:grid-cols-2"
                    role="radiogroup"
                    aria-label="Yetkazib berish xizmati"
                  >
                    <!-- Yandex Dastavka -->
                    <button
                      type="button"
                      role="radio"
                      :aria-checked="selectedCarrier === 'YANDEX'"
                      class="relative flex flex-col justify-between rounded-xl border p-3.5 text-left outline-none transition focus-visible:ring-3 focus-visible:ring-ring/50"
                      :class="selectedCarrier === 'YANDEX' ? 'border-primary bg-secondary/80 ring-1 ring-primary' : 'border-border bg-background hover:bg-muted/50'"
                      @click="selectedCarrier = 'YANDEX'"
                    >
                      <div class="flex items-start justify-between gap-2">
                        <div class="flex items-center gap-2.5">
                          <div class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-amber-500/10 text-amber-600 dark:text-amber-400">
                            <Icon name="lucide:zap" class="size-4" />
                          </div>
                          <div>
                            <span class="block text-sm font-semibold text-foreground">Yandex Dastavka</span>
                            <span class="text-[11px] font-medium text-muted-foreground">Faqat Toshkent shahri</span>
                          </div>
                        </div>
                        <span class="inline-flex items-center rounded-md bg-primary/10 px-1.5 py-0.5 text-[10px] font-medium text-primary">
                          B2B Real-time
                        </span>
                      </div>
                      <div class="mt-3 flex items-center justify-between border-t border-border/60 pt-2 text-xs">
                        <span class="text-muted-foreground">Muddat: <strong class="font-medium text-foreground">{{ deliveryConfigQuery.data.value?.providers?.YANDEX?.estimated_days || '2–3 kun' }}</strong></span>
                        <span class="font-semibold text-foreground">
                          <template v-if="selectedCarrier === 'YANDEX' && isCalculatingDelivery">
                            <Icon name="lucide:loader-2" class="size-3 animate-spin inline mr-1" />...
                          </template>
                          <template v-else-if="selectedCarrier === 'YANDEX'">
                            {{ formatMoney(deliveryCost) }}
                          </template>
                          <template v-else>
                            {{ formatMoney(35000) }}
                          </template>
                        </span>
                      </div>
                    </button>

                    <!-- BTS Pochta -->
                    <button
                      type="button"
                      role="radio"
                      :aria-checked="selectedCarrier === 'BTS'"
                      class="relative flex flex-col justify-between rounded-xl border p-3.5 text-left outline-none transition focus-visible:ring-3 focus-visible:ring-ring/50"
                      :class="selectedCarrier === 'BTS' ? 'border-primary bg-secondary/80 ring-1 ring-primary' : 'border-border bg-background hover:bg-muted/50'"
                      @click="selectedCarrier = 'BTS'"
                    >
                      <div class="flex items-start justify-between gap-2">
                        <div class="flex items-center gap-2.5">
                          <div class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400">
                            <Icon name="lucide:package-check" class="size-4" />
                          </div>
                          <div>
                            <span class="block text-sm font-semibold text-foreground">BTS Pochta</span>
                            <span class="text-[11px] font-medium text-muted-foreground">O'zbekiston bo'ylab</span>
                          </div>
                        </div>
                        <span class="inline-flex items-center rounded-md bg-muted px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground">
                          Filial yuklamasi
                        </span>
                      </div>
                      <div class="mt-3 flex items-center justify-between border-t border-border/60 pt-2 text-xs">
                        <span class="text-muted-foreground">Muddat: <strong class="font-medium text-foreground">{{ deliveryConfigQuery.data.value?.providers?.BTS?.estimated_days || '3–4 kun' }}</strong></span>
                        <span class="font-semibold text-foreground">
                          <template v-if="selectedCarrier === 'BTS' && isCalculatingDelivery">
                            <Icon name="lucide:loader-2" class="size-3 animate-spin inline mr-1" />...
                          </template>
                          <template v-else-if="selectedCarrier === 'BTS'">
                            {{ formatMoney(deliveryCost) }}
                          </template>
                          <template v-else>
                            {{ formatMoney(25000) }}
                          </template>
                        </span>
                      </div>
                    </button>
                  </div>

                  <!-- Outside Tashkent hint if Yandex selected -->
                  <div
                    v-if="selectedCarrier === 'YANDEX' && form.shipping_city && form.shipping_city.toLowerCase() !== 'toshkent' && !form.shipping_city.toLowerCase().includes('tashkent')"
                    class="flex items-center gap-2 rounded-xl bg-amber-500/10 px-3 py-2 text-xs text-amber-700 dark:text-amber-400 border border-amber-500/20"
                  >
                    <Icon name="lucide:info" class="size-4 shrink-0" />
                    <span>Yandex Dastavka faqat Toshkent shahrida amal qiladi. Boshqa viloyatlar uchun <strong>BTS Pochta</strong>ni tanlash tavsiya etiladi.</span>
                  </div>
                </div>
              </template>

              <BranchPickupMap
                v-else
                v-model="selectedBranchId"
                @select="selectedBranch = $event"
              />
            </UiCardContent>
          </UiCard>

          <!-- 3. Payment Method -->
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <UiCardTitle class="flex items-center gap-2.5 font-semibold">
                <span class="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">3</span>
                {{ t('user.checkout.paymentMethod') }}
              </UiCardTitle>
            </UiCardHeader>
            <UiCardContent>
              <div
                class="flex items-center justify-between gap-4 rounded-xl border border-[#0065FF] bg-[#0065FF]/5 dark:bg-[#0065FF]/10 p-4 ring-2 ring-[#0065FF]/30 transition"
              >
                <div class="flex items-center gap-3.5 min-w-0">
                  <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-[#0065FF] text-white shadow-sm">
                    <BrandClickMark class="size-6 text-white" />
                  </span>
                  <div class="min-w-0">
                    <span class="block text-sm font-semibold text-[#0065FF] dark:text-[#388bfd]">
                      {{ t('user.checkout.payClick') }}
                    </span>
                    <span class="mt-0.5 line-clamp-1 block text-xs text-muted-foreground">
                      {{ t('user.checkout.payClickHint') }}
                    </span>
                  </div>
                </div>
                <div class="flex items-center gap-1.5 shrink-0">
                  <span class="inline-flex items-center rounded-full bg-[#0065FF]/15 px-2.5 py-1 text-xs font-semibold text-[#0065FF] dark:text-[#388bfd]">
                    <Icon name="lucide:check" class="size-3.5 mr-1" />
                    Tanlangan
                  </span>
                </div>
              </div>
            </UiCardContent>
          </UiCard>

          <!-- 4. Note -->
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <UiCardTitle class="flex items-center gap-2.5 font-semibold">
                <span class="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">4</span>
                {{ t('user.checkout.note') }}
                <span class="text-sm font-normal text-muted-foreground">{{ t('user.common.optional') }}</span>
              </UiCardTitle>
            </UiCardHeader>
            <UiCardContent>
              <UiTextarea
                v-model="form.customer_notes"
                :aria-label="t('user.checkout.note')"
                class="min-h-20 resize-none"
                :placeholder="form.delivery_method === 'PICKUP'
                  ? t('user.checkout.notePickupPlaceholder')
                  : t('user.checkout.noteDeliveryPlaceholder')"
              />
            </UiCardContent>
          </UiCard>
        </form>

        <aside class="lg:sticky lg:top-4">
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <UiCardTitle class="font-semibold">
                {{ t('user.checkout.contents') }}
              </UiCardTitle>
              <UiCardAction>
                <UiBadge
                  variant="secondary"
                  class="tabular-nums"
                >
                  {{ t('user.common.units', cart.total_items) }}
                </UiBadge>
              </UiCardAction>
            </UiCardHeader>
            <UiCardContent class="text-sm">
              <ul class="divide-y divide-border">
                <li
                  v-for="item in cart.items"
                  :key="item.uuid"
                  class="py-3 first:pt-0"
                >
                  <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                      <p class="font-medium text-foreground">
                        {{ item.product_name }}
                      </p>
                      <p class="mt-0.5 text-xs text-muted-foreground">
                        {{ item.variant_name }} · {{ item.color_name }} ·
                        <template v-if="item.size">
                          {{ item.size }} ·
                        </template>
                        {{ t('user.common.pieces', item.quantity) }}
                      </p>
                    </div>
                    <span class="shrink-0 font-semibold tabular-nums text-foreground">{{ formatMoney(item.total_price) }}</span>
                  </div>
                  <CommerceMockupGallery
                    :images="item.mockups"
                    :alt="item.product_name"
                    layout="row"
                    tile-class="size-11"
                    class="mt-2.5"
                  />
                </li>
              </ul>
              <UiSeparator class="mb-3" />
              <div class="space-y-3">
                <div class="flex items-center justify-between gap-3">
                  <span class="text-muted-foreground">{{ t('user.common.subtotal') }}</span>
                  <span class="font-medium tabular-nums text-foreground">{{ formatMoney(cart.subtotal) }}</span>
                </div>
                <div class="flex items-center justify-between gap-3">
                  <span class="text-muted-foreground">
                    {{ form.delivery_method === 'PICKUP' ? t('user.common.pickup') : (selectedCarrier === 'YANDEX' ? 'Yandex Dastavka' : 'BTS Pochta') }}
                  </span>
                  <span v-if="form.delivery_method === 'PICKUP'" class="text-right font-medium text-emerald-600 dark:text-emerald-400">
                    {{ t('user.common.free') }}
                  </span>
                  <span v-else-if="isCalculatingDelivery" class="text-right text-xs text-muted-foreground animate-pulse">
                    Hisoblanmoqda...
                  </span>
                  <span v-else class="text-right font-medium tabular-nums text-foreground">
                    {{ formatMoney(deliveryCost) }}
                  </span>
                </div>
                <div
                  v-if="form.delivery_method === 'DELIVERY'"
                  class="flex items-center justify-between text-xs text-muted-foreground -mt-1.5"
                >
                  <span>Taxminiy yetkazish:</span>
                  <span class="font-medium text-foreground">{{ estimatedDeliveryDays }}</span>
                </div>
                <UiSeparator />
                <div class="flex h-7 items-center justify-between gap-3">
                  <span class="font-semibold text-foreground">{{ t('user.common.total') }}</span>
                  <span class="text-xl font-bold tabular-nums text-foreground">{{ formatMoney(checkoutTotal) }}</span>
                </div>
              </div>
            </UiCardContent>
            <UiCardFooter class="flex-col items-stretch gap-3">
              <UiButton
                type="submit"
                form="checkout-form"
                size="lg"
                :disabled="!canSubmit || submitting"
              >
                <Icon
                  v-if="submitting"
                  name="lucide:loader-2"
                  class="animate-spin text-lg"
                />
                {{ submitting ? t('user.checkout.sending') : t('user.checkout.placeOrder') }}
              </UiButton>
              <p class="text-center text-xs text-muted-foreground">
                <template v-if="missing.length">
                  {{ t('user.checkout.fillIn', { fields: missing.join(', ') }) }}
                </template>
                <template v-else>
                  {{ t('user.checkout.payClickHint') }}
                </template>
              </p>
            </UiCardFooter>
          </UiCard>
        </aside>
      </div>
    </template>
  </div>
</template>
