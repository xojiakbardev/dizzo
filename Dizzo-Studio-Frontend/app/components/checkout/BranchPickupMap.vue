<script setup lang="ts">
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

const { t } = useI18n();
const runtimeConfig = useRuntimeConfig();
const yandexApiKey = runtimeConfig.public.yandexMapsApiKey as string | undefined;
const { data: branches, isLoading } = useBranches(true);

const mapEl = ref<HTMLDivElement | null>(null);
let mapInstance: any = null;
const markersMap = new Map<number, any>();

const selectedBranch = computed(() => {
  if (!branches.value || !props.modelValue) return branches.value?.[0] || null;
  return branches.value.find(b => b.id === props.modelValue) || branches.value[0] || null;
});

function createCustomPin(branch: Branch, isSelected: boolean) {
  const activeClass = isSelected
    ? 'bg-primary text-primary-foreground ring-4 ring-primary/30 scale-110 shadow-xl'
    : 'bg-card text-foreground border border-border/80 shadow-md hover:scale-105';

  return {
    iconLayout: 'default#image',
    iconImageHref: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none">
        <rect x="4" y="4" width="16" height="16" rx="8" fill="${isSelected ? '#ed5123' : '#ffffff'}" stroke="${isSelected ? '#f97316' : '#0f172a'}" stroke-width="1.5"/>
        <path d="M7 14.5V9.5C7 8.67 7.67 8 8.5 8H15.5C16.33 8 17 8.67 17 9.5V14.5C17 15.33 16.33 16 15.5 16H8.5C7.67 16 7 15.33 7 14.5Z" fill="${isSelected ? '#ffffff' : '#ed5123'}"/>
        <path d="M9.5 12.5h5" stroke="${isSelected ? '#ed5123' : '#ffffff'}" stroke-width="1.5" stroke-linecap="round"/>
        <path d="M12 10v5" stroke="${isSelected ? '#ed5123' : '#ffffff'}" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    `)}`,
    iconImageSize: [40, 40],
    iconImageOffset: [-20, -40],
  };
}

function selectBranch(branch: Branch) {
  emit('update:modelValue', branch.id);
  emit('select', branch);

  if (mapInstance && branch.latitude && branch.longitude) {
    mapInstance.panTo([branch.latitude, branch.longitude], { flying: true });
    mapInstance.setZoom(15, { duration: 200 });
  }

  markersMap.forEach((marker, id) => {
    if (branch.id !== id) return;
    marker.options.set('icon', createCustomPin(branch, true));
  });
}

async function ensureYandexMaps() {
  if ((window as any).ymaps) return;
  if (!yandexApiKey) throw new Error('missing-yandex-api-key');

  await new Promise<void>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = `https://api-maps.yandex.ru/2.1/?apikey=${encodeURIComponent(yandexApiKey)}&lang=uz_UZ`;
    script.async = true;
    script.defer = true;
    script.dataset.yandexMaps = 'true';
    script.onload = () => {
      if ((window as any).ymaps) {
        (window as any).ymaps.ready(() => resolve());
        return;
      }
      reject(new Error('yandex-maps-script-failed'));
    };
    script.onerror = () => reject(new Error('yandex-maps-script-failed'));
    document.head.appendChild(script);
  });
}

async function initMap() {
  if (!mapEl.value || !import.meta.client) return;
  try {
    await ensureYandexMaps();
    const ymaps = (window as any).ymaps;
    const center = selectedBranch.value?.latitude && selectedBranch.value?.longitude
      ? [selectedBranch.value.latitude, selectedBranch.value.longitude]
      : [41.311081, 69.240562];

    mapInstance = new ymaps.Map(mapEl.value, {
      center,
      zoom: 13,
      controls: [],
    }, { suppressMapOpenBlock: true });

    if (branches.value && branches.value.length > 0) {
      branches.value.forEach((branch) => {
        if (!branch.latitude || !branch.longitude) return;
        const isSelected = selectedBranch.value?.id === branch.id;
        const marker = new ymaps.Placemark([branch.latitude, branch.longitude], {}, createCustomPin(branch, isSelected));
        marker.events.add('click', () => selectBranch(branch));
        mapInstance.geoObjects.add(marker);
        markersMap.set(branch.id, marker);
      });

      if (!props.modelValue && branches.value[0]) {
        selectBranch(branches.value[0]);
      }
    }
  }
  catch {
    // Silently fail; branch selection still works without a map render.
  }
}

watch(branches, () => {
  if (!mapInstance || !branches.value) return;
  markersMap.forEach((marker) => mapInstance.geoObjects.remove(marker));
  markersMap.clear();

  branches.value.forEach((branch) => {
    if (!branch.latitude || !branch.longitude) return;
    const isSelected = selectedBranch.value?.id === branch.id;
    const yMarker = new (window as any).ymaps.Placemark([branch.latitude, branch.longitude], {}, createCustomPin(branch, isSelected));
    yMarker.events.add('click', () => selectBranch(branch));
    mapInstance.geoObjects.add(yMarker);
    markersMap.set(branch.id, yMarker);
  });
});

onMounted(() => {
  nextTick(() => {
    initMap();
  });
});

onBeforeUnmount(() => {
  if (mapInstance) {
    mapInstance.destroy();
    mapInstance = null;
  }
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

<style>
/* Reset default leaflet marker shadows to keep custom clean aesthetics */
.custom-dizzo-marker {
  background: transparent !important;
  border: none !important;
}
</style>
