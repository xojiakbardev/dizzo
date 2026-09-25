<script setup lang="ts">
// "Dizaynlarim": the customer's saved Studio designs as cards — the
// Studio's views (the main picture and the others under it, as on an
// order), the product, type and colour, when it was last saved — to reopen
// in the Studio or delete. The skeleton mirrors the cards.
import { getApiErrorMessage } from '~/composables/useApi';
import type { DesignSummary } from '~/composables/queries/useDesigns';

definePageMeta({ layout: 'cabinet' });

const { t } = useI18n();
const localePath = useLocalePath();

const { start: startDesign } = useProductPicker();
const designsQuery = useMyDesigns();
const remove = useDeleteDesign();

const designs = computed(() => designsQuery.data.value ?? []);
const deleting = ref<DesignSummary | null>(null);
const confirmDelete = ref(false);
const error = ref<string | null>(null);

async function handleDelete() {
  if (!deleting.value) return;
  error.value = null;
  try {
    await remove.mutateAsync(deleting.value.id);
  }
  catch (e) {
    error.value = getApiErrorMessage(e, t('user.designs.deleteError'));
  }
  finally {
    confirmDelete.value = false;
  }
}
</script>

<template>
  <div>
    <!-- loading: a few cards in grey -->
    <div
      v-if="designsQuery.isLoading.value"
      class="grid gap-4 min-[480px]:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4"
      aria-busy="true"
    >
      <UiCard
        v-for="i in 4"
        :key="i"
        class="gap-0 py-0 shadow-xs"
      >
        <CommerceMockupGallery
          skeleton
          layout="stacked"
          class="p-3 pb-0"
        />
        <div class="flex flex-1 flex-col p-4 pt-3">
          <div class="flex h-lh items-center text-sm">
            <UiSkeleton class="h-3.5 w-2/3" />
          </div>
          <div class="mt-0.5 flex h-lh items-center text-xs">
            <UiSkeleton class="h-3 w-1/2" />
          </div>
          <div class="mt-auto flex gap-2 pt-3">
            <UiSkeleton class="h-8.5 flex-1 rounded-lg" />
            <UiSkeleton class="size-8.5 rounded-lg" />
          </div>
        </div>
      </UiCard>
    </div>

    <template v-else>
      <UiAlert
        v-if="error || designsQuery.isError.value"
        variant="destructive"
        class="mb-4"
      >
        <Icon name="lucide:circle-alert" />
        {{ error ?? t('user.designs.loadError') }}
      </UiAlert>

      <EmptyState
        v-if="!designsQuery.isError.value && !designs.length"
        icon="lucide:palette"
        :title="t('user.designs.empty')"
      >
        <UiButton @click="startDesign()">
          <Icon
            name="lucide:sparkles"
            class="text-base"
          />
          {{ t('user.common.startDesign') }}
        </UiButton>
      </EmptyState>

      <div
        v-else
        class="grid gap-4 min-[480px]:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4"
      >
        <UiCard
          v-for="d in designs"
          :key="d.id"
          class="gap-0 py-0 shadow-xs"
        >
          <div class="p-3 pb-0">
            <CommerceMockupGallery
              v-if="d.previews.length"
              :images="d.previews"
              :alt="`${d.product_name} · ${d.variant_name}`"
              layout="stacked"
            />
            <!-- saved before the Studio kept its views: the colour instead -->
            <NuxtLink
              v-else
              :to="localePath(designStudioPath(d))"
              class="block rounded-xl outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
              :aria-label="t('user.designs.openInStudio', { name: d.product_name })"
            >
              <MediaThumb
                :alt="d.product_name"
                class="aspect-square w-full rounded-xl bg-muted/60"
              >
                <template #fallback>
                  <span
                    class="size-1/3 rounded-2xl ring-1 ring-inset ring-black/10"
                    :style="{ background: d.color_hex }"
                  />
                </template>
              </MediaThumb>
            </NuxtLink>
          </div>
          <div class="flex flex-1 flex-col p-4 pt-3">
            <p class="truncate text-sm font-semibold text-foreground">
              {{ d.product_name }} · {{ d.variant_name }}
            </p>
            <p class="mt-0.5 flex items-center gap-1.5 truncate text-xs text-muted-foreground">
              <span
                class="size-2.5 shrink-0 rounded-full ring-1 ring-inset ring-black/15"
                :style="{ background: d.color_hex }"
              />
              <span class="truncate">{{ d.color_name }} · {{ formatDateTime(d.updated_at) }}</span>
            </p>
            <div class="mt-auto flex gap-2 pt-3">
              <UiButton
                as-child
                size="sm"
                class="flex-1"
              >
                <NuxtLink :to="localePath(designStudioPath(d))">
                  <Icon
                    name="lucide:pencil"
                    class="text-sm"
                  />
                  {{ t('user.designs.continue') }}
                </NuxtLink>
              </UiButton>
              <UiButton
                variant="ghost"
                size="icon-sm"
                class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                :aria-label="t('user.common.delete')"
                :disabled="remove.isPending.value"
                @click="deleting = d; confirmDelete = true"
              >
                <Icon
                  name="lucide:trash-2"
                  class="text-base"
                />
              </UiButton>
            </div>
          </div>
        </UiCard>
      </div>
    </template>

    <UiAlertDialog v-model:open="confirmDelete">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('user.designs.deleteTitle') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>{{ t('user.common.cancel') }}</UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="remove.isPending.value"
            @click="handleDelete"
          >
            <Icon
              v-if="remove.isPending.value"
              name="lucide:loader-2"
              class="animate-spin text-base"
            />
            {{ t('user.common.delete') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
