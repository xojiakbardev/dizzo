<script setup lang="ts">
// "Rasmlar": every picture of the product in one place — the cover and the
// product's own gallery on top, then each type with its plain base shot and
// each of its colours with a card picture and a gallery — beside a preview
// of what the customer sees for a chosen type and colour. Files can be
// dropped on any list, or all at once on the tray and then placed by
// dragging or by their names.
import PictureCell from '~/components/admin/products/images/PictureCell.vue';
import PicturesPreview from '~/components/admin/products/images/PicturesPreview.vue';
import { MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import { PICTURE_DRAG, PICTURES_KEY, useProductPictures, type DraggedPicture } from '~/composables/useProductPictures';
import { cellKey, liveColors, liveVariants, matchFileName } from '~/lib/catalogPictures';
import type { AdminCatalogProduct, Variant, VariantColor } from '~/types/catalog';

const props = defineProps<{ product: AdminCatalogProduct }>();
const { t } = useI18n();
const product = computed(() => props.product);

const variants = computed(() => liveVariants(props.product));
const shapeOf = (v: Variant) => props.product.shapes.find(s => s.id === v.shape_id) ?? null;

/** The type (and colour) a list belongs to. A type's base shot counts as the
 * type's own, a colour's card as that colour's. */
function ownerOf(key: string): { variant: Variant; color: VariantColor | null } | null {
  for (const v of variants.value) {
    if (key === cellKey('variant', v.id) || key === cellKey('variantMain', v.id)) return { variant: v, color: null };
    const c = liveColors(v).find(x => key === cellKey('color', x.id) || key === cellKey('colorCard', x.id));
    if (c) return { variant: v, color: c };
  }
  return null;
}

function labelOf(key: string): string {
  if (key === 'cover') return t('admin.images.cover');
  if (key === 'product') return t('admin.images.productPictures');
  const owner = ownerOf(key);
  if (!owner) return key;
  if (!owner.color) return `${owner.variant.name} · ${t('admin.images.shared')}`;
  return `${owner.variant.name} · ${owner.color.name}`;
}

const canGenerate = (v: Variant) => {
  const s = shapeOf(v);
  return Boolean(s && (s.kind !== 'model' || s.model_url));
};

// ── The preview's choice; clicking a row's name shows that row there ──
const previewVariant = ref<number | null>(variants.value[0]?.id ?? null);
const previewColor = ref<number | null>(variants.value[0] ? liveColors(variants.value[0])[0]?.id ?? null : null);
watch(variants, (list) => {
  if (!list.some(v => v.id === previewVariant.value)) {
    previewVariant.value = list[0]?.id ?? null;
    previewColor.value = list[0] ? liveColors(list[0])[0]?.id ?? null : null;
  }
});
function show(v: Variant, c: VariantColor | null) {
  previewVariant.value = v.id;
  previewColor.value = c?.id ?? null;
}
const shownVariant = computed(() => variants.value.find(v => v.id === previewVariant.value) ?? null);
const shownColor = computed(() => (shownVariant.value ? liveColors(shownVariant.value).find(c => c.id === previewColor.value) ?? null : null));
/** "Muqova yarat" needs a type with a usable 3D shape to draw. */
const coverReady = computed(() => Boolean(shownVariant.value && canGenerate(shownVariant.value)));

/** The cover belongs to no type, so it has its own path: the type and colour
 * the preview is showing are drawn, and the hero frame is composed on the
 * brand's background. */
async function drawCover(onProgress: (done: number, total: number) => void): Promise<string[]> {
  const v = shownVariant.value;
  const shape = v && shapeOf(v);
  if (!v || !shape) return [];
  const [{ renderPictures }, { composeCover }] = await Promise.all([
    import('~/lib/catalogRender'),
    import('~/lib/coverRender'),
  ]);
  // One step more than the drawing: composing the picture.
  const frames = await renderPictures(shape, v.material, shownColor.value?.hex ?? null, (done, total) => onProgress(done, total + 1));
  const hero = frames[0];
  if (!hero) return [];
  const cover = await composeCover(hero);
  onProgress(1, 1);
  return [cover];
}

const store = useProductPictures(product, {
  render(key, onProgress) {
    if (key === 'cover') return coverReady.value ? drawCover(onProgress) : null;
    const owner = ownerOf(key);
    const shape = owner && shapeOf(owner.variant);
    if (!owner || !shape) return null;
    // A type's base shot is drawn without a colour: a GLB keeps its own
    // baked colours, a parametric body comes out white.
    return import('~/lib/catalogRender').then(m =>
      m.renderPictures(shape, owner.variant.material, owner.color?.hex ?? null, onProgress));
  },
});
provide(PICTURES_KEY, store);

// ── What's missing ──
const emptyCount = (v: Variant) => liveColors(v).filter(c => !store.images(`c:${c.id}`).length).length;
const totalEmpty = computed(() => variants.value.reduce((n, v) => n + emptyCount(v), 0) + (store.images('cover').length ? 0 : 1));
const onlyEmpty = ref(false);

const collapsed = reactive(new Set<number>());
function toggle(id: number) {
  if (collapsed.has(id)) collapsed.delete(id);
  else collapsed.add(id);
}

// ── The tray: many files at once ──
const trayOver = ref(false);
function onTrayDrop(event: DragEvent) {
  trayOver.value = false;
  if (event.defaultPrevented) return;
  event.preventDefault();
  const files = Array.from(event.dataTransfer?.files ?? []).filter(f => MEDIA_IMAGE_TYPES.includes(f.type));
  if (files.length) store.uploadToTray(files);
}
function onTrayDragStart(event: DragEvent, id: string) {
  const media = store.tray.value.find(item => item.id === id)?.media;
  if (!media || !event.dataTransfer) return;
  const payload: DraggedPicture = { mediaId: media.media_id, url: media.url, from: 'tray' };
  event.dataTransfer.setData(PICTURE_DRAG, JSON.stringify(payload));
  event.dataTransfer.effectAllowed = 'move';
}
const trayReady = computed(() => store.tray.value.filter(item => item.status === 'ready'));
const trayBusy = computed(() => store.tray.value.some(item => item.status === 'uploading'));

// ── Placing by name ──
const matching = ref(false);
const matches = ref<Array<{ trayId: string; name: string; preview: string; cellKey: string | null; order: number; on: boolean }>>([]);
function openMatching() {
  matches.value = trayReady.value.map((item) => {
    const m = matchFileName(item.name, props.product);
    return { trayId: item.id, name: item.name, preview: item.preview, cellKey: m?.cellKey ?? null, order: m?.order ?? 0, on: Boolean(m) };
  }).sort((a, b) => (a.cellKey ?? '~').localeCompare(b.cellKey ?? '~') || a.order - b.order || a.name.localeCompare(b.name));
  matching.value = true;
}
const matchedCount = computed(() => matches.value.filter(m => m.cellKey && m.on).length);
function applyMatching() {
  store.assign(matches.value.filter(m => m.cellKey && m.on).map(m => ({ trayId: m.trayId, cellKey: m.cellKey! })));
  matching.value = false;
}

// ── "Rasm yaratish" ──
const job = store.job;
const jobOpen = computed({
  get: () => job.value !== null,
  set: (open: boolean) => {
    if (!open && job.value?.status !== 'saving') store.closeJob();
  },
});
const jobOwner = computed(() => (job.value ? ownerOf(job.value.cellKey) : null));
const chosenCount = computed(() => job.value?.chosen.filter(Boolean).length ?? 0);

// ── "Har bir rang uchun": every colour of one type, drawn in turn ──
const batch = store.batch;
const batchOpen = computed({
  get: () => batch.value !== null,
  set: (open: boolean) => {
    if (!open) store.closeBatch();
  },
});
const batchDone = computed(() => batch.value?.steps.filter(s => s.status === 'done' || s.status === 'error').length ?? 0);
const BATCH_ICON: Record<string, string> = {
  waiting: 'lucide:clock',
  rendering: 'lucide:loader-2',
  saving: 'lucide:loader-2',
  done: 'lucide:circle-check',
  error: 'lucide:circle-alert',
};
</script>

<template>
  <div class="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
    <div class="min-w-0 space-y-4">
      <!-- The tray -->
      <UiCard class="gap-0 py-0">
        <UiCardContent class="space-y-3 py-4">
          <div class="flex flex-wrap items-center gap-2">
            <h3 class="flex items-center gap-2 font-semibold">
              <Icon
                name="lucide:images"
                class="text-base text-muted-foreground"
              />
              {{ t('admin.images.bulkTitle') }}
            </h3>
            <UiStatusBadge
              :tone="totalEmpty ? 'warn' : 'success'"
              class="ml-auto"
            >
              {{ totalEmpty ? t('admin.images.missingCount', { n: totalEmpty }, totalEmpty) : t('admin.images.allHavePictures') }}
            </UiStatusBadge>
            <UiLabel class="flex cursor-pointer items-center gap-2 text-xs font-normal text-muted-foreground">
              <UiSwitch v-model="onlyEmpty" />
              {{ t('admin.images.onlyEmpty') }}
            </UiLabel>
          </div>
          <UiFileInput
            multiple
            :accept="MEDIA_IMAGE_TYPES.join(',')"
            class="min-h-16 flex-wrap"
            :class="trayOver ? 'border-primary bg-primary/5' : ''"
            @select="store.uploadToTray"
          >
            <Icon
              name="lucide:upload"
              class="text-lg"
            />
            {{ t('admin.images.dropHere') }}
          </UiFileInput>
          <div
            v-if="store.tray.value.length"
            class="space-y-2"
            @dragover.prevent="trayOver = true"
            @dragleave="trayOver = false"
            @drop="onTrayDrop"
          >
            <div class="flex flex-wrap gap-2">
              <div
                v-for="item in store.tray.value"
                :key="item.id"
                class="group relative w-20 shrink-0"
                :draggable="item.status === 'ready'"
                :class="item.status === 'ready' ? 'cursor-grab active:cursor-grabbing' : ''"
                :title="item.error ?? item.name"
                data-tray-item
                @dragstart="onTrayDragStart($event, item.id)"
              >
                <img
                  :src="item.preview"
                  alt=""
                  class="size-20 rounded-xl border object-contain"
                  :class="[item.status === 'uploading' ? 'opacity-50' : '', item.status === 'error' ? 'border-destructive' : 'border-border']"
                >
                <Icon
                  v-if="item.status === 'uploading'"
                  name="lucide:loader-2"
                  class="absolute left-1/2 top-8 -translate-x-1/2 animate-spin text-xl text-primary"
                />
                <Icon
                  v-if="item.status === 'error'"
                  name="lucide:circle-alert"
                  class="absolute left-1/2 top-8 -translate-x-1/2 text-xl text-destructive"
                />
                <p class="mt-0.5 truncate text-[10px] text-muted-foreground">
                  {{ item.name }}
                </p>
                <UiButton
                  type="button"
                  variant="ghost"
                  size="icon-xs"
                  class="absolute right-1 top-1 rounded-full bg-white/90 text-slate-500 opacity-0 shadow-xs group-hover:opacity-100 pointer-coarse:opacity-100"
                  :aria-label="t('admin.images.removeFromTray')"
                  @click="store.removeFromTray(item.id)"
                >
                  <Icon
                    name="lucide:x"
                    class="text-sm"
                  />
                </UiButton>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <p class="text-xs text-muted-foreground">
                {{ t('admin.images.dragHint') }}
              </p>
              <UiButton
                size="sm"
                class="ml-auto"
                :disabled="!trayReady.length || trayBusy"
                @click="openMatching"
              >
                <Icon
                  name="lucide:wand"
                  class="text-sm"
                />
                {{ t('admin.images.placeByName') }}
              </UiButton>
            </div>
          </div>
        </UiCardContent>
      </UiCard>

      <!-- The product's own pictures: the cover that sells it in listings,
           and the pictures true of every type and colour (they close the
           customer's gallery). -->
      <UiCard
        v-if="!onlyEmpty || !store.images('cover').length"
        class="gap-0 py-0"
      >
        <UiCardHeader class="border-b py-3">
          <UiCardTitle class="font-semibold">
            {{ t('admin.images.product') }}
          </UiCardTitle>
        </UiCardHeader>
        <UiCardContent class="space-y-4 py-4">
          <div class="space-y-1">
            <p class="text-xs font-medium text-muted-foreground">
              {{ t('admin.images.cover') }}
              <span class="font-normal">— {{ t('admin.images.coverHint') }}</span>
            </p>
            <PictureCell
              cell-key="cover"
              size="md"
              :can-generate="coverReady"
              :generate-label="t('admin.images.makeCover')"
            />
          </div>
          <div class="space-y-1">
            <p class="text-xs font-medium text-muted-foreground">
              {{ t('admin.images.productPictures') }}
              <span class="font-normal">— {{ t('admin.images.productPicturesHint') }}</span>
            </p>
            <PictureCell
              cell-key="product"
              :starrable="false"
            />
          </div>
        </UiCardContent>
      </UiCard>

      <!-- The matrix: each type and its colours; pictures live on the colours -->
      <EmptyState
        v-if="!variants.length"
        icon="lucide:layers"
        :title="t('admin.images.noVariants')"
        :description="t('admin.images.noVariantsHint')"
      />
      <template
        v-for="v in variants"
        :key="v.id"
      >
        <UiCard
          v-if="!onlyEmpty || emptyCount(v)"
          class="gap-0 py-0"
          :data-variant="v.id"
        >
          <UiCardHeader class="border-b py-3">
            <div class="flex flex-wrap items-center gap-2">
              <button
                type="button"
                class="flex min-w-0 items-center gap-2 text-left"
                :aria-expanded="!collapsed.has(v.id)"
                @click="toggle(v.id)"
              >
                <Icon
                  name="lucide:chevron-down"
                  class="shrink-0 text-muted-foreground transition-transform"
                  :class="collapsed.has(v.id) ? '-rotate-90' : ''"
                />
                <UiCardTitle class="truncate font-semibold">
                  {{ v.name }}
                </UiCardTitle>
              </button>
              <span class="text-xs text-muted-foreground">{{ shapeOf(v)?.name }}</span>
              <UiStatusBadge
                v-if="!v.is_available"
                tone="neutral"
              >
                {{ t('admin.images.notOnSale') }}
              </UiStatusBadge>
              <UiStatusBadge
                :tone="emptyCount(v) ? 'warn' : 'success'"
                class="ml-auto"
              >
                {{ emptyCount(v) ? t('admin.images.emptyCount', { n: emptyCount(v) }, emptyCount(v)) : t('admin.images.complete') }}
              </UiStatusBadge>
              <UiButton
                v-if="canGenerate(v) && liveColors(v).length"
                type="button"
                variant="outline"
                size="sm"
                :disabled="batch?.running"
                @click="store.generateBatch(liveColors(v).map(c => `c:${c.id}`))"
              >
                <Icon
                  name="lucide:wand-sparkles"
                  class="text-sm"
                />
                {{ t('admin.images.generateAll') }}
              </UiButton>
            </div>
          </UiCardHeader>
          <UiCardContent
            v-if="!collapsed.has(v.id)"
            class="divide-y divide-border py-0"
          >
            <template
              v-for="c in liveColors(v)"
              :key="c.id"
            >
              <div
                v-if="!onlyEmpty || !store.images(`c:${c.id}`).length"
                class="grid gap-2 py-3 sm:grid-cols-[11rem_minmax(0,1fr)] sm:items-start"
              >
                <button
                  type="button"
                  class="flex min-w-0 items-center gap-2 rounded-lg p-1 text-left text-sm hover:bg-muted sm:mt-5"
                  :class="previewVariant === v.id && previewColor === c.id ? 'bg-primary/10 text-primary' : ''"
                  @click="show(v, c)"
                >
                  <span
                    class="size-5 shrink-0 rounded-full border border-border"
                    :style="{ backgroundColor: c.hex }"
                  />
                  <span class="min-w-0">
                    <span class="block truncate font-medium">{{ c.name }}</span>
                    <span
                      v-if="!store.images(`c:${c.id}`).length"
                      class="block text-[11px] font-medium text-destructive"
                    >{{ t('admin.images.noPicture') }}</span>
                    <span
                      v-else-if="!c.is_available"
                      class="block text-[11px] text-muted-foreground"
                    >{{ t('admin.images.notOnSale') }}</span>
                  </span>
                </button>
                <div class="min-w-0 space-y-1">
                  <p class="px-0.5 text-[11px] font-medium text-muted-foreground">
                    {{ t('admin.images.colorGallery') }}
                  </p>
                  <PictureCell
                    :cell-key="`c:${c.id}`"
                    :can-generate="canGenerate(v)"
                    :starrable="true"
                  />
                </div>
              </div>
            </template>
            <p
              v-if="!liveColors(v).length"
              class="py-3 text-sm text-muted-foreground"
            >
              {{ t('admin.images.noColors') }}
            </p>
          </UiCardContent>
        </UiCard>
      </template>
    </div>

    <div class="xl:sticky xl:top-20">
      <PicturesPreview
        v-model:variant="previewVariant"
        v-model:color="previewColor"
        :product="product"
      />
    </div>

    <!-- Placing the tray by file names -->
    <UiDialog v-model:open="matching">
      <UiDialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-xl">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.images.placeByName') }}</UiDialogTitle>
          <UiDialogDescription>
            <code class="text-xs">{{ t('admin.images.fileNamePattern') }}</code>
          </UiDialogDescription>
        </UiDialogHeader>
        <ul class="divide-y divide-border">
          <li
            v-for="m in matches"
            :key="m.trayId"
            class="flex items-center gap-3 py-2"
          >
            <UiCheckbox
              :model-value="m.on"
              :disabled="!m.cellKey"
              :aria-label="m.name"
              @update:model-value="(on: boolean | 'indeterminate') => (m.on = on === true)"
            />
            <img
              :src="m.preview"
              alt=""
              class="size-10 shrink-0 rounded-lg border border-border object-contain"
            >
            <span class="min-w-0 flex-1 truncate text-sm">{{ m.name }}</span>
            <Icon
              name="lucide:arrow-right"
              class="shrink-0 text-muted-foreground"
            />
            <span
              class="w-44 shrink-0 truncate text-sm font-medium"
              :class="m.cellKey ? '' : 'text-amber-700 dark:text-amber-400'"
            >{{ m.cellKey ? labelOf(m.cellKey) : t('admin.images.notFound') }}</span>
          </li>
        </ul>
        <UiDialogFooter>
          <UiButton
            variant="outline"
            @click="matching = false"
          >
            {{ t('admin.common.cancel') }}
          </UiButton>
          <UiButton
            :disabled="!matchedCount"
            @click="applyMatching"
          >
            {{ t('admin.images.placeCount', { n: matchedCount }, matchedCount) }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>

    <!-- Pictures from the 3D shape -->
    <UiDialog v-model:open="jobOpen">
      <UiDialogContent
        v-if="job"
        class="max-h-[90dvh] overflow-y-auto sm:max-w-2xl"
      >
        <UiDialogHeader>
          <UiDialogTitle class="flex items-center gap-2">
            <span
              v-if="jobOwner?.color"
              class="size-4 rounded-full border border-border"
              :style="{ backgroundColor: jobOwner.color.hex }"
            />
            {{ t('admin.images.generateTitle', { name: labelOf(job.cellKey) }) }}
          </UiDialogTitle>
        </UiDialogHeader>
        <div
          v-if="job.status === 'rendering' || job.status === 'saving'"
          class="space-y-2 py-6"
        >
          <p class="flex items-center gap-2 text-sm font-medium">
            <Icon
              name="lucide:loader-2"
              class="animate-spin text-primary"
            />
            {{ job.status === 'rendering' ? t('admin.images.rendering') : t('admin.images.uploading') }}
            <span
              v-if="job.total"
              class="ml-auto tabular-nums text-muted-foreground"
            >{{ job.done }} / {{ job.total }}</span>
          </p>
          <div class="h-2 overflow-hidden rounded-full bg-muted">
            <div
              class="h-full rounded-full bg-primary transition-all"
              :style="{ width: `${job.total ? (job.done / job.total) * 100 : 8}%` }"
            />
          </div>
        </div>
        <UiAlert
          v-else-if="job.status === 'error'"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          {{ job.error }}
        </UiAlert>
        <div
          v-if="job.frames.length && job.status !== 'saving'"
          class="grid grid-cols-3 gap-2 sm:grid-cols-5"
        >
          <button
            v-for="(frame, i) in job.frames"
            :key="i"
            type="button"
            class="relative aspect-square overflow-hidden rounded-xl border-2 bg-[repeating-conic-gradient(var(--color-muted)_0_25%,transparent_0_50%)] bg-size-[16px_16px] transition"
            :class="job.chosen[i] ? 'border-primary' : 'border-border opacity-50'"
            :aria-pressed="job.chosen[i]"
            data-generated
            @click="job.chosen[i] = !job.chosen[i]"
          >
            <img
              :src="frame"
              alt=""
              class="size-full object-contain"
            >
            <Icon
              v-if="job.chosen[i]"
              name="lucide:circle-check"
              class="absolute right-1 top-1 text-lg text-primary"
            />
          </button>
        </div>
        <UiDialogFooter>
          <UiButton
            variant="outline"
            :disabled="job.status === 'saving'"
            @click="store.closeJob()"
          >
            {{ t('admin.common.cancel') }}
          </UiButton>
          <UiButton
            v-if="job.status === 'error'"
            variant="outline"
            @click="store.generate(job.cellKey)"
          >
            <Icon
              name="lucide:refresh-cw"
              class="text-sm"
            />
            {{ t('admin.common.retry') }}
          </UiButton>
          <UiButton
            :disabled="job.status !== 'ready' || !chosenCount"
            @click="store.attachGenerated()"
          >
            <Icon
              name="lucide:image-plus"
              class="text-sm"
            />
            {{ t('admin.images.addCount', { n: chosenCount }, chosenCount) }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>

    <!-- Every colour of one type, one after another -->
    <UiDialog v-model:open="batchOpen">
      <UiDialogContent
        v-if="batch"
        class="max-h-[90dvh] overflow-y-auto sm:max-w-lg"
      >
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.images.generateAll') }}</UiDialogTitle>
          <UiDialogDescription>
            {{ t('admin.images.generateAllHint') }}
          </UiDialogDescription>
        </UiDialogHeader>
        <div class="space-y-2">
          <div class="h-2 overflow-hidden rounded-full bg-muted">
            <div
              class="h-full rounded-full bg-primary transition-all"
              :style="{ width: `${(batchDone / batch.steps.length) * 100}%` }"
            />
          </div>
          <ul class="divide-y divide-border text-sm">
            <li
              v-for="(step, i) in batch.steps"
              :key="step.cellKey"
              class="flex items-center gap-2 py-1.5"
            >
              <Icon
                :name="BATCH_ICON[step.status]!"
                class="shrink-0"
                :class="[
                  step.status === 'rendering' || step.status === 'saving' ? 'animate-spin text-primary' : '',
                  step.status === 'done' ? 'text-emerald-600' : '',
                  step.status === 'error' ? 'text-destructive' : 'text-muted-foreground',
                ]"
              />
              <span class="min-w-0 flex-1 truncate">{{ labelOf(step.cellKey) }}</span>
              <span
                v-if="step.status === 'error'"
                class="min-w-0 truncate text-xs text-destructive"
              >{{ step.error }}</span>
              <span
                v-else-if="i === batch.index && batch.total"
                class="shrink-0 text-xs tabular-nums text-muted-foreground"
              >{{ batch.done }} / {{ batch.total }}</span>
            </li>
          </ul>
        </div>
        <UiDialogFooter>
          <UiButton
            v-if="batch.running"
            variant="outline"
            :disabled="batch.stopped"
            @click="store.stopBatch()"
          >
            {{ batch.stopped ? t('admin.images.stopping') : t('admin.images.stop') }}
          </UiButton>
          <UiButton
            v-else
            @click="store.closeBatch()"
          >
            {{ t('admin.common.close') }}
          </UiButton>
        </UiDialogFooter>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
