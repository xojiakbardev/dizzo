<script setup lang="ts">
import { PRODUCTION_LABELS } from '~/lib/orderStatus';
import type { OrderItem } from '~/types/commerce';
import type { CatalogMethod } from '~/types/catalog';
import { METHOD_INFO, METHOD_LABELS } from '~/types/catalog';

const props = withDefaults(defineProps<{
  item: OrderItem;
  showProduction?: boolean;
}>(), {
  showProduction: false,
});

const { t, locale } = useI18n();

const PRODUCTION_TONES = {
  PENDING: 'neutral',
  PRINTING: 'brand',
  PRINTED: 'info',
  PACKED: 'success',
} as const satisfies Record<OrderItem['production_status'], string>;

const active = ref(0);
const show3D = ref(false);

watch(() => props.item.mockups.length, (n) => {
  if (active.value >= n) active.value = 0;
});

const methods = computed<CatalogMethod[]>(() => [
  ...new Set([...props.item.files.map(f => f.method), ...(props.item.quote?.methods ?? []).map(m => m.method)]),
]);

const mm = (v: unknown) => Number(v ?? 0).toLocaleString(locale.value === 'en' ? 'en-US' : 'ru-RU', { maximumFractionDigits: 1 });

function whereText(anchor: Record<string, unknown>): string | null {
  if ('start_mm' in anchor) return t('admin.orders.item.whereCylinder', { start: mm(anchor.start_mm), top: mm(anchor.top_mm) });
  if ('x_mm' in anchor) {
    const where = t('admin.orders.item.whereFlat', { x: mm(anchor.x_mm), y: mm(anchor.y_mm) });
    if (anchor.side === 'back') return t('admin.orders.item.onSide', { side: t('admin.orders.item.back'), where });
    if (anchor.side === 'front') return t('admin.orders.item.onSide', { side: t('admin.orders.item.front'), where });
    return where;
  }
  return null;
}

interface ContentRow {
  key: string;
  kind: string;
  content: string;
  font: string | null;
  size: string;
  url: string | null;
}

const contentRows = computed<ContentRow[]>(() => (props.item.document?.layers ?? [])
  .filter(l => l.area !== null && (l.text || l.image))
  .map(l => (l.text
    ? {
        key: l.id,
        kind: t('admin.orders.item.text'),
        content: t('admin.orders.item.quoted', { text: l.text.content }),
        font: String(l.text.font),
        size: `${mm(l.text.size_mm)} mm`,
        url: null,
      }
    : {
        key: l.id,
        kind: t('admin.orders.item.image'),
        content: `${l.image!.px_w}×${l.image!.px_h} px`,
        font: null,
        size: `${mm(l.w_mm)}×${mm(l.h_mm)} mm`,
        url: l.image!.url,
      })));
</script>

<template>
  <UiCard class="gap-0 py-0 overflow-hidden shadow-xs border border-border">
    <UiCardHeader class="flex flex-wrap items-center justify-between gap-3 border-b bg-muted/25 px-4 py-3.5 sm:px-5">
      <div class="min-w-0 flex-1">
        <UiCardTitle class="truncate font-bold text-base sm:text-lg text-foreground">
          {{ item.product_name }}
        </UiCardTitle>
      </div>

      <div class="flex items-center gap-3">
        <UiStatusBadge
          v-if="showProduction"
          :tone="PRODUCTION_TONES[item.production_status]"
        >
          {{ PRODUCTION_LABELS[item.production_status] }}
        </UiStatusBadge>

        <div class="text-right font-bold text-base tabular-nums text-foreground">
          {{ formatMoney(item.total_price) }}
        </div>
      </div>
    </UiCardHeader>

    <UiCardContent class="p-4 sm:p-5 space-y-5">
      <div class="grid gap-5 sm:gap-6 md:grid-cols-[14rem_minmax(0,1fr)]">
        <!-- Mockup preview + 3D button -->
        <div class="mx-auto w-full max-w-xs space-y-2.5 md:max-w-none">
          <div class="relative aspect-square w-full overflow-hidden rounded-xl border border-border bg-muted/20">
            <a
              v-if="item.mockups.length"
              :href="item.mockups[active]"
              target="_blank"
              rel="noopener"
              class="block h-full w-full outline-none focus-visible:ring-2 focus-visible:ring-ring"
              :aria-label="t('admin.orders.item.openFrame')"
            >
              <MediaThumb
                :src="item.mockups[active]"
                :alt="t('admin.orders.item.frame', { n: active + 1 })"
                class="h-full w-full object-contain transition duration-200 hover:scale-102"
              />
            </a>
            <MediaThumb
              v-else
              class="h-full w-full object-contain"
            />

            <!-- Keep the 3D entry point with the preview it controls. -->
            <UiButton
              variant="outline"
              size="sm"
              class="absolute right-3 bottom-3 z-10 gap-2 border-primary/30 bg-background/90 text-primary shadow-sm backdrop-blur hover:bg-background hover:border-primary/40 font-semibold"
              @click="show3D = true"
            >
              <Icon
                name="lucide:box"
                class="size-4 text-primary"
              />
              <span>3D</span>
            </UiButton>
          </div>

          <!-- Thumbnail switcher -->
          <div
            v-if="item.mockups.length > 1"
            class="grid grid-cols-5 gap-1.5"
          >
            <button
              v-for="(src, i) in item.mockups"
              :key="src"
              type="button"
              class="aspect-square rounded-lg border overflow-hidden transition outline-none focus-visible:ring-2 focus-visible:ring-ring"
              :class="i === active ? 'border-primary ring-1 ring-primary' : 'border-border opacity-70 hover:opacity-100'"
              @click="active = i"
            >
              <MediaThumb
                :src="src"
                :alt="t('admin.orders.item.frame', { n: i + 1 })"
                class="h-full w-full object-cover"
              />
            </button>
          </div>

        </div>

        <!-- Specifications list -->
        <div class="min-w-0 space-y-4">
          <dl class="divide-y divide-border/60 text-sm">
            <!-- Color -->
            <div
              v-if="item.color_name"
              class="flex items-center justify-between py-2.5 first:pt-0"
            >
              <dt class="shrink-0 text-muted-foreground font-medium">
                {{ t('admin.orders.item.color') }}
              </dt>
              <dd class="flex items-center gap-2 font-medium text-foreground">
                <span
                  class="size-3.5 rounded-full border border-black/15 shrink-0 shadow-2xs"
                  :style="{ background: item.color_hex }"
                />
                <span>{{ item.color_name }}</span>
              </dd>
            </div>

            <!-- Size -->
            <div
              v-if="item.size"
              class="flex items-center justify-between py-2.5"
            >
              <dt class="shrink-0 text-muted-foreground font-medium">
                {{ t('admin.orders.item.col.size') }}
              </dt>
              <dd class="font-semibold font-mono text-foreground">
                <UiBadge
                  variant="secondary"
                  class="px-2 py-0.5"
                >
                  {{ item.size }}
                </UiBadge>
              </dd>
            </div>

            <!-- Shape -->
            <div
              v-if="item.shape"
              class="flex items-center justify-between py-2.5"
            >
              <dt class="shrink-0 text-muted-foreground font-medium">
                {{ t('admin.orders.item.shape') }}
              </dt>
              <dd class="font-medium text-foreground">
                {{ item.shape.name }}
              </dd>
            </div>

            <!-- Print methods -->
            <div
              v-if="methods.length"
              class="flex items-center justify-between py-2.5"
            >
              <dt class="shrink-0 text-muted-foreground font-medium">
                {{ t('admin.orders.item.col.method') }}
              </dt>
              <dd class="flex flex-wrap gap-1">
                <UiBadge
                  v-for="m in methods"
                  :key="m"
                  variant="secondary"
                  class="gap-1 font-medium text-xs"
                >
                  <Icon
                    v-if="METHOD_INFO[m]?.icon"
                    :name="METHOD_INFO[m].icon"
                    class="text-primary size-3.5"
                  />
                  {{ METHOD_LABELS[m] || t(`user.method.${m}`) }}
                </UiBadge>
              </dd>
            </div>

            <!-- Quantity -->
            <div class="flex items-center justify-between py-2.5">
              <dt class="shrink-0 text-muted-foreground font-medium">
                {{ t('admin.orders.item.quantity') }}
              </dt>
              <dd class="font-semibold text-foreground">
                {{ t('admin.orders.item.pieces', { n: item.quantity }) }}
              </dd>
            </div>

            <!-- Unit price -->
            <div class="flex items-center justify-between py-2.5">
              <dt class="shrink-0 text-muted-foreground font-medium">
                {{ t('admin.orders.item.unitPrice') }}
              </dt>
              <dd class="tabular-nums text-muted-foreground">
                {{ formatMoney(item.unit_price) }}
              </dd>
            </div>

            <!-- Total price -->
            <div class="flex items-center justify-between py-2.5">
              <dt class="shrink-0 font-semibold text-foreground">
                {{ t('admin.orders.item.totalPieces', { n: item.quantity }) }}
              </dt>
              <dd class="text-base font-bold tabular-nums text-foreground">
                {{ formatMoney(item.total_price) }}
              </dd>
            </div>
          </dl>

        </div>
      </div>

      <!-- Placements and design layers are order information, not a hidden panel. -->
      <div
        v-if="item.placements?.length || contentRows.length"
        class="border-t border-border pt-4 space-y-4"
      >
        <!-- Placements -->
        <div
          v-if="item.placements?.length"
          class="space-y-2"
        >
          <div class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            {{ t('admin.orders.item.placement') }}
          </div>
          <div class="grid w-full grid-cols-1 gap-2">
            <div
              v-for="p in item.placements"
              :key="p.area"
              class="w-full rounded-xl border border-border bg-muted/20 p-3 text-xs space-y-1"
            >
              <div class="font-semibold text-foreground flex items-center justify-between">
                <span>{{ p.area_name }}</span>
                <span class="font-mono text-muted-foreground">{{ mm(p.width_mm) }}×{{ mm(p.height_mm) }} mm</span>
              </div>
              <div
                v-if="whereText(p.anchor)"
                class="text-muted-foreground"
              >
                {{ whereText(p.anchor) }}
              </div>
              <div
                v-if="p.placement_note"
                class="text-[11px] text-muted-foreground italic"
              >
                {{ p.placement_note }}
              </div>
            </div>
          </div>
        </div>

        <!-- Design Content (User's text and pictures) -->
        <div
          v-if="contentRows.length"
          class="space-y-2"
        >
          <div class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            {{ t('admin.orders.item.designContent') }}
          </div>
          <div class="grid w-full grid-cols-1 gap-2">
            <div
              v-for="c in contentRows"
              :key="c.key"
              class="flex w-full items-center gap-3 rounded-xl border border-border bg-muted/20 p-2.5 text-xs"
            >
              <MediaThumb
                v-if="c.url"
                :src="c.url"
                class="size-10 shrink-0 rounded-lg border border-border object-contain"
              />
              <div
                v-else
                class="size-10 shrink-0 rounded-lg border border-border bg-muted grid place-items-center"
              >
                <Icon
                  name="lucide:type"
                  class="size-5 text-muted-foreground"
                />
              </div>
              <div class="min-w-0 flex-1">
                <div class="font-semibold text-foreground truncate">
                  {{ c.content }}
                </div>
                <div class="text-[11px] text-muted-foreground flex items-center gap-2 mt-0.5">
                  <span>{{ c.kind }}</span>
                  <span v-if="c.font">· {{ c.font }}</span>
                  <span>· {{ c.size }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </UiCardContent>

    <!-- 3D simulation modal -->
    <CommerceOrderItem3DModal
      v-model="show3D"
      :item="item"
    />
  </UiCard>
</template>
