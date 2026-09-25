<script setup lang="ts">
definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const userQuery = useCurrentUser();
const user = computed(() => userQuery.data.value ?? null);

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
</script>

<template>
  <ProfileSettings :role="roleLabel" />
</template>
