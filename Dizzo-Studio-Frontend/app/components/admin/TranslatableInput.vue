<script setup lang="ts">
// One content field in Uzbek, Russian and English:
//   <TranslatableInput v-model="form.name" v-model:translations="form.tr" field="name" :label="…" required />
// v-model is the Uzbek text (the resource's own field); `translations` is
// `{ ru: { [field]: … }, en: { … } }` (see lib/admin/translations.ts).
// kind: 'input' (default), 'textarea' or 'rich' (RichTextEditor, HTML).
// Without a label the UZ/RU/EN tabs sit in front of the field (list rows);
// `lang` + `hide-tabs` let one set of tabs drive several fields.
import type { HTMLAttributes } from 'vue';
import type { TranslationLang } from '~/types/catalog';
import type { ContentLang, TextTranslations } from '~/lib/admin/translations';
import { missingLangs } from '~/lib/admin/translations';
import { cn } from '@/lib/utils';

const props = withDefaults(defineProps<{
  field: string;
  kind?: 'input' | 'textarea' | 'rich';
  label?: string;
  id?: string;
  placeholder?: string;
  hint?: string;
  required?: boolean;
  /** Flag an untranslated language with a dot (off for codes like "XL"). */
  checkMissing?: boolean;
  hideTabs?: boolean;
  maxlength?: number | string;
  inputmode?: HTMLAttributes['inputmode'];
  ariaLabel?: string;
  class?: HTMLAttributes['class'];
  inputClass?: HTMLAttributes['class'];
}>(), { kind: 'input', checkMissing: true });

const uz = defineModel<string>({ required: true });
const translations = defineModel<TextTranslations>('translations', { required: true });
const lang = defineModel<ContentLang>('lang', { default: 'uz' });
const { t } = useI18n();

const value = computed({
  get: () => (lang.value === 'uz' ? uz.value : translations.value[lang.value]?.[props.field] ?? ''),
  set: (text: string) => {
    if (lang.value === 'uz') {
      uz.value = text;
      return;
    }
    const code: TranslationLang = lang.value;
    translations.value = { ...translations.value, [code]: { ...translations.value[code], [props.field]: text } };
  },
});

// Only nag once there is something to translate.
const missing = computed<ContentLang[]>(() =>
  props.checkMissing && uz.value.trim() ? missingLangs(translations.value, props.field) : []);
const error = computed(() => {
  if (!props.required || !missing.value.length) return null;
  return missing.value.length > 1 ? t('admin.translate.required.both') : t(`admin.translate.required.${missing.value[0]}`);
});
const langName = computed(() => t(`admin.translate.lang.${lang.value}`));
const placeholder = computed(() => (lang.value === 'uz' || !uz.value.trim() ? props.placeholder : uz.value.replace(/<[^>]*>/g, ' ').trim().slice(0, 80)));
const aria = computed(() => {
  const base = props.ariaLabel ?? props.label;
  return base ? `${base} (${langName.value})` : langName.value;
});
</script>

<template>
  <div :class="cn('grid min-w-0 gap-1.5', props.class)">
    <div
      v-if="label"
      class="flex min-h-7 items-center justify-between gap-2"
    >
      <UiLabel
        :for="id"
        class="text-xs font-semibold text-foreground"
      >
        {{ label }}
      </UiLabel>
      <AdminLangTabs
        v-if="!hideTabs"
        v-model="lang"
        :missing="missing"
        :required="required"
      />
    </div>
    <div
      class="flex min-w-0 gap-1.5"
      :class="kind === 'input' ? 'items-center' : 'items-start'"
    >
      <AdminLangTabs
        v-if="!label && !hideTabs"
        v-model="lang"
        :missing="missing"
        :required="required"
      />
      <UiInput
        v-if="kind === 'input'"
        :id="id"
        v-model="value"
        :class="cn('min-w-0 flex-1', inputClass)"
        :placeholder="placeholder"
        :maxlength="maxlength"
        :inputmode="inputmode"
        :lang="lang"
        :aria-label="aria"
        :aria-invalid="error ? true : undefined"
      />
      <UiTextarea
        v-else-if="kind === 'textarea'"
        :id="id"
        v-model="value"
        :class="cn('min-w-0 flex-1', inputClass)"
        :placeholder="placeholder"
        :maxlength="maxlength"
        :lang="lang"
        :aria-label="aria"
      />
      <RichTextEditor
        v-else
        :id="id"
        v-model="value"
        :class="cn('min-w-0 flex-1', inputClass)"
        :placeholder="lang === 'uz' ? props.placeholder : `${props.placeholder ?? ''} (${langName})`"
      />
    </div>
    <p
      v-if="error"
      class="text-xs text-destructive"
    >
      {{ error }}
    </p>
    <p
      v-else-if="hint"
      class="text-xs text-muted-foreground"
    >
      {{ hint }}
    </p>
  </div>
</template>
