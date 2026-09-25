import { localizedPath, stripLocalePrefix } from '~/lib/i18n';
// The customer's cabinet (/user/*) needs an account: a signed-out visit
// goes to /login and comes back here after it. Admins are sent on to
// /admin by admin-lockout.global.ts. The cabinet is rendered in the
// browser only (routeRules), where the session is known.
export default defineNuxtRouteMiddleware((to) => {
  if (import.meta.server || !/^\/user(\/|$)/.test(stripLocalePrefix(to.path))) return;
  if (!isAuthenticated()) return navigateTo(`${localizedPath('/login')}?redirect=${encodeURIComponent(to.fullPath)}`);
});
