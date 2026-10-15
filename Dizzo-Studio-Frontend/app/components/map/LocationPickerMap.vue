<script setup lang="ts">
import { createMapView, onMapProviderLost, reverseGeocode as nameOf, searchPlaces, TASHKENT } from '~/utils/maps';
import type { LatLng, MapPin, MapView, Suggestion } from '~/utils/maps';

const props = withDefaults(defineProps<{
  latitude?: number | null;
  longitude?: number | null;
  address?: string;
  city?: string;
  mapClass?: string;
}>(), {
  mapClass: 'h-[300px] w-full sm:h-[360px]',
});

const emit = defineEmits<{
  'update:latitude': [value: number];
  'update:longitude': [value: number];
  'update:address': [value: string];
  'update:city': [value: string];
  confirm: [value: { latitude: number; longitude: number; address: string; city: string }];
}>();

const { t } = useI18n();
const mapEl = ref<HTMLDivElement | null>(null);
const searchQuery = ref('');
const searchResults = ref<Suggestion[]>([]);
const showSearchResults = ref(false);
const geocoding = ref(false);
const geocodeError = ref<string | null>(null);
const isLocating = ref(false);
const selectedLat = ref(props.latitude ?? TASHKENT.lat);
const selectedLng = ref(props.longitude ?? TASHKENT.lng);
const selectedAddress = ref(props.address || '');
const selectedCity = ref(props.city || 'Toshkent');

let view: MapView | null = null;
let pin: MapPin | null = null;
let searchTimer: ReturnType<typeof setTimeout> | null = null;
let searchTicket = 0;
let geocodeTicket = 0;
let stopWatchingProvider: (() => void) | null = null;

function applySelection(point: LatLng, shouldCenter = true, zoom?: number) {
  selectedLat.value = point.lat;
  selectedLng.value = point.lng;
  emit('update:latitude', Number(point.lat.toFixed(6)));
  emit('update:longitude', Number(point.lng.toFixed(6)));
  pin?.setPosition(point);
  if (shouldCenter) view?.panTo(point, zoom);
}

async function reverseGeocode(point: LatLng) {
  // Only the last dropped pin names the address.
  const ticket = ++geocodeTicket;
  geocoding.value = true;
  geocodeError.value = null;
  const place = await nameOf(point);
  if (ticket !== geocodeTicket) return;
  geocoding.value = false;
  if (!place) {
    geocodeError.value = t('user.map.geocodeError');
    selectedAddress.value = `${point.lat.toFixed(5)}, ${point.lng.toFixed(5)}`;
    emit('update:address', selectedAddress.value);
    return;
  }
  selectedAddress.value = place.address;
  selectedCity.value = place.city || selectedCity.value;
  emit('update:address', selectedAddress.value);
  emit('update:city', selectedCity.value);
}

function pick(point: LatLng) {
  applySelection(point, true);
  void reverseGeocode(point);
}

async function initializeMap() {
  if (!mapEl.value) return;
  view?.destroy();
  const here = { lat: selectedLat.value, lng: selectedLng.value };
  view = await createMapView(mapEl.value, here, 14);
  pin = view.addPin(here, { draggable: true, onDragEnd: point => pick(point) });
  view.onClick(pick);
}

function onSearchInput() {
  if (searchTimer) clearTimeout(searchTimer);
  const q = searchQuery.value.trim();
  if (q.length < 2) {
    searchResults.value = [];
    showSearchResults.value = false;
    return;
  }

  searchTimer = setTimeout(async () => {
    // A slower answer to an earlier query must not replace a newer one.
    const ticket = ++searchTicket;
    const found = await searchPlaces(q, { lat: selectedLat.value, lng: selectedLng.value });
    if (ticket !== searchTicket) return;
    searchResults.value = found;
    showSearchResults.value = found.length > 0;
  }, 350);
}

async function selectSearchResult(item: Suggestion) {
  searchQuery.value = item.title;
  showSearchResults.value = false;
  geocoding.value = true;
  const place = await item.resolve().catch(() => null);
  geocoding.value = false;
  if (!place) {
    geocodeError.value = t('user.map.geocodeError');
    return;
  }
  applySelection(place, true, 16);
  selectedAddress.value = place.address;
  selectedCity.value = place.city || selectedCity.value;
  emit('update:address', selectedAddress.value);
  emit('update:city', selectedCity.value);
}

function locateMe() {
  if (!import.meta.client || !navigator.geolocation) return;
  isLocating.value = true;
  navigator.geolocation.getCurrentPosition(
    (position) => {
      isLocating.value = false;
      const point = { lat: position.coords.latitude, lng: position.coords.longitude };
      applySelection(point, true, 16);
      void reverseGeocode(point);
    },
    () => {
      isLocating.value = false;
      geocodeError.value = t('user.map.locateFailed');
    },
    { enableHighAccuracy: true, timeout: 8000 },
  );
}

function confirmSelection() {
  emit('confirm', {
    latitude: Number(selectedLat.value.toFixed(6)),
    longitude: Number(selectedLng.value.toFixed(6)),
    address: selectedAddress.value || `${selectedLat.value.toFixed(5)}, ${selectedLng.value.toFixed(5)}`,
    city: selectedCity.value || 'Toshkent',
  });
}

watch(() => [props.latitude, props.longitude], ([lat, lon]) => {
  if (lat != null && lon != null) {
    selectedLat.value = lat;
    selectedLng.value = lon;
  }
}, { immediate: true });

watch(() => props.address, (value) => {
  if (value) selectedAddress.value = value;
}, { immediate: true });

watch(() => props.city, (value) => {
  if (value) selectedCity.value = value;
}, { immediate: true });

onMounted(async () => {
  stopWatchingProvider = onMapProviderLost(() => void initializeMap());
  try {
    await initializeMap();
  }
  catch (err) {
    console.error('Map init error:', err);
    geocodeError.value = t('user.map.loadFailed');
  }
  // A pin with no name yet (coordinates only) gets one.
  if (props.latitude != null && props.longitude != null && !props.address) {
    void reverseGeocode({ lat: props.latitude, lng: props.longitude });
  }
});

onBeforeUnmount(() => {
  if (searchTimer) clearTimeout(searchTimer);
  stopWatchingProvider?.();
  view?.destroy();
  view = null;
});
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-center gap-2">
      <div class="relative flex-1">
        <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-muted-foreground">
          <Icon v-if="!geocoding" name="lucide:search" class="size-4" />
          <Icon v-else name="lucide:loader-2" class="size-4 animate-spin text-primary" />
        </div>
        <input
          v-model="searchQuery"
          type="text"
          class="h-10 w-full rounded-xl border border-border bg-background pl-9 pr-9 text-sm text-foreground placeholder:text-muted-foreground/70 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
          :placeholder="t('user.checkout.addressPlaceholder')"
          @input="onSearchInput"
          @focus="showSearchResults = searchResults.length > 0"
        />
        <button
          v-if="searchQuery"
          type="button"
          class="absolute inset-y-0 right-0 flex items-center pr-3 text-muted-foreground hover:text-foreground"
          @click="searchQuery = ''; searchResults = []; showSearchResults = false"
        >
          <Icon name="lucide:x" class="size-4" />
        </button>

        <div
          v-if="showSearchResults && searchResults.length"
          class="absolute left-0 right-0 top-full z-50 mt-2 max-h-56 overflow-y-auto rounded-xl border border-border bg-popover p-1.5 shadow-2xl"
        >
          <button
            v-for="item in searchResults"
            :key="item.id"
            type="button"
            class="flex w-full items-start gap-2 rounded-lg p-2 text-left text-sm transition hover:bg-muted"
            @click="selectSearchResult(item)"
          >
            <Icon name="lucide:map-pin" class="mt-0.5 size-4 text-primary" />
            <div class="min-w-0 flex-1">
              <p class="truncate font-medium text-foreground">{{ item.title }}</p>
              <p class="truncate text-xs text-muted-foreground">{{ item.subtitle }}</p>
            </div>
          </button>
        </div>
      </div>

      <UiButton type="button" variant="outline" size="sm" class="shrink-0" :disabled="isLocating" @click="locateMe">
        <Icon v-if="isLocating" name="lucide:loader-2" class="size-4 animate-spin" />
        <Icon v-else name="lucide:locate-fixed" class="size-4" />
        {{ t('user.map.locate') }}
      </UiButton>
    </div>

    <div class="relative overflow-hidden rounded-2xl border border-border bg-muted shadow-inner">
      <div
        ref="mapEl"
        :class="mapClass"
      />
      <div class="pointer-events-none absolute top-3 left-3 z-20 rounded-full border border-border/80 bg-background/90 px-2.5 py-1 text-[11px] font-mono text-foreground shadow-sm backdrop-blur">
        {{ selectedLat.toFixed(5) }}, {{ selectedLng.toFixed(5) }}
      </div>
    </div>

    <div class="rounded-xl border border-dashed border-border bg-muted/40 p-3">
      <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">{{ t('user.map.selectedAddress') }}</p>
      <p class="mt-1 text-sm font-medium text-foreground">{{ selectedAddress || t('user.map.noAddress') }}</p>
      <p v-if="selectedCity" class="mt-1 text-xs text-muted-foreground">{{ selectedCity }}</p>
    </div>

    <div class="flex items-center justify-between gap-3">
      <p v-if="geocoding" class="flex items-center gap-1.5 text-xs text-muted-foreground">
        <Icon name="lucide:loader-2" class="size-3.5 animate-spin text-primary" />
        {{ t('user.map.geocoding') }}
      </p>
      <p v-else-if="geocodeError" class="text-xs text-amber-700">{{ geocodeError }}</p>
      <span v-else class="text-xs text-muted-foreground">{{ t('user.map.clickHint') }}</span>

      <UiButton type="button" variant="default" class="ml-auto" @click="confirmSelection">
        {{ t('user.common.confirm') }}
      </UiButton>
    </div>
  </div>
</template>

<style scoped>
:deep(.gm-style) {
  border-radius: 1rem;
}
</style>
