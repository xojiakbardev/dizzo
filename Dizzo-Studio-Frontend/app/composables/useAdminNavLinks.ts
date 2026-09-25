import { i18nT, stripLocalePrefix } from '~/lib/i18n';
import { useCurrentUserRoles, useIsAdmin } from '~/composables/queries/useAuth';

// Shared between AdminSidebar and the admin layout's navbar — one source of truth for the admin nav structure.
// The customer's cabinet uses the same shell with its own links (CABINET_NAV_LINKS in cabinetNav.ts).
export interface AdminNavLink {
  to: string;
  label: string;
  icon: string;
  exact?: boolean;
  /** Other paths that belong to this section (checkout under "Savat"). */
  also?: string[];
}

export function useAdminNavLinks() {
  const isAdmin = useIsAdmin();
  const roles = useCurrentUserRoles();

  return computed<AdminNavLink[]>(() => {
    if (!isAdmin.value) return [];
    const r = roles.value;

    // 1. Branch Worker: orders, products (read-only), gallery submit, profile — no dashboard
    if (r.isBranchWorker) {
      return [
        { to: '/admin/orders', label: i18nT('common.adminNav.orders'), icon: 'lucide:clipboard-list' },
        { to: '/admin/branches/inventory', label: i18nT('common.adminNav.products'), icon: 'lucide:boxes' },
        { to: '/admin/gallery', label: i18nT('common.adminNav.gallerySubmit'), icon: 'lucide:images' },
        { to: '/admin/profile', label: i18nT('common.adminNav.profile'), icon: 'lucide:user' },
      ];
    }

    // 2. Branch Manager / Admin: orders, branch products inventory, branch workers, gallery, profile
    if (r.isBranchManager && !r.isGlobalStaff) {
      return [
        { to: '/admin', label: i18nT('common.adminNav.dashboard'), icon: 'lucide:layout-dashboard', exact: true },
        { to: '/admin/orders', label: i18nT('common.adminNav.orders'), icon: 'lucide:clipboard-list' },
        { to: '/admin/branches/inventory', label: 'Mahsulotlar mavjudligi', icon: 'lucide:boxes' },
        { to: '/admin/branches/workers', label: 'Filial xodimlari', icon: 'lucide:users-round' },
        { to: '/admin/gallery', label: i18nT('common.adminNav.gallerySubmit'), icon: 'lucide:images' },
        { to: '/admin/profile', label: i18nT('common.adminNav.profile'), icon: 'lucide:user' },
      ];
    }

    // 3. Global staff: Moderator / Admin / Super Admin
    const links: AdminNavLink[] = [
      { to: '/admin', label: i18nT('common.adminNav.dashboard'), icon: 'lucide:layout-dashboard', exact: true },
      { to: '/admin/orders', label: i18nT('common.adminNav.orders'), icon: 'lucide:clipboard-list' },
      { to: '/admin/products', label: i18nT('common.adminNav.products'), icon: 'lucide:boxes' },
      { to: '/admin/categories', label: i18nT('common.adminNav.categories'), icon: 'lucide:folder-tree' },
      { to: '/admin/gallery', label: i18nT('common.adminNav.gallery'), icon: 'lucide:images', also: ['/admin/tutorials'] },
      { to: '/admin/reviews', label: i18nT('common.adminNav.reviews'), icon: 'lucide:message-square-heart' },
    ];

    if (r.isSuperAdmin) {
      links.push({ to: '/admin/users', label: i18nT('common.adminNav.users'), icon: 'lucide:users' });
      links.push({ to: '/admin/branches', label: 'Filiallar', icon: 'lucide:store' });
      links.push({ to: '/admin/settings', label: 'Sozlamalar', icon: 'lucide:settings' });
    } else {
      links.push({ to: '/admin/branches', label: 'Filiallar', icon: 'lucide:store' });
    }

    links.push({ to: '/admin/profile', label: i18nT('common.adminNav.profile'), icon: 'lucide:user' });

    return links;
  });
}


// `path` may carry a /ru or /en prefix; the links never do.
export function isAdminLinkActive(link: AdminNavLink, path: string) {
  const bare = stripLocalePrefix(path);
  if (link.exact) return bare === link.to;
  return [link.to, ...(link.also ?? [])].some(to => bare.startsWith(to));
}
