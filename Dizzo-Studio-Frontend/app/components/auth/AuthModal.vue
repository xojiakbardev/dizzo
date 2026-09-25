<script setup lang="ts">
// The app's sign-in modal (see useAuthModal): the same Google/Telegram
// buttons and email forms as /login and /register, without leaving the
// page — the Studio keeps the design, the cart keeps its place.
import { DialogClose, DialogContent, DialogOverlay, DialogPortal, DialogRoot, DialogTitle } from 'reka-ui';

const { open, mode, finish } = useAuthModal();
const { t } = useI18n();

const visible = computed({
  get: () => open.value,
  set: (value: boolean) => { if (!value) finish(false); },
});
</script>

<template>
  <DialogRoot v-model:open="visible">
    <DialogPortal>
      <DialogOverlay class="fixed inset-0 z-[60] bg-slate-950/50 backdrop-blur-[1px] data-[state=open]:animate-fade-in" />
      <DialogContent
        class="fixed left-1/2 top-1/2 z-[60] max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-3xl border border-border bg-card p-6 shadow-overlay outline-none data-[state=open]:animate-scale-in sm:p-8"
      >
        <DialogClose
          class="absolute right-4 top-4 rounded-full p-1.5 text-muted-foreground transition hover:bg-muted"
          :aria-label="t('storefront.common.close')"
        >
          <Icon
            name="lucide:x"
            class="h-4 w-4"
          />
        </DialogClose>

        <div class="text-center">
          <img
            src="/brand/dizzo-mark-144.png"
            width="144"
            height="144"
            alt=""
            class="mx-auto h-11 w-11 rounded-[10px] object-contain"
          >
          <DialogTitle class="mt-3 text-xl font-extrabold tracking-tight text-slate-900">
            {{ mode === 'login' ? t('storefront.auth.modalLogin') : t('storefront.auth.register') }}
          </DialogTitle>
        </div>

        <AuthOAuthButtons class="mt-5" />

        <div class="my-5 flex items-center gap-3 text-xs font-semibold uppercase tracking-wide text-brand-muted">
          <span class="h-px flex-1 bg-brand-border/60" />
          {{ t('storefront.auth.orWithEmail') }}
          <span class="h-px flex-1 bg-brand-border/60" />
        </div>

        <AuthLoginForm
          v-if="mode === 'login'"
          @done="finish(true)"
        />
        <AuthRegisterForm
          v-else
          @done="finish(true)"
        />

        <p class="mt-5 text-center text-sm text-brand-muted">
          <template v-if="mode === 'login'">
            {{ t('storefront.auth.noAccount') }}
            <button
              type="button"
              class="font-semibold text-secondary-700 hover:text-secondary-800"
              @click="mode = 'register'"
            >
              {{ t('storefront.auth.signUpLink') }}
            </button>
          </template>
          <template v-else>
            {{ t('storefront.auth.haveAccountShort') }}
            <button
              type="button"
              class="font-semibold text-secondary-700 hover:text-secondary-800"
              @click="mode = 'login'"
            >
              {{ t('storefront.auth.signInLink') }}
            </button>
          </template>
        </p>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
