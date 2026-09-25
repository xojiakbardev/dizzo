// The server's HTML is complete: let the browser paint it before the app
// starts hydrating. Without this the module scripts run first and a slow
// phone shows a blank screen until they finish (measured: first paint at
// 280 ms without JavaScript, 1.2 s with it).
export default defineNuxtPlugin({
  name: 'paint-first',
  enforce: 'pre',
  async setup() {
    await new Promise<void>((resolve) => {
      requestAnimationFrame(() => setTimeout(resolve, 0));
      // A tab opened in the background has no frames: don't wait for one.
      setTimeout(resolve, 100);
    });
  },
});
