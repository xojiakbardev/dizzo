<script setup lang="ts">
import { getApiErrorMessage } from '~/composables/useApi';
import { adminHomePath, useCurrentUser, useCurrentUserRoles } from '~/composables/queries/useAuth';
import { useSaveSystemSetting, useSystemSettings } from '~/composables/queries/useSystemSettings';

definePageMeta({ layout: 'admin' });

const TELEGRAM_GROUP_KEY = 'telegram_moderator_group_id';

const { t } = useI18n();
const roles = useCurrentUserRoles();
const { data: me } = useCurrentUser();
const router = useRouter();
const localePath = useLocalePath();

useHead({ title: () => t('admin.settings.title') });

watchEffect(() => {
  if (roles.value && !roles.value.isSuperAdmin && roles.value.role !== 'customer') {
    void router.replace(localePath(adminHomePath(me.value)));
  }
});

const { data: settings, isLoading, isError, refetch } = useSystemSettings();
const saveMutation = useSaveSystemSetting();

const groupId = ref('');
const hydrated = ref(false);
const formError = ref<string | null>(null);
const justSaved = ref(false);

watch(settings, (rows) => {
  if (hydrated.value || !rows) return;
  groupId.value = rows.find(s => s.key === TELEGRAM_GROUP_KEY)?.value ?? '';
  hydrated.value = true;
}, { immediate: true });

const storedValue = computed(() => settings.value?.find(s => s.key === TELEGRAM_GROUP_KEY)?.value ?? '');
const dirty = computed(() => groupId.value.trim() !== storedValue.value);

async function save() {
  formError.value = null;
  justSaved.value = false;
  try {
    await saveMutation.mutateAsync({
      key: TELEGRAM_GROUP_KEY,
      value: groupId.value.trim(),
      description: t('admin.settings.telegram.groupIdShort'),
    });
    groupId.value = groupId.value.trim();
    justSaved.value = true;
  } catch (err) {
    formError.value = getApiErrorMessage(err, t('admin.settings.saveFailed'));
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl space-y-4">
    <div>
      <h1 class="text-xl font-bold tracking-tight text-foreground">
        {{ t('admin.settings.title') }}
      </h1>
      <p class="mt-1 text-sm text-muted-foreground">
        {{ t('admin.settings.subtitle') }}
      </p>
    </div>

    <EmptyState
      v-if="isError && !settings"
      :title="t('admin.settings.loadFailed')"
      icon="lucide:circle-alert"
      tone="destructive"
    >
      <UiButton
        variant="outline"
        size="sm"
        @click="refetch()"
      >
        {{ t('admin.common.retry') }}
      </UiButton>
    </EmptyState>

    <UiCard
      v-else
      class="gap-0 py-0"
    >
      <UiCardHeader class="border-b py-5">
        <div class="flex items-start gap-3">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <Icon
              name="lucide:send"
              class="size-5"
            />
          </div>
          <div class="min-w-0">
            <UiCardTitle class="text-base">
              {{ t('admin.settings.telegram.title') }}
            </UiCardTitle>
            <UiCardDescription class="mt-0.5">
              {{ t('admin.settings.telegram.description') }}
            </UiCardDescription>
          </div>
        </div>
      </UiCardHeader>

      <form
        class="space-y-4 p-5"
        @submit.prevent="save"
      >
        <div
          v-if="isLoading && !hydrated"
          class="space-y-2"
        >
          <UiSkeleton class="h-4 w-40" />
          <UiSkeleton class="h-10 rounded-xl" />
          <UiSkeleton class="h-10 w-full" />
        </div>

        <div
          v-else
          class="space-y-1.5"
        >
          <label
            for="telegram-group-id"
            class="text-sm font-medium text-foreground"
          >{{ t('admin.settings.telegram.groupId') }}</label>
          <UiInput
            id="telegram-group-id"
            v-model="groupId"
            inputmode="numeric"
            autocomplete="off"
            :placeholder="t('admin.settings.telegram.groupIdPlaceholder')"
          />
          <p class="text-xs leading-relaxed text-muted-foreground">
            {{ t('admin.settings.telegram.groupIdHint') }}
          </p>
        </div>

        <UiAlert
          v-if="formError"
          variant="destructive"
        >
          <Icon name="lucide:circle-alert" />
          <UiAlertDescription>{{ formError }}</UiAlertDescription>
        </UiAlert>

        <div class="flex justify-end pt-1">
          <UiButton
            type="submit"
            :disabled="saveMutation.isPending.value || !dirty"
          >
            <Icon
              v-if="saveMutation.isPending.value"
              name="lucide:loader-2"
              class="mr-2 size-4 animate-spin"
            />
            {{ justSaved && !dirty ? t('admin.common.saved') : t('admin.common.save') }}
          </UiButton>
        </div>
      </form>
    </UiCard>
  </div>
</template>
