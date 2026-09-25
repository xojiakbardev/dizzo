// Dizzo's one pickup point. Checkout, the admin's order page and the landing
// all show it from here, so it reads the same everywhere. The texts follow
// the current language (read when used, not when this file loads). Code
// that runs outside a component's setup (a head tag's getter) passes its own
// `t` from useI18n().
type Translate = (key: string) => string;
export function pickupPoint(t: Translate = useNuxtApp().$i18n.t) {
  return {
    name: t('user.pickup.name'),
    address: t('user.pickup.address'),
    hours: t('user.pickup.hours'),
  };
}

export const PICKUP_POINT = {
  get name() { return pickupPoint().name; },
  get address() { return pickupPoint().address; },
  get hours() { return pickupPoint().hours; },
};
