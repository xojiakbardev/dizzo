<script setup lang="ts">
// A variant's form, on its own page. A new variant
// needs a name, a shape and a price (created, it opens for the rest:
// colours need it to exist); an existing one edits everything. Delete and
// save sit in the header. Pictures belong to the colours.
// Name, description, specs, size labels and colour names are entered in
// Uzbek, Russian and English (the name in all three is required).
import { getApiErrorMessage } from '~/composables/useApi';
import type { AdminCatalogProduct, CatalogMethod, Material, Shape, ShapeKind, Variant } from '~/types/catalog';
import { DEFAULT_SIZES, MATERIAL_LABELS, MATERIALS, METHOD_LABELS } from '~/types/catalog';
import type { ContentLang, SizeRow, SpecRow } from '~/lib/admin/translations';
import {
  TRANSLATION_LANGS, isSizeCode, isTranslated, newSizeRow, newSpecRow, sizeRows, specRows, splitSizeRows, splitSpecRows,
  textTranslations, trimTranslations,
} from '~/lib/admin/translations';
import ColorRow from '~/components/admin/products/ColorRow.vue';
import ShapePicture from '~/components/admin/products/ShapePicture.vue';

const props = defineProps<{ product: AdminCatalogProduct; variant: Variant | null }>();
const emit = defineEmits<{ created: [id: number]; saved: []; removed: [] }>();
const { run, busy } = useCatalogAdminActions();
const { t } = useI18n();
const localePath = useLocalePath();

/** Shapes a variant can use: ready, on sale, not being revised. */
const shapes = computed(() => props.product.shapes.filter(s => !s.archived && s.replaces_id === null && s.status === 'ready'));
const DEFAULT_MATERIAL: Record<ShapeKind, Material> = { model: 'fabric', cylinder: 'ceramic_glossy', plane: 'paper', disc: 'plastic' };
const methodsOf = (shape: Shape | undefined) => [...new Set(shape?.areas.flatMap(a => a.methods.map(m => m.method)) ?? [])] as CatalogMethod[];
const areaCount = (shape: Shape) => t('admin.variants.areaCount', { n: shape.areas.length }, shape.areas.length);

const v = props.variant;
const form = reactive({
  name: v?.name ?? '',
  base_price: v?.base_price ?? '',
  shape_id: v?.shape_id ?? shapes.value[0]?.id ?? 0,
  material: (v?.material ?? 'fabric') as Material,
  methods: [...(v?.methods ?? [])] as CatalogMethod[],
  white_underbase: v?.white_underbase ?? false,
  short_description: v?.short_description ?? '',
  description: v?.description ?? '',
});
// Name and description in Russian and English (Uzbek is in `form`).
// A PATCH replaces a language's whole block, so short_description (not
// edited here) is sent back as it was.
const tr = ref(textTranslations(v?.translations, ['name', 'short_description', 'description']));

// Specs: one row per item, its label and value in all three languages.
// One language switch drives every row.
const specs = ref<SpecRow[]>(specRows(v?.specs ?? [], v?.translations));
const specLang = ref<ContentLang>('uz');
const specMissing = (row: SpecRow) => (row.label.trim() || row.value.trim()
  ? TRANSLATION_LANGS.filter(l => !row.tr[l].label?.trim() || !row.tr[l].value?.trim())
  : []);

// Sizes are one ordered list, saved whole with the rest of the form. An
// empty list means the product has no sizes (a mug) and none is asked for.
const sizes = ref<SizeRow[]>(sizeRows(v?.sizes ?? [], v?.translations));
const sizeLang = ref<ContentLang>('uz');
const sizesDirty = computed(() => JSON.stringify(splitSizeRows(sizes.value).sizes) !== JSON.stringify(props.variant?.sizes ?? []));
function moveSize(index: number, by: number) {
  const [moved] = sizes.value.splice(index, 1);
  sizes.value.splice(index + by, 0, moved!);
}

const shape = computed(() => shapes.value.find(s => s.id === form.shape_id));
const shapeMethods = computed(() => new Set(methodsOf(shape.value)));
function toggleMethod(method: CatalogMethod) {
  form.methods = form.methods.includes(method) ? form.methods.filter(m => m !== method) : [...form.methods, method];
}
function pickShape(id: unknown) {
  const n = Number(id);
  if (shapes.value.some(s => s.id === n)) form.shape_id = n;
}
function pickMaterial(value: unknown) {
  const material = MATERIALS.find(m => m === value);
  if (material) form.material = material;
}
const colors = computed(() => props.variant?.colors.filter(c => !c.archived) ?? []);

const canSave = computed(() => !busy.value && Boolean(form.name.trim()) && isTranslated(tr.value, 'name')
  && (props.variant ? true : Boolean(shape.value) && Number(form.base_price) > 0));

const error = ref<string | null>(null);
async function act(fn: () => Promise<unknown>, fallback: string) {
  error.value = null;
  try {
    await fn();
    return true;
  }
  catch (err) {
    error.value = getApiErrorMessage(err, fallback);
    return false;
  }
}
const base = computed(() => `/admin/catalog/variants/${props.variant?.id}/`);
const back = computed(() => localePath(`/admin/products/${props.product.id}?tab=variants`));

async function save() {
  if (!canSave.value) return;
  const names = trimTranslations(tr.value);
  if (!props.variant) {
    const s = shape.value!;
    let createdId = 0;
    const ok = await act(async () => {
      const product = await run('post', `/admin/catalog/products/${props.product.id}/variants/`, {
        name: form.name.trim(),
        shape_id: s.id,
        base_price: form.base_price,
        methods: methodsOf(s),
        material: DEFAULT_MATERIAL[s.kind],
        translations: { ru: { name: names.ru.name }, en: { name: names.en.name } },
      });
      createdId = product.variants.at(-1)!.id;
    }, t('admin.variants.createFailed'));
    if (ok) emit('created', createdId);
    return;
  }
  const spec = splitSpecRows(specs.value);
  // A language with no spec translated at all sends no list (the site shows
  // the Uzbek one); an empty cell in a translated list keeps the Uzbek text.
  const specsIn = (rows: typeof spec.ru) => (rows.some(r => r.label || r.value)
    ? rows.map((r, i) => ({ label: r.label || spec.specs[i]!.label, value: r.value || spec.specs[i]!.value }))
    : []);
  const size = splitSizeRows(sizes.value);
  const ok = await act(async () => {
    // Size names are matched to the Uzbek labels, saved here first.
    if (sizesDirty.value) {
      await run('put', `${base.value}sizes/`, { sizes: size.sizes });
    }
    await run('patch', base.value, {
      ...form,
      name: form.name.trim(),
      specs: spec.specs,
      translations: {
        ru: { name: names.ru.name, short_description: names.ru.short_description, description: names.ru.description, specs: specsIn(spec.ru), sizes: size.ru },
        en: { name: names.en.name, short_description: names.en.short_description, description: names.en.description, specs: specsIn(spec.en), sizes: size.en },
      },
    });
  }, t('admin.common.saveFailed'));
  if (ok) emit('saved');
}

const removing = ref(false);
async function remove() {
  const ok = await act(() => run('patch', base.value, { archived: true }), t('admin.common.deleteFailed'));
  removing.value = false;
  if (ok) emit('removed');
}

const newSpec = ref<SpecRow>(newSpecRow());
function addSpec() {
  const row = newSpec.value;
  if (!row.label.trim() || !row.value.trim() || specs.value.length >= 20) return;
  specs.value.push(row);
  newSpec.value = newSpecRow();
}
const newSize = ref<SizeRow>(newSizeRow(''));
function addSize() {
  if (!newSize.value.label.trim() || sizes.value.length >= 30) return;
  sizes.value.push({ ...newSize.value, label: newSize.value.label.trim(), surcharge: newSize.value.surcharge || '0' });
  newSize.value = newSizeRow('');
}

const newColor = reactive({ name: '', hex: '#111111', surcharge: '0', tr: textTranslations(null, ['name']) });
const canAddColor = computed(() => !busy.value && Boolean(newColor.name.trim()) && isTranslated(newColor.tr, 'name'));
async function addColor() {
  if (!canAddColor.value) return;
  const body = { name: newColor.name.trim(), hex: newColor.hex, surcharge: newColor.surcharge, translations: trimTranslations(newColor.tr) };
  if (await act(() => run('post', `${base.value}colors/`, body), t('admin.variants.colorAddFailed'))) {
    Object.assign(newColor, { name: '', hex: '#111111', surcharge: '0', tr: textTranslations(null, ['name']) });
  }
}

defineExpose({ save, canSave, busy });
</script>

<template>
  <div class="space-y-5">
    <AdminDetailHeader
      :back="back"
      :back-label="t('admin.variants.backToList')"
      :title="form.name.trim() || variant?.name || t('admin.variants.new')"
    >
      <template #actions>
        <UiButton
          v-if="variant"
          type="button"
          variant="ghost"
          class="text-destructive hover:bg-destructive/10 hover:text-destructive"
          :disabled="busy"
          @click="removing = true"
        >
          <Icon
            name="lucide:trash-2"
            class="h-4 w-4"
          />
          {{ t('admin.common.delete') }}
        </UiButton>
        <UiButton
          as-child
          variant="outline"
        >
          <NuxtLink :to="back">
            {{ t('admin.common.cancel') }}
          </NuxtLink>
        </UiButton>
        <UiButton
          type="button"
          :disabled="!canSave"
          @click="save"
        >
          <Icon
            :name="busy ? 'lucide:loader-2' : variant ? 'lucide:check' : 'lucide:plus'"
            :class="busy ? 'h-4 w-4 animate-spin' : 'h-4 w-4'"
          />
          {{ variant ? t('admin.common.save') : t('admin.common.add') }}
        </UiButton>
      </template>
    </AdminDetailHeader>

    <UiAlert
      v-if="error"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ error }}
    </UiAlert>

    <form
      class="space-y-5"
      @submit.prevent="save"
    >
      <UiCard class="gap-0 py-0">
        <UiCardContent class="space-y-4 py-5">
          <div class="grid items-start gap-4 sm:grid-cols-2">
            <TranslatableInput
              :id="variant ? 'variant-name' : 'new-variant-name'"
              v-model="form.name"
              v-model:translations="tr"
              field="name"
              :label="t('admin.common.name')"
              :placeholder="t('admin.variants.namePlaceholder')"
              required
            />
            <UiField
              :label="t('admin.variants.price')"
              :for="variant ? 'variant-price' : 'new-variant-price'"
              class="[&>[data-slot=label]]:min-h-7"
            >
              <div class="relative">
                <UiInput
                  :id="variant ? 'variant-price' : 'new-variant-price'"
                  v-model="form.base_price"
                  class="pr-12"
                  inputmode="decimal"
                  placeholder="85000"
                />
                <span class="pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">{{ t('admin.common.sum') }}</span>
              </div>
            </UiField>
          </div>
          <UiField
            :label="t('admin.variants.shape')"
          >
            <p
              v-if="!shapes.length"
              class="rounded-xl border border-dashed border-border p-4 text-center text-sm text-muted-foreground"
            >
              {{ t('admin.variants.noReadyShape') }}
            </p>
            <div
              v-else
              class="flex gap-3 overflow-x-auto pb-2 pt-1 scroll-smooth snap-x snap-mandatory focus:outline-none"
              tabindex="0"
            >
              <button
                v-for="s in shapes"
                :key="s.id"
                type="button"
                :class="[
                  'group flex w-[100px] shrink-0 cursor-pointer flex-col items-center gap-1.5 snap-start text-left outline-none',
                ]"
                @click="pickShape(s.id)"
              >
                <div
                  :class="[
                    'relative size-[100px] overflow-hidden rounded-xl border p-2 transition-all flex items-center justify-center',
                    s.id === form.shape_id
                      ? 'border-primary bg-primary/5 ring-2 ring-primary/20 shadow-xs'
                      : 'border-border bg-card hover:border-primary/40 hover:bg-muted/30'
                  ]"
                >
                  <ShapePicture
                    :shape="s"
                    :size="200"
                    class="size-full rounded-lg object-contain"
                  />
                  <div
                    v-if="s.id === form.shape_id"
                    class="absolute right-1.5 top-1.5 flex size-4 items-center justify-center rounded-full bg-primary text-primary-foreground shadow-xs"
                  >
                    <Icon
                      name="lucide:check"
                      class="size-2.5 stroke-[3]"
                    />
                  </div>
                </div>
                <div class="w-full text-center">
                  <span
                    :class="[
                      'block truncate text-xs font-medium transition-colors',
                      s.id === form.shape_id ? 'font-semibold text-primary' : 'text-foreground group-hover:text-primary'
                    ]"
                    :title="s.name"
                  >
                    {{ s.name }}
                  </span>
                  <span
                    v-if="s.description || areaCount(s)"
                    class="block truncate text-[10px] text-muted-foreground"
                    :title="s.description || areaCount(s)"
                  >
                    {{ s.description || areaCount(s) }}
                  </span>
                </div>
              </button>
            </div>
          </UiField>
          <template v-if="variant">
            <UiField
              :label="t('admin.variants.material')"
              for="variant-material"
              :hint="t('admin.variants.materialHint')"
            >
              <UiSelect
                :model-value="form.material"
                @update:model-value="pickMaterial"
              >
                <UiSelectTrigger
                  id="variant-material"
                  class="w-full"
                >
                  <UiSelectValue :placeholder="t('admin.common.choose')" />
                </UiSelectTrigger>
                <UiSelectContent position="popper">
                  <UiSelectItem
                    v-for="m in MATERIALS"
                    :key="m"
                    :value="m"
                  >
                    {{ MATERIAL_LABELS[m] }}
                  </UiSelectItem>
                </UiSelectContent>
              </UiSelect>
            </UiField>
            <UiField
              :label="t('admin.variants.methods')"
              :hint="t('admin.variants.methodsHint')"
            >
              <div class="flex flex-wrap items-center gap-2">
                <UiButton
                  v-for="(text, method) in METHOD_LABELS"
                  :key="method"
                  type="button"
                  variant="outline"
                  :class="form.methods.includes(method) ? 'h-9 border-primary bg-primary/10 font-medium hover:bg-primary/15' : 'h-9 font-medium text-muted-foreground hover:text-foreground'"
                  :aria-pressed="form.methods.includes(method)"
                  :disabled="!shapeMethods.has(method)"
                  @click="toggleMethod(method)"
                >
                  <Icon
                    :name="form.methods.includes(method) ? 'lucide:check' : 'lucide:plus'"
                    class="h-3.5 w-3.5"
                  />
                  {{ text }}
                </UiButton>
              </div>
            </UiField>
            <UiLabel class="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-border px-4 py-3">
              <span class="grid gap-1">
                <span class="text-sm font-medium text-foreground">{{ t('admin.variants.underbase') }}</span>
                <span class="text-xs font-normal text-muted-foreground">{{ t('admin.variants.underbaseHint') }}</span>
              </span>
              <UiSwitch v-model="form.white_underbase" />
            </UiLabel>
            <TranslatableInput
              id="variant-desc"
              v-model="form.description"
              v-model:translations="tr"
              field="description"
              kind="rich"
              :label="t('admin.variants.description')"
              :placeholder="t('admin.variants.description')"
            />
          </template>
        </UiCardContent>
      </UiCard>

      <UiCard
        v-if="variant"
        class="gap-0 py-0"
      >
        <UiCardHeader class="border-b py-4">
          <UiCardTitle class="font-semibold">
            {{ t('admin.variants.specs') }}
          </UiCardTitle>
        </UiCardHeader>
        <UiCardContent class="space-y-2 py-5">
          <AdminListRow
            v-for="(spec, index) in specs"
            :key="index"
          >
            <AdminLangTabs
              v-model="specLang"
              :missing="specMissing(spec)"
            />
            <TranslatableInput
              v-model="spec.label"
              v-model:translations="spec.tr"
              v-model:lang="specLang"
              field="label"
              hide-tabs
              class="min-w-28 flex-1"
              input-class="h-9"
              :placeholder="t('admin.common.name')"
              :aria-label="t('admin.variants.specN', { n: index + 1 })"
            />
            <TranslatableInput
              v-model="spec.value"
              v-model:translations="spec.tr"
              v-model:lang="specLang"
              field="value"
              hide-tabs
              class="min-w-28 flex-1"
              input-class="h-9"
              :placeholder="t('admin.variants.value')"
              :aria-label="t('admin.variants.valueN', { n: index + 1 })"
            />
            <UiButton
              type="button"
              variant="ghost"
              size="icon-sm"
              class="text-destructive hover:bg-destructive/10 hover:text-destructive"
              :aria-label="t('admin.variants.specDelete')"
              @click="specs.splice(index, 1)"
            >
              <Icon
                name="lucide:trash-2"
                class="h-4 w-4"
              />
            </UiButton>
          </AdminListRow>
          <AdminAddRow
            :label="t('admin.variants.specAdd')"
            :disabled="specs.length >= 20 || !newSpec.label.trim() || !newSpec.value.trim()"
            @add="addSpec"
          >
            <AdminLangTabs
              v-model="specLang"
              :missing="specMissing(newSpec)"
            />
            <TranslatableInput
              v-model="newSpec.label"
              v-model:translations="newSpec.tr"
              v-model:lang="specLang"
              field="label"
              hide-tabs
              class="min-w-28 flex-1"
              input-class="h-9"
              :placeholder="t('admin.variants.specLabelPlaceholder')"
              :aria-label="t('admin.variants.newSpecLabel')"
            />
            <TranslatableInput
              v-model="newSpec.value"
              v-model:translations="newSpec.tr"
              v-model:lang="specLang"
              field="value"
              hide-tabs
              class="min-w-28 flex-1"
              input-class="h-9"
              :placeholder="t('admin.variants.specValuePlaceholder')"
              :aria-label="t('admin.variants.newSpecValue')"
            />
          </AdminAddRow>
        </UiCardContent>
      </UiCard>
      <UiCard
        v-if="variant"
        class="gap-0 py-0"
      >
        <UiCardHeader class="border-b py-4">
          <UiCardTitle class="font-semibold">
            {{ t('admin.variants.sizes') }}
            <span class="ml-1 text-sm font-normal text-muted-foreground">{{ sizes.length }}</span>
          </UiCardTitle>
        </UiCardHeader>
        <UiCardContent class="space-y-2 py-5">
          <AdminListRow
            v-for="(size, index) in sizes"
            :key="index"
          >
            <TranslatableInput
              v-model="size.label"
              v-model:translations="size.tr"
              v-model:lang="sizeLang"
              field="label"
              class="w-44"
              input-class="h-9"
              maxlength="20"
              placeholder="M"
              :check-missing="!isSizeCode(size.label)"
              :aria-label="t('admin.variants.sizeN', { n: index + 1 })"
            />
            <div class="relative w-36">
              <UiInput
                v-model="size.surcharge"
                class="h-9 pr-10"
                inputmode="decimal"
                :placeholder="t('admin.variants.surcharge')"
                :aria-label="t('admin.variants.surchargeN', { n: index + 1 })"
              />
              <span class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">{{ t('admin.common.sum') }}</span>
            </div>
            <div class="ml-auto flex items-center gap-1">
              <UiLabel class="flex h-9 cursor-pointer items-center gap-2 px-2 text-xs font-normal text-muted-foreground">
                <UiSwitch
                  v-model="size.is_available"
                  :aria-label="t('admin.variants.onSaleN', { n: index + 1 })"
                />
                <span class="hidden sm:inline">{{ t('admin.common.onSale') }}</span>
              </UiLabel>
              <UiButton
                type="button"
                variant="ghost"
                size="icon-sm"
                :aria-label="t('admin.common.moveUp')"
                :disabled="index === 0"
                @click="moveSize(index, -1)"
              >
                <Icon
                  name="lucide:chevron-up"
                  class="h-4 w-4"
                />
              </UiButton>
              <UiButton
                type="button"
                variant="ghost"
                size="icon-sm"
                :aria-label="t('admin.common.moveDown')"
                :disabled="index === sizes.length - 1"
                @click="moveSize(index, 1)"
              >
                <Icon
                  name="lucide:chevron-down"
                  class="h-4 w-4"
                />
              </UiButton>
              <UiButton
                type="button"
                variant="ghost"
                size="icon-sm"
                class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                :aria-label="t('admin.variants.sizeDelete')"
                @click="sizes.splice(index, 1)"
              >
                <Icon
                  name="lucide:trash-2"
                  class="h-4 w-4"
                />
              </UiButton>
            </div>
          </AdminListRow>
          <AdminAddRow
            :label="t('admin.variants.sizeAdd')"
            :disabled="sizes.length >= 30 || !newSize.label.trim()"
            @add="addSize"
          >
            <TranslatableInput
              v-model="newSize.label"
              v-model:translations="newSize.tr"
              v-model:lang="sizeLang"
              field="label"
              class="w-44"
              input-class="h-9"
              maxlength="20"
              :placeholder="t('admin.variants.newSize')"
              :check-missing="!isSizeCode(newSize.label)"
              :aria-label="t('admin.variants.newSize')"
            />
            <div class="relative w-36">
              <UiInput
                v-model="newSize.surcharge"
                class="h-9 pr-10"
                inputmode="decimal"
                :placeholder="t('admin.variants.surcharge')"
                :aria-label="t('admin.variants.newSizeSurcharge')"
              />
              <span class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">{{ t('admin.common.sum') }}</span>
            </div>
            <UiButton
              v-if="!sizes.length"
              type="button"
              variant="outline"
              size="sm"
              class="h-9"
              @click="sizes = DEFAULT_SIZES.map(label => newSizeRow(label))"
            >
              <Icon
                name="lucide:shirt"
                class="h-4 w-4"
              />
              S–XXL
            </UiButton>
          </AdminAddRow>
        </UiCardContent>
      </UiCard>
    </form>

    <UiCard
      v-if="variant"
      class="gap-0 py-0"
    >
      <UiCardHeader class="border-b py-4">
        <UiCardTitle class="font-semibold">
          {{ t('admin.variants.colors') }}
          <span class="ml-1 text-sm font-normal text-muted-foreground">{{ colors.length }}</span>
        </UiCardTitle>
      </UiCardHeader>
      <UiCardContent class="space-y-2 py-5">
        <ColorRow
          v-for="color in colors"
          :key="color.id"
          :color="color"
        />
        <AdminAddRow
          :label="t('admin.variants.colorAdd')"
          :disabled="!canAddColor"
          @add="addColor"
        >
          <UiInput
            v-model="newColor.hex"
            type="color"
            class="h-9 w-10 shrink-0 cursor-pointer rounded-lg p-1"
            :aria-label="t('admin.variants.color')"
          />
          <TranslatableInput
            v-model="newColor.name"
            v-model:translations="newColor.tr"
            field="name"
            class="min-w-40 flex-1"
            input-class="h-9"
            :placeholder="t('admin.variants.newColorName')"
            :aria-label="t('admin.variants.colorName')"
            required
          />
          <div class="relative w-28 shrink-0">
            <UiInput
              v-model="newColor.surcharge"
              class="h-9 pr-10"
              inputmode="decimal"
              :aria-label="t('admin.variants.surchargeSum')"
              :placeholder="t('admin.variants.surcharge')"
            />
            <span class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">{{ t('admin.common.sum') }}</span>
          </div>
        </AdminAddRow>
      </UiCardContent>
    </UiCard>

    <template v-if="variant">
      <UiAlertDialog v-model:open="removing">
        <UiAlertDialogContent>
          <UiAlertDialogHeader>
            <UiAlertDialogTitle>{{ t('admin.variants.deleteTitle') }}</UiAlertDialogTitle>
          </UiAlertDialogHeader>
          <UiAlertDialogFooter>
            <UiAlertDialogCancel>{{ t('admin.common.cancel') }}</UiAlertDialogCancel>
            <UiButton
              variant="destructive"
              :disabled="busy"
              @click="remove"
            >
              <Icon
                v-if="busy"
                name="lucide:loader-2"
                class="h-4 w-4 animate-spin"
              />
              {{ t('admin.common.delete') }}
            </UiButton>
          </UiAlertDialogFooter>
        </UiAlertDialogContent>
      </UiAlertDialog>
    </template>
  </div>
</template>
