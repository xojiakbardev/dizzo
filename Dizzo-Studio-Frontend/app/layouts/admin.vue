<script setup lang="ts">
import { stripLocalePrefix } from '~/lib/i18n';

import { ApiError } from '~/composables/useApi';

// Single login flow for the whole app — no separate admin-only login form.
// A logged-out visit to /admin just bounces to the regular /login page
// (redirect=back-to-here); once authenticated, the global admin-lockout
// middleware takes over and keeps admin/staff accounts confined here.
const route = useRoute();
const { t } = useI18n();
const localePath = useLocalePath();
const { data: currentUser, isLoading, isError, error } = useCurrentUser();
const isAdmin = useIsAdmin();
const roles = useCurrentUserRoles();
const authState = useAuthState();

// The navbar shows the active section's own label (from the same source
// as the sidebar links) instead of a static "Admin panel" placeholder.
const links = useAdminNavLinks();
const section = computed(() => links.value.find(link => isAdminLinkActive(link, route.path)) ?? null);
const crumbs = useAdminCrumbState();
// Crumb links in the page's language (a page may pass one localized already).
const trail = computed(() => [
  { label: section.value?.label ?? t('admin.shell.panel'), to: section.value?.to },
  ...crumbs.value,
].map(c => ({ ...c, to: c.to ? localePath(stripLocalePrefix(c.to)) : undefined })));
// On phones the navbar has room for one crumb: the page, with a way back
// to the crumb before it.
const current = computed(() => trail.value.at(-1)!);
const parent = computed(() => trail.value.slice(0, -1).reverse().find(c => c.to) ?? null);
const menuOpen = ref(false);
const sidebarCollapsed = ref(false);

watch([isLoading, isAdmin, currentUser], ([loading, admin, user]) => {
  if (!loading && user && !admin) {
    navigateTo(localePath('/'));
  }
}, { immediate: true });

onMounted(() => {
  if (!isAuthenticated()) {
    navigateTo(localePath(`/login?redirect=${encodeURIComponent(route.fullPath)}`));
  }
});

// Signed out or session expired while here: off to /login immediately
// instead of getting stuck on a permanent loader spinner.
const router = useRouter();
watch(authState, (signedIn) => {
  const here = router.currentRoute.value;
  if (!signedIn && stripLocalePrefix(here.path).startsWith('/admin')) {
    navigateTo(localePath(`/login?redirect=${encodeURIComponent(here.fullPath)}`));
  }
});

watch(isError, (errored) => {
  if (errored) {
    const err = error.value;
    if (err instanceof ApiError && err.status === 401) {
      setSignedInFlag(false);
      syncAuthState(false);
      const here = router.currentRoute.value;
      if (stripLocalePrefix(here.path).startsWith('/admin')) {
        navigateTo(localePath(`/login?redirect=${encodeURIComponent(here.fullPath)}`));
      }
    }
  }
});
</script>

<template>
  <ClientOnly>
    <div
      v-if="!authState || (isLoading && !currentUser)"
      class="flex min-h-screen items-center justify-center bg-brand-surface-low"
    >
      <BrandLoader />
    </div>

    <div
      v-else-if="!isAdmin && !currentUser"
      class="flex min-h-screen items-center justify-center bg-brand-surface-low"
    >
      <BrandLoader />
    </div>

    <UiTooltipProvider
      v-else
      :delay-duration="250"
    >
      <div class="flex h-screen overflow-hidden bg-muted/40">
        <AdminSidebar
          v-model:open="menuOpen"
          :links="links"
          :home="roles.isBranchWorker ? '/admin/orders' : '/admin'"
          brand="admin"
          :collapsed="sidebarCollapsed"
        />

        <div class="flex min-w-0 flex-1 flex-col">
          <header class="flex h-14 shrink-0 items-center gap-2 border-b border-border bg-card px-3 md:gap-3 md:px-4">
            <!-- Mobile Menu Toggle -->
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="md:hidden"
              :aria-label="t('admin.shell.menu')"
              @click="menuOpen = true"
            >
              <Icon
                name="lucide:menu"
                class="h-5 w-5"
              />
            </UiButton>

            <!-- Desktop Sidebar Collapse Toggle -->
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="hidden md:flex text-muted-foreground hover:text-foreground cursor-pointer"
              :aria-label="t('admin.shell.toggleSidebar')"
              :title="t(sidebarCollapsed ? 'admin.shell.openSidebar' : 'admin.shell.closeSidebar')"
              @click="sidebarCollapsed = !sidebarCollapsed"
            >
              <Icon
                name="lucide:panel-left"
                class="h-5 w-5"
              />
            </UiButton>

            <UiBreadcrumb
              :items="trail"
              class="hidden min-w-0 flex-1 sm:block"
            />
            <div class="flex min-w-0 flex-1 items-center gap-1 sm:hidden">
              <UiButton
                v-if="parent?.to"
                as-child
                variant="ghost"
                size="icon-sm"
                class="-ml-1 shrink-0"
              >
                <NuxtLink
                  :to="parent.to"
                  :aria-label="parent.label"
                >
                  <Icon
                    name="lucide:chevron-left"
                    class="h-5 w-5"
                  />
                </NuxtLink>
              </UiButton>
              <span class="truncate text-sm font-semibold text-foreground">{{ current.label }}</span>
            </div>
            <div
              id="admin-actions"
              class="flex shrink-0 items-center gap-2"
            />
            <LanguageSwitcher />
          </header>

          <main class="flex-1 overflow-y-auto p-3 sm:p-4">
            <slot />
          </main>
        </div>
      </div>
    </UiTooltipProvider>

    <template #fallback>
      <div class="flex min-h-screen items-center justify-center bg-brand-surface-low">
        <BrandLoader />
      </div>
    </template>
  </ClientOnly>
</template>
