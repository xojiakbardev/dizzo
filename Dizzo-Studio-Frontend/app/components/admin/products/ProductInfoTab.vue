<script setup lang="ts">
// The product's own details: the cover large in its own card on the left,
// the fields in a card on the right. Delete / cancel / save sit in the page header.
// The cover saves as it's picked; other pictures belong to the colours.
import { getApiErrorMessage } from '~/composables/useApi';
import type { AdminCatalogProduct } from '~/types/catalog';
import { isTranslated, sameTranslations, textTranslations, trimTranslations } from '~/lib/admin/translations';
import ImagePicker from '~/components/admin/products/ImagePicker.vue';

const props = defineProps<{ product: AdminCatalogProduct }>();
const { run, busy } = useCatalogAdminActions();
const { t } = useI18n();
const localePath = useLocalePath();
const error = ref<string | null>(null);
const saved = ref(false);

const fromProduct = () => ({
  name: props.product.name,
  is_available: props.product.is_available,
  is_featured: props.product.is_featured,
  category: props.product.category,
});
const form = reactive(fromProduct());
// The name in Russian and English. A PATCH replaces a language's whole
// block, so the description (not edited here) is sent back as it was.
const savedTr = () => textTranslations(props.product.translations, ['name', 'description']);
const nameTr = ref(savedTr());
const reset = () => {
  Object.assign(form, fromProduct());
  nameTr.value = savedTr();
};
const trDirty = computed(() => !sameTranslations(nameTr.value, savedTr()));
const dirty = computed(() => trDirty.value || (Object.keys(form) as Array<keyof typeof form>).some(k => form[k] !== props.product[k]));
const canSave = computed(() => !busy.value && dirty.value && Boolean(form.name.trim()) && isTranslated(nameTr.value, 'name'));
watch([form, nameTr], () => {
  saved.value = false;
}, { deep: true });
const shelves = useAdminCategories();
function setCategory(value: unknown) {
  if (typeof value === 'string' && shelves.data.value?.some(c => c.slug === value)) form.category = value;
}

const base = computed(() => `/admin/catalog/products/${props.product.id}/`);
async function act(verb: 'patch' | 'put', path: string, body: Record<string, unknown>) {
  error.value = null;
  try {
    await run(verb, path, body);
    return true;
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.common.saveFailed'));
    return false;
  }
}
async function save() {
  if (!canSave.value) return;
  saved.value = await act('patch', base.value, { ...form, name: form.name.trim(), translations: trimTranslations(nameTr.value) });
}

const deleting = ref(false);
async function remove() {
  if (await act('patch', base.value, { archived: true })) await navigateTo(localePath('/admin/products'));
  deleting.value = false;
}
</script>

<template>
  <form @submit.prevent="save">
    <div class="grid items-start gap-5 lg:grid-cols-[auto_minmax(0,1fr)]">
      <!-- The cover; the pictures customers see live on the colours. -->
      <UiCard class="gap-0 py-0">
        <UiCardHeader class="border-b py-4">
          <UiCardTitle class="font-semibold">
            {{ t('admin.products.cover') }}
          </UiCardTitle>
        </UiCardHeader>
        <UiCardContent class="flex justify-center py-5">
          <ImagePicker
            :images="product.cover ? [product.cover] : []"
            :max="1"
            size="xl"
            @change="ids => act('patch', base, { cover_media_id: ids[0] ?? null })"
          />
        </UiCardContent>
      </UiCard>

      <UiCard class="gap-0 py-0">
        <UiCardHeader class="border-b py-4">
          <UiCardTitle class="font-semibold">
            {{ t('admin.products.basics') }}
          </UiCardTitle>
        </UiCardHeader>
        <UiCardContent class="space-y-4 py-5">
          <TranslatableInput
            id="product-name"
            v-model="form.name"
            v-model:translations="nameTr"
            field="name"
            :label="t('admin.common.name')"
            required
          />

          <UiField
            :label="t('admin.products.category')"
            for="product-category"
          >
            <UiSelect
              :model-value="form.category"
              @update:model-value="setCategory"
            >
              <UiSelectTrigger
                id="product-category"
                class="w-full"
              >
                <UiSelectValue :placeholder="t('admin.common.choose')" />
              </UiSelectTrigger>
              <UiSelectContent position="popper">
                <UiSelectItem
                  v-for="c in shelves.data.value ?? []"
                  :key="c.slug"
                  :value="c.slug"
                >
                  <span class="flex items-center gap-2">
                    <CategoryIcon
                      :svg="c.icon_svg"
                      :image="c.image_url"
                    />
                    {{ c.name }}
                  </span>
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <UiLabel class="flex w-full cursor-pointer items-center justify-between gap-3 rounded-xl border border-border px-4 py-3">
            <span class="text-sm font-medium text-foreground">{{ t('admin.common.onSale') }}</span>
            <UiSwitch v-model="form.is_available" />
          </UiLabel>

          <UiLabel class="flex w-full cursor-pointer items-center justify-between gap-3 rounded-xl border border-border px-4 py-3">
            <span class="text-sm font-medium text-foreground">{{ t('admin.products.featured') }}</span>
            <UiSwitch v-model="form.is_featured" />
          </UiLabel>
          <UiAlert
            v-if="error"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ error }}
          </UiAlert>
        </UiCardContent>
      </UiCard>
    </div>

    <Teleport
      defer
      to="#product-detail-actions"
    >
      <UiButton
        type="button"
        variant="ghost"
        class="text-destructive hover:bg-destructive/10 hover:text-destructive"
        @click="deleting = true"
      >
        <Icon
          name="lucide:trash-2"
          class="text-base"
        />
        {{ t('admin.common.delete') }}
      </UiButton>
      <UiButton
        type="button"
        variant="outline"
        :disabled="busy || !dirty"
        @click="reset"
      >
        {{ t('admin.common.cancel') }}
      </UiButton>
      <UiButton
        :disabled="!canSave"
        @click="save"
      >
        <Icon
          :name="busy && dirty ? 'lucide:loader-2' : saved && !dirty ? 'lucide:check' : 'lucide:save'"
          :class="busy && dirty ? 'animate-spin text-base' : 'text-base'"
        />
        {{ saved && !dirty ? t('admin.common.saved') : t('admin.common.save') }}
      </UiButton>
    </Teleport>

    <UiAlertDialog v-model:open="deleting">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.products.deleteTitle') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>
            {{ t('admin.common.cancel') }}
          </UiAlertDialogCancel>
          <UiAlertDialogAction
            variant="destructive"
            :disabled="busy"
            @click="remove"
          >
            <Icon
              v-if="busy"
              name="lucide:loader-2"
              class="animate-spin text-base"
            />
            {{ t('admin.common.delete') }}
          </UiAlertDialogAction>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </form>
</template>
