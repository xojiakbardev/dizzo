<script setup lang="ts">
// Storefront header: the mark, four ways into the shop's content, then the
// account, whose menu opens with the account itself (name, email → the
// profile) over the rest of the cabinet (cart, orders, reviews, designs)
// and the way out. On phones the links and the account move into a side
// menu so the bar keeps just the mark and the menu button.
const { data: currentUser } = useCurrentUser();
const { t } = useI18n();
const localePath = useLocalePath();
// The account's spot: the avatar once the user is here, a skeleton of its
// size while a signed-in visitor's user loads (from the cookie on the
// server, so a reload never flashes "Kirish"), else "Kirish". It stays
// client-only past that skeleton — a reload's route middleware fetches the
// user before hydration, so the client's first render can't match the
// server's user-less one.
const signedIn = useSignedIn();
const userPending = useCurrentUserPending();
const logoutMutation = useLogout();
const { getImageUrl } = useMediaUrl();
const isAdmin = useIsAdmin();
const roles = useCurrentUserRoles();
const panelHome = computed(() => localePath(adminHomePath(currentUser.value)));
const { start } = useProductPicker();

const avatarUrl = computed(() => (currentUser.value?.avatar ? getImageUrl(currentUser.value.avatar) : null));
const displayName = computed(() => currentUser.value?.first_name || currentUser.value?.full_name || '');
const fullName = computed(() => {
  const u = currentUser.value;
  return [u?.first_name, u?.last_name].filter(Boolean).join(' ') || u?.full_name || t('storefront.nav.profile');
});
// Under the name: the email, or the phone for accounts without one (Telegram).
const contactLine = computed(() => currentUser.value?.email || currentUser.value?.phone_number || '');

// The profile is the account card on top, so it isn't listed again.
const accountLinks = CABINET_NAV_LINKS.filter(link => link.to !== '/user/profile');

// `to` is a path, or a path with a #section of the home page.
const navLinks = computed(() => [
  { label: t('storefront.nav.products'), key: 'catalog', to: localePath('/catalog') },
  { label: t('storefront.nav.tutorials'), key: 'tutorials', to: localePath({ path: '/', hash: '#tutorials' }) },
  { label: t('storefront.nav.gallery'), key: 'gallery', to: localePath('/gallery') },
  { label: t('storefront.nav.faq'), key: 'faq', to: localePath({ path: '/', hash: '#faq' }) },
]);

const menuOpen = ref(false);
const route = useRoute();
watch(() => route.fullPath, () => {
  menuOpen.value = false;
});

function startDesign() {
  menuOpen.value = false;
  start();
}

function handleLogout() {
  menuOpen.value = false;
  logoutMutation.mutate();
}
</script>

<template>
  <header class="sticky top-0 z-50 border-b border-line bg-brand-bg/85 backdrop-blur-md supports-[backdrop-filter]:bg-brand-bg/75">
    <div class="mx-auto grid h-16 max-w-7xl grid-cols-[auto_1fr_auto] items-center gap-4 px-4 sm:px-6 lg:px-8">
      <NuxtLink
        :to="localePath('/')"
        class="flex items-center gap-1 rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cta"
        :aria-label="t('storefront.nav.homeAria')"
      >
        <img
          src="/brand/dizzo-mark-144.png"
          alt=""
          class="h-9 w-9 object-contain lg:h-10 lg:w-10"
        >
        <span class="font-brand text-[1.4rem] font-black tracking-tight text-dizzo lg:text-2xl">Dizzo</span>
      </NuxtLink>

      <nav
        :aria-label="t('storefront.nav.main')"
        class="hidden justify-center lg:flex"
      >
        <ul class="flex items-center xl:gap-1">
          <li
            v-for="link in navLinks"
            :key="link.key"
          >
            <NuxtLink
              :to="link.to"
              class="rounded-full px-3 py-2 text-[15px] font-semibold text-slate-700 transition hover:bg-white hover:text-ink focus-visible:outline-2 focus-visible:outline-cta xl:px-4"
            >
              {{ link.label }}
            </NuxtLink>
          </li>
        </ul>
      </nav>

      <div class="col-start-3 flex items-center gap-1.5 sm:gap-2">
        <LanguageSwitcher />

        <ClientOnly>
          <UiButton
            v-if="isAdmin && !roles.isBranchWorker"
            as-child
            variant="outline"
            size="sm"
            class="inline-flex items-center gap-1.5 border-primary/40 bg-primary/5 font-semibold text-primary hover:bg-primary/10"
          >
            <NuxtLink :to="panelHome">
              <Icon name="lucide:layout-dashboard" class="size-4" />
              <span>{{ t('common.adminNav.dashboard') }}</span>
            </NuxtLink>
          </UiButton>

          <UiDropdownMenu v-if="currentUser">
            <UiDropdownMenuTrigger as-child>
              <button
                type="button"
                class="hidden h-10 w-10 cursor-pointer items-center justify-center overflow-hidden rounded-full bg-white ring-1 ring-line transition hover:ring-slate-300 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cta md:flex"
                :aria-label="t('storefront.nav.profileMenu', { name: displayName })"
              >
                <img
                  v-if="avatarUrl"
                  :src="avatarUrl"
                  alt=""
                  class="h-full w-full object-cover"
                >
                <Icon
                  v-else
                  name="lucide:user"
                  class="h-[18px] w-[18px] text-slate-700"
                />
              </button>
            </UiDropdownMenuTrigger>
            <!-- The account (name, email → the profile), then the cabinet and the way out. -->
            <UiDropdownMenuContent
              align="end"
              class="w-64 p-1.5"
            >
              <UiDropdownMenuItem
                as-child
                class="gap-3 px-2.5 py-2"
              >
                <NuxtLink :to="localePath(isAdmin ? '/admin/profile' : '/user/profile')">
                  <span class="flex size-9 shrink-0 items-center justify-center overflow-hidden rounded-full bg-muted">
                    <img
                      v-if="avatarUrl"
                      :src="avatarUrl"
                      alt=""
                      class="h-full w-full object-cover"
                    >
                    <Icon
                      v-else
                      name="lucide:user"
                      class="text-base text-muted-foreground"
                    />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="block truncate text-sm font-semibold text-foreground">{{ fullName }}</span>
                    <span
                      v-if="contactLine"
                      class="block truncate text-xs text-muted-foreground"
                    >{{ contactLine }}</span>
                  </span>
                  <Icon
                    name="lucide:chevron-right"
                    class="text-base text-muted-foreground"
                  />
                </NuxtLink>
              </UiDropdownMenuItem>
              <UiDropdownMenuSeparator />
              <UiDropdownMenuItem
                v-if="isAdmin"
                as-child
                class="px-2.5 py-2"
              >
                <NuxtLink :to="panelHome">
                  <Icon :name="roles.isBranchWorker ? 'lucide:clipboard-list' : 'lucide:layout-dashboard'" />
                  {{ roles.isBranchWorker ? t('common.adminNav.orders') : t('storefront.nav.adminPanel') }}
                </NuxtLink>
              </UiDropdownMenuItem>
              <template v-else>
                <UiDropdownMenuItem
                  v-for="link in accountLinks"
                  :key="link.to"
                  as-child
                  class="px-2.5 py-2"
                >
                  <NuxtLink :to="localePath(link.to)">
                    <Icon :name="link.icon" />
                    {{ link.label }}
                  </NuxtLink>
                </UiDropdownMenuItem>
              </template>
              <UiDropdownMenuSeparator />
              <UiDropdownMenuItem
                variant="destructive"
                class="px-2.5 py-2"
                @select="handleLogout"
              >
                <Icon name="lucide:log-out" />
                {{ t('storefront.nav.logout') }}
              </UiDropdownMenuItem>
            </UiDropdownMenuContent>
          </UiDropdownMenu>

          <UiSkeleton
            v-else-if="userPending"
            class="hidden size-10 rounded-full md:block"
          />

          <UiButton
            v-else
            as-child
            variant="outline"
            class="hidden md:inline-flex"
          >
            <NuxtLink :to="localePath('/login')">
              {{ t('storefront.nav.signIn') }}
            </NuxtLink>
          </UiButton>

          <template #fallback>
            <UiSkeleton
              v-if="signedIn"
              class="hidden size-10 rounded-full md:block"
            />
            <UiButton
              v-else
              as-child
              variant="outline"
              class="hidden md:inline-flex"
            >
              <NuxtLink :to="localePath('/login')">
                {{ t('storefront.nav.signIn') }}
              </NuxtLink>
            </UiButton>
          </template>
        </ClientOnly>

        <UiButton
          variant="outline"
          size="icon"
          class="lg:hidden"
          :aria-label="t('storefront.nav.openMenu')"
          @click="menuOpen = true"
        >
          <Icon
            name="lucide:menu"
            class="text-xl"
          />
        </UiButton>
      </div>
    </div>

    <UiSheet v-model:open="menuOpen">
      <UiSheetContent
        side="right"
        class="w-[86%] max-w-sm gap-0 bg-brand-bg p-0"
      >
        <UiSheetHeader class="border-b border-line px-5 py-4">
          <UiSheetTitle class="flex items-center gap-1">
            <img
              src="/brand/dizzo-mark-144.png"
              alt=""
              class="h-8 w-8 object-contain"
            >
            <span class="font-brand text-xl font-black tracking-tight text-dizzo">Dizzo</span>
          </UiSheetTitle>
          <UiSheetDescription class="sr-only">
            {{ t('storefront.nav.menuDescription') }}
          </UiSheetDescription>
        </UiSheetHeader>

        <div class="flex flex-1 flex-col overflow-y-auto px-5 py-4">
          <nav :aria-label="t('storefront.nav.main')">
            <ul>
              <li
                v-for="link in navLinks"
                :key="link.key"
              >
                <NuxtLink
                  :to="link.to"
                  class="flex items-center justify-between border-b border-line py-4 text-lg font-semibold text-ink"
                  @click="menuOpen = false"
                >
                  {{ link.label }}
                  <Icon
                    name="lucide:chevron-right"
                    class="h-5 w-5 text-slate-400"
                  />
                </NuxtLink>
              </li>
            </ul>
          </nav>

          <!-- The sheet only renders once opened, on the client: no
               ClientOnly needed (it'd leave the account blank a tick). -->
          <NuxtLink
            v-if="currentUser"
            :to="localePath(isAdmin ? '/admin/profile' : '/user/profile')"
            class="mt-4 flex items-center gap-3 rounded-xl border border-line bg-white px-3 py-2.5 hover:bg-slate-50"
          >
            <span class="flex size-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-muted">
              <img
                v-if="avatarUrl"
                :src="avatarUrl"
                alt=""
                class="h-full w-full object-cover"
              >
              <Icon
                v-else
                name="lucide:user"
                class="text-lg text-muted-foreground"
              />
            </span>
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm font-semibold text-foreground">{{ fullName }}</span>
              <span
                v-if="contactLine"
                class="block truncate text-xs text-muted-foreground"
              >{{ contactLine }}</span>
            </span>
            <Icon
              name="lucide:chevron-right"
              class="text-lg text-muted-foreground"
            />
          </NuxtLink>
          <ul
            v-if="currentUser"
            class="mt-2 space-y-1 text-[15px] font-medium text-slate-700"
          >
            <li v-if="isAdmin">
              <NuxtLink
                :to="panelHome"
                class="flex items-center gap-3 rounded-xl px-2 py-3 hover:bg-white"
              >
                <Icon
                  :name="roles.isBranchWorker ? 'lucide:clipboard-list' : 'lucide:layout-dashboard'"
                  class="text-xl"
                />
                {{ roles.isBranchWorker ? t('common.adminNav.orders') : t('storefront.nav.adminPanel') }}
              </NuxtLink>
            </li>
            <template v-else>
              <li
                v-for="link in accountLinks"
                :key="link.to"
              >
                <NuxtLink
                  :to="localePath(link.to)"
                  class="flex items-center gap-3 rounded-xl px-2 py-3 hover:bg-white"
                >
                  <Icon
                    :name="link.icon"
                    class="text-xl"
                  />
                  {{ link.label }}
                </NuxtLink>
              </li>
            </template>
            <li>
              <button
                type="button"
                class="flex w-full cursor-pointer items-center gap-3 rounded-xl px-2 py-3 text-left text-rose-600 hover:bg-rose-50"
                @click="handleLogout"
              >
                <Icon
                  name="lucide:log-out"
                  class="text-xl"
                />
                {{ t('storefront.nav.logout') }}
              </button>
            </li>
          </ul>
          <div
            v-else-if="userPending"
            class="mt-4 flex items-center gap-3 rounded-xl border border-line bg-white px-3 py-2.5"
            aria-hidden="true"
          >
            <UiSkeleton class="size-10 shrink-0 rounded-full" />
            <span class="min-w-0 flex-1 space-y-1.5">
              <UiSkeleton class="h-3.5 w-32" />
              <UiSkeleton class="h-3 w-40" />
            </span>
          </div>

          <div class="mt-auto space-y-3 pt-8">
            <div class="-ml-3">
              <LanguageSwitcher
                full
                align="start"
              />
            </div>
            <UiButton
              size="lg"
              class="w-full rounded-xl"
              @click="startDesign"
            >
              {{ t('storefront.nav.startDesign') }}
              <Icon name="lucide:arrow-right" />
            </UiButton>
            <UiButton
              v-if="!currentUser && !userPending"
              as-child
              variant="outline"
              size="lg"
              class="w-full rounded-xl"
            >
              <NuxtLink :to="localePath('/login')">
                {{ t('storefront.nav.signIn') }}
              </NuxtLink>
            </UiButton>
          </div>
        </div>
      </UiSheetContent>
    </UiSheet>
  </header>
</template>
