import type { AdminNavLink } from '~/composables/useAdminNavLinks';
import { i18nT } from '~/lib/i18n';

// The customer's cabinet (layouts/cabinet.vue): the admin panel's shell with
// the customer's own sections.
// `label` is a getter, read in the page's current language.
export const CABINET_NAV_LINKS: AdminNavLink[] = [
  { to: '/user/cart', get label() { return i18nT('common.cabinetNav.cart'); }, icon: 'lucide:shopping-cart', also: ['/user/checkout'] },
  { to: '/user/orders', get label() { return i18nT('common.cabinetNav.orders'); }, icon: 'lucide:package' },
  { to: '/user/feedback', get label() { return i18nT('common.cabinetNav.feedback'); }, icon: 'lucide:message-square-heart' },
  { to: '/user/designs', get label() { return i18nT('common.cabinetNav.designs'); }, icon: 'lucide:palette' },
  { to: '/user/profile', get label() { return i18nT('common.cabinetNav.profile'); }, icon: 'lucide:user' },
];
