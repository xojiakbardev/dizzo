<script setup lang="ts">
import { useCurrentUserRoles } from '~/composables/queries/useAuth';
import { useBranches } from '~/composables/queries/useBranches';
import type { DataTableColumn } from '~/components/ui/DataTable.vue';
import type { Branch } from '~/types/commerce';
import { useQueryClient } from '@tanstack/vue-query';

definePageMeta({
  layout: 'admin',
});

const { t } = useI18n();
const localePath = useLocalePath();
const roles = useCurrentUserRoles();
const api = useApi();
const queryClient = useQueryClient();
const route = useRoute();
const router = useRouter();

const { data: branches, isLoading, refetch } = useBranches(true);

const search = ref((route.query.search as string) || '');
const statusFilter = ref<'all' | 'active' | 'inactive'>((route.query.status as any) || 'all');
const page = ref(Number(route.query.page) || 1);
const PER_PAGE = 20;

// Sync to URL params
watch([search, statusFilter, page], () => {
  const query: Record<string, string | undefined> = {};
  if (search.value.trim()) query.search = search.value.trim();
  if (statusFilter.value !== 'all') query.status = statusFilter.value;
  if (page.value > 1) query.page = String(page.value);
  router.replace({ query });
});

const FILTERS = [
  { value: 'all', label: 'Barchasi' },
  { value: 'active', label: 'Faol' },
  { value: 'inactive', label: 'Nofaol' },
] as const;

const filteredBranches = computed(() => {
  if (!branches.value) return [];
  let list = branches.value;

  if (statusFilter.value === 'active') {
    list = list.filter(b => b.is_active);
  } else if (statusFilter.value === 'inactive') {
    list = list.filter(b => !b.is_active);
  }

  const q = search.value.trim().toLowerCase();
  if (!q) return list;

  return list.filter(
    b =>
      b.name.toLowerCase().includes(q) ||
      b.city.toLowerCase().includes(q) ||
      b.address.toLowerCase().includes(q) ||
      (b.phone && b.phone.toLowerCase().includes(q)),
  );
});

const totalPages = computed(() => Math.ceil(filteredBranches.value.length / PER_PAGE) || 1);
const pageRows = computed(() =>
  filteredBranches.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE),
);

watch([search, statusFilter], () => {
  page.value = 1;
});

const columns = computed<DataTableColumn[]>(() => [
  { key: 'name', header: 'Filial nomi' },
  { key: 'branch_type', header: 'Turi' },
  { key: 'city', header: 'Shahar' },
  { key: 'address', header: 'Manzil' },
  { key: 'capacity_days', header: 'Yuklama / Muddat', className: 'hidden md:table-cell' },
  { key: 'phone', header: 'Telefon', className: 'hidden lg:table-cell' },
  { key: 'is_active', header: 'Holati' },
  { key: 'actions', header: '', className: 'text-right' },
]);

// ── Form Modal State ──
const isDialogOpen = ref(false);
const editingBranch = ref<Branch | null>(null);
const isSubmitting = ref(false);
const formError = ref<string | null>(null);

const form = reactive({
  name: '',
  slug: '',
  city: 'Toshkent',
  address: '',
  phone: '',
  work_hours: '09:00 - 20:00',
  latitude: 41.311081,
  longitude: 69.240562,
  is_active: true,
  notes: '',
  branch_type: 'DIZZO' as 'DIZZO' | 'BTS',
  daily_order_capacity: 50,
  delivery_days: 3,
  base_shipping_cost: 25000,
});

const DRAFT_KEY = 'dizzo:admin:branch-draft';
const pendingEditId = ref<number | null>(null);

function clearDraft() {
  if (import.meta.client) sessionStorage.removeItem(DRAFT_KEY);
}

function saveDraft() {
  if (!import.meta.client) return;
  sessionStorage.setItem(DRAFT_KEY, JSON.stringify({
    ...toRaw(form),
    editingId: editingBranch.value?.id ?? pendingEditId.value,
  }));
}

function applyDraft(draft: Record<string, unknown>) {
  form.name = String(draft.name ?? '');
  form.slug = String(draft.slug ?? '');
  form.city = String(draft.city ?? 'Toshkent');
  form.address = String(draft.address ?? '');
  form.phone = String(draft.phone ?? '');
  form.work_hours = String(draft.work_hours ?? '09:00 - 20:00');
  form.latitude = Number(draft.latitude) || 41.311081;
  form.longitude = Number(draft.longitude) || 69.240562;
  form.is_active = draft.is_active !== false;
  form.notes = String(draft.notes ?? '');
  form.branch_type = (draft.branch_type as any) === 'BTS' ? 'BTS' : 'DIZZO';
  form.daily_order_capacity = Number(draft.daily_order_capacity) || 50;
  form.delivery_days = Number(draft.delivery_days) || 3;
  form.base_shipping_cost = Number(draft.base_shipping_cost) || 25000;
  pendingEditId.value = typeof draft.editingId === 'number' ? draft.editingId : null;
  resolveEditingBranch();
}

function resolveEditingBranch() {
  if (pendingEditId.value == null) {
    editingBranch.value = null;
    return;
  }
  const found = branches.value?.find(b => b.id === pendingEditId.value) ?? null;
  if (found) editingBranch.value = found;
}

watch(branches, resolveEditingBranch);

function openLocationPicker() {
  saveDraft();
  void navigateTo({
    path: localePath('/admin/branches/location'),
    query: {
      lat: String(form.latitude),
      lon: String(form.longitude),
      address: form.address || undefined,
      city: form.city || undefined,
    },
  });
}

function hydrateFromLocationReturn() {
  if (!import.meta.client) return;
  const q = route.query;
  const lat = typeof q.lat === 'string' ? Number(q.lat) : NaN;
  const lon = typeof q.lon === 'string' ? Number(q.lon) : NaN;
  const returned = typeof q.selected_address === 'string' || (Number.isFinite(lat) && Number.isFinite(lon) && typeof q.lon === 'string');
  if (!returned) return;

  try {
    const raw = sessionStorage.getItem(DRAFT_KEY);
    if (raw) applyDraft(JSON.parse(raw) as Record<string, unknown>);
  }
  catch {
    // Keep the current empty form and only apply the pin.
  }
  clearDraft();
  if (typeof q.selected_address === 'string') form.address = q.selected_address;
  if (typeof q.selected_city === 'string') form.city = q.selected_city;
  if (Number.isFinite(lat)) form.latitude = lat;
  if (Number.isFinite(lon)) form.longitude = lon;
  isDialogOpen.value = true;

  const next: Record<string, string | undefined> = {};
  if (search.value.trim()) next.search = search.value.trim();
  if (statusFilter.value !== 'all') next.status = statusFilter.value;
  if (page.value > 1) next.page = String(page.value);
  void router.replace({ query: next });
}

onMounted(hydrateFromLocationReturn);

function openNew() {
  clearDraft();
  pendingEditId.value = null;
  editingBranch.value = null;
  form.name = '';
  form.slug = '';
  form.city = 'Toshkent';
  form.address = '';
  form.phone = '';
  form.work_hours = '09:00 - 20:00';
  form.latitude = 41.311081;
  form.longitude = 69.240562;
  form.is_active = true;
  form.notes = '';
  form.branch_type = 'DIZZO';
  form.daily_order_capacity = 50;
  form.delivery_days = 3;
  form.base_shipping_cost = 25000;
  formError.value = null;
  isDialogOpen.value = true;
}

function openEdit(branch: Branch) {
  clearDraft();
  pendingEditId.value = branch.id;
  editingBranch.value = branch;
  form.name = branch.name;
  form.slug = branch.slug;
  form.city = branch.city;
  form.address = branch.address;
  form.phone = branch.phone || '';
  form.work_hours = branch.work_hours;
  form.latitude = branch.latitude;
  form.longitude = branch.longitude;
  form.is_active = branch.is_active;
  form.notes = branch.notes || '';
  form.branch_type = (branch.branch_type as 'DIZZO' | 'BTS') || 'DIZZO';
  form.daily_order_capacity = branch.daily_order_capacity ?? 50;
  form.delivery_days = branch.delivery_days ?? 3;
  form.base_shipping_cost = branch.base_shipping_cost ?? 25000;
  formError.value = null;
  isDialogOpen.value = true;
}

function onNameInput() {
  if (!editingBranch.value && form.name) {
    form.slug = form.name
      .toLowerCase()
      .trim()
      .replace(/[\s_]+/g, '-')
      .replace(/[^\w-]+/g, '');
  }
}

async function handleSave() {
  if (!form.name || !form.address) {
    formError.value = 'Nomi va manzili kiritilishi shart';
    return;
  }
  isSubmitting.value = true;
  formError.value = null;
  try {
    const payload = {
      name: form.name,
      slug: form.slug,
      city: form.city,
      address: form.address,
      phone: form.phone || null,
      work_hours: form.work_hours,
      latitude: form.latitude,
      longitude: form.longitude,
      is_active: form.is_active,
      notes: form.notes || null,
      branch_type: form.branch_type,
      daily_order_capacity: Number(form.daily_order_capacity),
      delivery_days: Number(form.delivery_days),
      base_shipping_cost: Number(form.base_shipping_cost),
    };

    if (editingBranch.value) {
      await api.patch(`/branches/${editingBranch.value.id}`, payload);
    } else {
      await api.post('/branches', payload);
    }
    isDialogOpen.value = false;
    queryClient.invalidateQueries({ queryKey: ['branches'] });
  } catch (err: any) {
    formError.value = err?.data?.detail || 'Filialni saqlashda xatolik yuz berdi';
  } finally {
    isSubmitting.value = false;
  }
}

async function handleDelete(branch: Branch) {
  if (!confirm(`"${branch.name}" filialini o'chirishni tasdiqlaysizmi?`)) return;
  try {
    await api.delete(`/branches/${branch.id}`);
    queryClient.invalidateQueries({ queryKey: ['branches'] });
  } catch (err: any) {
    alert(err?.data?.detail || 'O\'chirishda xatolik yuz berdi');
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
      placeholder="Filiallarni qidirish..."
      :refreshing="isLoading"
      @refresh="refetch()"
    >
      <div class="max-w-full overflow-x-auto scrollbar-none">
        <UiTabs
          :model-value="statusFilter"
          @update:model-value="statusFilter = ($event as any)"
        >
          <UiTabsList class="h-10 w-max gap-1 rounded-xl border border-border bg-card p-1 shadow-2xs group-data-horizontal/tabs:h-10">
            <UiTabsTrigger
              v-for="f in FILTERS"
              :key="f.value"
              :value="f.value"
              class="h-full flex-none rounded-lg px-3 text-muted-foreground hover:bg-primary/10 hover:text-primary data-active:bg-primary data-active:text-primary-foreground data-active:shadow-xs data-active:hover:bg-primary data-active:hover:text-primary-foreground"
            >
              {{ f.label }}
            </UiTabsTrigger>
          </UiTabsList>
        </UiTabs>
      </div>

      <template #actions>
        <UiButton
          v-if="roles?.isSuperAdmin || roles?.role === 'admin'"
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          title="Yangi filial"
          @click="openNew"
        >
          <Icon
            name="lucide:store"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiDataTable
      :columns="columns"
      :data="pageRows"
      :is-loading="isLoading"
      :row-key="(row: Branch) => row.id"
      empty-text="Filiallar topilmadi"
      empty-icon="lucide:store"
      clickable
      @row-click="openEdit"
    >
      <template #cell-name="{ row }">
        <span class="flex items-center gap-2 whitespace-nowrap">
          <Icon
            name="lucide:store"
            class="size-4 text-primary shrink-0"
          />
          <span class="font-semibold text-foreground truncate max-w-xs">{{ row.name }}</span>
        </span>
      </template>

      <template #cell-branch_type="{ row }">
        <UiBadge
          v-if="row.branch_type === 'BTS'"
          variant="outline"
          class="border-blue-500/40 text-blue-600 bg-blue-500/10 text-xs"
        >
          BTS Pochta
        </UiBadge>
        <UiBadge
          v-else
          variant="secondary"
          class="text-xs"
        >
          Dizzo do'kon
        </UiBadge>
      </template>

      <template #cell-capacity_days="{ row }">
        <div class="text-xs whitespace-nowrap">
          <span class="font-medium text-foreground">{{ row.daily_order_capacity || 50 }} ta/kun</span>
          <span class="text-muted-foreground ml-1">· {{ row.estimated_delivery_days || `${row.delivery_days || 3} kun` }}</span>
        </div>
      </template>

      <template #cell-city="{ row }">
        <span class="whitespace-nowrap text-sm text-muted-foreground">{{ row.city }}</span>
      </template>

      <template #cell-address="{ row }">
        <span
          class="block max-w-xs truncate text-sm text-foreground/80 xl:max-w-sm"
          :title="row.address"
        >
          {{ row.address }}
        </span>
      </template>

      <template #cell-phone="{ row }">
        <span class="whitespace-nowrap font-mono text-xs text-muted-foreground">{{ row.phone || '—' }}</span>
      </template>

      <template #cell-work_hours="{ row }">
        <span class="whitespace-nowrap text-xs text-muted-foreground">{{ row.work_hours || '09:00 - 20:00' }}</span>
      </template>

      <template #cell-is_active="{ row }">
        <UiStatusBadge :tone="row.is_active ? 'success' : 'neutral'">
          {{ row.is_active ? 'Faol' : 'Nofaol' }}
        </UiStatusBadge>
      </template>

      <template #cell-created_at="{ row }">
        <span class="whitespace-nowrap text-xs text-muted-foreground">{{ formatDateTime(row.created_at) }}</span>
      </template>

      <template #cell-updated_at="{ row }">
        <span class="whitespace-nowrap text-xs text-muted-foreground">{{ formatDateTime(row.updated_at) }}</span>
      </template>

      <template #cell-actions="{ row }">
        <div
          class="flex items-center justify-end gap-1"
          @click.stop
        >
          <UiButton
            v-if="roles?.isSuperAdmin"
            variant="ghost"
            size="icon-sm"
            class="hover:text-destructive"
            title="O'chirish"
            @click="handleDelete(row)"
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
      v-if="filteredBranches.length > PER_PAGE"
      v-model:page="page"
      :total-pages="totalPages"
      :total-count="filteredBranches.length"
    />

    <!-- Create / Edit Dialog -->
    <UiDialog v-model:open="isDialogOpen">
      <UiDialogContent class="sm:max-w-lg max-h-[92vh] overflow-y-auto">
        <UiDialogHeader>
          <UiDialogTitle>
            {{ editingBranch ? 'Filialni tahrirlash' : 'Yangi filial qo\'shish' }}
          </UiDialogTitle>
        </UiDialogHeader>

        <form
          class="space-y-4 py-2"
          @submit.prevent="handleSave"
        >
          <div class="grid gap-3 sm:grid-cols-2">
            <div class="space-y-1.5">
              <label
                for="branch-name"
                class="text-xs font-medium text-foreground"
              >Filial nomi *</label>
              <UiInput
                id="branch-name"
                v-model="form.name"
                placeholder="Dizzo Yunusobod"
                required
                @input="onNameInput"
              />
            </div>
            <div class="space-y-1.5">
              <label
                for="branch-slug"
                class="text-xs font-medium text-foreground"
              >Slug (identifikator) *</label>
              <UiInput
                id="branch-slug"
                v-model="form.slug"
                placeholder="dizzo-yunusobod"
                required
              />
            </div>
          </div>

          <div class="grid gap-3 sm:grid-cols-3">
            <div class="space-y-1.5">
              <label
                for="branch-city"
                class="text-xs font-medium text-foreground"
              >Shahar *</label>
              <UiInput
                id="branch-city"
                v-model="form.city"
                placeholder="Toshkent"
                required
              />
            </div>
            <div class="space-y-1.5">
              <label
                for="branch-phone"
                class="text-xs font-medium text-foreground"
              >Telefon raqami</label>
              <UiInput
                id="branch-phone"
                v-model="form.phone"
                placeholder="+998 90 123 45 67"
              />
            </div>
            <div class="space-y-1.5">
              <label
                for="branch-hours"
                class="text-xs font-medium text-foreground"
              >Ish vaqti</label>
              <UiInput
                id="branch-hours"
                v-model="form.work_hours"
                placeholder="09:00 - 20:00"
              />
            </div>
          </div>

          <div class="space-y-1.5">
            <label class="text-xs font-medium text-foreground">
              Filial joylashuvi *
            </label>
            <button
              type="button"
              class="flex w-full items-start gap-3 rounded-xl border border-border bg-background px-3 py-3 text-left transition hover:border-primary/50 hover:bg-muted/40"
              @click="openLocationPicker"
            >
              <Icon
                name="lucide:map-pin"
                class="mt-0.5 size-5 shrink-0 text-primary"
              />
              <span class="min-w-0 flex-1">
                <span class="block text-sm font-medium text-foreground">
                  {{ form.address || 'Xaritadan tanlang' }}
                </span>
                <span class="mt-0.5 block text-xs text-muted-foreground">
                  {{ form.city }} · {{ form.latitude.toFixed(5) }}, {{ form.longitude.toFixed(5) }}
                </span>
              </span>
              <Icon
                name="lucide:chevron-right"
                class="mt-0.5 size-4 shrink-0 text-muted-foreground"
              />
            </button>
          </div>

          <div class="space-y-1.5">
            <label
              for="branch-address"
              class="text-xs font-medium text-foreground"
            >Aniq manzil *</label>
            <UiInput
              id="branch-address"
              v-model="form.address"
              placeholder="Amir Temur ko'chasi, 107B"
              required
            />
          </div>

          <!-- Filial turi va yetkazib berish parametrlari (Vazifa 2 talabi) -->
          <div class="rounded-xl border border-border/80 bg-muted/30 p-3.5 space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-xs font-semibold text-foreground">Yetkazib berish va filial parametrlari</span>
              <span class="text-[11px] text-muted-foreground">BTS & Dastavka hisoblash uchun</span>
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <div class="space-y-1.5">
                <label for="branch-type" class="text-xs font-medium text-foreground">Filial turi *</label>
                <select
                  id="branch-type"
                  v-model="form.branch_type"
                  class="flex h-9 w-full rounded-md border border-input bg-background px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                >
                  <option value="DIZZO">Dizzo (Olib ketish nuqtasi)</option>
                  <option value="BTS">BTS Pochta filiali</option>
                </select>
              </div>

              <div class="space-y-1.5">
                <label for="branch-cost" class="text-xs font-medium text-foreground">Baza yetkazish narxi (so'm)</label>
                <UiInput
                  id="branch-cost"
                  v-model.number="form.base_shipping_cost"
                  type="number"
                  min="0"
                  step="1000"
                  placeholder="25000"
                />
              </div>
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <div class="space-y-1.5">
                <label for="branch-capacity" class="text-xs font-medium text-foreground">
                  Kuniga o'rtacha nechta buyurtma qayta ishlaydi *
                </label>
                <UiInput
                  id="branch-capacity"
                  v-model.number="form.daily_order_capacity"
                  type="number"
                  min="1"
                  placeholder="50"
                  required
                />
              </div>

              <div class="space-y-1.5">
                <label for="branch-delivery-days" class="text-xs font-medium text-foreground">
                  Shu miqdorni necha kunda yetkazadi *
                </label>
                <UiInput
                  id="branch-delivery-days"
                  v-model.number="form.delivery_days"
                  type="number"
                  min="1"
                  placeholder="3"
                  required
                />
              </div>
            </div>

            <div
              v-if="editingBranch"
              class="flex items-center gap-2 rounded-lg bg-background/80 p-2.5 text-xs text-muted-foreground ring-1 ring-border/50"
            >
              <Icon name="lucide:calculator" class="size-4 shrink-0 text-primary" />
              <span>
                Navbatdagi buyurtmalar: <strong class="text-foreground">{{ editingBranch.current_pending_orders ?? 0 }} ta</strong> ·
                Dinamik muddat: <strong class="text-foreground">{{ editingBranch.estimated_delivery_days || `${editingBranch.delivery_days} kun` }}</strong>
              </span>
            </div>
          </div>

          <div class="flex items-center gap-2 pt-2">
            <input
              id="branch-active"
              v-model="form.is_active"
              type="checkbox"
              class="size-4 rounded border-border text-primary focus:ring-primary"
            >
            <label
              for="branch-active"
              class="text-xs font-medium text-foreground cursor-pointer"
            >
              Filial faol (mijozlar buyurtma bera oladi)
            </label>
          </div>

          <UiAlert
            v-if="formError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            <UiAlertDescription>{{ formError }}</UiAlertDescription>
          </UiAlert>

          <UiDialogFooter class="gap-2 sm:gap-0 pt-2">
            <UiButton
              type="button"
              variant="outline"
              @click="isDialogOpen = false"
            >
              Bekor qilish
            </UiButton>
            <UiButton
              type="submit"
              :disabled="isSubmitting"
            >
              <Icon
                v-if="isSubmitting"
                name="lucide:loader-2"
                class="mr-2 size-4 animate-spin"
              />
              Saqlash
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>
  </div>
</template>
