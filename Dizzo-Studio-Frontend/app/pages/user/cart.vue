<script setup lang="ts">
// The cart: each design on its own card — its pictures from the Studio
// (CommerceMockupGallery), what it is and how it is printed, the quantity
// and the price — and beside it the summary with the way to checkout. The
// skeleton mirrors the cards and the summary. In the cabinet: the navbar
// says "Savat", the row above the cards has the count and "tozalash".
import { getApiErrorMessage } from '~/composables/useApi';
import { METHOD_INFO } from '~/types/catalog';

const MAX_QUANTITY = 1000; // the backend's limit per item

definePageMeta({ layout: 'cabinet' });

const { t } = useI18n();
const localePath = useLocalePath();

const { start: startDesign } = useProductPicker();
const cartQuery = useCart();
const updateMutation = useUpdateCartItem();
const removeMutation = useRemoveCartItem();
const clearMutation = useClearCart();

const busyItem = ref<string | null>(null);
const actionError = ref<string | null>(null);
const confirmClear = ref(false);

const cart = computed(() => cartQuery.data.value ?? null);
const error = computed(() => actionError.value
  ?? (cartQuery.isError.value ? getApiErrorMessage(cartQuery.error.value, t('user.cart.loadError')) : null));

async function handleQuantityChange(itemUuid: string, quantity: number) {
  busyItem.value = itemUuid;
  actionError.value = null;
  try {
    await updateMutation.mutateAsync({ itemUuid, quantity });
  }
  catch {
    actionError.value = t('user.cart.updateError');
  }
  finally {
    busyItem.value = null;
  }
}

async function handleRemove(itemUuid: string) {
  busyItem.value = itemUuid;
  actionError.value = null;
  try {
    await removeMutation.mutateAsync(itemUuid);
  }
  catch {
    actionError.value = t('user.cart.removeError');
  }
  finally {
    busyItem.value = null;
  }
}

async function handleClear() {
  busyItem.value = 'clear';
  actionError.value = null;
  try {
    await clearMutation.mutateAsync();
    confirmClear.value = false;
  }
  catch {
    actionError.value = t('user.cart.clearError');
    confirmClear.value = false;
  }
  finally {
    busyItem.value = null;
  }
}
</script>

<template>
  <div>
    <!-- loading: the count row, two item cards and the summary in grey -->
    <div
      v-if="cartQuery.isLoading.value"
      class="space-y-4"
      aria-busy="true"
    >
      <div class="flex items-center justify-between gap-3">
        <div class="flex h-lh items-center text-sm">
          <UiSkeleton class="h-3.5 w-24" />
        </div>
        <UiSkeleton class="h-8.5 w-40 rounded-lg" />
      </div>

      <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <div class="space-y-4">
          <UiCard
            v-for="i in 2"
            :key="i"
            class="gap-0 py-0 shadow-xs"
          >
            <div class="flex flex-col gap-4 p-4 sm:flex-row sm:gap-5 sm:p-5">
              <CommerceMockupGallery
                skeleton
                class="sm:w-48 sm:shrink-0"
              />
              <div class="flex min-w-0 flex-1 flex-col">
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0 flex-1">
                    <div class="flex h-lh items-center text-base leading-snug">
                      <UiSkeleton class="h-4 w-40 max-w-full" />
                    </div>
                    <div class="mt-1 flex h-lh items-center text-sm">
                      <UiSkeleton class="h-3.5 w-32" />
                    </div>
                  </div>
                  <div class="flex flex-col items-end">
                    <div class="flex h-lh items-center text-base">
                      <UiSkeleton class="h-4 w-24" />
                    </div>
                    <div class="mt-0.5 flex h-lh items-center text-xs">
                      <UiSkeleton class="h-3 w-20" />
                    </div>
                  </div>
                </div>
                <div class="mt-3 flex gap-1.5">
                  <UiSkeleton class="h-6 w-40 rounded-4xl" />
                </div>
                <div class="mt-auto pt-4">
                  <UiSeparator class="mb-3" />
                  <div class="flex flex-wrap items-center justify-between gap-2">
                    <UiSkeleton class="h-10 w-[7.5rem] rounded-xl" />
                    <div class="flex gap-1">
                      <UiSkeleton class="h-8.5 w-26 rounded-lg" />
                      <UiSkeleton class="h-8.5 w-9 rounded-lg sm:w-30" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </UiCard>
        </div>

        <UiCard class="shadow-xs">
          <UiCardHeader>
            <div class="flex h-lh items-center text-base leading-snug">
              <UiSkeleton class="h-4 w-36" />
            </div>
          </UiCardHeader>
          <UiCardContent class="space-y-3 text-sm">
            <div
              v-for="i in 3"
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
          </UiCardContent>
          <UiCardFooter class="flex-col items-stretch gap-3">
            <UiSkeleton class="h-12 rounded-2xl" />
            <div class="text-xs leading-relaxed">
              <div class="flex h-lh items-center">
                <UiSkeleton class="h-3 w-full" />
              </div>
              <div class="flex h-lh items-center">
                <UiSkeleton class="h-3 w-2/3" />
              </div>
            </div>
          </UiCardFooter>
        </UiCard>
      </div>
    </div>

    <div
      v-else
      class="space-y-4"
    >
      <AdminPageHeader v-if="cart && !cart.is_empty">
        <span class="text-sm text-muted-foreground">{{ t('user.cart.count', cart.total_items) }}</span>
        <template #actions>
          <UiButton
            variant="ghost"
            size="sm"
            class="text-destructive hover:bg-destructive/10 hover:text-destructive"
            :disabled="busyItem === 'clear'"
            @click="confirmClear = true"
          >
            <Icon
              name="lucide:trash-2"
              class="text-sm"
            />
            {{ t('user.cart.clear') }}
          </UiButton>
        </template>
      </AdminPageHeader>

      <template v-if="!cart || cart.is_empty">
        <UiAlert
          v-if="error"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          <UiAlertDescription>{{ error }}</UiAlertDescription>
        </UiAlert>
        <EmptyState
          icon="lucide:shopping-cart"
          :title="t('user.cart.empty')"
        >
          <UiButton @click="startDesign()">
            <Icon
              name="lucide:sparkles"
              class="text-base"
            />
            {{ t('user.common.startDesign') }}
          </UiButton>
        </EmptyState>
      </template>

      <div
        v-else
        class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]"
      >
        <div class="min-w-0 space-y-4">
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
              {{ t('user.cart.blocked') }}
            </UiAlertDescription>
          </UiAlert>

          <UiCard
            v-for="item in cart.items"
            :key="item.uuid"
            class="gap-0 py-0 shadow-xs transition-opacity"
            :class="{ 'opacity-60': busyItem === item.uuid }"
            :aria-busy="busyItem === item.uuid"
          >
            <div class="flex flex-col gap-4 p-4 sm:flex-row sm:gap-5 sm:p-5">
              <CommerceMockupGallery
                :images="item.mockups"
                :alt="item.product_name"
                class="sm:w-48 sm:shrink-0"
              />
              <div class="flex min-w-0 flex-1 flex-col">
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <h2 class="text-base font-semibold leading-snug text-foreground">
                      {{ item.product_name }}
                    </h2>
                    <p class="mt-1 flex flex-wrap items-center gap-x-1.5 text-sm text-muted-foreground">
                      {{ item.variant_name }}
                      <span aria-hidden="true">·</span>
                      <span class="inline-flex items-center gap-1.5">
                        <span
                          class="size-3 rounded-full ring-1 ring-inset ring-black/15"
                          :style="{ background: item.color_hex }"
                        />
                        {{ item.color_name }}
                      </span>
                      <template v-if="item.size">
                        <span aria-hidden="true">·</span>
                        <span>{{ t('user.cart.size') }} <span class="font-medium text-foreground">{{ item.size }}</span></span>
                      </template>
                    </p>
                  </div>
                  <div class="shrink-0 text-right">
                    <p class="text-base font-bold tabular-nums text-foreground">
                      {{ formatMoney(item.total_price) }}
                    </p>
                    <p class="mt-0.5 text-xs tabular-nums text-muted-foreground">
                      {{ t('user.common.perPiece', { price: formatMoney(item.unit_price) }) }}
                    </p>
                  </div>
                </div>

                <div class="mt-3 flex flex-wrap gap-1.5">
                  <UiBadge
                    v-for="m in item.quote.methods"
                    :key="m.method"
                    variant="outline"
                    class="h-6 gap-1.5 px-2.5 text-muted-foreground"
                  >
                    <Icon
                      :name="METHOD_INFO[m.method].icon"
                      class="text-xs"
                    />
                    {{ t(`user.method.${m.method}`) }} · {{ Math.round(Number(m.area_cm2)) }} cm²
                  </UiBadge>
                  <UiStatusBadge
                    v-if="!item.available"
                    tone="warn"
                  >
                    {{ t('user.common.notOnSale') }}
                  </UiStatusBadge>
                </div>

                <div class="mt-auto pt-4">
                  <UiSeparator class="mb-3" />
                  <div class="flex flex-wrap items-center justify-between gap-2">
                    <div
                      class="flex h-10 items-center rounded-xl border border-border bg-background px-1"
                      role="group"
                      :aria-label="t('user.cart.quantityOf', { name: item.product_name })"
                    >
                      <UiButton
                        variant="ghost"
                        size="icon-sm"
                        :disabled="busyItem === item.uuid || item.quantity <= 1"
                        :aria-label="t('user.cart.decrease')"
                        @click="handleQuantityChange(item.uuid, Math.max(1, item.quantity - 1))"
                      >
                        <Icon
                          name="lucide:minus"
                          class="text-base"
                        />
                      </UiButton>
                      <span
                        class="flex w-9 justify-center text-sm font-semibold tabular-nums text-foreground"
                        aria-live="polite"
                      >
                        <Icon
                          v-if="busyItem === item.uuid"
                          name="lucide:loader-2"
                          class="animate-spin text-base text-muted-foreground"
                        />
                        <template v-else>{{ item.quantity }}</template>
                      </span>
                      <UiButton
                        variant="ghost"
                        size="icon-sm"
                        :disabled="busyItem === item.uuid || item.quantity >= MAX_QUANTITY"
                        :aria-label="t('user.cart.increase')"
                        @click="handleQuantityChange(item.uuid, item.quantity + 1)"
                      >
                        <Icon
                          name="lucide:plus"
                          class="text-base"
                        />
                      </UiButton>
                    </div>

                    <div class="flex items-center gap-1">
                      <UiButton
                        v-if="item.design_id"
                        as-child
                        variant="ghost"
                        size="sm"
                      >
                        <NuxtLink :to="localePath(`/studio/${item.product_slug}?design=${item.design_id}`)">
                          <Icon
                            name="lucide:pencil"
                            class="text-sm"
                          />
                          {{ t('user.common.edit') }}
                        </NuxtLink>
                      </UiButton>
                      <UiButton
                        variant="ghost"
                        size="sm"
                        class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                        :disabled="busyItem === item.uuid"
                        :aria-label="t('user.cart.removeFromCart')"
                        @click="handleRemove(item.uuid)"
                      >
                        <Icon
                          name="lucide:trash-2"
                          class="text-sm"
                        />
                        <span class="hidden sm:inline">{{ t('user.common.remove') }}</span>
                      </UiButton>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </UiCard>
        </div>

        <aside class="lg:sticky lg:top-4">
          <UiCard class="shadow-xs">
            <UiCardHeader>
              <UiCardTitle class="font-semibold">
                {{ t('user.cart.summary') }}
              </UiCardTitle>
            </UiCardHeader>
            <UiCardContent class="space-y-3 text-sm">
              <div class="flex items-center justify-between gap-3">
                <span class="text-muted-foreground">{{ t('user.cart.itemCount') }}</span>
                <span class="font-medium tabular-nums text-foreground">{{ t('user.common.units', cart.total_items) }}</span>
              </div>
              <div class="flex items-center justify-between gap-3">
                <span class="text-muted-foreground">{{ t('user.common.subtotal') }}</span>
                <span class="font-medium tabular-nums text-foreground">{{ formatMoney(cart.subtotal) }}</span>
              </div>
              <div class="flex items-center justify-between gap-3">
                <span class="text-muted-foreground">{{ t('user.common.delivery') }}</span>
                <span class="text-right text-muted-foreground">{{ t('user.cart.deliveryAtCheckout') }}</span>
              </div>
              <UiSeparator />
              <div class="flex h-7 items-center justify-between gap-3">
                <span class="font-semibold text-foreground">{{ t('user.common.total') }}</span>
                <span class="text-xl font-bold tabular-nums text-foreground">{{ formatMoney(cart.total_amount) }}</span>
              </div>
            </UiCardContent>
            <UiCardFooter class="flex-col items-stretch gap-3">
              <UiButton
                v-if="!cart.blocked"
                as-child
                size="lg"
              >
                <NuxtLink :to="localePath('/user/checkout')">
                  {{ t('user.cart.toCheckout') }}
                  <Icon
                    name="lucide:arrow-right"
                    class="text-lg"
                  />
                </NuxtLink>
              </UiButton>
              <UiButton
                v-else
                size="lg"
                disabled
              >
                {{ t('user.cart.toCheckout') }}
                <Icon
                  name="lucide:arrow-right"
                  class="text-lg"
                />
              </UiButton>
              <p class="text-xs leading-relaxed text-muted-foreground">
                {{ t('user.cart.afterOrder') }}
              </p>
            </UiCardFooter>
          </UiCard>
        </aside>
      </div>
    </div>

    <UiAlertDialog v-model:open="confirmClear">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('user.cart.clear') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>{{ t('user.common.cancel') }}</UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="busyItem === 'clear'"
            @click="handleClear"
          >
            <Icon
              v-if="busyItem === 'clear'"
              name="lucide:loader-2"
              class="animate-spin text-base"
            />
            {{ t('user.cart.clearConfirm') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
