<script setup lang="ts">
// Admin: saves the Studio's design as a template for the type open in the
// editor (with its five pictures); "Galereyada ko‘rsatish" puts it on the
// public page. Designs are told apart by their product, so there is no
// section to pick.
import type { AdminTemplate, PublicVariant } from '~/types/catalog';

export interface TemplateForm {
  name: string; // Uzbek, the default language
  category: string;
  variant_ids: number[];
  in_gallery: boolean;
  translations: { ru: { name: string }; en: { name: string } };
}
type NameTranslations = Partial<Record<'ru' | 'en', { name?: string | null }>>;

const props = defineProps<{
  open: boolean;
  editing: AdminTemplate | null;
  variants: PublicVariant[];
  variantId: number | null;
  busy: boolean;
  error: string | null;
}>();
const emit = defineEmits<{ 'update:open': [open: boolean]; 'save': [form: TemplateForm] }>();

const form = reactive<TemplateForm>({
  name: '', category: '', variant_ids: [], in_gallery: true, translations: { ru: { name: '' }, en: { name: '' } },
});
const names = computed(() => [form.name, form.translations.ru.name, form.translations.en.name]);
const complete = computed(() => names.value.every(n => n.trim()));

function submit() {
  emit('save', {
    ...form,
    name: form.name.trim(),
    translations: { ru: { name: form.translations.ru.name.trim() }, en: { name: form.translations.en.name.trim() } },
  });
}

watch(() => props.open, (open) => {
  if (!open) return;
  form.name = props.editing?.name ?? '';
  const translations = ((props.editing as { translations?: NameTranslations } | null)?.translations ?? {}) as NameTranslations;
  form.translations = { ru: { name: translations.ru?.name ?? '' }, en: { name: translations.en?.name ?? '' } };
  form.in_gallery = props.editing?.in_gallery ?? true;
  // Always the type chosen in the editor.
  form.variant_ids = props.variantId ? [props.variantId] : [];
});
</script>

<template>
  <UiDialog
    :open="open"
    @update:open="(v: boolean) => emit('update:open', v)"
  >
    <UiDialogContent class="sm:max-w-md">
      <UiDialogHeader>
        <UiDialogTitle>{{ $t('studio.templateSave.title') }}</UiDialogTitle>
      </UiDialogHeader>
      <form
        class="space-y-4"
        @submit.prevent="submit"
      >
        <fieldset class="space-y-2">
          <legend class="mb-2 text-sm font-medium">
            {{ $t('studio.templateSave.name') }}
          </legend>
          <label
            for="template-name-uz"
            class="flex items-center gap-2"
          >
            <span class="w-8 shrink-0 rounded-md bg-muted py-1 text-center text-[11px] font-bold text-muted-foreground">UZ</span>
            <UiInput
              id="template-name-uz"
              v-model="form.name"
              maxlength="120"
              :placeholder="$t('studio.templateSave.namePlaceholderUz')"
              :aria-label="$t('studio.templateSave.nameIn', { lang: 'UZ' })"
              required
            />
          </label>
          <label
            for="template-name-ru"
            class="flex items-center gap-2"
          >
            <span class="w-8 shrink-0 rounded-md bg-muted py-1 text-center text-[11px] font-bold text-muted-foreground">RU</span>
            <UiInput
              id="template-name-ru"
              v-model="form.translations.ru.name"
              maxlength="120"
              :placeholder="$t('studio.templateSave.namePlaceholderRu')"
              :aria-label="$t('studio.templateSave.nameIn', { lang: 'RU' })"
              required
            />
          </label>
          <label
            for="template-name-en"
            class="flex items-center gap-2"
          >
            <span class="w-8 shrink-0 rounded-md bg-muted py-1 text-center text-[11px] font-bold text-muted-foreground">EN</span>
            <UiInput
              id="template-name-en"
              v-model="form.translations.en.name"
              maxlength="120"
              :placeholder="$t('studio.templateSave.namePlaceholderEn')"
              :aria-label="$t('studio.templateSave.nameIn', { lang: 'EN' })"
              required
            />
          </label>
        </fieldset>
        <label class="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-border px-3 py-2.5 text-sm font-medium">
          {{ $t('studio.templateSave.inGallery') }}
          <UiSwitch v-model="form.in_gallery" />
        </label>
        <UiAlert
          v-if="error"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          {{ error }}
        </UiAlert>
        <UiDialogFooter>
          <UiButton
            type="button"
            variant="outline"
            @click="emit('update:open', false)"
          >
            {{ $t('studio.common.cancel') }}
          </UiButton>
          <UiButton
            type="submit"
            :disabled="busy || !complete || !form.variant_ids.length"
          >
            <Icon
              :name="busy ? 'lucide:loader-circle' : 'lucide:save'"
              :class="{ 'animate-spin': busy }"
            />
            {{ busy ? $t('studio.common.saving') : $t('studio.common.save') }}
          </UiButton>
        </UiDialogFooter>
      </form>
    </UiDialogContent>
  </UiDialog>
</template>
