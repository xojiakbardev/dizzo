<script setup lang="ts">
// The customer's cabinet (/user/*) — cart, orders, reviews, designs and
// profile — in the admin panel's shell: the sidebar ("Dizzo Profile"; on
// phones a bar of the sections' icons at the bottom), the navbar with the
// section and the page's own trail (useAdminCrumbs), and the way back to
// the Studio. It needs an account (user-area.global.ts): a session that
// runs out here goes to /login and comes back after it.
import { ApiError } from '~/composables/useApi';

const route = useRoute();
const { t } = useI18n();
const localePath = useLocalePath();
const router = useRouter();
const authState = useAuthState();
const userQuery = useCurrentUser();
const designsQuery = useMyDesigns();
const lastDesign = computed(() => designsQuery.data.value?.[0] ?? null);

// route.path without its /ru or /en prefix, for comparing with the section links.
const basePath = computed(() => route.path.replace(/^\/(ru|en)(?=\/|$)/, '') || '/');
const section = computed(() => CABINET_NAV_LINKS.find(link => isAdminLinkActive(link, basePath.value)) ?? null);
const crumbs = useAdminCrumbState();
const trail = computed(() => [
  { label: section.value?.label ?? t('storefront.cabinet.profile'), to: section.value?.to },
  ...crumbs.value,
]);
// On phones the navbar has room for one crumb: the page, with a way back
// to the crumb before it.
const current = computed(() => trail.value.at(-1)!);
const parent = computed(() => trail.value.slice(0, -1).reverse().find(c => c.to) ?? null);
const sidebarCollapsed = ref(false);
const studioOpen = ref(false);

// Signed out while here (the token couldn't be refreshed, or the account's
// own request is refused): off to /login. After a logout the live route
// has already left for /, so nothing happens then.
watch(() => userQuery.error.value, (err) => {
  if (err instanceof ApiError && err.status === 401) {
    setSignedInFlag(false);
    syncAuthState(false);
  }
});
watch(authState, (signedIn) => {
  const here = router.currentRoute.value;
  if (!signedIn && !isAuthenticated() && /^(\/(ru|en))?\/user(\/|$)/.test(here.path)) {
    void navigateTo(localePath({ path: '/login', query: { redirect: here.fullPath } }));
  }
});

// The page scrolls inside <main>, not the window: each page starts at its top.
const main = ref<HTMLElement | null>(null);
watch(() => route.path, () => main.value?.scrollTo({ top: 0 }));
</script>

<template>
  <UiTooltipProvider :delay-duration="250">
    <div class="flex h-dvh overflow-hidden bg-muted/40">
      <AdminSidebar
        :links="CABINET_NAV_LINKS"
        home="/"
        brand="Profile"
        :collapsed="sidebarCollapsed"
      />

      <div class="flex min-w-0 flex-1 flex-col">
        <header class="flex h-14 shrink-0 items-center gap-2 border-b border-border bg-card px-3 md:gap-3 md:px-4">
          <NuxtLink
            :to="localePath('/')"
            class="-ml-0.5 shrink-0 md:hidden"
            :aria-label="t('storefront.common.home')"
          >
            <img
              src="/brand/dizzo-mark-80.webp"
              width="40"
              height="40"
              alt="Dizzo"
              class="h-9 w-9 object-contain"
            >
          </NuxtLink>

          <UiButton
            variant="ghost"
            size="icon-sm"
            class="hidden cursor-pointer text-muted-foreground hover:text-foreground md:flex"
            :aria-label="t('storefront.cabinet.toggleSidebar')"
            :title="sidebarCollapsed ? t('storefront.cabinet.openSidebar') : t('storefront.cabinet.closeSidebar')"
            @click="sidebarCollapsed = !sidebarCollapsed"
          >
            <Icon
              name="lucide:panel-left"
              class="text-xl"
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
                  class="text-xl"
                />
              </NuxtLink>
            </UiButton>
            <span class="truncate text-sm font-semibold text-foreground">{{ current.label }}</span>
          </div>

          <UiButton
            class="shrink-0 max-sm:size-10 max-sm:px-0"
            :aria-label="t('storefront.cabinet.backToStudio')"
            @click="studioOpen = true"
          >
            <Icon
              name="lucide:palette"
              class="text-base"
            />
            <span class="hidden sm:inline">{{ t('storefront.cabinet.backToStudio') }}</span>
          </UiButton>
        </header>

        <main
          id="main-content"
          ref="main"
          class="flex-1 overflow-y-auto p-3 sm:p-4"
        >
          <slot v-if="authState" />
        </main>

        <!-- Phones: the sections as a bar of icons instead of the sidebar -->
        <nav
          class="grid shrink-0 grid-cols-5 border-t border-border bg-card pb-[env(safe-area-inset-bottom,0px)] md:hidden"
          :aria-label="t('storefront.cabinet.sections')"
        >
          <NuxtLink
            v-for="link in CABINET_NAV_LINKS"
            :key="link.to"
            :to="localePath(link.to)"
            :aria-label="link.label"
            :title="link.label"
            :aria-current="isAdminLinkActive(link, basePath) ? 'page' : undefined"
            class="group flex h-14 items-center justify-center outline-none"
          >
            <span
              :class="[
                'flex h-9 w-12 items-center justify-center rounded-xl transition-colors group-focus-visible:ring-3 group-focus-visible:ring-ring/50',
                isAdminLinkActive(link, basePath) ? 'bg-primary text-primary-foreground' : 'text-muted-foreground group-hover:bg-muted group-hover:text-foreground',
              ]"
            >
              <Icon
                :name="link.icon"
                class="text-xl"
              />
            </span>
          </NuxtLink>
        </nav>
      </div>
    </div>

    <!-- "Studio’ga qaytish": the last design, the products or the home page -->
    <UiDialog v-model:open="studioOpen">
      <UiDialogContent class="gap-4 sm:max-w-sm">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('storefront.cabinet.backToStudio') }}</UiDialogTitle>
          <UiDialogDescription class="sr-only">
            {{ t('storefront.cabinet.chooseWhere') }}
          </UiDialogDescription>
        </UiDialogHeader>
        <div class="grid gap-2">
          <UiButton
            v-if="lastDesign"
            as-child
            class="justify-start"
          >
            <NuxtLink
              :to="localePath(designStudioPath(lastDesign))"
              @click="studioOpen = false"
            >
              <Icon
                name="lucide:pencil"
                class="text-base"
              />
              <span class="truncate">{{ t('storefront.cabinet.continueDesign') }}</span>
            </NuxtLink>
          </UiButton>
          <UiButton
            as-child
            :variant="lastDesign ? 'outline' : 'default'"
            class="justify-start"
          >
            <NuxtLink
              :to="localePath('/catalog')"
              @click="studioOpen = false"
            >
              <Icon
                name="lucide:shirt"
                class="text-base"
              />
              {{ t('storefront.common.products') }}
            </NuxtLink>
          </UiButton>
          <UiButton
            as-child
            variant="outline"
            class="justify-start"
          >
            <NuxtLink
              :to="localePath('/')"
              @click="studioOpen = false"
            >
              <Icon
                name="lucide:house"
                class="text-base"
              />
              {{ t('storefront.common.home') }}
            </NuxtLink>
          </UiButton>
        </div>
      </UiDialogContent>
    </UiDialog>
    <!-- "Dizayn yaratish" when there are several products to choose from -->
    <ProductPicker />
  </UiTooltipProvider>
</template>
