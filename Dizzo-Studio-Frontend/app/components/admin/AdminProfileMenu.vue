<script setup lang="ts">
// The navbar's avatar menu, in the admin panel and the customer's cabinet
// (whose profile is /user/profile).
const props = withDefaults(defineProps<{ profileTo?: string }>(), { profileTo: '/admin/profile' });
const { t } = useI18n();
const userQuery = useCurrentUser();
const user = computed(() => userQuery.data.value ?? null);
// Until the user loads (the cabinet shows this menu from the session
// cookie alone), a skeleton the avatar's size and not a "?" avatar.
const pending = useCurrentUserPending();
const initial = computed(() => (user.value?.first_name || user.value?.full_name || user.value?.email || '?').charAt(0).toUpperCase());
const { getImageUrl } = useMediaUrl();
const avatarUrl = computed(() => (user.value?.avatar_url || user.value?.avatar ? getImageUrl(user.value?.avatar_url || user.value?.avatar) : null));

const roleLabel = computed(() => {
  if (user.value?.role === 'super_admin' || user.value?.is_super_admin) return t('admin.shell.role.superAdmin');
  if (user.value?.role === 'admin') return t('admin.shell.role.admin');
  if (user.value?.role === 'moderator') return t('admin.shell.role.moderator');
  if (user.value?.role === 'branch_admin') return t('admin.shell.role.branchAdmin');
  if (user.value?.role === 'branch_manager') return t('admin.shell.role.branchManager');
  if (user.value?.role === 'branch_worker') return t('admin.shell.role.branchWorker');
  if (!user.value?.role || user.value.role === 'customer') return t('admin.shell.role.customer');
  return t('admin.shell.role.staff');
});

const logoutMutation = useLogout();
</script>

<template>
  <div
    v-if="pending"
    class="flex size-10 shrink-0 items-center justify-center"
  >
    <UiSkeleton class="size-8 rounded-full" />
  </div>
  <UiDropdownMenu v-else>
    <UiDropdownMenuTrigger as-child>
      <UiButton
        variant="ghost"
        size="icon"
        class="shrink-0 rounded-full"
        :aria-label="t('admin.shell.profileMenu')"
      >
        <UiAvatar>
          <UiAvatarImage
            v-if="avatarUrl"
            :src="avatarUrl"
            alt=""
          />
          <UiAvatarFallback class="bg-primary text-xs font-semibold text-primary-foreground">
            {{ initial }}
          </UiAvatarFallback>
        </UiAvatar>
      </UiButton>
    </UiDropdownMenuTrigger>
    <UiDropdownMenuContent
      align="end"
      class="w-56"
    >
      <UiDropdownMenuLabel class="font-normal">
        <p class="truncate text-sm font-semibold text-foreground">
          {{ user?.full_name || user?.email }}
        </p>
        <p class="truncate text-xs text-muted-foreground">
          {{ roleLabel }}
        </p>
      </UiDropdownMenuLabel>
      <UiDropdownMenuSeparator />
      <UiDropdownMenuItem as-child>
        <NuxtLinkLocale :to="props.profileTo">
          <Icon name="lucide:user" />
          {{ t('admin.shell.profile') }}
        </NuxtLinkLocale>
      </UiDropdownMenuItem>
      <UiDropdownMenuItem
        variant="destructive"
        @select="logoutMutation.mutate()"
      >
        <Icon name="lucide:log-out" />
        {{ t('admin.shell.logout') }}
      </UiDropdownMenuItem>
    </UiDropdownMenuContent>
  </UiDropdownMenu>
</template>
