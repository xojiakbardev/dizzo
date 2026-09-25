<script setup lang="ts">
import { useCurrentUserRoles } from '~/composables/queries/useAuth';
import {
  useBranches,
  useBranchWorkers,
  useAssignBranchWorker,
  useRemoveBranchWorker,
} from '~/composables/queries/useBranches';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { BranchWorker } from '~/types/commerce';

definePageMeta({
  layout: 'admin',
});

const roles = useCurrentUserRoles();
const route = useRoute();
const router = useRouter();

const selectedBranchId = ref<number | null>(route.query.branch ? Number(route.query.branch) : null);

const { data: branches, isLoading: branchesLoading } = useBranches(true);

// If user is a branch manager, lock to their branch
watch(
  [roles, branches],
  ([r, bList]) => {
    if (r.branchId) {
      selectedBranchId.value = r.branchId;
    } else if (!selectedBranchId.value && bList && bList.length > 0 && bList[0]) {
      selectedBranchId.value = bList[0].id;
    }
  },
  { immediate: true },
);

const { data: workers, isLoading: workersLoading, refetch } = useBranchWorkers(selectedBranchId);
const assignMutation = useAssignBranchWorker(selectedBranchId);
const removeMutation = useRemoveBranchWorker(selectedBranchId);

const search = ref((route.query.search as string) || '');
const page = ref(Number(route.query.page) || 1);
const PER_PAGE = 20;

// URL query synchronization
watch([selectedBranchId, search, page], () => {
  const query: Record<string, string | undefined> = {};
  if (selectedBranchId.value) query.branch = String(selectedBranchId.value);
  if (search.value.trim()) query.search = search.value.trim();
  if (page.value > 1) query.page = String(page.value);
  router.replace({ query });
});

const filteredWorkers = computed(() => {
  if (!workers.value) return [];
  const q = search.value.trim().toLowerCase();
  if (!q) return workers.value;
  return workers.value.filter(
    w =>
      w.full_name.toLowerCase().includes(q) ||
      (w.phone_number && w.phone_number.toLowerCase().includes(q)) ||
      (w.email && w.email.toLowerCase().includes(q)),
  );
});

const totalPages = computed(() => Math.ceil(filteredWorkers.value.length / PER_PAGE) || 1);
const pageRows = computed(() =>
  filteredWorkers.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE),
);

watch(search, () => {
  page.value = 1;
});

const columns = computed<DataTableColumn[]>(() => [
  { key: 'full_name', header: 'Xodim F.I.SH.' },
  { key: 'role', header: 'Roli' },
  { key: 'phone_number', header: 'Telefon raqami', className: 'hidden sm:table-cell' },
  { key: 'email', header: 'Email', className: 'hidden md:table-cell' },
  { key: 'assigned_at', header: 'Biriktirilgan sana', className: 'hidden lg:table-cell' },
  { key: 'actions', header: '', className: 'text-right' },
]);

// Add worker modal state
const modalOpen = ref(false);
const assignUserId = ref<number | undefined>(undefined);
const assignRole = ref<'branch_worker' | 'branch_manager'>('branch_worker');
const assignError = ref<string | null>(null);

function openNew() {
  assignUserId.value = undefined;
  assignRole.value = 'branch_worker';
  assignError.value = null;
  modalOpen.value = true;
}

async function handleAssign() {
  if (!assignUserId.value) return;
  assignError.value = null;
  try {
    await assignMutation.mutateAsync({
      user_id: assignUserId.value,
      role: assignRole.value,
    });
    modalOpen.value = false;
    assignUserId.value = undefined;
  } catch (err: any) {
    assignError.value = err?.data?.detail || 'Xodimni biriktirishda xatolik yuz berdi';
  }
}

async function handleRemove(worker: BranchWorker) {
  if (!confirm(`Haqiqatan ham ${worker.full_name}ni filialdan bo'shatmoqchimisiz?`)) return;
  try {
    await removeMutation.mutateAsync(worker.id);
  } catch (err: any) {
    alert(err?.data?.detail || 'Xatolik yuz berdi');
  }
}

function formatDateTime(dateStr: string | null | undefined): string {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('uz-UZ', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-model:search="search"
      placeholder="Xodimlarni qidirish..."
      :refreshing="workersLoading"
      @refresh="refetch()"
    >
      <div class="flex items-center gap-2">
        <!-- Branch selector if global staff -->
        <div
          v-if="roles.isGlobalStaff && branches && branches.length > 1"
          class="flex items-center gap-1.5"
        >
          <span class="text-xs font-medium text-muted-foreground whitespace-nowrap">Filial:</span>
          <select
            v-model="selectedBranchId"
            class="h-9 rounded-xl border border-input bg-card px-2.5 py-1 text-xs shadow-xs focus:ring-2 focus:ring-primary"
          >
            <option
              v-for="b in branches"
              :key="b.id"
              :value="b.id"
            >
              {{ b.name }}
            </option>
          </select>
        </div>
      </div>

      <template #actions>
        <UiButton
          v-if="roles.isSuperAdmin || roles.isBranchManager"
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          title="Xodim biriktirish"
          @click="openNew"
        >
          <Icon
            name="lucide:user"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiDataTable
      :columns="columns"
      :data="pageRows"
      :is-loading="workersLoading || branchesLoading"
      :row-key="(row: BranchWorker) => row.id"
      empty-text="Filialda biriktirilgan xodimlar yo'q"
      empty-icon="lucide:users"
    >
      <template #cell-full_name="{ row }">
        <div class="flex items-center gap-2 whitespace-nowrap">
          <div class="flex size-7 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary font-bold text-xs">
            {{ row.full_name?.charAt(0) || 'X' }}
          </div>
          <span class="font-semibold text-foreground truncate max-w-xs">{{ row.full_name }}</span>
        </div>
      </template>

      <template #cell-role="{ row }">
        <UiBadge
          :variant="row.role === 'branch_manager' ? 'default' : 'secondary'"
          class="whitespace-nowrap font-medium text-[11px]"
        >
          {{ row.role === 'branch_manager' ? 'Menejer' : 'Ishchi' }}
        </UiBadge>
      </template>

      <template #cell-phone_number="{ row }">
        <span class="whitespace-nowrap font-mono text-xs text-muted-foreground">{{ row.phone_number || '—' }}</span>
      </template>

      <template #cell-email="{ row }">
        <span class="whitespace-nowrap text-xs text-muted-foreground">{{ row.email || '—' }}</span>
      </template>

      <template #cell-assigned_at="{ row }">
        <span class="whitespace-nowrap text-xs text-muted-foreground">{{ formatDateTime(row.assigned_at || row.created_at) }}</span>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end">
          <UiButton
            v-if="roles.isSuperAdmin || (roles.isBranchManager && row.role === 'branch_worker')"
            variant="ghost"
            size="icon-sm"
            class="hover:text-destructive"
            title="Filialdan chiqarish"
            @click="handleRemove(row)"
          >
            <Icon
              name="lucide:trash-2"
              class="size-4 text-destructive/70 hover:text-destructive"
            />
          </UiButton>
        </div>
      </template>
    </UiDataTable>

    <UiSimplePagination
      v-if="filteredWorkers.length > PER_PAGE"
      v-model:page="page"
      :total-pages="totalPages"
      :total-count="filteredWorkers.length"
    />

    <!-- Add Worker Modal -->
    <UiDialog v-model:open="modalOpen">
      <UiDialogContent class="sm:max-w-md">
        <UiDialogHeader>
          <UiDialogTitle>Filialga xodim biriktirish</UiDialogTitle>
        </UiDialogHeader>

        <form
          class="space-y-4 py-2"
          @submit.prevent="handleAssign"
        >
          <div class="space-y-1.5">
            <label
              for="worker-user-id"
              class="text-xs font-medium text-foreground"
            >Foydalanuvchi ID raqami *</label>
            <UiInput
              id="worker-user-id"
              v-model.number="assignUserId"
              type="number"
              placeholder="Masalan: 42"
              required
            />
          </div>

          <div class="space-y-1.5">
            <label
              for="worker-role"
              class="text-xs font-medium text-foreground"
            >Filialdagi roli *</label>
            <select
              id="worker-role"
              v-model="assignRole"
              class="h-9 w-full rounded-xl border border-input bg-card px-3 py-1 text-sm shadow-xs focus:ring-2 focus:ring-primary"
            >
              <option value="branch_worker">
                Ishchi (branch_worker)
              </option>
              <option
                v-if="roles.isSuperAdmin"
                value="branch_manager"
              >
                Menejer (branch_manager)
              </option>
            </select>
          </div>

          <UiAlert
            v-if="assignError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            <UiAlertDescription>{{ assignError }}</UiAlertDescription>
          </UiAlert>

          <UiDialogFooter class="gap-2 sm:gap-0 pt-2">
            <UiButton
              type="button"
              variant="outline"
              @click="modalOpen = false"
            >
              Bekor qilish
            </UiButton>
            <UiButton
              type="submit"
              :disabled="assignMutation.isPending.value"
            >
              <Icon
                v-if="assignMutation.isPending.value"
                name="lucide:loader-2"
                class="mr-2 size-4 animate-spin"
              />
              Biriktirish
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
