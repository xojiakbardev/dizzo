<script setup lang="ts">
// Answers that match how the shop works today: the operator confirms every
// order and agrees payment and delivery. Keep them in step when that
// changes. `wide`: the section has the row to itself, so the questions
// split into two columns on a laptop.
import { ldJson } from '#shared/seo';

defineProps<{ wide?: boolean }>();

const { t } = useI18n();

const FAQ_KEYS = ['what', 'images', 'time', 'payment', 'delivery', 'cancel'] as const;
// The head's JSON-LD reads this outside the setup context: only `t` from here.
const faqs = computed(() => {
  const pickup = pickupPoint(key => t(key));
  return FAQ_KEYS.map(key => ({
    q: t(`storefront.faq.${key}.q`),
    a: t(`storefront.faq.${key}.a`, { address: pickup.address, hours: pickup.hours }),
  }));
});

// The structured data follows the page's language.
useHead({
  script: [{
    type: 'application/ld+json',
    key: 'faq-ld',
    innerHTML: computed(() => ldJson({
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      'mainEntity': faqs.value.map(f => ({ '@type': 'Question', 'name': f.q, 'acceptedAnswer': { '@type': 'Answer', 'text': f.a } })),
    })),
  }],
});

const openIndex = ref<number | null>(null);
const toggle = (i: number) => { openIndex.value = openIndex.value === i ? null : i; };
</script>

<template>
  <section
    id="faq"
    aria-labelledby="faq-title"
    class="scroll-mt-20"
  >
    <h2
      id="faq-title"
      class="text-2xl font-extrabold tracking-[-0.02em] text-ink sm:text-[1.75rem]"
    >
      {{ t('storefront.footer.faq') }}
    </h2>
    <ul class="mt-5 flex flex-col gap-2.5">
      <li
        v-for="(faq, i) in faqs"
        :key="i"
        class="rounded-2xl border border-line bg-white"
      >
        <h3>
          <button
            :id="`faq-q-${i}`"
            type="button"
            class="flex min-h-14 w-full cursor-pointer items-center justify-between gap-4 px-4 py-3 text-left text-base font-semibold text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta"
            :aria-expanded="openIndex === i"
            :aria-controls="`faq-a-${i}`"
            @click="toggle(i)"
          >
            {{ faq.q }}
            <Icon
              name="lucide:chevron-down"
              class="h-5 w-5 shrink-0 text-slate-500 transition-transform duration-300 motion-reduce:transition-none"
              :class="{ 'rotate-180': openIndex === i }"
            />
          </button>
        </h3>
        <div
          :id="`faq-a-${i}`"
          role="region"
          :aria-labelledby="`faq-q-${i}`"
          class="grid transition-[grid-template-rows] duration-300 ease-out motion-reduce:transition-none"
          :class="openIndex === i ? 'grid-rows-[1fr]' : 'grid-rows-[0fr]'"
          :inert="openIndex !== i"
        >
          <div class="overflow-hidden">
            <p class="px-4 pb-4 text-[15px] leading-6 text-slate-700">
              {{ faq.a }}
            </p>
          </div>
        </div>
      </li>
    </ul>
  </section>
</template>
