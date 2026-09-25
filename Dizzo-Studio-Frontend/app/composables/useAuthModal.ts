// Sign-in in a modal instead of a trip to /login: `requireAuth()` opens it
// and resolves true once the user is signed in (email, Google or Telegram),
// false if they close it. One modal for the whole app (<AuthModal> in
// app.vue); only the browser ever opens it.

export type AuthModalMode = 'login' | 'register';

const open = ref(false);
const mode = ref<AuthModalMode>('login');
const reason = ref('');
let settle: ((signedIn: boolean) => void) | null = null;

export function useAuthModal() {
  const authed = useAuthState();

  function requireAuth(why = ''): Promise<boolean> {
    if (authed.value) return Promise.resolve(true);
    settle?.(false);
    reason.value = why;
    mode.value = 'login';
    open.value = true;
    return new Promise((resolve) => {
      settle = resolve;
    });
  }

  function finish(signedIn: boolean) {
    open.value = false;
    const done = settle;
    settle = null;
    done?.(signedIn);
  }

  return { open, mode, reason, requireAuth, finish };
}
