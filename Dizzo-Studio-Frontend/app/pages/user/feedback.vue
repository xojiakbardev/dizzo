<script setup lang="ts">
// "Fikrlarim": the reviews the customer left on completed orders, with
// their stars, photos and whether they are on the site yet — as the admin's
// "Fikrlar" list. A row opens its order (the review is written there).
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { Review } from '~/composables/queries/useReviews';

definePageMeta({ layout: 'cabinet' });

const { t } = useI18n();
const localePath = useLocalePath();

const TONES = { pending: 'warn', approved: 'success', rejected: 'neutral' } as const;
const columns = computed<DataTableColumn[]>(() => [
  { key: 'product', header: t('user.common.product') },
  { key: 'rating', header: t('user.feedback.colRating'), className: 'hidden sm:table-cell' },
  { key: 'text', header: t('user.feedback.colText'), className: 'hidden md:table-cell' },
  { key: 'photos', header: t('user.feedback.colPhotos'), className: 'hidden lg:table-cell' },
  { key: 'order', header: t('user.feedback.colOrder'), className: 'hidden xl:table-cell' },
  { key: 'date', header: t('user.common.date'), className: 'hidden md:table-cell' },
  { key: 'status', header: t('user.common.status') },
]);

const reviewsQuery = useMyReviews();

function open(review: Review) {
  if (review.order_number) navigateTo(localePath(`/user/orders/${review.order_number}`));
}
</script>

<template>
  <div class="space-y-4">
    <UiAlert
      v-if="reviewsQuery.isError.value"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ t('user.feedback.loadError') }}
    </UiAlert>

    <UiDataTable
      :columns="columns"
      :data="reviewsQuery.data.value"
      :is-loading="reviewsQuery.isLoading.value"
      :row-key="(row: Review) => row.id"
      :empty-text="t('user.feedback.empty')"
      empty-icon="lucide:message-square-heart"
      clickable
      @row-click="open"
    >
      <template #empty>
        <UiButton
          as-child
          variant="outline"
        >
          <NuxtLink :to="localePath('/user/orders')">
            {{ t('user.feedback.myOrders') }}
          </NuxtLink>
        </UiButton>
      </template>

      <template #cell-product="{ row }">
        <span class="block max-w-40 truncate font-semibold text-foreground sm:max-w-56">{{ row.product_name || '—' }}</span>
      </template>

      <template #cell-rating="{ row }">
        <StarRating
          :value="row.rating"
          class="h-3.5 w-3.5"
        />
      </template>

      <template #cell-text="{ row }">
        <p
          class="max-w-xs truncate text-sm text-foreground/80 xl:max-w-sm"
          :title="row.text"
        >
          {{ row.text }}
        </p>
      </template>

      <template #cell-photos="{ row }">
        <div
          v-if="row.photos.length"
          class="flex gap-1.5"
        >
          <a
            v-for="url in row.photos.slice(0, 3)"
            :key="url"
            :href="url"
            target="_blank"
            rel="noopener"
            class="block rounded-lg outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
            @click.stop
          >
            <MediaThumb
              :src="url"
              class="size-9 rounded-lg border border-border"
            />
          </a>
          <span
            v-if="row.photos.length > 3"
            class="flex size-9 items-center justify-center rounded-lg bg-muted text-xs font-semibold text-muted-foreground"
          >+{{ row.photos.length - 3 }}</span>
        </div>
        <span
          v-else
          class="text-sm text-muted-foreground"
        >—</span>
      </template>

      <template #cell-order="{ row }">
        <span class="font-mono text-xs text-muted-foreground">{{ row.order_number ? `№${row.order_number}` : '—' }}</span>
      </template>

      <template #cell-date="{ row }">
        <span class="whitespace-nowrap text-sm text-muted-foreground">{{ formatDate(row.created_at) }}</span>
      </template>

      <template #cell-status="{ row }">
        <UiStatusBadge :tone="TONES[row.status]">
          {{ t(`user.reviewStatus.${row.status}`) }}
        </UiStatusBadge>
      </template>
    </UiDataTable>
  </div>
</template>
