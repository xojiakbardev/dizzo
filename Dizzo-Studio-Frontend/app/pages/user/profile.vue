<script setup lang="ts">
// The customer's "Profil" in the cabinet: the same page as the admin's,
// without the role, and under it the site's language (the same switch as
// the header's: it also saves the choice to the profile), then deleting the
// account (the stores require it), behind a confirmation.
import { getApiErrorMessage } from '~/composables/useApi';

definePageMeta({ layout: 'cabinet' });

const { t } = useI18n();
const localePath = useLocalePath();
const remove = useDeleteAccount();
const confirmOpen = ref(false);
const deleteError = ref<string | null>(null);

async function deleteAccount() {
  deleteError.value = null;
  try {
    await remove.mutateAsync();
    confirmOpen.value = false;
  }
  catch (err) {
    deleteError.value = getApiErrorMessage(err, t('user.deleteAccount.failed'));
  }
}
</script>

<template>
  <div class="space-y-5">
    <ProfileSettings />
    <UiCard class="gap-0 py-0">
      <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-4">
        <div class="flex min-w-0 items-center gap-3">
          <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-muted text-muted-foreground">
            <Icon
              name="lucide:languages"
              class="text-lg"
            />
          </span>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-foreground">
              {{ t('user.profile.language') }}
            </p>
            <p class="text-xs text-muted-foreground">
              {{ t('user.profile.languageHint') }}
            </p>
          </div>
        </div>
        <LanguageSwitcher full />
      </div>
    </UiCard>

    <UiCard class="gap-0 border-destructive/30 py-0">
      <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-4">
        <div class="flex min-w-0 items-center gap-3">
          <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-destructive/10 text-destructive">
            <Icon
              name="lucide:user-x"
              class="text-lg"
            />
          </span>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-foreground">
              {{ t('user.deleteAccount.title') }}
            </p>
            <p class="text-xs text-muted-foreground">
              {{ t('user.deleteAccount.hint') }}
              <NuxtLink
                :to="localePath('/privacy') + '#delete-account'"
                class="underline hover:text-foreground"
              >{{ t('user.deleteAccount.more') }}</NuxtLink>
            </p>
          </div>
        </div>
        <UiButton
          variant="outline"
          class="border-destructive/40 text-destructive hover:bg-destructive/10 hover:text-destructive"
          @click="deleteError = null; confirmOpen = true"
        >
          <Icon name="lucide:trash-2" />
          {{ t('user.deleteAccount.button') }}
        </UiButton>
      </div>
    </UiCard>

    <UiAlertDialog v-model:open="confirmOpen">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('user.deleteAccount.confirmTitle') }}</UiAlertDialogTitle>
          <UiAlertDialogDescription class="space-y-2 text-left">
            <span class="block">{{ t('user.deleteAccount.confirmWhat') }}</span>
            <span class="block">{{ t('user.deleteAccount.confirmOrders') }}</span>
            <span class="block font-semibold text-foreground">{{ t('user.deleteAccount.confirmFinal') }}</span>
          </UiAlertDialogDescription>
        </UiAlertDialogHeader>
        <UiAlert
          v-if="deleteError"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          {{ deleteError }}
        </UiAlert>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel :disabled="remove.isPending.value">
            {{ t('user.deleteAccount.cancel') }}
          </UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="remove.isPending.value"
            @click="deleteAccount"
          >
            <Icon
              :name="remove.isPending.value ? 'lucide:loader-circle' : 'lucide:trash-2'"
              :class="{ 'animate-spin': remove.isPending.value }"
            />
            {{ t('user.deleteAccount.confirm') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
