<script setup lang="ts">
import { useCurrentUserRoles } from '~/composables/queries/useAuth';
import { useBranches } from '~/composables/queries/useBranches';
import { useAdminOrders } from '~/composables/queries/useAdminOrders';
import OrdersKanbanBoard from '~/components/admin/orders/OrdersKanbanBoard.vue';
import type { OrderSummary } from '~/types/commerce';

// Entirely custom layout: no sidebar, no admin header, no navbar
definePageMeta({
  layout: false,
});

const { t } = useI18n();
const localePath = useLocalePath();
const roles = useCurrentUserRoles();
const { data: branches } = useBranches(true);

const search = ref('');
const selectedBranchId = ref<number | null>(null);

// Lock to user's branch if manager/worker
watch(
  [roles, branches],
  ([r, bList]) => {
    if (r.branchId) {
      selectedBranchId.value = r.branchId;
    }
  },
  { immediate: true },
);

const filters = computed(() => ({
  search: search.value || undefined,
  branch_id: selectedBranchId.value || undefined,
  page: 1,
  limit: 100,
}));

// Real-time polling every 2.5 seconds (live streaming feel)
const ordersQuery = useAdminOrders(filters, { refetchInterval: 2500 });

const results = computed<OrderSummary[]>(() => {
  const data = ordersQuery.data.value;
  if (!data) return [];
  if (Array.isArray(data.results)) return data.results;
  if (Array.isArray(data)) return data;
  return [];
});

const isNativeFullscreen = ref(false);

function toggleNativeFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen?.().then(() => {
      isNativeFullscreen.value = true;
    }).catch(() => {});
  } else {
    document.exitFullscreen?.().then(() => {
      isNativeFullscreen.value = false;
    }).catch(() => {});
  }
}

onMounted(() => {
  const handleFsChange = () => {
    isNativeFullscreen.value = Boolean(document.fullscreenElement);
  };
  document.addEventListener('fullscreenchange', handleFsChange);
  onUnmounted(() => {
    document.removeEventListener('fullscreenchange', handleFsChange);
  });
});
</script>

<template>
  <div class="flex h-screen w-screen flex-col overflow-hidden bg-muted/25 dark:bg-background text-foreground select-none">
    <!-- Clean Minimalist Topbar -->
    <header class="flex h-14 shrink-0 items-center justify-between border-b border-border/80 bg-background/95 px-4 backdrop-blur-md">
      <!-- Left side: Back, Brand, and Branch info -->
      <div class="flex items-center gap-3">
        <NuxtLink
          :to="localePath('/admin/orders')"
          class="flex items-center gap-1.5 rounded-lg border border-border/80 bg-card px-2.5 py-1.5 text-xs font-semibold text-muted-foreground transition-all hover:bg-muted hover:text-foreground shadow-2xs"
          title="Buyurtmalar ro'yxatiga qaytish"
        >
          <Icon
            name="lucide:arrow-left"
            class="size-4"
          />
          <span class="hidden sm:inline">Chiqish</span>
        </NuxtLink>

        <div class="h-4 w-px bg-border/80" />

        <div class="flex items-center gap-2">
          <div class="flex size-7 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <Icon
              name="lucide:kanban"
              class="size-4"
            />
          </div>
          <span class="text-sm font-bold tracking-tight text-foreground">
            Buyurtmalar Kanbani
          </span>
        </div>

        <!-- Branch Select for Super Admin, or Branch Badge for Worker -->
        <div
          v-if="roles.isSuperAdmin && branches && branches.length > 0"
          class="hidden md:flex items-center ml-2"
        >
          <UiSelect v-model="selectedBranchId">
            <UiSelectTrigger
              size="sm"
              class="h-8 w-44 bg-card text-xs font-medium"
            >
              <UiSelectValue placeholder="Barcha filiallar" />
            </UiSelectTrigger>
            <UiSelectContent position="popper">
              <UiSelectItem :value="null">
                Barcha filiallar
              </UiSelectItem>
              <UiSelectItem
                v-for="b in branches"
                :key="b.id"
                :value="b.id"
              >
                {{ b.name }}
              </UiSelectItem>
            </UiSelectContent>
          </UiSelect>
        </div>
        <div
          v-else-if="roles.branchName"
          class="hidden md:flex items-center ml-2"
        >
          <UiBadge
            variant="outline"
            class="gap-1 px-2.5 py-0.5 text-xs font-medium"
          >
            <Icon
              name="lucide:store"
              class="size-3 text-primary"
            />
            {{ roles.branchName }}
          </UiBadge>
        </div>
      </div>

      <!-- Center: Live streaming indicator & Search -->
      <div class="flex items-center gap-3">
        <!-- Live heartbeat indicator -->
        <div
          class="flex items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/10 px-3 py-1 text-xs font-medium text-emerald-600 dark:text-emerald-400"
          title="Streaming orqali real-time avto yangilanish faol"
        >
          <span class="relative flex size-2">
            <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
            <span class="relative inline-flex size-2 rounded-full bg-emerald-500" />
          </span>
          <span class="font-mono text-[11px] font-semibold tracking-wide uppercase">Jonli</span>
        </div>

        <!-- Quick filter search -->
        <div class="relative hidden sm:block w-48 lg:w-64">
          <Icon
            name="lucide:search"
            class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 size-3.5 text-muted-foreground"
          />
          <input
            v-model="search"
            type="text"
            placeholder="Buyurtmalarni izlash..."
            class="h-8 w-full rounded-lg border border-border/80 bg-card pl-8 pr-3 text-xs placeholder:text-muted-foreground/60 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
          >
        </div>
      </div>

      <!-- Right side: Total counter & Native Fullscreen toggle -->
      <div class="flex items-center gap-2">
        <div class="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
          <span>Jami:</span>
          <span class="font-bold text-foreground font-mono">{{ results.length }}</span>
        </div>

        <div class="h-4 w-px bg-border/80" />

        <button
          type="button"
          class="flex size-8 items-center justify-center rounded-lg border border-border/80 bg-card text-muted-foreground hover:bg-muted hover:text-foreground transition-colors shadow-2xs"
          :title="isNativeFullscreen ? 'Oddiy ko\'rinish' : 'Brauzer to\'liq ekrani'"
          @click="toggleNativeFullscreen"
        >
          <Icon
            :name="isNativeFullscreen ? 'lucide:minimize' : 'lucide:maximize'"
            class="size-4"
          />
        </button>
      </div>
    </header>

    <!-- Main Fullscreen Kanban Area -->
    <main class="flex-1 overflow-hidden p-4">
      <OrdersKanbanBoard
        :orders="results"
        :is-loading="ordersQuery.isLoading.value"
        @refresh="ordersQuery.refetch()"
      />
    </main>
  </div>
</template>
