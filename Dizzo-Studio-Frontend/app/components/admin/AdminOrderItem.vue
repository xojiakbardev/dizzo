<script setup lang="ts">
// One order line as production needs it: the mockup frames (one large, the
// rest to pick from), what was ordered and how its price adds up, then one
// print file per area and method (exact area size at the method's DPI) with
// the white underbase masks, where each area goes on the product and what is
// in it. AdminOrderSkeleton mirrors this card — keep the two in step.
import { getApiErrorMessage } from '~/composables/useApi';
import { PRODUCTION_LABELS } from '~/lib/orderStatus';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { OrderItem, OrderPlacement, PackageFile } from '~/types/commerce';
import type { CatalogMethod } from '~/types/catalog';
import { METHOD_LABELS } from '~/types/catalog';

const props = defineProps<{ orderId: number; item: OrderItem }>();
const { t, locale } = useI18n();
const mutation = useUpdateOrderItemProduction();
const error = ref<string | null>(null);

const mm = (v: unknown) => Number(v ?? 0).toLocaleString(locale.value === 'en' ? 'en-US' : 'ru-RU', { maximumFractionDigits: 1 });

/** Where the area sits, in words, from its anchor (flat and round shapes). */
function whereText(anchor: Record<string, unknown>): string | null {
  if ('start_mm' in anchor) return t('admin.orders.item.whereCylinder', { start: mm(anchor.start_mm), top: mm(anchor.top_mm) });
  if ('x_mm' in anchor) {
    const where = t('admin.orders.item.whereFlat', { x: mm(anchor.x_mm), y: mm(anchor.y_mm) });
    if (anchor.side === 'back') return t('admin.orders.item.onSide', { side: t('admin.orders.item.back'), where });
    if (anchor.side === 'front') return t('admin.orders.item.onSide', { side: t('admin.orders.item.front'), where });
    return where;
  }
  return null; // GLB areas: the placement note and the frames tell where
}

// The frame shown large; the thumbnails under it switch it.
const active = ref(0);
const show3D = ref(false);
watch(() => props.item.mockups.length, (n) => {
  if (active.value >= n) active.value = 0;
});

const methods = computed<CatalogMethod[]>(() => [
  ...new Set([...props.item.files.map(f => f.method), ...(props.item.quote?.methods ?? []).map(m => m.method)]),
]);

// Print files and white underbase masks in one table.
interface FileRow { key: string; area_name: string; url: string; file: PackageFile | null }
const fileRows = computed<FileRow[]>(() => [
  ...props.item.files.map(f => ({ key: `f-${f.url}`, area_name: f.area_name, url: f.url, file: f })),
  ...props.item.underbase.map(u => ({ key: `u-${u.url}`, area_name: u.area_name, url: u.url, file: null })),
]);
const FILE_COLUMNS = computed<DataTableColumn[]>(() => [
  { key: 'area_name', header: t('admin.orders.item.col.area') },
  { key: 'method', header: t('admin.orders.item.col.method') },
  { key: 'size', header: t('admin.orders.item.col.size'), className: 'hidden sm:table-cell' },
  { key: 'dpi', header: 'DPI', className: 'hidden md:table-cell' },
  { key: 'painted', header: t('admin.orders.item.col.painted'), className: 'hidden md:table-cell' },
  { key: 'download', header: '', className: 'text-right' },
]);

const PLACEMENT_COLUMNS = computed<DataTableColumn[]>(() => [
  { key: 'area_name', header: t('admin.orders.item.col.area') },
  { key: 'size', header: t('admin.orders.item.col.size') },
  { key: 'where', header: t('admin.orders.item.col.where'), className: 'hidden sm:table-cell' },
  { key: 'note', header: t('admin.orders.item.col.note'), className: 'hidden md:table-cell' },
  { key: 'svg', header: '', className: 'text-right' },
]);

const generatingSvg = ref<string | null>(null);

// SVG is 1 user-unit = 1 mm, so physical size = width/height attributes.
// Layers use centre-based mm coords (x_mm, y_mm = centre).
async function generateAreaSvg(areaKey: string, widthMm: number, heightMm: number): Promise<string> {
  const layers = (props.item.document?.layers ?? []).filter(l => l.area === areaKey);

  // Pre-fetch all image layers to embed as base64
  const imageDataMap = new Map<string, string>();
  await Promise.all(
    layers
      .filter(l => l.image?.url)
      .map(async (l) => {
        try {
          const resp = await fetch(l.image!.url);
          const blob = await resp.blob();
          const b64 = await new Promise<string>((res, rej) => {
            const r = new FileReader();
            r.onloadend = () => res(r.result as string);
            r.onerror = rej;
            r.readAsDataURL(blob);
          });
          imageDataMap.set(l.id, b64);
        }
        catch { /* skip failed images */ }
      }),
  );

  const layerSvgs = layers.map((l) => {
    // SVG transform: translate to centre, rotate, then render relative to centre
    const cx = l.x_mm;
    const cy = l.y_mm;
    const rot = l.rotation || 0;
    const transform = rot
      ? `translate(${cx} ${cy}) rotate(${rot})`
      : `translate(${cx} ${cy})`;

    if (l.text) {
      const tx = l.text;
      // SVG font-size in mm (1 user-unit = 1 mm). dominant-baseline=central
      // vertically centres the text at the translated origin (= layer centre).
      const anchor = tx.align === 'right' ? 'end' : tx.align === 'center' ? 'middle' : 'start';
      const dx = tx.align === 'right' ? l.w_mm / 2 : tx.align === 'center' ? 0 : -l.w_mm / 2;
      return `  <text transform="${transform}"
        x="${dx.toFixed(3)}" y="0"
        font-family="'${tx.font}',sans-serif"
        font-size="${tx.size_mm}mm"
        font-weight="${tx.bold ? 'bold' : 'normal'}"
        font-style="${tx.italic ? 'italic' : 'normal'}"
        fill="${tx.color}"
        text-anchor="${anchor}"
        dominant-baseline="central"
        xml:space="preserve">${tx.content.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</text>`;
    }

    if (l.image) {
      const data = imageDataMap.get(l.id);
      if (!data) return '';
      return `  <image transform="${transform}"
        x="${(-l.w_mm / 2).toFixed(3)}" y="${(-l.h_mm / 2).toFixed(3)}"
        width="${l.w_mm}" height="${l.h_mm}"
        href="${data}"
        preserveAspectRatio="none" />`;
    }

    return '';
  }).filter(Boolean).join('\n');

  // Embed Google Fonts for text layers so the SVG is self-contained
  const usedFonts = [...new Set(
    layers.filter(l => l.text).map(l => l.text!.font),
  )];
  const fontUrls = usedFonts.map(f => `https://fonts.googleapis.com/css2?family=${encodeURIComponent(f)}:ital,wght@0,400;0,700;1,400;1,700&display=swap`);
  const styleBlock = fontUrls.length
    ? `  <defs>\n    <style>\n${fontUrls.map(u => `      @import url('${u}');`).join('\n')}\n    </style>\n  </defs>`
    : '';

  return `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${widthMm}mm"
     height="${heightMm}mm"
     viewBox="0 0 ${widthMm} ${heightMm}"
     version="1.1">
  <!-- Dizzo Print-Ready Artwork -->
  <!-- Physical size: ${widthMm}mm x ${heightMm}mm (1 user-unit = 1 mm) -->
  <!-- Product: ${props.item.product_name} · ${props.item.variant_name} -->
  <!-- Area: ${areaKey} -->
${styleBlock}
${layerSvgs}
</svg>`;
}

async function downloadPlacementSvg(placement: OrderPlacement) {
  if (generatingSvg.value) return;
  generatingSvg.value = placement.area;
  try {
    const widthMm = Number(placement.width_mm);
    const heightMm = Number(placement.height_mm);
    const svgContent = await generateAreaSvg(placement.area, widthMm, heightMm);
    const safeProduct = (props.item.product_name || 'dizzo').replace(/[\s/\\?%*:|"<>]+/g, '_');
    const safeArea = (placement.area_name || placement.area).replace(/[\s/\\?%*:|"<>]+/g, '_');
    const filename = `${safeProduct}_${safeArea}_${widthMm}x${heightMm}mm.svg`;
    const blob = new Blob([svgContent], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }
  catch (err) {
    console.error('SVG generation failed:', err);
    error.value = 'SVG faylni generatsiya qilishda xatolik yuz berdi';
  }
  finally {
    generatingSvg.value = null;
  }
}

async function downloadAreaSvg(row: FileRow) {
  if (generatingSvg.value) return;
  generatingSvg.value = row.key;
  try {
    const placement = props.item.placements.find(
      p => p.area === row.file?.area || p.area_name === row.area_name,
    );
    const dpi = row.file?.dpi || 300;
    const widthMm = Number(placement?.width_mm) || (row.file ? Number(((row.file.width_px / dpi) * 25.4).toFixed(1)) : 300);
    const heightMm = Number(placement?.height_mm) || (row.file ? Number(((row.file.height_px / dpi) * 25.4).toFixed(1)) : 300);
    const areaKey = placement?.area ?? row.area_name;
    const svgContent = await generateAreaSvg(areaKey, widthMm, heightMm);
    const safeProduct = (props.item.product_name || 'dizzo').replace(/[\s/\\?%*:|"<>]+/g, '_');
    const safeVariant = (props.item.variant_name || '').replace(/[\s/\\?%*:|"<>]+/g, '_');
    const safeArea = (row.area_name || 'print').replace(/[\s/\\?%*:|"<>]+/g, '_');
    const filename = `${safeProduct}_${safeVariant}_${safeArea}_${widthMm}x${heightMm}mm.svg`;
    const blob = new Blob([svgContent], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }
  catch (err) {
    console.error('Failed to generate print SVG:', err);
    error.value = 'SVG faylni generatsiya qilishda xatolik yuz berdi';
  }
  finally {
    generatingSvg.value = null;
  }
}

async function setStatus(status: OrderItem['production_status']) {
  error.value = null;
  try {
    await mutation.mutateAsync({ orderId: props.orderId, itemId: props.item.id, status });
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.orders.item.statusFailed'));
  }
}
</script>

<template>
  <UiCard class="gap-0 py-0">
    <UiCardHeader class="flex flex-wrap items-center justify-between gap-3 border-b py-4">
      <div class="min-w-0">
        <UiCardTitle class="truncate font-semibold">
          {{ item.product_name }}
        </UiCardTitle>
        <UiCardDescription class="truncate">
          {{ item.variant_name }}
        </UiCardDescription>
      </div>
      <UiSelect
        :model-value="item.production_status"
        :disabled="mutation.isPending.value"
        @update:model-value="setStatus($event as OrderItem['production_status'])"
      >
        <UiSelectTrigger
          size="sm"
          class="w-40 bg-card font-semibold"
          :aria-label="t('admin.orders.item.productionStatus')"
        >
          <UiSelectValue />
        </UiSelectTrigger>
        <UiSelectContent position="popper">
          <UiSelectItem
            v-for="(label, key) in PRODUCTION_LABELS"
            :key="key"
            :value="key"
          >
            {{ label }}
          </UiSelectItem>
        </UiSelectContent>
      </UiSelect>
    </UiCardHeader>

    <UiCardContent class="space-y-5 py-5">
      <UiAlert
        v-if="error"
        variant="destructive"
      >
        <Icon name="lucide:circle-alert" />
        {{ error }}
      </UiAlert>

      <!-- The frames beside what was ordered and its price. -->
      <div class="grid gap-5 md:grid-cols-[16rem_minmax(0,1fr)]">
        <div class="mx-auto w-full max-w-xs space-y-2 md:max-w-none">
          <a
            v-if="item.mockups.length"
            :href="item.mockups[active]"
            target="_blank"
            rel="noopener"
            class="block rounded-xl outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
            :aria-label="t('admin.orders.item.openFrame')"
          >
            <MediaThumb
              :src="item.mockups[active]"
              :alt="t('admin.orders.item.frame', { n: active + 1 })"
              class="aspect-square w-full border border-border transition hover:opacity-90"
            />
          </a>
          <MediaThumb
            v-else
            class="aspect-square w-full border border-border"
          />
          <div
            v-if="item.mockups.length > 1"
            class="grid grid-cols-5 gap-2"
          >
            <button
              v-for="(src, i) in item.mockups"
              :key="src"
              type="button"
              class="rounded-lg outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
              :aria-label="t('admin.orders.item.frame', { n: i + 1 })"
              :aria-pressed="i === active"
              @click="active = i"
            >
              <MediaThumb
                :src="src"
                :alt="t('admin.orders.item.frame', { n: i + 1 })"
                class="aspect-square w-full rounded-lg border transition"
                :class="i === active ? 'border-primary ring-1 ring-primary' : 'border-border hover:opacity-80'"
              />
            </button>
          </div>

          <UiButton
            variant="outline"
            size="sm"
            class="w-full gap-2 border-primary/30 bg-primary/5 text-primary hover:bg-primary/10 hover:border-primary/40 font-semibold shadow-2xs"
            @click="show3D = true"
          >
            <Icon
              name="lucide:box"
              class="size-4 text-primary"
            />
            <span>3D simulatsiya</span>
          </UiButton>
        </div>

        <div class="min-w-0 text-sm">
          <dl class="space-y-2.5">
            <div class="flex h-5 items-center justify-between gap-3">
              <dt class="shrink-0 text-muted-foreground">
                {{ t('admin.orders.item.color') }}
              </dt>
              <dd class="flex min-w-0 items-center gap-1.5 font-medium text-foreground">
                <span
                  class="size-3.5 shrink-0 rounded-full border border-black/10"
                  :style="{ background: item.color_hex }"
                />
                <span class="truncate">{{ item.color_name }}</span>
              </dd>
            </div>
            <div
              v-if="item.size"
              class="flex h-5 items-center justify-between gap-3"
            >
              <dt class="shrink-0 text-muted-foreground">
                {{ t('admin.orders.item.col.size') }}
              </dt>
              <dd class="truncate font-medium text-foreground">
                {{ item.size }}
              </dd>
            </div>
            <div
              v-if="item.shape"
              class="flex h-5 items-center justify-between gap-3"
            >
              <dt class="shrink-0 text-muted-foreground">
                {{ t('admin.orders.item.shape') }}
              </dt>
              <dd class="truncate font-medium text-foreground">
                {{ item.shape.name }}
              </dd>
            </div>
            <div
              v-if="methods.length"
              class="flex h-5 items-center justify-between gap-3"
            >
              <dt class="shrink-0 text-muted-foreground">
                {{ t('admin.orders.item.col.method') }}
              </dt>
              <dd class="flex min-w-0 gap-1">
                <UiBadge
                  v-for="m in methods"
                  :key="m"
                  :variant="m === 'uv' ? 'info' : 'warning'"
                >
                  {{ METHOD_LABELS[m] }}
                </UiBadge>
              </dd>
            </div>
            <div class="flex h-5 items-center justify-between gap-3">
              <dt class="shrink-0 text-muted-foreground">
                {{ t('admin.orders.item.quantity') }}
              </dt>
              <dd class="font-medium text-foreground">
                {{ t('admin.orders.item.pieces', { n: item.quantity }) }}
              </dd>
            </div>
          </dl>

          <UiSeparator class="my-4" />

          <dl class="space-y-2.5">
            <template v-if="item.quote">
              <div class="flex h-5 items-center justify-between gap-3">
                <dt class="shrink-0 text-muted-foreground">
                  {{ t('admin.orders.item.basePrice') }}
                </dt>
                <dd class="font-mono text-foreground">
                  {{ formatMoney(item.quote.base_price) }}
                </dd>
              </div>
              <div
                v-if="Number(item.quote.color_surcharge) > 0"
                class="flex h-5 items-center justify-between gap-3"
              >
                <dt class="shrink-0 text-muted-foreground">
                  {{ t('admin.orders.item.colorSurcharge') }}
                </dt>
                <dd class="font-mono text-foreground">
                  +{{ formatMoney(item.quote.color_surcharge) }}
                </dd>
              </div>
              <div
                v-if="Number(item.quote.size_surcharge) > 0"
                class="flex h-5 items-center justify-between gap-3"
              >
                <dt class="shrink-0 text-muted-foreground">
                  {{ t('admin.orders.item.sizeSurcharge') }}
                </dt>
                <dd class="font-mono text-foreground">
                  +{{ formatMoney(item.quote.size_surcharge) }}
                </dd>
              </div>
              <div
                v-for="line in item.quote.methods"
                :key="line.method"
                class="flex h-5 items-center justify-between gap-3"
              >
                <dt class="min-w-0 truncate text-muted-foreground">
                  {{ METHOD_LABELS[line.method] }} · {{ mm(line.area_cm2) }} cm²
                </dt>
                <dd class="shrink-0 font-mono text-foreground">
                  +{{ formatMoney(line.surcharge) }}
                </dd>
              </div>
            </template>
            <div class="flex h-5 items-center justify-between gap-3">
              <dt class="shrink-0 text-muted-foreground">
                {{ t('admin.orders.item.unitPrice') }}
              </dt>
              <dd class="font-mono text-foreground">
                {{ formatMoney(item.unit_price) }}
              </dd>
            </div>
            <div class="flex h-6 items-center justify-between gap-3">
              <dt class="shrink-0 font-semibold text-foreground">
                {{ t('admin.orders.item.totalPieces', { n: item.quantity }) }}
              </dt>
              <dd class="font-mono text-base font-bold text-foreground">
                {{ formatMoney(item.total_price) }}
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <section>
        <h3 class="mb-2 text-sm font-semibold text-foreground">
          {{ t('admin.orders.item.printFiles') }}
        </h3>
        <UiDataTable
          :columns="FILE_COLUMNS"
          :data="fileRows"
          :row-key="(row: FileRow) => row.key"
          :empty-text="t('admin.orders.item.noPrintFiles')"
          empty-icon="lucide:file-image"
        >
          <template #cell-area_name="{ row }">
            <span class="font-semibold">{{ row.area_name }}</span>
          </template>
          <template #cell-method="{ row }">
            <UiBadge
              v-if="row.file"
              :variant="row.file.method === 'uv' ? 'info' : 'warning'"
            >
              {{ METHOD_LABELS[row.file.method] }}
            </UiBadge>
            <UiBadge
              v-else
              variant="secondary"
            >
              {{ t('admin.orders.item.underbase') }}
            </UiBadge>
          </template>
          <template #cell-size="{ row }">
            <span class="whitespace-nowrap font-mono text-xs text-muted-foreground">{{ row.file ? `${row.file.width_px}×${row.file.height_px} px` : '—' }}</span>
          </template>
          <template #cell-dpi="{ row }">
            <span class="font-mono text-xs text-muted-foreground">{{ row.file ? row.file.dpi : '—' }}</span>
          </template>
          <template #cell-painted="{ row }">
            <span class="whitespace-nowrap font-mono text-xs text-muted-foreground">{{ row.file ? `${Number(row.file.painted_cm2).toFixed(1)} cm²` : '—' }}</span>
          </template>
          <template #cell-download="{ row }">
            <div class="flex items-center justify-end gap-1.5">
              <UiButton
                variant="outline"
                size="sm"
                :disabled="generatingSvg === row.key"
                class="h-8 gap-1 px-2.5 font-semibold text-primary hover:border-primary hover:bg-primary/10"
                title="Chop etish uchun aniq o'lchamli va shaffof SVG yuklab olish"
                @click="downloadAreaSvg(row)"
              >
                <Icon
                  v-if="generatingSvg === row.key"
                  name="lucide:loader-2"
                  class="size-3.5 animate-spin"
                />
                <Icon
                  v-else
                  name="lucide:file-code-2"
                  class="size-3.5"
                />
                <span>SVG</span>
              </UiButton>
              <UiButton
                as-child
                variant="outline"
                size="sm"
                class="h-8 gap-1 px-2.5 font-medium"
              >
                <a
                  :href="row.url"
                  target="_blank"
                  rel="noopener"
                  download
                >
                  <Icon
                    name="lucide:download"
                    class="size-3.5"
                  />
                  <span>PNG</span>
                </a>
              </UiButton>
            </div>
          </template>
        </UiDataTable>
      </section>

      <section v-if="item.placements.length">
        <h3 class="mb-2 text-sm font-semibold text-foreground">
          {{ t('admin.orders.item.placement') }}
        </h3>
        <UiDataTable
          :columns="PLACEMENT_COLUMNS"
          :data="item.placements"
          :row-key="(row: OrderPlacement) => row.area"
        >
          <template #cell-area_name="{ row }">
            <span class="font-semibold">{{ row.area_name }}</span>
          </template>
          <template #cell-size="{ row }">
            <span class="whitespace-nowrap font-mono text-xs text-muted-foreground">{{ mm(row.width_mm) }}×{{ mm(row.height_mm) }} mm</span>
          </template>
          <template #cell-where="{ row }">
            <span class="text-muted-foreground">{{ whereText(row.anchor) ?? '—' }}</span>
          </template>
          <template #cell-note="{ row }">
            <span class="text-muted-foreground">{{ row.placement_note || '—' }}</span>
          </template>
          <template #cell-svg="{ row }">
            <UiButton
              variant="outline"
              size="sm"
              :disabled="generatingSvg === row.area"
              class="h-8 gap-1 px-2.5 font-semibold text-primary hover:border-primary hover:bg-primary/10"
              :title="`SVG yuklab olish — ${mm(row.width_mm)}×${mm(row.height_mm)} mm`"
              @click="downloadPlacementSvg(row)"
            >
              <Icon
                v-if="generatingSvg === row.area"
                name="lucide:loader-2"
                class="size-3.5 animate-spin"
              />
              <Icon
                v-else
                name="lucide:file-code-2"
                class="size-3.5"
              />
              <span>SVG</span>
            </UiButton>
          </template>
        </UiDataTable>
      </section>
    </UiCardContent>
    <CommerceOrderItem3DModal
      v-model="show3D"
      :item="item"
    />
  </UiCard>
</template>
