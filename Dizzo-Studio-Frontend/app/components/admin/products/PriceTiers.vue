<script setup lang="ts">
// Area-based surcharge tiers for one print method. Each row starts where the
// previous one ends and the last is open-ended, so only upper bounds are typed.
import { getApiErrorMessage } from '~/composables/useApi';
import type { CatalogMethod, PriceTier } from '~/types/catalog';
import { METHOD_INFO, METHOD_LABELS } from '~/types/catalog';

const props = defineProps<{ productId: number; method: CatalogMethod; tiers: PriceTier[] }>();
const { run, busy } = useCatalogAdminActions();
const { t } = useI18n();
const error = ref<string | null>(null);
const saved = ref(false);

interface Row { max_cm2: string; surcharge: string }
const rows = ref<Row[]>(
  props.tiers.length
    ? props.tiers.map(tier => ({ max_cm2: tier.max_cm2 ?? '', surcharge: tier.surcharge }))
    : [{ max_cm2: '', surcharge: '0' }],
);
watch(rows, () => {
  saved.value = false;
}, { deep: true });

const from = (i: number) => (i === 0 ? '0' : rows.value[i - 1]!.max_cm2 || '…');
function addRow() {
  rows.value.splice(rows.value.length - 1, 0, { max_cm2: '', surcharge: rows.value.at(-1)!.surcharge });
}

async function save() {
  error.value = null;
  const tiers = rows.value.map((row, i) => ({
    min_cm2: i === 0 ? '0' : rows.value[i - 1]!.max_cm2,
    max_cm2: i === rows.value.length - 1 ? null : row.max_cm2,
    surcharge: row.surcharge || '0',
  }));
  try {
    await run('put', `/admin/catalog/products/${props.productId}/price-tiers/${props.method}/`, { tiers });
    saved.value = true;
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.prices.saveFailed'));
  }
}
</script>

<template>
  <UiCard class="gap-0 py-0">
    <UiCardHeader class="flex items-center justify-between gap-3 border-b py-4">
      <div class="flex min-w-0 items-center gap-2.5">
        <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
          <Icon
            :name="METHOD_INFO[method].icon"
            class="h-4 w-4"
          />
        </span>
        <div class="min-w-0">
          <UiCardTitle class="font-semibold">
            {{ METHOD_LABELS[method] }}
          </UiCardTitle>
        </div>
      </div>
      <UiStatusBadge :tone="tiers.length ? 'success' : 'warn'">
        {{ tiers.length ? t('admin.prices.configured') : t('admin.prices.notConfigured') }}
      </UiStatusBadge>
    </UiCardHeader>
    <UiCardContent class="space-y-3 py-4">
      <div class="hidden grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2.25rem] gap-2 px-2 text-xs font-semibold text-muted-foreground sm:grid">
        <span>{{ t('admin.prices.area') }}</span>
        <span>{{ t('admin.prices.surcharge') }}</span>
      </div>
      <div
        v-for="(row, i) in rows"
        :key="i"
        class="grid grid-cols-[minmax(0,1fr)_2.25rem] items-center gap-2 rounded-xl border border-border bg-card p-3 text-sm sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2.25rem]"
      >
        <div class="flex min-w-0 items-center gap-2">
          <span class="w-10 shrink-0 text-right font-mono text-muted-foreground tabular-nums">{{ from(i) }}</span>
          <span class="text-muted-foreground">–</span>
          <UiInput
            v-if="i < rows.length - 1"
            v-model="row.max_cm2"
            class="h-9 min-w-0 flex-1 bg-card"
            inputmode="decimal"
            :placeholder="t('admin.prices.upTo')"
            :aria-label="t('admin.prices.rangeLimit', { n: i + 1 })"
          />
          <span
            v-else
            class="flex h-9 flex-1 items-center px-3 font-mono text-muted-foreground"
          >∞</span>
        </div>
        <UiButton
          type="button"
          variant="ghost"
          size="icon-sm"
          class="shrink-0 text-destructive hover:bg-destructive/10 hover:text-destructive sm:order-last"
          :disabled="rows.length === 1"
          :aria-label="t('admin.prices.removeRange')"
          @click="rows.splice(i, 1)"
        >
          <Icon
            name="lucide:trash-2"
            class="h-4 w-4"
          />
        </UiButton>
        <div class="relative col-span-2 min-w-0 sm:col-span-1">
          <span class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground">+</span>
          <UiInput
            v-model="row.surcharge"
            class="h-9 bg-card pl-7 pr-12"
            inputmode="decimal"
            :aria-label="t('admin.prices.rangeSurcharge', { n: i + 1 })"
          />
          <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">{{ t('admin.common.sum') }}</span>
        </div>
      </div>
      <AdminAddRow
        :label="t('admin.prices.addRange')"
        @add="addRow"
      />
      <UiAlert
        v-if="error"
        variant="destructive"
      >
        <Icon name="lucide:circle-alert" />
        {{ error }}
      </UiAlert>
    </UiCardContent>
    <UiCardFooter class="justify-end gap-2">
      <UiButton
        type="button"
        size="sm"
        :disabled="busy"
        @click="save"
      >
        <Icon
          :name="saved ? 'lucide:check' : 'lucide:save'"
          class="h-4 w-4"
        />
        {{ saved ? t('admin.common.saved') : t('admin.common.save') }}
      </UiButton>
    </UiCardFooter>
  </UiCard>
</template>
