<script setup lang="ts">
import { getApiErrorMessage } from '~/composables/useApi';
import { useBranches } from '~/composables/queries/useBranches';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { CurrentUser, UserRole } from '~/types/commerce';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const PER_PAGE = 20;
const ROLE_OPTIONS = computed<Array<{ value: UserRole; label: string }>>(() => [
  { value: 'customer', label: t('admin.shell.role.customer') },
  { value: 'branch_worker', label: t('admin.shell.role.branchWorker') },
  { value: 'branch_manager', label: t('admin.shell.role.branchManager') },
  { value: 'branch_admin', label: t('admin.shell.role.branchAdmin') },
  { value: 'moderator', label: t('admin.shell.role.moderator') },
  { value: 'admin', label: t('admin.shell.role.admin') },
  { value: 'super_admin', label: t('admin.shell.role.superAdmin') },
]);

const isSuperAdmin = useIsSuperAdmin();
const me = useCurrentUser();
const usersQuery = useAdminUsers();
const { data: branches } = useBranches(true);
const createUser = useCreateAdminUser();
const updateRole = useUpdateUserRole();

const users = computed(() => {
  const data = usersQuery.data.value;
  if (!data) return [];
  return Array.isArray(data) ? data : data.results;
});

const search = ref((route.query.search as string) || '');
const roleFilter = ref<string>((route.query.role as string) || 'ALL');
const branchFilter = ref<string>((route.query.branch as string) || 'ALL');
const page = ref(Number(route.query.page) || 1);

// URL query synchronization
watch([search, roleFilter, branchFilter, page], () => {
  const query: Record<string, string | undefined> = {};
  if (search.value.trim()) query.search = search.value.trim();
  if (roleFilter.value !== 'ALL') query.role = roleFilter.value;
  if (branchFilter.value !== 'ALL') query.branch = branchFilter.value;
  if (page.value > 1) query.page = String(page.value);
  router.replace({ query });
});

const filteredUsers = computed(() => {
  let list = users.value;
  if (roleFilter.value !== 'ALL') {
    list = list.filter((u: CurrentUser) => (u.role ?? 'customer') === roleFilter.value);
  }
  if (branchFilter.value !== 'ALL') {
    if (branchFilter.value === 'NONE') {
      list = list.filter((u: CurrentUser) => !u.branch_id);
    } else {
      list = list.filter((u: CurrentUser) => u.branch_id === Number(branchFilter.value));
    }
  }
  if (search.value.trim()) {
    const q = search.value.trim().toLowerCase();
    list = list.filter((u: CurrentUser) =>
      (u.full_name && u.full_name.toLowerCase().includes(q))
      || (u.first_name && u.first_name.toLowerCase().includes(q))
      || (u.last_name && u.last_name.toLowerCase().includes(q))
      || (u.email && u.email.toLowerCase().includes(q))
      || (u.phone_number && u.phone_number.includes(q)),
    );
  }
  return list;
});

const totalPages = computed(() => Math.ceil(filteredUsers.value.length / PER_PAGE) || 1);
const pageRows = computed(() => filteredUsers.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE));
watch([search, roleFilter, branchFilter], () => {
  page.value = 1;
});

interface NewUserForm {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  role: UserRole;
  branch_id: number | null;
}

const EMPTY_NEW_USER: NewUserForm = {
  email: '',
  password: '',
  first_name: '',
  last_name: '',
  role: 'admin',
  branch_id: null,
};

const showCreateModal = ref(false);
const form = reactive<NewUserForm>({ ...EMPTY_NEW_USER });
const createError = ref<string | null>(null);

function startCreate() {
  Object.assign(form, EMPTY_NEW_USER);
  createError.value = null;
  showCreateModal.value = true;
}

function handleCreate() {
  createError.value = null;
  createUser.mutate({
    ...form,
    branch_id: form.branch_id || null,
  }, {
    onSuccess: () => {
      Object.assign(form, EMPTY_NEW_USER);
      showCreateModal.value = false;
    },
    onError: (err) => {
      createError.value = getApiErrorMessage(err, t('admin.users.createFailed'));
    },
  });
}

interface EditUserForm {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  phone_number: string;
  role: UserRole;
  branch_id: number | null;
  is_active: boolean;
}

const showEditModal = ref(false);
const editError = ref<string | null>(null);
const editForm = reactive<EditUserForm>({
  id: 0,
  email: '',
  first_name: '',
  last_name: '',
  phone_number: '',
  role: 'customer',
  branch_id: null,
  is_active: true,
});

function startEdit(user: CurrentUser) {
  if (!isSuperAdmin.value) return;
  editError.value = null;
  editForm.id = user.id;
  editForm.email = user.email || '';
  editForm.first_name = user.first_name || '';
  editForm.last_name = user.last_name || '';
  editForm.phone_number = user.phone_number || user.profile?.phone_number || '';
  editForm.role = (user.role ?? 'customer') as UserRole;
  editForm.branch_id = user.branch_id ?? null;
  editForm.is_active = user.is_active !== false;
  showEditModal.value = true;
}

function handleUpdate() {
  editError.value = null;
  updateRole.mutate({
    id: editForm.id,
    payload: {
      first_name: editForm.first_name.trim(),
      last_name: editForm.last_name.trim(),
      phone_number: editForm.phone_number.trim(),
      role: editForm.role,
      branch_id: editForm.branch_id,
      is_active: editForm.is_active,
    },
  }, {
    onSuccess: () => {
      showEditModal.value = false;
    },
    onError: (err) => {
      editError.value = getApiErrorMessage(err, "Foydalanuvchini yangilashda xatolik yuz berdi");
    },
  });
}

const BRANCH_ROLES: UserRole[] = ['branch_worker', 'branch_manager', 'branch_admin'];

function isBranchRole(role: UserRole | string | undefined | null): boolean {
  return role ? BRANCH_ROLES.includes(role as UserRole) : false;
}

function getAvailableRoleOptions(branchId: number | null | undefined) {
  if (branchId) {
    return ROLE_OPTIONS.value.filter(opt => isBranchRole(opt.value));
  }
  return ROLE_OPTIONS.value.filter(opt => !isBranchRole(opt.value));
}

const createRoleOptions = computed(() => getAvailableRoleOptions(form.branch_id));
const editRoleOptions = computed(() => getAvailableRoleOptions(editForm.branch_id));

const filterRoleOptions = computed(() => {
  if (branchFilter.value === 'NONE') {
    return ROLE_OPTIONS.value.filter(opt => !isBranchRole(opt.value));
  }
  if (branchFilter.value !== 'ALL') {
    return ROLE_OPTIONS.value.filter(opt => isBranchRole(opt.value));
  }
  return ROLE_OPTIONS.value;
});

function onNewUserBranchChange(val: unknown) {
  const branchId = val === 'NONE' ? null : Number(val);
  form.branch_id = branchId;
  if (branchId && !isBranchRole(form.role)) {
    form.role = 'branch_worker';
  } else if (!branchId && isBranchRole(form.role)) {
    form.role = 'customer';
  }
}

function onEditUserBranchChange(val: unknown) {
  const branchId = val === 'NONE' ? null : Number(val);
  editForm.branch_id = branchId;
  if (branchId && !isBranchRole(editForm.role)) {
    editForm.role = 'branch_worker';
  } else if (!branchId && isBranchRole(editForm.role)) {
    editForm.role = 'customer';
  }
}

watch(branchFilter, (newVal) => {
  if (newVal === 'NONE' && isBranchRole(roleFilter.value)) {
    roleFilter.value = 'ALL';
  }
  if (newVal !== 'ALL' && newVal !== 'NONE' && roleFilter.value !== 'ALL' && !isBranchRole(roleFilter.value)) {
    roleFilter.value = 'ALL';
  }
});

const roleError = ref<string | null>(null);
function handleRoleChange(user: CurrentUser, newRole: unknown) {
  const available = getAvailableRoleOptions(user.branch_id);
  const role = available.find(r => r.value === newRole)?.value;
  if (!role || user.role === role) return;
  roleError.value = null;
  updateRole.mutate({ id: user.id, payload: { role } }, {
    onError: (err) => {
      roleError.value = getApiErrorMessage(err, t('admin.users.roleFailed'));
    },
  });
}
function setNewUserRole(value: unknown) {
  const role = createRoleOptions.value.find(r => r.value === value)?.value;
  if (role) form.role = role;
}

const nameOf = (u: CurrentUser) => u.full_name || [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email;
const initialOf = (u: CurrentUser) => (u.first_name?.[0] || u.email?.[0] || 'U').toUpperCase();
const { getImageUrl } = useMediaUrl();

const columns = computed<DataTableColumn[]>(() => [
  { key: 'name', header: t('admin.users.col.user') },
  { key: 'email', header: t('admin.users.col.email'), className: 'hidden md:table-cell' },
  { key: 'phone', header: t('admin.users.col.phone'), className: 'hidden lg:table-cell' },
  { key: 'branch', header: 'Filial', className: 'hidden sm:table-cell' },
  { key: 'role', header: t('admin.users.col.role'), width: '210px' },
  { key: 'created_at', header: 'Sana', className: 'hidden xl:table-cell' },
  { key: 'status', header: t('admin.users.col.status'), className: 'hidden sm:table-cell' },
]);
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      :placeholder="t('admin.users.searchPlaceholder')"
    >
      <UiSelect v-model="branchFilter">
        <UiSelectTrigger
          class="w-full bg-card sm:w-48"
          aria-label="Filial bo'yicha filter"
        >
          <UiSelectValue placeholder="Barcha filiallar" />
        </UiSelectTrigger>
        <UiSelectContent position="popper">
          <UiSelectItem value="ALL">
            Barcha filiallar
          </UiSelectItem>
          <UiSelectItem value="NONE">
            Filialsiz
          </UiSelectItem>
          <UiSelectItem
            v-for="b in (branches || [])"
            :key="b.id"
            :value="String(b.id)"
          >
            {{ b.name }}
          </UiSelectItem>
        </UiSelectContent>
      </UiSelect>

      <UiSelect v-model="roleFilter">
        <UiSelectTrigger
          class="w-full bg-card sm:w-48"
          :aria-label="t('admin.users.byRole')"
        >
          <UiSelectValue />
        </UiSelectTrigger>
        <UiSelectContent position="popper">
          <UiSelectItem value="ALL">
            {{ t('admin.users.allRoles') }}
          </UiSelectItem>
          <UiSelectItem
            v-for="r in filterRoleOptions"
            :key="r.value"
            :value="r.value"
          >
            {{ r.label }}
          </UiSelectItem>
        </UiSelectContent>
      </UiSelect>

      <template #actions>
        <UiButton
          :disabled="!isSuperAdmin"
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          :title="t('admin.users.add')"
          @click="startCreate"
        >
          <Icon
            name="lucide:user"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiAlert
      v-if="roleError || usersQuery.isError.value"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ roleError ?? t('admin.users.loadFailed') }}
    </UiAlert>

    <UiDataTable
      :columns="columns"
      :data="pageRows"
      :is-loading="usersQuery.isLoading.value"
      :clickable="isSuperAdmin"
      :row-key="(row: CurrentUser) => row.id"
      :empty-text="!isSuperAdmin ? t('admin.users.superOnly') : search || roleFilter !== 'ALL' || branchFilter !== 'ALL' ? t('admin.users.notFound') : t('admin.users.empty')"
      :empty-icon="!isSuperAdmin ? 'lucide:lock' : 'lucide:users'"
      @row-click="startEdit"
    >
      <template #cell-name="{ row }">
        <div class="flex min-w-0 items-center gap-3">
          <UiAvatar class="size-9">
            <UiAvatarImage
              v-if="row.avatar_url || row.avatar"
              :src="getImageUrl(row.avatar_url || row.avatar)"
              alt=""
            />
            <UiAvatarFallback class="bg-secondary text-xs font-semibold text-secondary-foreground">
              {{ initialOf(row) }}
            </UiAvatarFallback>
          </UiAvatar>
          <span class="min-w-0 truncate font-semibold text-foreground">
            {{ nameOf(row) }}
            <span
              v-if="row.id === me.data.value?.id"
              class="font-normal text-muted-foreground"
            >{{ t('admin.users.you') }}</span>
          </span>
        </div>
      </template>

      <template #cell-email="{ row }">
        <span class="text-sm text-muted-foreground">{{ row.email || '—' }}</span>
      </template>

      <template #cell-phone="{ row }">
        <span class="text-sm text-muted-foreground">
          {{ row.phone_number || row.profile?.phone_number || '—' }}
        </span>
      </template>

      <template #cell-branch="{ row }">
        <UiBadge
          v-if="row.branch_name"
          variant="outline"
          class="font-medium text-xs whitespace-nowrap"
        >
          <Icon
            name="lucide:store"
            class="mr-1 size-3 text-primary"
          />
          {{ row.branch_name }}
        </UiBadge>
        <span
          v-else
          class="text-xs text-muted-foreground"
        >—</span>
      </template>

      <template #cell-role="{ row }">
        <div @click.stop>
          <UiSelect
            :model-value="row.role ?? 'customer'"
            :disabled="updateRole.isPending.value || row.id === me.data.value?.id"
            @update:model-value="handleRoleChange(row, $event)"
          >
            <UiSelectTrigger
              size="sm"
              class="w-44 bg-card text-xs font-semibold"
              :aria-label="t('admin.users.roleOf', { name: nameOf(row) })"
            >
              <UiSelectValue />
            </UiSelectTrigger>
            <UiSelectContent position="popper">
              <UiSelectItem
                v-for="r in getAvailableRoleOptions(row.branch_id)"
                :key="r.value"
                :value="r.value"
              >
                {{ r.label }}
              </UiSelectItem>
            </UiSelectContent>
          </UiSelect>
        </div>
      </template>

      <template #cell-created_at="{ row }">
        <span class="whitespace-nowrap text-xs text-muted-foreground">
          {{ row.created_at ? formatDateTime(row.created_at) : '—' }}
        </span>
      </template>

      <template #cell-status="{ row }">
        <UiStatusBadge :tone="row.is_active !== false ? 'success' : 'neutral'">
          {{ row.is_active !== false ? t('admin.users.active') : t('admin.users.inactive') }}
        </UiStatusBadge>
      </template>
    </UiDataTable>

    <UiSimplePagination
      v-if="filteredUsers.length > 0"
      v-model:page="page"
      :total-pages="totalPages"
      :total-count="filteredUsers.length"
    />

    <UiDialog v-model:open="showCreateModal">
      <UiDialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-md">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.users.new') }}</UiDialogTitle>
        </UiDialogHeader>

        <form
          class="space-y-4"
          @submit.prevent="handleCreate"
        >
          <UiAlert
            v-if="createError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ createError }}
          </UiAlert>

          <div class="grid gap-4 sm:grid-cols-2">
            <UiField
              :label="`${t('admin.users.firstName')} *`"
              for="new-user-first-name"
            >
              <UiInput
                id="new-user-first-name"
                v-model="form.first_name"
                required
                :placeholder="t('admin.users.firstNamePlaceholder')"
              />
            </UiField>
            <UiField
              :label="t('admin.users.lastName')"
              for="new-user-last-name"
            >
              <UiInput
                id="new-user-last-name"
                v-model="form.last_name"
                :placeholder="t('admin.users.lastNamePlaceholder')"
              />
            </UiField>
          </div>

          <UiField
            :label="`${t('admin.users.col.email')} *`"
            for="new-user-email"
          >
            <UiInput
              id="new-user-email"
              v-model="form.email"
              type="email"
              required
              placeholder="admin@dizzo.uz"
            />
          </UiField>

          <UiField
            :label="`${t('admin.users.password')} *`"
            for="new-user-password"
            :hint="t('admin.users.passwordHint')"
          >
            <UiInput
              id="new-user-password"
              v-model="form.password"
              type="password"
              required
              minlength="8"
              autocomplete="new-password"
            />
          </UiField>

          <UiField
            label="Filial"
            for="new-user-branch"
          >
            <UiSelect
              :model-value="form.branch_id ? String(form.branch_id) : 'NONE'"
              @update:model-value="onNewUserBranchChange"
            >
              <UiSelectTrigger
                id="new-user-branch"
                class="w-full"
              >
                <UiSelectValue placeholder="Filialni tanlang" />
              </UiSelectTrigger>
              <UiSelectContent position="popper">
                <UiSelectItem value="NONE">
                  Filialsiz
                </UiSelectItem>
                <UiSelectItem
                  v-for="b in (branches || [])"
                  :key="b.id"
                  :value="String(b.id)"
                >
                  {{ b.name }}
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <UiField
            :label="t('admin.users.role')"
            for="new-user-role"
            :hint="form.branch_id ? t('admin.users.branchRolesOnly') : undefined"
          >
            <UiSelect
              :model-value="form.role"
              @update:model-value="setNewUserRole"
            >
              <UiSelectTrigger
                id="new-user-role"
                class="w-full"
              >
                <UiSelectValue />
              </UiSelectTrigger>
              <UiSelectContent position="popper">
                <UiSelectItem
                  v-for="opt in createRoleOptions"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <UiDialogFooter>
            <UiButton
              variant="outline"
              type="button"
              @click="showCreateModal = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="createUser.isPending.value"
            >
              <Icon
                v-if="createUser.isPending.value"
                name="lucide:loader-2"
                class="animate-spin text-base"
              />
              {{ createUser.isPending.value ? t('admin.users.creating') : t('admin.users.create') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>

    <!-- Edit User Modal -->
    <UiDialog v-model:open="showEditModal">
      <UiDialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-md">
        <UiDialogHeader>
          <UiDialogTitle>Foydalanuvchini tahrirlash</UiDialogTitle>
          <UiDialogDescription>
            {{ editForm.email || "Foydalanuvchi ma'lumotlarini o'zgartirish" }}
          </UiDialogDescription>
        </UiDialogHeader>

        <form
          class="space-y-4"
          @submit.prevent="handleUpdate"
        >
          <UiAlert
            v-if="editError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ editError }}
          </UiAlert>

          <div class="grid gap-4 sm:grid-cols-2">
            <UiField
              :label="t('admin.users.firstName')"
              for="edit-user-first-name"
            >
              <UiInput
                id="edit-user-first-name"
                v-model="editForm.first_name"
                :placeholder="t('admin.users.firstNamePlaceholder')"
              />
            </UiField>
            <UiField
              :label="t('admin.users.lastName')"
              for="edit-user-last-name"
            >
              <UiInput
                id="edit-user-last-name"
                v-model="editForm.last_name"
                :placeholder="t('admin.users.lastNamePlaceholder')"
              />
            </UiField>
          </div>

          <UiField
            :label="t('admin.users.col.email')"
            for="edit-user-email"
          >
            <UiInput
              id="edit-user-email"
              :model-value="editForm.email"
              disabled
              class="opacity-70 bg-muted/50 cursor-not-allowed"
            />
          </UiField>

          <UiField
            :label="t('admin.users.col.phone')"
            for="edit-user-phone"
          >
            <UiInput
              id="edit-user-phone"
              v-model="editForm.phone_number"
              placeholder="+998 90 123 45 67"
            />
          </UiField>

          <UiField
            label="Filial"
            for="edit-user-branch"
          >
            <UiSelect
              :model-value="editForm.branch_id ? String(editForm.branch_id) : 'NONE'"
              @update:model-value="onEditUserBranchChange"
            >
              <UiSelectTrigger
                id="edit-user-branch"
                class="w-full"
              >
                <UiSelectValue placeholder="Filialni tanlang" />
              </UiSelectTrigger>
              <UiSelectContent position="popper">
                <UiSelectItem value="NONE">
                  Filialsiz
                </UiSelectItem>
                <UiSelectItem
                  v-for="b in (branches || [])"
                  :key="b.id"
                  :value="String(b.id)"
                >
                  {{ b.name }}
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <UiField
            :label="t('admin.users.role')"
            for="edit-user-role"
            :hint="editForm.branch_id ? t('admin.users.branchRolesOnly') : undefined"
          >
            <UiSelect
              :model-value="editForm.role"
              :disabled="editForm.id === me.data.value?.id"
              @update:model-value="(val) => {
                const r = editRoleOptions.find(opt => opt.value === val)?.value;
                if (r) editForm.role = r;
              }"
            >
              <UiSelectTrigger
                id="edit-user-role"
                class="w-full"
              >
                <UiSelectValue />
              </UiSelectTrigger>
              <UiSelectContent position="popper">
                <UiSelectItem
                  v-for="opt in editRoleOptions"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </UiSelectItem>
              </UiSelectContent>
            </UiSelect>
          </UiField>

          <div class="flex items-center justify-between rounded-xl border border-border p-3 bg-muted/20">
            <div>
              <p class="text-sm font-medium text-foreground">Holat</p>
              <p class="text-xs text-muted-foreground">
                {{ editForm.is_active ? 'Foydalanuvchi faol holatda' : 'Foydalanuvchi bloklangan' }}
              </p>
            </div>
            <UiSwitch
              v-model="editForm.is_active"
              :disabled="editForm.id === me.data.value?.id"
            />
          </div>

          <UiDialogFooter>
            <UiButton
              variant="outline"
              type="button"
              @click="showEditModal = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="updateRole.isPending.value"
            >
              <Icon
                v-if="updateRole.isPending.value"
                name="lucide:loader-2"
                class="animate-spin text-base"
              />
              {{ updateRole.isPending.value ? 'Saqlanmoqda...' : 'Saqlash' }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
