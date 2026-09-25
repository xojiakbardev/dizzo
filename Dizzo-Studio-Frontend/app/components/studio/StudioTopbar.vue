<script setup lang="ts">
// The Studio's own top bar: back, the logo and the product; then
// undo/redo, zoom and a menu with save (signing in first if needed), share
// and the picture.
defineProps<{
  productName: string;
  areaName?: string | null; // the side being designed, when the product has several
  canUndo: boolean;
  canRedo: boolean;
  zoom: number | null; // null: nothing to zoom (the flat view)
  templateMode?: boolean; // an admin making a template: "Shablonni saqlash"
}>();
const emit = defineEmits<{
  undo: [];
  redo: [];
  zoomIn: [];
  zoomOut: [];
  zoomReset: [];
  save: [];
  saveTemplate: [];
  share: [how: 'link' | 'image' | 'native'];
}>();

const localePath = useLocalePath();
const router = useRouter();
const isAdmin = useIsAdmin();
const { data: currentUser } = useCurrentUser();
const roles = useCurrentUserRoles();
const panelHome = computed(() => localePath(adminHomePath(currentUser.value)));
const canNativeShare = ref(false);
onMounted(() => {
  canNativeShare.value = typeof navigator.share === 'function';
});
</script>

<template>
  <header class="relative z-40 flex h-14 shrink-0 items-center gap-1 bg-transparent px-2 sm:h-16 sm:gap-2 sm:px-4">
    <UiButton
      variant="outline"
      size="icon"
      :aria-label="$t('studio.topbar.back')"
      :title="$t('studio.topbar.back')"
      @click="router.go(-1)"
    >
      <Icon
        name="lucide:arrow-left"
        class="text-lg"
      />
    </UiButton>
    <!-- The same mark and size as the site's navbar. -->
    <NuxtLink
      :to="localePath('/')"
      class="ml-1 hidden shrink-0 items-center gap-1 md:flex"
      :aria-label="$t('studio.topbar.home')"
    >
      <img
        src="/brand/dizzo-mark-80.webp"
        width="40"
        height="40"
        alt="Dizzo"
        class="h-9 w-9 object-contain lg:h-10 lg:w-10"
      >
      <span class="flex items-baseline gap-1.5 font-brand text-[1.4rem] font-black tracking-tight lg:text-2xl">
        <span class="text-dizzo">Dizzo</span>
        <span class="text-slate-900">studio</span>
      </span>
    </NuxtLink>

    <h1 class="min-w-0 flex-1 truncate px-2 text-sm font-bold text-foreground sm:text-[15px] md:absolute md:left-1/2 md:w-[min(36vw,420px)] md:-translate-x-1/2 md:px-0 md:text-center">
      {{ productName }}<span
        v-if="areaName"
        class="font-semibold text-muted-foreground"
      > · {{ areaName }}</span>
    </h1>

    <div class="ml-auto flex items-center gap-0.5 sm:gap-1.5">
      <UiButton
        variant="ghost"
        size="icon-sm"
        :disabled="!canUndo"
        :aria-label="$t('studio.topbar.undo')"
        :title="`${$t('studio.topbar.undo')} (Ctrl+Z)`"
        @click="emit('undo')"
      >
        <Icon
          name="lucide:undo-2"
          class="text-lg"
        />
      </UiButton>
      <UiButton
        variant="ghost"
        size="icon-sm"
        :disabled="!canRedo"
        :aria-label="$t('studio.topbar.redo')"
        :title="`${$t('studio.topbar.redo')} (Ctrl+Y)`"
        @click="emit('redo')"
      >
        <Icon
          name="lucide:redo-2"
          class="text-lg"
        />
      </UiButton>

      <div class="mx-1 hidden h-10 items-center rounded-xl border border-border bg-background px-1 md:flex">
        <UiButton
          variant="ghost"
          size="icon-sm"
          :disabled="zoom === null"
          :aria-label="$t('studio.topbar.zoomOut')"
          :title="$t('studio.topbar.zoomOut')"
          @click="emit('zoomOut')"
        >
          <Icon name="lucide:minus" />
        </UiButton>
        <UiButton
          variant="ghost"
          size="sm"
          class="min-w-14 px-1 font-semibold tabular-nums"
          :disabled="zoom === null"
          :title="$t('studio.topbar.zoomFit')"
          @click="emit('zoomReset')"
        >
          {{ zoom ?? 100 }}%
        </UiButton>
        <UiButton
          variant="ghost"
          size="icon-sm"
          :disabled="zoom === null"
          :aria-label="$t('studio.topbar.zoomIn')"
          :title="$t('studio.topbar.zoomIn')"
          @click="emit('zoomIn')"
        >
          <Icon name="lucide:plus" />
        </UiButton>
      </div>

      <UiButton
        v-if="templateMode"
        class="font-semibold"
        @click="emit('saveTemplate')"
      >
        <Icon
          name="lucide:save"
          class="text-base"
        />
        {{ $t('studio.common.save') }}
      </UiButton>
      <UiButton
        v-if="isAdmin && !roles.isBranchWorker"
        as-child
        variant="outline"
        size="sm"
        class="hidden sm:inline-flex items-center gap-1.5 border-primary/40 bg-primary/5 font-semibold text-primary hover:bg-primary/10"
      >
        <NuxtLink :to="panelHome">
          <Icon name="lucide:layout-dashboard" class="size-4" />
          <span>Dashboard</span>
        </NuxtLink>
      </UiButton>
      <LanguageSwitcher align="end" />
      <!-- Save, share and the picture: one menu. -->
      <UiDropdownMenu>
        <UiDropdownMenuTrigger as-child>
          <UiButton
            variant="outline"
            size="icon"
            :aria-label="$t('studio.topbar.actions')"
            :title="$t('studio.topbar.actions')"
          >
            <Icon
              name="lucide:ellipsis-vertical"
              class="text-xl"
            />
          </UiButton>
        </UiDropdownMenuTrigger>
        <UiDropdownMenuContent
          align="end"
          class="w-56"
        >
          <UiDropdownMenuItem @select="emit('save')">
            <Icon name="lucide:save" />
            {{ $t('studio.common.save') }}
          </UiDropdownMenuItem>
          <UiDropdownMenuSeparator />
          <UiDropdownMenuItem
            v-if="canNativeShare"
            @select="emit('share', 'native')"
          >
            <Icon name="lucide:send" />
            {{ $t('studio.topbar.share') }}
          </UiDropdownMenuItem>
          <UiDropdownMenuItem @select="emit('share', 'link')">
            <Icon name="lucide:link" />
            {{ $t('studio.topbar.copyLink') }}
          </UiDropdownMenuItem>
          <UiDropdownMenuSeparator />
          <!-- The same five pictures as the stage's camera button. -->
          <UiDropdownMenuItem @select="emit('share', 'image')">
            <Icon name="lucide:camera" />
            {{ $t('studio.shots.title') }}
          </UiDropdownMenuItem>
        </UiDropdownMenuContent>
      </UiDropdownMenu>
    </div>
  </header>
</template>
