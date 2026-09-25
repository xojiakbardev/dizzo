<script setup lang="ts">
// The order card under the stage: the type's name and description, its
// colours, its sizes (clothing only) and the print method (for the whole
// design); then what the price is made of, the total, quantity and
// "Savatga qo‘shish".
import { useStudioContext } from '~/composables/useStudio';
import type { CatalogMethod } from '~/types/catalog';
import { METHOD_LABELS, METHOD_INFO } from '~/types/catalog';

const emit = defineEmits<{
  addToCart: [quantity: number];
}>();
const {
  variant, color, colorId, liveQuote, provisionalPrice, blocked, placedCount, problemCount, croppedCount,
  saveState, saveError, cartState, cartStep, cartError, confirmQuote, confirmPrice, cancelCart,
  pickColor, designMethod, setDesignMethod, methods, editingTemplate, background, canBackground, setBackground,
  sizes, size, sizeLabel, needsSize, pickSize,
} = useStudioContext();

const { t } = useI18n();
const quantity = defineModel<number>('quantity', { default: 1 });
const ALL_METHODS: CatalogMethod[] = ['uv', 'engrave'];
const methodError = ref<string | null>(null);

async function chooseMethod(m: CatalogMethod) {
  methodError.value = await setDesignMethod(m);
}

const unitPrice = computed(() => (liveQuote.value ? Number(liveQuote.value.unit_price) : provisionalPrice.value));
const note = computed(() => {
  if (editingTemplate.value) return t('studio.order.editingTemplate');
  if (saveState.value === 'error') return saveError.value ?? t('studio.save.failed');
  return null;
});
const needsSizePick = computed(() => needsSize.value && !sizeLabel.value);
const orderReady = computed(() => (
  placedCount.value > 0
  && problemCount.value === 0
  && !needsSizePick.value
  && !editingTemplate.value
));

const label = 'mb-2.5 text-[13px] font-semibold text-foreground';
</script>

<template>
  <div class="rounded-2xl border border-border/70 bg-card p-4 shadow-xs sm:p-5">
    <!-- Colour, size, method -->
    <div
      class="grid gap-5 lg:gap-0 lg:divide-x lg:divide-border/70"
      :class="needsSize ? 'lg:grid-cols-3' : 'lg:grid-cols-2'"
    >
      <section
        v-if="variant"
        class="lg:pr-5"
      >
        <h3 :class="label">
          {{ $t('studio.order.color') }}<span class="font-normal text-muted-foreground">: {{ color?.name }}</span>
        </h3>
        <!-- Colour swatches — scrollable row -->
        <div class="scrollbar-none -mx-1.5 flex snap-x snap-mandatory items-center gap-2.5 overflow-x-auto overflow-y-hidden scroll-px-1.5 px-1.5 py-1">
          <UiButton
            v-for="c in variant.colors"
            :key="c.id"
            variant="outline"
            size="icon"
            class="size-11 shrink-0 snap-start overflow-hidden rounded-full border-black/15 p-0 shadow-sm"
            :class="c.id === colorId ? 'ring-2 ring-primary ring-offset-2' : ''"
            :style="!c.images?.[0] ? { background: c.hex } : undefined"
            :title="Number(c.surcharge) > 0 ? `${c.name} (+${formatMoney(c.surcharge)})` : c.name"
            :aria-label="c.name"
            :aria-pressed="c.id === colorId"
            @click="pickColor(c.id)"
          >
            <img
              v-if="c.images?.[0]"
              :src="c.images[0]"
              :alt="c.name"
              class="size-full object-cover"
            >
          </UiButton>
        </div>
        <UiLabel
          v-if="canBackground || background"
          class="mt-2 flex w-fit cursor-pointer items-center gap-2.5 text-[13px] font-medium text-foreground"
        >
          <UiSwitch
            :model-value="background"
            :disabled="!canBackground && !background"
            @update:model-value="(on: boolean) => setBackground(on)"
          />
          {{ $t('studio.order.background', { color: color?.name?.toLowerCase() ?? '' }) }}
        </UiLabel>
      </section>

      <section
        v-if="needsSize"
        class="lg:px-5"
      >
        <h3 :class="label">
          {{ $t('studio.order.size') }}<span class="font-normal text-muted-foreground">: {{ sizeLabel ?? $t('studio.order.sizeNone') }}</span>
        </h3>
        <div class="flex flex-wrap items-center gap-2">
          <UiButton
            v-for="s in sizes"
            :key="s.label"
            variant="outline"
            class="h-11 min-w-11 px-3 font-semibold text-foreground"
            :class="s.label === sizeLabel ? 'border-primary bg-primary/10 ring-1 ring-primary' : ''"
            :disabled="!s.is_available"
            :title="Number(s.surcharge) > 0 ? `${s.label} (+${formatMoney(s.surcharge)})` : s.label"
            :aria-pressed="s.label === sizeLabel"
            @click="pickSize(s.label)"
          >
            {{ s.label }}
          </UiButton>
        </div>
      </section>

      <section class="lg:pl-5">
        <h3 :class="label">
          {{ $t('studio.order.method') }}
        </h3>
        <UiSelect
          :model-value="designMethod ?? undefined"
          @update:model-value="(v) => chooseMethod(v as CatalogMethod)"
        >
          <UiSelectTrigger class="w-full h-11 px-3 py-2">
            <UiSelectValue>
              <template v-if="designMethod" #default>
                <span class="flex items-center gap-2">
                  <span class="flex size-5 shrink-0 items-center justify-center rounded bg-primary/10 text-primary">
                    <Icon :name="METHOD_INFO[designMethod].icon" class="text-xs" />
                  </span>
                  <span class="text-xs font-semibold text-foreground">{{ METHOD_LABELS[designMethod] }}</span>
                </span>
              </template>
            </UiSelectValue>
          </UiSelectTrigger>
          <UiSelectContent
            position="popper"
            side="bottom"
            align="start"
            :side-offset="4"
          >
            <UiSelectItem
              v-for="m in ALL_METHODS"
              :key="m"
              :value="m"
              :disabled="!methods.includes(m)"
              class="py-1.5 px-2.5"
            >
              <span class="flex items-center gap-2.5">
                <span
                  class="flex size-6 shrink-0 items-center justify-center rounded-md"
                  :class="methods.includes(m) ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'"
                >
                  <Icon :name="METHOD_INFO[m].icon" class="text-sm" />
                </span>
                <span class="min-w-0">
                  <span class="block text-xs font-semibold leading-tight text-foreground">{{ METHOD_LABELS[m] }}</span>
                  <span class="block text-[11px] leading-tight text-muted-foreground">{{ METHOD_INFO[m].short }}</span>
                </span>
              </span>
            </UiSelectItem>
          </UiSelectContent>
        </UiSelect>
        <p
          v-if="methodError"
          class="mt-2 text-xs font-medium text-amber-800"
        >
          {{ methodError }}
        </p>
      </section>
    </div>

    <UiSeparator class="my-5" />

    <div class="grid items-start gap-4 lg:grid-cols-2 lg:gap-6">
      <div class="space-y-2">
        <UiAlert
          v-if="needsSizePick"
          variant="warning"
        >
          <Icon name="lucide:ruler" />
          <UiAlertTitle>{{ $t('studio.order.pickSize') }}</UiAlertTitle>
        </UiAlert>
        <UiAlert
          v-else-if="placedCount === 0"
          variant="warning"
        >
          <Icon name="lucide:circle-alert" />
          <UiAlertTitle>{{ $t('studio.order.emptyHint') }}</UiAlertTitle>
        </UiAlert>
        <UiAlert
          v-else-if="problemCount"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          <UiAlertTitle>{{ $t('studio.order.problems', problemCount) }}</UiAlertTitle>
        </UiAlert>
        <UiAlert
          v-if="croppedCount"
          variant="warning"
        >
          <Icon name="lucide:scissors" />
          <UiAlertTitle>{{ $t('studio.order.cropped', croppedCount) }}</UiAlertTitle>
        </UiAlert>
        <UiAlert
          v-else-if="orderReady && !cartError"
          variant="success"
        >
          <Icon name="lucide:circle-check" />
          <UiAlertTitle>{{ $t('studio.order.allClearTitle') }}</UiAlertTitle>
          <UiAlertDescription class="font-medium text-emerald-800/80">
            {{ $t('studio.order.allClear') }}
          </UiAlertDescription>
        </UiAlert>
        <UiAlert
          v-if="cartError"
          variant="destructive"
        >
          <Icon name="lucide:circle-x" />
          <UiAlertTitle>{{ cartError }}</UiAlertTitle>
        </UiAlert>
        <UiAlert
          v-if="note"
          variant="warning"
        >
          <Icon name="lucide:info" />
          <UiAlertTitle>{{ note }}</UiAlertTitle>
        </UiAlert>
      </div>

      <div class="space-y-3">
        <section>
          <h3 :class="label">
            {{ $t('studio.order.summary') }}
          </h3>
          <dl class="divide-y divide-border/70 rounded-xl border border-border/70 text-[13px]">
            <div
              v-if="variant"
              class="flex justify-between gap-3 px-3 py-2"
            >
              <dt class="truncate text-muted-foreground">
                {{ variant.name }}
              </dt>
              <dd class="shrink-0 font-semibold text-foreground">
                {{ formatMoney(variant.base_price) }}
              </dd>
            </div>
            <div
              v-if="color && Number(color.surcharge) > 0"
              class="flex justify-between gap-3 px-3 py-2"
            >
              <dt class="truncate text-muted-foreground">
                {{ $t('studio.order.color') }}: {{ color.name }}
              </dt>
              <dd class="shrink-0 font-semibold text-foreground">
                +{{ formatMoney(color.surcharge) }}
              </dd>
            </div>
            <div
              v-if="size && Number(size.surcharge) > 0"
              class="flex justify-between gap-3 px-3 py-2"
            >
              <dt class="truncate text-muted-foreground">
                {{ $t('studio.order.size') }}: {{ size.label }}
              </dt>
              <dd class="shrink-0 font-semibold text-foreground">
                +{{ formatMoney(size.surcharge) }}
              </dd>
            </div>
            <template v-if="liveQuote">
              <div
                v-for="m in liveQuote.methods"
                :key="m.method"
                class="flex justify-between gap-3 px-3 py-2"
              >
                <dt class="truncate text-muted-foreground">
                  {{ METHOD_LABELS[m.method] }} · {{ $t('studio.order.areaCm2', { n: Math.round(Number(m.area_cm2)) }) }}
                </dt>
                <dd class="shrink-0 font-semibold text-foreground">
                  +{{ formatMoney(m.surcharge) }}
                </dd>
              </div>
            </template>
          </dl>
        </section>

        <div class="flex flex-wrap items-center justify-between gap-3 pt-1">
          <div class="text-xl font-extrabold tabular-nums text-foreground sm:text-2xl">
            <template v-if="unitPrice !== null">{{ liveQuote ? '' : '≈ ' }}{{ formatMoney(unitPrice * quantity) }}</template>
            <UiSkeleton
              v-else
              class="inline-block h-7 w-28 align-middle"
            />
          </div>

          <div class="flex items-center gap-2.5">
            <div class="flex h-11 items-center rounded-xl border border-border bg-background">
              <UiButton
                variant="ghost"
                size="icon"
                :disabled="quantity <= 1"
                :aria-label="$t('studio.order.decrease')"
                @click="quantity--"
              >
                <Icon name="lucide:minus" />
              </UiButton>
              <span
                class="w-8 text-center text-sm font-bold tabular-nums"
                aria-live="polite"
              >{{ quantity }}</span>
              <UiButton
                variant="ghost"
                size="icon"
                :disabled="quantity >= 1000"
                :aria-label="$t('studio.order.increase')"
                @click="quantity = Math.min(1000, quantity + 1)"
              >
                <Icon name="lucide:plus" />
              </UiButton>
            </div>
            <UiButton
              size="lg"
              class="h-11 flex-1 rounded-xl px-5 sm:flex-initial"
              :disabled="cartState === 'working' || blocked || needsSizePick || Boolean(editingTemplate)"
              @click="emit('addToCart', quantity)"
            >
              <Icon name="lucide:shopping-cart" />
              {{ cartState === 'working' ? $t('studio.common.preparing') : $t('studio.cart.add') }}
            </UiButton>
          </div>
        </div>
      </div>
    </div>

    <!-- Full-screen cart-working overlay -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition-opacity duration-300 ease-out"
        leave-active-class="transition-opacity duration-200 ease-in"
        enter-from-class="opacity-0"
        leave-to-class="opacity-0"
      >
        <div
          v-if="cartState === 'working'"
          class="fixed inset-0 z-[9999] flex flex-col items-center justify-center backdrop-blur-sm bg-white/60"
          role="status"
          aria-live="polite"
        >
          <BrandLoader size="clamp(3.5rem, 10vmin, 5rem)" />
          <div class="mt-4 grid text-center text-[14px] font-medium text-slate-700">
            <Transition
              enter-active-class="transition duration-200 ease-out"
              leave-active-class="transition duration-150 ease-in"
              enter-from-class="opacity-0 translate-y-1"
              leave-to-class="opacity-0 -translate-y-1"
            >
              <span
                v-if="cartStep"
                :key="cartStep"
                class="[grid-area:1/1] tabular-nums"
              >{{ cartStep }}</span>
            </Transition>
          </div>
        </div>
      </Transition>
    </Teleport>

    <UiDialog
      :open="Boolean(confirmQuote)"
      @update:open="(open: boolean) => { if (!open) cancelCart(); }"
    >
      <UiDialogContent class="sm:max-w-md">
        <UiDialogHeader>
          <UiDialogTitle>{{ $t('studio.order.priceUpdated') }}</UiDialogTitle>
        </UiDialogHeader>
        <p
          v-if="confirmQuote"
          class="text-sm text-muted-foreground"
        >
          <i18n-t
            keypath="studio.order.exactPrice"
            scope="global"
          >
            <template #price>
              <strong class="text-foreground">{{ formatMoney(confirmQuote.unit_price) }}</strong>
            </template>
          </i18n-t>
          {{ $t('studio.order.confirmPrice') }}
        </p>
        <UiDialogFooter>
          <UiButton
            variant="outline"
            @click="cancelCart"
          >
            {{ $t('studio.common.cancel') }}
          </UiButton>
          <UiButton @click="confirmPrice">
            {{ $t('studio.order.confirmAdd') }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
