<script setup lang="ts">
import type { AdminNavLink } from '~/composables/useAdminNavLinks';

// The admin panel's sidebar, and the customer cabinet's (other links and logo).
const props = withDefaults(defineProps<{
  links: AdminNavLink[];
  home: string;
  brand: string;
  collapsed?: boolean;
  guest?: boolean;
}>(), {
  collapsed: false,
  guest: false,
});
const emit = defineEmits<{ login: [] }>();
const open = defineModel<boolean>('open', { default: false });
const route = useRoute();
const logoutMutation = useLogout();

watch(() => route.path, () => {
  open.value = false;
});

function login() {
  open.value = false;
  emit('login');
}
</script>

<template>
  <aside
    :class="[
      'hidden h-screen shrink-0 border-r border-border bg-card transition-[width] duration-300 ease-in-out md:flex overflow-hidden',
      props.collapsed ? 'w-16' : 'w-64',
    ]"
  >
    <AdminSidebarContent
      :links="props.links"
      :path="route.path"
      :home="props.home"
      :brand="props.brand"
      :collapsed="props.collapsed"
      :guest="props.guest"
      @logout="logoutMutation.mutate()"
      @login="login"
    />
  </aside>

  <UiSheet v-model:open="open">
    <UiSheetContent
      side="left"
      class="p-0 w-64"
    >
      <UiSheetHeader class="sr-only">
        <UiSheetTitle>{{ $t('admin.shell.menu') }}</UiSheetTitle>
      </UiSheetHeader>
      <AdminSidebarContent
        :links="props.links"
        :path="route.path"
        :home="props.home"
        :brand="props.brand"
        :collapsed="false"
        :guest="props.guest"
        @logout="logoutMutation.mutate()"
        @login="login"
      />
    </UiSheetContent>
  </UiSheet>
</template>
