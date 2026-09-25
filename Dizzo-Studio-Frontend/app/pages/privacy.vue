<script setup lang="ts">
// The privacy policy in the page's language (the text: app/lib/privacy.ts).
// Its #delete-account section is where the profile and the stores point.
import { PRIVACY, PRIVACY_UPDATED } from '~/lib/privacy';

const { locale } = useI18n();
const text = computed(() => PRIVACY[locale.value === 'ru' || locale.value === 'en' ? locale.value : 'uz']);
</script>

<template>
  <article class="mx-auto max-w-3xl px-4 pb-16 pt-8 sm:px-6 sm:pt-10">
    <h1 class="text-[1.75rem] font-extrabold tracking-[-0.02em] text-ink sm:text-3xl">
      {{ text.title }}
    </h1>
    <p class="mt-2 text-sm text-slate-500">
      {{ text.updated }}: {{ formatDate(PRIVACY_UPDATED) }}
    </p>
    <p class="mt-6 text-base leading-7 text-slate-700">
      {{ text.intro }}
    </p>

    <nav class="mt-6 rounded-2xl border border-line bg-white p-4">
      <ol class="list-decimal space-y-1 pl-5 text-sm">
        <li
          v-for="s in text.sections"
          :key="s.id"
        >
          <a
            :href="`#${s.id}`"
            class="text-cta hover:underline"
          >{{ s.title }}</a>
        </li>
      </ol>
    </nav>

    <section
      v-for="(s, i) in text.sections"
      :id="s.id"
      :key="s.id"
      class="mt-8 scroll-mt-24"
    >
      <h2 class="text-xl font-bold text-ink">
        {{ i + 1 }}. {{ s.title }}
      </h2>
      <p
        v-for="(p, j) in s.paragraphs ?? []"
        :key="j"
        class="mt-3 text-base leading-7 text-slate-700"
      >
        {{ p }}
      </p>
      <ul
        v-if="s.items?.length"
        class="mt-3 list-disc space-y-2 pl-5 text-base leading-7 text-slate-700"
      >
        <li
          v-for="(item, j) in s.items"
          :key="j"
        >
          {{ item }}
        </li>
      </ul>
    </section>
  </article>
</template>
