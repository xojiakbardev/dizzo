<script setup lang="ts">
// "Profil" in the admin panel and in the customer's cabinet: the name and
// phone, and Telegram for order messages (staff: new orders; customers:
// their orders' status). `role` is the badge beside the name (admins only).
import { getApiErrorMessage } from '~/composables/useApi';
import { useCreateTelegramLinkToken, useCurrentUser, useUpdateProfile } from '~/composables/queries/useAuth';
import { useMediaUpload } from '~/composables/useMediaUpload';

const props = defineProps<{ role?: string }>();
const { t } = useI18n();

const userQuery = useCurrentUser();
const user = computed(() => userQuery.data.value ?? null);
const updateProfileMutation = useUpdateProfile();

const form = reactive({
  first_name: '',
  last_name: '',
  phone_number: '',
});

watch(user, (u) => {
  if (u) {
    form.first_name = u.first_name || '';
    form.last_name = u.last_name || '';
    form.phone_number = u.phone_number || '';
  }
}, { immediate: true });

const displayName = computed(() => {
  const parts = [user.value?.first_name, user.value?.last_name].filter(Boolean).join(' ').trim();
  return parts || t('storefront.profile.namePlaceholder');
});

const initial = computed(() => {
  const name = [user.value?.first_name, user.value?.last_name].filter(Boolean).join(' ').trim();
  if (name) return name.charAt(0).toUpperCase();
  if (user.value?.email) return user.value.email.charAt(0).toUpperCase();
  return 'A';
});

const { getImageUrl } = useMediaUrl();
const avatarUrl = computed(() => {
  const path = user.value?.avatar_url || user.value?.avatar;
  if (!path) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return getImageUrl(path);
});

const mediaUpload = useMediaUpload();
const avatarInput = ref<HTMLInputElement | null>(null);
const isUploadingAvatar = ref(false);
const avatarError = ref<string | null>(null);

function triggerAvatarUpload() {
  avatarInput.value?.click();
}

async function onAvatarChange(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  avatarError.value = null;

  if (file.size > 5 * 1024 * 1024) {
    avatarError.value = 'Rasm hajmi 5MB dan oshmasligi kerak';
    input.value = '';
    return;
  }

  isUploadingAvatar.value = true;
  try {
    const media = await mediaUpload.upload(file, 'avatar');
    await updateProfileMutation.mutateAsync({ avatar: media.url });
    profileMessage.value = { type: 'success', text: 'Profil rasmi muvaffaqiyatli yangilandi' };
  }
  catch (err) {
    avatarError.value = getApiErrorMessage(err, 'Profil rasmini yuklab bo\'lmadi');
  }
  finally {
    isUploadingAvatar.value = false;
    input.value = '';
  }
}

async function removeAvatar() {
  avatarError.value = null;
  isUploadingAvatar.value = true;
  try {
    await updateProfileMutation.mutateAsync({ avatar: '' });
    profileMessage.value = { type: 'success', text: 'Profil rasmi o\'chirildi' };
  }
  catch (err) {
    avatarError.value = getApiErrorMessage(err, 'Profil rasmini o\'chirib bo\'lmadi');
  }
  finally {
    isUploadingAvatar.value = false;
  }
}

// ── Telegram (order notifications): a one-time t.me/<bot>?start=link_<token>
// link; the bot consumes the token and links the chat to this account. The
// page polls the profile until telegram_linked(_at) changes. Re-linking moves
// the link to whichever Telegram account opens the new link.
const LINK_POLL_MS = 3000;
const LINK_WAIT_MS = 90_000;
const linkToken = useCreateTelegramLinkToken();
const linking = ref(false);
const linkError = ref<string | null>(null);
let pollTimer: ReturnType<typeof setInterval> | null = null;

function stopPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
  linking.value = false;
}
onBeforeUnmount(stopPolling);

const linkedAtLabel = computed(() => {
  const at = user.value?.telegram_linked_at;
  return at ? formatDate(at) : null;
});

async function connectTelegram() {
  linkError.value = null;
  // Opened now, inside the click, so the popup blocker lets it through.
  const tab = window.open('about:blank', '_blank');
  const before = user.value?.telegram_linked_at ?? null;
  try {
    const { deep_link } = await linkToken.mutateAsync();
    if (!deep_link) {
      tab?.close();
      linkError.value = t('storefront.profile.botMissing');
      return;
    }
    if (tab) tab.location.href = deep_link;
    else window.location.href = deep_link;
  }
  catch (err) {
    tab?.close();
    linkError.value = getApiErrorMessage(err, t('storefront.profile.linkError'));
    return;
  }
  stopPolling();
  linking.value = true;
  const startedAt = Date.now();
  pollTimer = setInterval(async () => {
    const { data } = await userQuery.refetch();
    if (data?.telegram_linked && data.telegram_linked_at !== before) {
      stopPolling();
    }
    else if (Date.now() - startedAt > LINK_WAIT_MS) {
      stopPolling();
      linkError.value = t('storefront.profile.linkTimeout');
    }
  }, LINK_POLL_MS);
}

const isUpdating = ref(false);
const profileMessage = ref<{ type: 'success' | 'error'; text: string } | null>(null);

async function handleSaveProfile() {
  profileMessage.value = null;
  isUpdating.value = true;
  try {
    await updateProfileMutation.mutateAsync({
      first_name: form.first_name,
      last_name: form.last_name,
      phone_number: form.phone_number,
    });
    profileMessage.value = { type: 'success', text: t('storefront.profile.saved') };
  }
  catch (err) {
    profileMessage.value = { type: 'error', text: getApiErrorMessage(err, t('storefront.profile.saveError')) };
  }
  finally {
    isUpdating.value = false;
  }
}
</script>

<template>
  <div class="space-y-5">
    <!-- loading: both cards in grey, at their loaded sizes -->
    <div
      v-if="userQuery.isLoading.value"
      class="space-y-5"
      aria-busy="true"
    >
      <UiCard class="gap-0 py-0">
        <div class="flex flex-wrap items-center gap-4 border-b px-4 pt-5 pb-4">
          <UiSkeleton class="size-16 shrink-0 rounded-full" />
          <div class="min-w-0 space-y-1">
            <div class="flex flex-wrap items-center gap-2">
              <div class="flex h-7 items-center">
                <UiSkeleton class="h-5 w-40" />
              </div>
              <UiSkeleton
                v-if="props.role"
                class="h-6 w-24 rounded-4xl"
              />
            </div>
            <div class="flex h-5 items-center">
              <UiSkeleton class="h-3.5 w-48" />
            </div>
          </div>
        </div>
        <div class="space-y-4 px-4 py-5">
          <div class="grid gap-4 sm:grid-cols-2">
            <div
              v-for="i in 2"
              :key="i"
              class="grid gap-1.5"
            >
              <div class="flex h-4 items-center">
                <UiSkeleton class="h-3 w-12" />
              </div>
              <UiSkeleton class="h-10 rounded-xl" />
            </div>
          </div>
          <div class="grid gap-1.5">
            <div class="flex h-4 items-center">
              <UiSkeleton class="h-3 w-24" />
            </div>
            <UiSkeleton class="h-10 rounded-xl" />
          </div>
        </div>
        <div class="flex justify-end border-t bg-muted/50 p-4">
          <UiSkeleton class="h-10 w-52 rounded-xl" />
        </div>
      </UiCard>
      <UiCard class="py-0">
        <div class="flex items-center justify-between gap-3 px-4 py-4">
          <div class="flex items-center gap-3">
            <UiSkeleton class="size-10 rounded-xl" />
            <UiSkeleton class="h-3.5 w-16" />
          </div>
          <UiSkeleton class="h-8.5 w-20 rounded-lg" />
        </div>
      </UiCard>
    </div>

    <template v-else>
      <UiCard class="gap-0 py-0">
        <UiCardHeader class="flex flex-wrap items-center gap-4 border-b py-5">
          <!-- Interactive Avatar with Camera Upload Overlay -->
          <div class="relative group">
            <input
              ref="avatarInput"
              type="file"
              accept="image/png,image/jpeg,image/webp"
              class="hidden"
              @change="onAvatarChange"
            />
            <button
              type="button"
              class="relative block size-16 rounded-full overflow-hidden focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 cursor-pointer shadow-sm"
              title="Rasmni o'zgartirish"
              :disabled="isUploadingAvatar"
              @click="triggerAvatarUpload"
            >
              <UiAvatar class="size-full">
                <UiAvatarImage
                  v-if="avatarUrl"
                  :src="avatarUrl"
                  alt=""
                  class="object-cover"
                />
                <UiAvatarFallback class="bg-primary text-xl font-bold text-primary-foreground">
                  {{ initial }}
                </UiAvatarFallback>
              </UiAvatar>

              <!-- Hover / uploading overlay -->
              <div
                class="absolute inset-0 flex items-center justify-center bg-black/40 transition-opacity"
                :class="isUploadingAvatar ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'"
              >
                <Icon
                  v-if="isUploadingAvatar"
                  name="lucide:loader-2"
                  class="size-5 animate-spin text-white"
                />
                <Icon
                  v-else
                  name="lucide:camera"
                  class="size-5 text-white drop-shadow"
                />
              </div>
            </button>

            <!-- Floating camera badge icon -->
            <button
              type="button"
              class="absolute -bottom-1 -right-1 flex size-6 items-center justify-center rounded-full border-2 border-card bg-primary text-primary-foreground shadow-sm transition hover:scale-110 active:scale-95 cursor-pointer"
              title="Rasm yuklash"
              :disabled="isUploadingAvatar"
              @click="triggerAvatarUpload"
            >
              <Icon
                name="lucide:camera"
                class="size-3"
              />
            </button>
          </div>

          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex flex-wrap items-center gap-2">
              <UiCardTitle class="text-xl font-bold">
                {{ displayName }}
              </UiCardTitle>
              <UiStatusBadge
                v-if="props.role"
                tone="brand"
              >
                {{ props.role }}
              </UiStatusBadge>
            </div>
            <UiCardDescription class="truncate">
              {{ user?.email }}
            </UiCardDescription>
            <div class="flex items-center gap-2 pt-0.5">
              <button
                type="button"
                class="text-xs text-primary hover:underline font-medium cursor-pointer"
                :disabled="isUploadingAvatar"
                @click="triggerAvatarUpload"
              >
                Rasm yuklash
              </button>
              <template v-if="avatarUrl">
                <span class="text-xs text-muted-foreground">•</span>
                <button
                  type="button"
                  class="text-xs text-destructive hover:underline font-medium cursor-pointer"
                  :disabled="isUploadingAvatar"
                  @click="removeAvatar"
                >
                  O'chirish
                </button>
              </template>
            </div>
          </div>
        </UiCardHeader>

        <div
          v-if="avatarError"
          class="px-5 pt-3"
        >
          <UiAlert variant="destructive">
            <Icon name="lucide:circle-alert" />
            {{ avatarError }}
          </UiAlert>
        </div>

        <form @submit.prevent="handleSaveProfile">
          <UiCardContent class="space-y-4 py-5">
            <UiAlert
              v-if="profileMessage"
              :variant="profileMessage.type === 'success' ? 'success' : 'destructive'"
            >
              <Icon :name="profileMessage.type === 'success' ? 'lucide:circle-check' : 'lucide:circle-alert'" />
              {{ profileMessage.text }}
            </UiAlert>

            <div class="grid gap-4 sm:grid-cols-2">
              <UiField
                :label="t('storefront.profile.firstName')"
                for="first_name"
              >
                <UiInput
                  id="first_name"
                  v-model="form.first_name"
                  :placeholder="t('storefront.profile.firstNamePlaceholder')"
                  autocomplete="given-name"
                />
              </UiField>
              <UiField
                :label="t('storefront.profile.lastName')"
                for="last_name"
              >
                <UiInput
                  id="last_name"
                  v-model="form.last_name"
                  :placeholder="t('storefront.profile.lastNamePlaceholder')"
                  autocomplete="family-name"
                />
              </UiField>
            </div>

            <UiField
              :label="t('storefront.profile.phone')"
              for="phone_number"
            >
              <UiInput
                id="phone_number"
                v-model="form.phone_number"
                type="tel"
                placeholder="+998 90 123 45 67"
                autocomplete="tel"
              />
            </UiField>
          </UiCardContent>

          <UiCardFooter class="justify-end">
            <UiButton
              type="submit"
              :disabled="isUpdating"
            >
              <Icon
                :name="isUpdating ? 'lucide:loader-2' : 'lucide:save'"
                :class="isUpdating ? 'animate-spin text-base' : 'text-base'"
              />
              {{ t('storefront.profile.save') }}
            </UiButton>
          </UiCardFooter>
        </form>
      </UiCard>

      <UiCard class="py-0">
        <UiCardContent class="flex flex-wrap items-center justify-between gap-3 py-4">
          <div class="flex min-w-0 items-center gap-3">
            <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-[#24A1DE]/10 text-[#24A1DE]">
              <svg
                class="size-5"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M12 0C5.37 0 0 5.37 0 12s5.37 12 12 12 12-5.37 12-12S18.63 0 12 0zm5.56 8.16l-1.97 9.28c-.15.67-.54.83-1.1.52l-3.02-2.23-1.46 1.4c-.16.16-.3.3-.61.3l.21-3.07 5.59-5.05c.24-.22-.05-.34-.37-.13l-6.91 4.35-2.98-.93c-.65-.2-.66-.65.14-.96l11.63-4.48c.54-.2 1.01.12.85.96z" />
              </svg>
            </span>
            <span class="text-sm font-semibold text-foreground">Telegram</span>
            <UiStatusBadge
              v-if="user?.telegram_linked"
              tone="success"
            >
              {{ t('storefront.profile.connected') }}<template v-if="linkedAtLabel">
                · {{ linkedAtLabel }}
              </template>
            </UiStatusBadge>
          </div>
          <UiButton
            :variant="user?.telegram_linked ? 'outline' : 'default'"
            size="sm"
            :disabled="linking || linkToken.isPending.value"
            @click="connectTelegram"
          >
            <Icon
              :name="linking || linkToken.isPending.value ? 'lucide:loader-2' : user?.telegram_linked ? 'lucide:refresh-cw' : 'lucide:link'"
              :class="linking || linkToken.isPending.value ? 'animate-spin text-sm' : 'text-sm'"
            />
            {{ linking ? t('storefront.profile.confirmInTelegram') : user?.telegram_linked ? t('storefront.profile.reconnect') : t('storefront.profile.connect') }}
          </UiButton>
          <UiAlert
            v-if="linkError"
            variant="destructive"
            class="basis-full"
          >
            <Icon name="lucide:circle-alert" />
            {{ linkError }}
          </UiAlert>
        </UiCardContent>
      </UiCard>
    </template>
  </div>
</template>
