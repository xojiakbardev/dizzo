<script setup lang="ts">
// One colour of a variant: swatch, name, surcharge, on/off and removal on the
// first row; its gallery underneath. The designated star/first picture serves
// as the color card.
import { getApiErrorMessage } from '~/composables/useApi';
import type { CatalogImage, VariantColor } from '~/types/catalog';
import { isTranslated, sameTranslations, textTranslations, trimTranslations } from '~/lib/admin/translations';
import { CELL_MAX, saveRequest } from '~/lib/catalogPictures';
import ImagePicker from '~/components/admin/products/ImagePicker.vue';

const props = defineProps<{ color: VariantColor }>();
const { run, busy } = useCatalogAdminActions();
const { t } = useI18n();
const error = ref<string | null>(null);

const savedTr = () => textTranslations(props.color.translations, ['name']);
const form = reactive({ name: props.color.name, hex: props.color.hex, surcharge: props.color.surcharge, tr: savedTr() });
// A fresh copy from the server (after a save) becomes the new baseline.
watch(() => JSON.stringify(props.color.translations ?? {}), () => {
  form.tr = savedTr();
});
const dirty = computed(() => form.name !== props.color.name || form.hex !== props.color.hex
  || Number(form.surcharge) !== Number(props.color.surcharge) || !sameTranslations(form.tr, savedTr()));
const canSave = computed(() => dirty.value && Boolean(form.name.trim()) && isTranslated(form.tr, 'name'));
function save() {
  if (!canSave.value) return;
  act({ name: form.name.trim(), hex: form.hex, surcharge: form.surcharge, translations: trimTranslations(form.tr) });
}
const removing = ref(false);

async function act(body: Record<string, unknown>, path = `/admin/catalog/colors/${props.color.id}/`, verb: 'patch' | 'put' = 'patch') {
  error.value = null;
  try {
    await run(verb, path, body);
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.variants.colorSaveFailed'));
  }
}

/** Saves the colour's gallery picture list through the shared request. */
function savePictures(ids: string[]) {
  const req = saveRequest({ kind: 'color', id: props.color.id }, ids);
  return act(req.body, req.path, req.verb);
}
</script>

<template>
  <div class="space-y-3 rounded-xl border border-border bg-card p-3">
    <!-- Birinchi qator: input va buttonlar -->
    <form
      class="flex min-w-0 flex-wrap items-center gap-2"
      @submit.prevent="save"
    >
      <UiInput
        v-model="form.hex"
        type="color"
        class="h-9 w-10 shrink-0 cursor-pointer rounded-lg p-1"
        :aria-label="t('admin.variants.color')"
      />
      <TranslatableInput
        v-model="form.name"
        v-model:translations="form.tr"
        field="name"
        class="min-w-40 flex-1"
        input-class="h-9"
        :placeholder="t('admin.variants.colorName')"
        :aria-label="t('admin.variants.colorName')"
        required
      />
      <div class="relative w-28 shrink-0">
        <UiInput
          v-model="form.surcharge"
          class="h-9 pr-10"
          inputmode="decimal"
          :aria-label="t('admin.variants.surchargeSum')"
        />
        <span class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">{{ t('admin.common.sum') }}</span>
      </div>
      <UiButton
        v-if="dirty"
        type="submit"
        size="sm"
        class="h-9"
        :disabled="busy || !canSave"
      >
        <Icon
          name="lucide:check"
          class="h-4 w-4"
        />
        {{ t('admin.common.save') }}
      </UiButton>
      <div class="ml-auto flex items-center gap-1">
        <UiLabel class="flex h-9 cursor-pointer items-center gap-2 px-2 text-xs font-normal text-muted-foreground">
          <UiSwitch
            :model-value="color.is_available"
            :disabled="busy"
            @update:model-value="(v: boolean) => act({ is_available: v })"
          />
          <span class="hidden sm:inline">{{ t('admin.common.onSale') }}</span>
        </UiLabel>
        <UiButton
          type="button"
          variant="ghost"
          size="icon-sm"
          class="text-destructive hover:bg-destructive/10 hover:text-destructive"
          :aria-label="t('admin.variants.colorDelete')"
          :disabled="busy"
          @click="removing = true"
        >
          <Icon
            name="lucide:trash-2"
            class="h-4 w-4"
          />
        </UiButton>
      </div>
    </form>

    <!-- Ikkinchi qator (tagidan): rasmlar galereyasi -->
    <div class="min-w-0 space-y-1.5 border-t border-border/40 pt-2">
      <p class="text-[11px] font-medium text-muted-foreground">
        {{ t('admin.images.colorGallery') }}
      </p>
      <ImagePicker
        :images="color.images"
        :max="CELL_MAX.color"
        size="md"
        scroll
        :starrable="true"
        @change="ids => savePictures(ids)"
      />
    </div>
    <UiAlert
      v-if="error"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ error }}
    </UiAlert>

    <UiAlertDialog v-model:open="removing">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.variants.colorDelete') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>{{ t('admin.common.cancel') }}</UiAlertDialogCancel>
          <UiAlertDialogAction
            variant="destructive"
            :disabled="busy"
            @click="act({ archived: true })"
          >
            {{ t('admin.common.delete') }}
          </UiAlertDialogAction>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
