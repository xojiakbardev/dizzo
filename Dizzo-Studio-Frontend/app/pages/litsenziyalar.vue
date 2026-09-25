<script setup lang="ts">
// "Litsenziyalar": the credit the CC BY 4.0 licence asks for the 3D models
// the site downloaded — each model's title, its author and the licence.
// A new downloaded model goes into MODEL_CREDITS.
const { t } = useI18n();
useHead({ title: () => t('storefront.licenses.title') });

const CC_BY = 'https://creativecommons.org/licenses/by/4.0/';

const MODEL_CREDITS = [
  { title: 'Tshirt', author: 'Tabbuso', url: 'https://sketchfab.com/3d-models/tshirt-5a21282b2e454d1696547148f617d3d0' },
  { title: 'Sweatshirt Raglan Sleeves Colorway 1', author: 'benski77', url: 'https://sketchfab.com/3d-models/8843727796bd4d7da801b092179eb1a2' },
  { title: 'UnderRated Hoodie', author: 'UnderRated', url: 'https://sketchfab.com/3d-models/9b898f0b2be344cfa07ba6b3a83708b4' },
  { title: 'Baseball Cap', author: 'Scott VanArsdale', url: 'https://sketchfab.com/3d-models/baseball-cap-1c1d34d73fd94e6b9e8f82b1eb7194a0' },
  { title: 'Baseball Cap', author: 'Microsoft', url: 'https://sketchfab.com/3d-models/baseball-cap-b62494f56bcb46a68f1f4610c8d1f346' },
  { title: 'New York Yankees 59FIFTY Fitted Cap', author: 'c42m05', url: 'https://sketchfab.com/3d-models/a2cd8106271a48e398962b2662db225c' },
];
</script>

<template>
  <div class="mx-auto max-w-3xl px-4 pb-14 pt-6 sm:px-6 sm:pt-8 lg:px-8">
    <h1 class="text-[1.75rem] font-extrabold tracking-[-0.02em] text-ink sm:text-3xl">
      {{ t('storefront.licenses.title') }}
    </h1>

    <section
      aria-labelledby="models-title"
      class="mt-6 overflow-hidden rounded-2xl border border-line bg-white"
    >
      <div class="flex flex-wrap items-center justify-between gap-2 border-b border-line px-4 py-3 sm:px-5">
        <h2
          id="models-title"
          class="text-base font-bold text-ink"
        >
          {{ t('storefront.licenses.models') }}
        </h2>
        <a
          :href="CC_BY"
          target="_blank"
          rel="noopener"
          class="inline-flex items-center gap-1 rounded-full bg-plate px-2.5 py-1 text-xs font-semibold text-slate-700 transition hover:text-ink"
        >
          CC BY 4.0
          <Icon
            name="lucide:external-link"
            class="size-3"
          />
        </a>
      </div>
      <ul class="divide-y divide-line">
        <li
          v-for="model in MODEL_CREDITS"
          :key="model.url"
          class="flex flex-col gap-1 px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4 sm:px-5"
        >
          <a
            :href="model.url"
            target="_blank"
            rel="noopener"
            class="font-semibold text-ink hover:text-cta hover:underline"
          >“{{ model.title }}”</a>
          <span class="shrink-0 text-sm text-slate-600">
            {{ model.author }} ·
            <a
              :href="CC_BY"
              target="_blank"
              rel="noopener"
              class="hover:text-ink hover:underline"
            >CC BY 4.0</a>
          </span>
        </li>
      </ul>
    </section>
  </div>
</template>
