<script setup lang="ts">
// "UZ | RU | EN": which language a translatable field shows. A language
// still missing its text carries a small dot (red once it's required).
import type { ContentLang } from '~/lib/admin/translations';
import { CONTENT_LANGS } from '~/lib/admin/translations';

const props = defineProps<{ missing?: readonly ContentLang[]; required?: boolean }>();
const lang = defineModel<ContentLang>({ default: 'uz' });
const { t } = useI18n();
</script>

<template>
  <div
    role="tablist"
    :aria-label="t('admin.translate.tabs')"
    class="inline-flex h-7 shrink-0 items-center gap-0.5 rounded-lg bg-muted p-0.5"
  >
    <button
      v-for="code in CONTENT_LANGS"
      :key="code"
      type="button"
      role="tab"
      :aria-selected="lang === code"
      :title="props.missing?.includes(code) ? `${t(`admin.translate.lang.${code}`)} — ${t('admin.translate.missing')}` : t(`admin.translate.lang.${code}`)"
      class="relative h-6 rounded-md px-1.5 text-[10px] font-semibold tracking-wide transition-colors"
      :class="lang === code ? 'bg-background text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'"
      @click="lang = code"
    >
      {{ code.toUpperCase() }}
      <span
        v-if="props.missing?.includes(code)"
        class="absolute right-0.5 top-0.5 size-1.5 rounded-full"
        :class="props.required ? 'bg-destructive' : 'bg-amber-500'"
      />
    </button>
  </div>
</template>
