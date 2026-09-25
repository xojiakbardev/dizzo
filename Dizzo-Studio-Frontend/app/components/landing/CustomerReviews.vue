<script setup lang="ts">
// Approved reviews only (customers write them after a completed order, the
// admin approves); the landing leaves the section out when there are none,
// and shows it in grey while they load.
import type { PublicReview } from '~/composables/queries/useReviews';

defineProps<{ reviews: PublicReview[]; loading?: boolean }>();
const { t } = useI18n();
const initials = (name: string) => name.split(/\s+/).map(w => w[0]).join('').slice(0, 2).toUpperCase();
</script>

<template>
  <section
    id="customers"
    aria-labelledby="reviews-title"
    class="scroll-mt-20"
  >
    <h2
      id="reviews-title"
      class="text-2xl font-extrabold tracking-[-0.02em] text-ink sm:text-[1.75rem]"
    >
      {{ t('storefront.landing.reviewsTitle') }}
    </h2>
    <ul
      v-if="loading"
      class="mt-5 grid gap-3 sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3"
      aria-busy="true"
    >
      <li
        v-for="i in 3"
        :key="i"
        class="flex flex-col rounded-2xl border border-line bg-white p-4"
      >
        <UiSkeleton class="h-4 w-[5.5rem] bg-plate" />
        <div class="mt-3 text-[15px] leading-6">
          <div
            v-for="(w, j) in ['w-full', 'w-full', 'w-2/3']"
            :key="j"
            class="flex h-lh items-center"
          >
            <UiSkeleton
              class="h-[0.9em] bg-plate"
              :class="w"
            />
          </div>
        </div>
        <div class="mt-auto flex items-center gap-3 pt-4">
          <UiSkeleton class="size-10 shrink-0 rounded-full bg-plate" />
          <span class="min-w-0 flex-1">
            <span class="flex h-lh items-center text-[15px]">
              <UiSkeleton class="h-[0.9em] w-24 bg-plate" />
            </span>
            <span class="flex h-lh items-center text-sm">
              <UiSkeleton class="h-[0.9em] w-20 bg-plate" />
            </span>
          </span>
        </div>
      </li>
    </ul>
    <ul
      v-else
      class="mt-5 grid gap-3 sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3"
    >
      <li
        v-for="review in reviews.slice(0, 3)"
        :key="review.id"
        class="flex flex-col rounded-2xl border border-line bg-white p-4"
      >
        <StarRating
          :value="review.rating"
          class="h-4 w-4"
        />
        <p class="mt-3 line-clamp-4 text-[15px] leading-6 text-slate-700">
          “{{ review.text }}”
        </p>
        <div class="mt-auto flex items-center gap-3 pt-4">
          <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-plate text-sm font-bold text-slate-700">
            {{ initials(review.name || t('storefront.reviews.anonymous')) }}
          </span>
          <span class="min-w-0">
            <span class="block truncate text-[15px] font-semibold text-ink">{{ review.name || t('storefront.reviews.anonymous') }}</span>
            <span
              v-if="review.product_name"
              class="block truncate text-sm text-slate-600"
            >{{ review.product_name }}</span>
          </span>
        </div>
      </li>
    </ul>
  </section>
</template>
