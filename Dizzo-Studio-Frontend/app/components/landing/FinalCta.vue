<script setup lang="ts">
// The last push: one line, one button, the products beside it — on the
// same warm tint as the shape behind the hero's products, so the page ends
// the way it began.
const { start } = useProductPicker();
const { t } = useI18n();
</script>

<template>
  <section
    aria-labelledby="final-cta-title"
    class="flex h-full min-h-[420px] flex-col justify-between overflow-hidden rounded-3xl bg-secondary-100 p-6 sm:p-8 lg:p-10"
  >
    <!-- Rasm tepada -->
    <div
      class="flex flex-1 items-center justify-center py-2 sm:py-4"
      aria-hidden="true"
    >
      <picture>
        <source
          type="image/avif"
          srcset="/generated/adventure-composite-640.avif 640w, /generated/adventure-composite-960.avif 960w"
          sizes="(max-width: 1023px) 90vw, 520px"
        >
        <img
          src="/generated/adventure-composite-640.webp"
          srcset="/generated/adventure-composite-640.webp 640w, /generated/adventure-composite-960.webp 960w"
          sizes="(max-width: 1023px) 90vw, 520px"
          alt=""
          width="1536"
          height="1024"
          class="mx-auto block h-auto max-h-60 sm:max-h-72 lg:max-h-80 w-auto max-w-full object-contain drop-shadow-xs"
          loading="lazy"
          decoding="async"
        >
      </picture>
    </div>

    <!-- Matn va button pastda -->
    <div class="mt-auto pt-4">
      <h2
        id="final-cta-title"
        class="text-2xl font-extrabold leading-tight tracking-[-0.02em] text-ink sm:text-3xl lg:text-[2.2rem]"
      >
        {{ t('storefront.landing.finalTitle') }}
      </h2>
      <UiButton
        size="lg"
        class="mt-5 w-full rounded-xl sm:w-auto"
        @click="start"
      >
        {{ t('storefront.nav.startDesign') }}
        <Icon name="lucide:arrow-right" />
      </UiButton>
    </div>
  </section>
</template>
