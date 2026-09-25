<script setup lang="ts">
// The site's language: O‘zbekcha / Русский / English. Switching keeps the
// page (its /ru or /en twin), remembers the choice (cookie) and, for a
// signed-in customer, saves it to the profile so Telegram and the app speak
// it too.
// `full`: the language's name beside the flag (the phone menu); otherwise
// its short code — "UZ", "RU", "EN".
const props = withDefaults(defineProps<{ full?: boolean; align?: 'start' | 'end' }>(), { full: false, align: 'end' });

const { locale, locales, setLocale, t } = useI18n();
const api = useApi();
const { data: user } = useCurrentUser();

const options = computed(() => (locales.value as { code: 'uz' | 'ru' | 'en'; name?: string }[]));
const current = computed(() => options.value.find(l => l.code === locale.value));
const short = (code: string) => code.toUpperCase();

async function pick(code: 'uz' | 'ru' | 'en') {
  if (code === locale.value) return;
  await setLocale(code);
  if (user.value) {
    try {
      await api.patch('/users/profile/me/', { language: code });
    }
    catch {
      // The page is already in the new language; the profile catches up next time.
    }
  }
}
</script>

<template>
  <UiDropdownMenu>
    <UiDropdownMenuTrigger as-child>
      <UiButton
        v-if="props.full"
        variant="ghost"
        class="gap-2 px-2.5 font-semibold"
        :aria-label="t('common.language.choose')"
      >
        <FlagIcon
          :code="locale"
          class="text-2xl"
        />
        <span>{{ current?.name }}</span>
      </UiButton>
      <!-- the Studio's back button look: outlined, icon height; flag and code -->
      <UiButton
        v-else
        variant="outline"
        class="h-10 gap-2 px-2.5 font-semibold"
        :aria-label="t('common.language.choose')"
        :title="current?.name"
      >
        <FlagIcon
          :code="locale"
          class="text-[22px]"
        />
        <span>{{ short(locale) }}</span>
      </UiButton>
    </UiDropdownMenuTrigger>
    <UiDropdownMenuContent :align="props.align">
      <UiDropdownMenuItem
        v-for="l in options"
        :key="l.code"
        class="justify-between gap-6"
        @select="pick(l.code)"
      >
        <span class="flex items-center gap-2.5">
          <FlagIcon
            :code="l.code"
            class="text-xl"
          />
          <span :lang="l.code">{{ l.name }}</span>
        </span>
        <Icon
          v-if="l.code === locale"
          name="lucide:check"
          class="text-primary"
        />
      </UiDropdownMenuItem>
    </UiDropdownMenuContent>
  </UiDropdownMenu>
</template>
