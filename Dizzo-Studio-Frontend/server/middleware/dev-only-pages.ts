// The engine's test harness exists only in development (nuxt.config.ts drops
// the page from production builds); /embed/** is a client-only shell, so
// without this its old address would still answer 200.
export default defineEventHandler((event) => {
  if (import.meta.dev) return;
  if (/^\/embed\/harness\/?(?:\?|$)/.test(event.path)) {
    throw createError({ statusCode: 404, statusMessage: 'Page not found' });
  }
});
