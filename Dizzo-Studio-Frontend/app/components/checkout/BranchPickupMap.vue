<script setup lang="ts">
import { createMapView, onMapProviderLost, TASHKENT } from '~/utils/maps';
import type { MapPin, MapView } from '~/utils/maps';
import { useBranches } from '~/composables/queries/useBranches';
import type { Branch } from '~/types/commerce';

const props = defineProps<{
  modelValue: number | null;
  productIds?: number[];
}>();

const emit = defineEmits<{
  'update:modelValue': [branchId: number];
  'select': [branch: Branch];
}>();

const { data: branches, isLoading } = useBranches(true);

const mapEl = ref<HTMLDivElement | null>(null);
// No map at all (offline, blocked): the branch list below still works alone.
const mapFailed = ref(false);
let view: MapView | null = null;
const pins = new Map<number, MapPin>();
let stopWatchingProvider: (() => void) | null = null;

const selectedBranch = computed(() => {
  if (!branches.value || !props.modelValue) return branches.value?.[0] || null;
  return branches.value.find(b => b.id === props.modelValue) || branches.value[0] || null;
});

function selectBranch(branch: Branch) {
  emit('update:modelValue', branch.id);
  emit('select', branch);
  if (view && branch.latitude && branch.longitude) {
    view.panTo({ lat: branch.latitude, lng: branch.longitude }, 15);
  }
}

function drawPins() {
  pins.forEach(pin => pin.remove());
  pins.clear();
  if (!view || !branches.value) return;
  for (const branch of branches.value) {
    if (!branch.latitude || !branch.longitude) continue;
    pins.set(branch.id, view.addPin({ lat: branch.latitude, lng: branch.longitude }, {
      kind: 'branch',
      selected: selectedBranch.value?.id === branch.id,
      onClick: () => selectBranch(branch),
    }));
  }
}

async function initMap() {
  if (!mapEl.value || !import.meta.client) return;
  view?.destroy();
  pins.clear();
  const branch = selectedBranch.value;
  const center = branch?.latitude && branch?.longitude ? { lat: branch.latitude, lng: branch.longitude } : TASHKENT;
  try {
    view = await createMapView(mapEl.value, center, 13);
    mapFailed.value = false;
    drawPins();
  }
  catch {
    mapFailed.value = true;
  }
}

watch(branches, () => {
  drawPins();
  // Branches that arrive after the map still preselect the first one.
  if (!props.modelValue && branches.value?.[0]) selectBranch(branches.value[0]);
}, { immediate: true });

watch(() => selectedBranch.value?.id, (id) => {
  pins.forEach((pin, branchId) => pin.setSelected(branchId === id));
});

onMounted(() => {
  stopWatchingProvider = onMapProviderLost(() => void initMap());
  nextTick(() => {
    void initMap();
  });
});

onBeforeUnmount(() => {
  stopWatchingProvider?.();
  view?.destroy();
  view = null;
});
</script>

<template>
  <div class="space-y-4">
    <!-- Map Container with custom UI frame -->
    <div class="relative overflow-hidden rounded-2xl border border-border/80 bg-muted shadow-inner">
      <!-- Custom Branded Loading Overlay -->
      <div
        v-if="isLoading"
        class="absolute inset-0 z-10 flex flex-col items-center justify-center bg-background/80 backdrop-blur-sm"
      >
        <div class="relative flex size-14 items-center justify-center">
          <div class="absolute size-full animate-ping rounded-full bg-primary/20" />
          <div class="flex size-10 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-lg">
            <Icon
              name="lucide:map-pin"
              class="size-5 animate-bounce"
            />
          </div>
        </div>
        <p class="mt-3 text-xs font-medium text-muted-foreground animate-pulse">
          Filiallar xaritasi yuklanmoqda...
        </p>
      </div>

      <!-- Map Canvas -->
      <div
        v-show="!mapFailed"
        ref="mapEl"
        class="h-72 w-full sm:h-80"
      />

      <!-- Dizzo Branding Badge on Map -->
      <div class="pointer-events-none absolute top-3 left-3 z-[400] flex items-center gap-2 rounded-xl bg-background/90 px-3 py-1.5 shadow-md backdrop-blur-md border border-border/60">
        <span class="size-2 rounded-full bg-emerald-500 animate-pulse" />
        <span class="text-[11px] font-semibold tracking-wide text-foreground">Dizzo Filiallari</span>
      </div>
    </div>

    <!-- Branches List / Grid -->
    <div
      v-if="branches && branches.length > 0"
      class="grid gap-3 sm:grid-cols-2"
    >
      <div
        v-for="branch in branches"
        :key="branch.id"
        class="relative flex cursor-pointer flex-col justify-between rounded-2xl border p-4 transition-all duration-200 hover:border-primary/50"
        :class="[
          selectedBranch?.id === branch.id
            ? 'border-primary bg-primary/5 shadow-xs ring-1 ring-primary'
            : 'border-border bg-card/60 hover:bg-muted/30',
        ]"
        @click="selectBranch(branch)"
      >
        <div class="space-y-1.5">
          <div class="flex items-center justify-between gap-2">
            <h4 class="font-semibold text-foreground text-sm flex items-center gap-1.5">
              <Icon
                name="lucide:store"
                class="size-4 text-primary shrink-0"
              />
              {{ branch.name }}
            </h4>
            <span
              v-if="selectedBranch?.id === branch.id"
              class="flex items-center gap-1 rounded-full bg-primary px-2 py-0.5 text-[10px] font-medium text-primary-foreground"
            >
              <Icon
                name="lucide:check"
                class="size-3"
              />
              Tanlangan
            </span>
          </div>

          <p class="text-xs text-muted-foreground line-clamp-2">
            {{ branch.address }}, {{ branch.city }}
          </p>
        </div>

        <div class="mt-3 flex items-center justify-between border-t border-border/50 pt-2.5 text-[11px] text-muted-foreground">
          <span class="flex items-center gap-1">
            <Icon
              name="lucide:clock"
              class="size-3.5 text-foreground/60"
            />
            {{ branch.work_hours || '09:00 - 20:00' }}
          </span>
          <span
            v-if="branch.phone"
            class="flex items-center gap-1 font-mono"
          >
            <Icon
              name="lucide:phone"
              class="size-3.5 text-foreground/60"
            />
            {{ branch.phone }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
