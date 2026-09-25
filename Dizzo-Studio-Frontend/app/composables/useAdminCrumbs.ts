// The admin navbar shows the section ("Mahsulotlar") and, deeper in, the
// page's own trail ("Krujka › Shakl"): pages set that trail here instead
// of drawing their own headers. Page actions go into the navbar through
// <Teleport defer to="#admin-actions">. The customer's cabinet
// (layouts/cabinet.vue) reads the same trail.
export interface AdminCrumb {
  label: string;
  to?: string;
}

export function useAdminCrumbState() {
  return useState<AdminCrumb[]>('admin-crumbs', () => []);
}

export function useAdminCrumbs(crumbs: MaybeRefOrGetter<AdminCrumb[]>) {
  const state = useAdminCrumbState();
  let mine: AdminCrumb[] = [];
  watchEffect(() => {
    mine = toValue(crumbs);
    state.value = mine;
  });
  // The next page may have set its trail already: only clear our own (the
  // state holds a reactive copy, so compare the raw arrays).
  onBeforeUnmount(() => {
    if (toRaw(state.value) === toRaw(mine)) state.value = [];
  });
}
