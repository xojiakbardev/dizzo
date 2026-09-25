// Weak phones get the light look: no blur behind sticky bars and sheets,
// no heavy shadows, shorter animations (main.css, `html.lite`).
import { isLowEndDevice } from '~/lib/device';

export default defineNuxtPlugin(() => {
  if (isLowEndDevice()) document.documentElement.classList.add('lite');
});
