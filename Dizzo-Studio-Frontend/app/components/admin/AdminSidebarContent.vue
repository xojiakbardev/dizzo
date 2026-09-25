<script setup lang="ts">
import type { AdminNavLink } from '~/composables/useAdminNavLinks';

// Also the customer's cabinet: `home` and `brand` make the logo ("Dizzo
// admin" / "Dizzo Profile"); a signed-out visitor (`guest`) gets "Kirish"
// where "Chiqish" is.
defineProps<{
  links: AdminNavLink[];
  path: string;
  home: string;
  brand: string;
  collapsed?: boolean;
  guest?: boolean;
}>();

defineEmits<{
  logout: [];
  login: [];
}>();
</script>

<template>
  <div class="flex h-full w-full flex-col justify-between select-none overflow-hidden">
    <div class="min-w-0">
      <!-- Header -->
      <div
        class="flex h-14 shrink-0 items-center border-b border-border transition-all overflow-hidden"
        :class="collapsed ? 'justify-center px-2' : 'px-4'"
      >
        <NuxtLinkLocale
          :to="home"
          class="flex items-center gap-1.5 overflow-hidden whitespace-nowrap"
          :title="collapsed ? `Dizzo ${brand}` : undefined"
        >
          <!-- The same mark and size as the site's navbar and the Studio. -->
          <img
            src="/brand/dizzo-mark-80.webp"
            width="40"
            height="40"
            alt="Dizzo"
            class="h-9 w-9 shrink-0 object-contain lg:h-10 lg:w-10"
          >
          <span
            class="flex items-baseline gap-1.5 whitespace-nowrap font-brand text-[1.4rem] font-black tracking-tight lg:text-2xl transition-opacity duration-200"
            :class="collapsed ? 'opacity-0 w-0 pointer-events-none' : 'opacity-100'"
          >
            <span class="text-dizzo">Dizzo</span>
            <span class="text-slate-900">{{ brand }}</span>
          </span>
        </NuxtLinkLocale>
      </div>

      <!-- Navigation Links -->
      <nav
        class="space-y-1.5 overflow-y-auto overflow-x-hidden"
        :class="collapsed ? 'p-2' : 'p-3'"
      >
        <NuxtLinkLocale
          v-for="link in links"
          :key="link.to"
          :to="link.to"
          :title="collapsed ? link.label : undefined"
          :class="[
            'flex items-center transition-all duration-150 rounded-xl font-medium select-none overflow-hidden whitespace-nowrap',
            collapsed
              ? 'h-11 w-11 justify-center mx-auto'
              : 'h-11 w-full px-3.5 gap-3 text-[15px]',
            isAdminLinkActive(link, path)
              ? 'bg-primary text-white hover:bg-primary/90 hover:text-white shadow-xs'
              : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100',
          ]"
        >
          <Icon
            :name="link.icon"
            class="h-5 w-5 shrink-0"
          />
          <span
            class="whitespace-nowrap truncate min-w-0 transition-opacity duration-200"
            :class="collapsed ? 'opacity-0 w-0 pointer-events-none' : 'opacity-100 flex-1'"
          >
            {{ link.label }}
          </span>
        </NuxtLinkLocale>
      </nav>
    </div>

    <!-- Footer Logout -->
    <div class="border-t border-border p-3 overflow-hidden">
      <button
        type="button"
        :class="[
          'flex items-center transition-all duration-150 rounded-xl font-medium select-none overflow-hidden whitespace-nowrap',
          guest ? 'text-primary hover:bg-primary/10' : 'text-destructive hover:bg-destructive/10',
          collapsed
            ? 'h-11 w-11 justify-center mx-auto'
            : 'h-11 w-full justify-center px-3.5 gap-3 text-[15px]',
        ]"
        :title="collapsed ? $t(guest ? 'admin.shell.login' : 'admin.shell.logout') : undefined"
        @click="guest ? $emit('login') : $emit('logout')"
      >
        <Icon
          :name="guest ? 'lucide:log-in' : 'lucide:log-out'"
          class="h-5 w-5 shrink-0"
        />
        <span
          class="whitespace-nowrap truncate min-w-0 transition-opacity duration-200"
          :class="collapsed ? 'opacity-0 w-0 pointer-events-none' : 'opacity-100'"
        >
          {{ $t(guest ? 'admin.shell.login' : 'admin.shell.logout') }}
        </span>
      </button>
    </div>
  </div>
</template>
