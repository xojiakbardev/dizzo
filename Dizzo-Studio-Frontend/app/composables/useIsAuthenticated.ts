// The session itself lives in the backend's HttpOnly cookies
// (access_token / refresh_token, sent with `credentials: 'include'`), so
// no token is kept where page scripts can read it. What the browser keeps
// is only the non-secret "signed in" flag: the dizzo_session cookie, which
// the backend sets too (on its own host) and which is mirrored here on the
// site's host for SSR (useSignedIn) and isAuthenticated().
const SESSION_COOKIE = 'dizzo_session';
const LEGACY_SESSION_COOKIE = 'enjoy_session';
// Where older builds kept a copy of the access token; cleared on sight.
const LEGACY_TOKEN_KEY = 'enjoy_token';

export function setSignedInFlag(signedIn: boolean) {
  if (import.meta.server) return;
  try {
    localStorage.removeItem(LEGACY_TOKEN_KEY);
  }
  catch {
    // Storage blocked: nothing was kept there either.
  }
  document.cookie = signedIn
    ? `${SESSION_COOKIE}=1; path=/; max-age=2592000; SameSite=Lax`
    : `${SESSION_COOKIE}=; path=/; max-age=0; SameSite=Lax`;
  if (!signedIn) {
    document.cookie = `${LEGACY_SESSION_COOKIE}=; path=/; max-age=0; SameSite=Lax`;
  }
}

export function isAuthenticated(): boolean {
  if (import.meta.server) return false;
  return document.cookie.split('; ').some(cookie => {
    const trimmed = cookie.trim();
    return trimmed.startsWith(`${SESSION_COOKIE}=1`) || trimmed.startsWith(`${LEGACY_SESSION_COOKIE}=1`);
  });
}

const authState = ref(false);
// Whether authState holds a real value yet: false on the server and on the
// client until app.vue's onMounted runs the first syncAuthState().
const authSynced = ref(false);

export function useAuthState() {
  return authState;
}

export function syncAuthState(value?: boolean) {
  authState.value = value ?? isAuthenticated();
  if (import.meta.client) authSynced.value = true;
}

// "Probably signed in", known before any user loads and on the server too:
// the enjoy_session cookie setSignedInFlag() keeps. Until
// the first syncAuthState() it's the cookie as the request brought it, so
// the server's markup and the hydrating client agree; from then on it's
// authState, which sign-in and logout keep current. For what's shown in
// the account's spot (a skeleton instead of "Kirish" while the user loads),
// not for access — authState itself stays false on the server, so no
// signed-in query runs there without a token.
export function useSignedIn() {
  const session = useCookie('dizzo_session', { readonly: true });
  const legacySession = useCookie('enjoy_session', { readonly: true });
  return computed(() => (authSynced.value ? authState.value : Boolean(session.value || legacySession.value)));
}
