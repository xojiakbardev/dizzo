<script setup lang="ts">
interface SearchResult {
  place_id: string;
  formatted_address: string;
  lat: number;
  lng: number;
}

declare global {
  interface Window {
    [key: string]: any;
  }
}

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
const runtimeConfig = useRuntimeConfig();
const googleApiKey = runtimeConfig.public.googleMapsApiKey as string | undefined;
const yandexApiKey = runtimeConfig.public.yandexMapsApiKey as string | undefined;
const mapEl = ref<HTMLDivElement | null>(null);
const searchQuery = ref('');
const searchResults = ref<SearchResult[]>([]);
const showSearchResults = ref(false);
const geocoding = ref(false);
const geocodeError = ref<string | null>(null);
const isLocating = ref(false);
const selectedLat = ref(props.latitude ?? 41.311081);
const selectedLng = ref(props.longitude ?? 69.240562);
const selectedAddress = ref(props.address || '');
const selectedCity = ref(props.city || 'Toshkent');

let map: any = null;
let marker: any = null;
let searchTimer: ReturnType<typeof setTimeout> | null = null;
let yandexMapInstance: any = null;
let yandexMapMarker: any = null;
let activeProvider: 'yandex' | 'leaflet' | null = null;

function makeBrandPin(color = '#ed5123') {
  return `<div style="width:22px;height:22px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 8px 18px rgba(0,0,0,.22);position:relative;display:flex;align-items:center;justify-content:center;"><div style="width:8px;height:8px;border-radius:50%;background:white;opacity:0.95;"></div></div>`;
}

function applySelection(lat: number, lon: number, shouldCenter = true) {
  selectedLat.value = lat;
  selectedLng.value = lon;
  emit('update:latitude', Number(lat.toFixed(6)));
  emit('update:longitude', Number(lon.toFixed(6)));

  if (activeProvider === 'yandex' && yandexMapInstance) {
    if (shouldCenter) yandexMapInstance.panTo([lat, lon], { flying: true });
    if (!yandexMapMarker) {
      yandexMapMarker = new (window as any).ymaps.Placemark([lat, lon], {}, {
        iconLayout: 'default#image',
        iconImageHref: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24"><path fill="#ed5123" d="M12 22s-8-7.6-8-12a8 8 0 1 1 16 0c0 4.4-8 12-8 12zm0-9.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/></svg>`)}`,
        iconImageSize: [28, 28],
        iconImageOffset: [-14, -28],
      });
      yandexMapInstance.geoObjects.add(yandexMapMarker);
      return;
    }
    yandexMapMarker.geometry.setCoordinates([lat, lon]);
    return;
  }

  if (map) {
    if (shouldCenter) map.panTo([lat, lon]);
    if (marker) marker.setLatLng([lat, lon]);
  }
}

async function ensureYandexMaps() {
  if ((window as any).ymaps) return;
  if (!yandexApiKey) throw new Error('missing-yandex-api-key');

  await new Promise<void>((resolve, reject) => {
    const existing = document.querySelector('script[data-yandex-maps="true"]');
    if (existing) {
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error('yandex-maps-script-failed')), { once: true });
      return;
    }

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

async function initializeYandexMap() {
  await ensureYandexMaps();
  const ymaps = (window as any).ymaps;
  yandexMapInstance = new ymaps.Map(mapEl.value!, {
    center: [selectedLat.value, selectedLng.value],
    zoom: 12,
    controls: [],
  }, { suppressMapOpenBlock: true });

  yandexMapInstance.events.add('click', (event: any) => {
    const coords = event.get('coords');
    const lat = Number(coords[0]);
    const lon = Number(coords[1]);
    applySelection(lat, lon, true);
    void reverseGeocode(lat, lon);
  });

  if (props.latitude != null && props.longitude != null) {
    applySelection(props.latitude, props.longitude, true);
    await reverseGeocode(props.latitude, props.longitude);
  }

  activeProvider = 'yandex';
}

async function initializeLeafletMap() {
  if (!mapEl.value || !import.meta.client) return;
  const leafletModule = await import('leaflet');
  const L = leafletModule.default || leafletModule;
  await import('leaflet/dist/leaflet.css');

  if (map) {
    try { map.remove(); } catch {}
    map = null;
    marker = null;
  }

  const initialLat = selectedLat.value || 41.311081;
  const initialLng = selectedLng.value || 69.240562;

  map = L.map(mapEl.value, {
    zoomControl: false,
    attributionControl: false,
  }).setView([initialLat, initialLng], 13);

  L.control.zoom({ position: 'topright' }).addTo(map);

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
  }).addTo(map);

  const customIcon = L.divIcon({
    className: '',
    html: makeBrandPin('#ed5123'),
    iconSize: [28, 28],
    iconAnchor: [14, 28],
  });

  marker = L.marker([initialLat, initialLng], {
    draggable: true,
    icon: customIcon,
  }).addTo(map);

  marker.on('dragend', () => {
    const pos = marker.getLatLng();
    if (!pos) return;
    applySelection(pos.lat, pos.lng, false);
    void reverseGeocode(pos.lat, pos.lng);
  });

  map.on('click', (event: any) => {
    const { lat, lng } = event.latlng;
    marker.setLatLng([lat, lng]);
    applySelection(lat, lng, false);
    void reverseGeocode(lat, lng);
  });

  setTimeout(() => {
    map?.invalidateSize();
  }, 250);

  activeProvider = 'leaflet';
  if (props.latitude != null && props.longitude != null) {
    void reverseGeocode(props.latitude, props.longitude);
  }
}

async function initializeMap() {
  if (!mapEl.value) return;

  if (yandexApiKey) {
    try {
      await initializeYandexMap();
      return;
    }
    catch (err) {
      console.warn('Yandex Maps yuklanmadi, Leaflet (OpenStreetMap) xaritasiga o‘tilmoqda:', err);
    }
  }

  try {
    await initializeLeafletMap();
  }
  catch (err) {
    console.error('Leaflet xaritasi yuklanmadi:', err);
    geocodeError.value = 'Xaritani yuklashda xatolik yuz berdi.';
  }
}

async function reverseGeocode(lat: number, lon: number) {
  geocoding.value = true;
  geocodeError.value = null;

  if (yandexApiKey) {
    try {
      const response = await fetch(`https://geocode-maps.yandex.ru/1.x/?apikey=${encodeURIComponent(yandexApiKey)}&format=json&geocode=${lon},${lat}`);
      if (response.ok) {
        const data = await response.json();
        const pos = data.response?.GeoObjectCollection?.featureMember?.[0]?.GeoObject;
        const name = pos?.metaDataProperty?.GeocoderMetaData?.text || pos?.name;
        if (name) {
          const city = pos?.metaDataProperty?.GeocoderMetaData?.Address?.Components?.find((item: any) => item.kind === 'locality')?.name
            || pos?.metaDataProperty?.GeocoderMetaData?.Address?.Components?.find((item: any) => item.kind === 'province')?.name
            || selectedCity.value;
          selectedAddress.value = name;
          selectedCity.value = city || selectedCity.value;
          emit('update:address', selectedAddress.value);
          emit('update:city', selectedCity.value);
          geocoding.value = false;
          return;
        }
      }
    }
    catch {
      // Fall through to OpenStreetMap
    }
  }

  try {
    const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1`, {
      headers: { 'Accept-Language': 'uz,ru,en' },
    });
    if (res.ok) {
      const data = await res.json();
      if (data.display_name) {
        const parts = [data.address?.road, data.address?.house_number].filter(Boolean).join(', ');
        const neighbourhood = data.address?.neighbourhood || data.address?.suburb || data.address?.quarter;
        const city = data.address?.city || data.address?.town || data.address?.county || data.address?.state || selectedCity.value;
        const formatted = [parts, neighbourhood, city].filter(Boolean).join(', ') || data.display_name;
        selectedAddress.value = formatted;
        selectedCity.value = city || selectedCity.value;
        emit('update:address', selectedAddress.value);
        emit('update:city', selectedCity.value);
        geocoding.value = false;
        return;
      }
    }
  }
  catch {
    // Fallback to coordinates
  }

  selectedAddress.value = `${lat.toFixed(5)}, ${lon.toFixed(5)}`;
  emit('update:address', selectedAddress.value);
  geocoding.value = false;
}

function normalizeApostrophes(text: string): string {
  return text.replace(/[`ʻʼʽ’‘]/g, '\'');
}

function toCyrillic(str: string): string {
  const text = normalizeApostrophes(str);
  const digraphs: Array<[RegExp, (m: string) => string]> = [
    [/yo/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ё' : 'ё'],
    [/yu/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ю' : 'ю'],
    [/ya/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Я' : 'я'],
    [/ch/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ч' : 'ч'],
    [/sh/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ш' : 'ш'],
    [/ye/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Е' : 'е'],
    [/o'/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ў' : 'ў'],
    [/g'/gi, (m: string) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ғ' : 'ғ'],
  ];

  let res = text;
  for (const [re, repl] of digraphs) {
    res = res.replace(re, repl);
  }

  const singles: Record<string, string> = {
    a: 'а', b: 'б', d: 'д', e: 'е', f: 'ф', g: 'г', h: 'ҳ',
    i: 'и', j: 'ж', k: 'к', l: 'л', m: 'м', n: 'н', o: 'о',
    p: 'п', q: 'қ', r: 'р', s: 'с', t: 'т', u: 'у', v: 'в',
    x: 'х', y: 'й', z: 'з',
    A: 'А', B: 'Б', D: 'Д', E: 'Е', F: 'Ф', G: 'Г', H: 'Ҳ',
    I: 'И', J: 'Ж', K: 'К', L: 'Л', M: 'М', N: 'Н', O: 'О',
    P: 'П', Q: 'Қ', R: 'Р', S: 'С', T: 'Т', U: 'У', V: 'В',
    X: 'Х', Y: 'Й', Z: 'З',
  };

  return res.split('').map(c => singles[c] ?? c).join('');
}

function toLatin(str: string): string {
  const map: Record<string, string> = {
    'ш': 'sh', 'Ш': 'Sh',
    'ч': 'ch', 'Ч': 'Ch',
    'щ': 'sh', 'Щ': 'Sh',
    'ё': 'yo', 'Ё': 'Yo',
    'ю': 'yu', 'Ю': 'Yu',
    'я': 'ya', 'Я': 'Ya',
    'ў': 'o\'', 'Ў': 'O\'',
    'ғ': 'g\'', 'Ғ': 'G\'',
    'ҳ': 'h', 'Ҳ': 'H',
    'қ': 'q', 'Қ': 'Q',
    'х': 'x', 'Х': 'X',
    'ц': 'ts', 'Ц': 'Ts',
    'ж': 'j', 'Ж': 'J',
    'э': 'e', 'Э': 'E',
    'ъ': '\'', 'Ъ': '\'',
    'ь': '', 'Ь': '',
    'а': 'a', 'А': 'A',
    'б': 'b', 'Б': 'B',
    'в': 'v', 'В': 'V',
    'г': 'g', 'Г': 'G',
    'д': 'd', 'Д': 'D',
    'е': 'e', 'Е': 'E',
    'з': 'z', 'З': 'Z',
    'и': 'i', 'И': 'I',
    'й': 'y', 'Й': 'Y',
    'к': 'k', 'К': 'K',
    'л': 'l', 'Л': 'L',
    'м': 'm', 'М': 'M',
    'н': 'n', 'Н': 'N',
    'о': 'o', 'О': 'O',
    'п': 'p', 'P': 'P',
    'р': 'r', 'Р': 'R',
    'с': 's', 'С': 'S',
    'т': 't', 'Т': 'T',
    'у': 'u', 'У': 'U',
    'ф': 'f', 'Ф': 'F',
  };

  return str.split('').map(c => map[c] ?? c).join('');
}

async function fetchGeocodeItem(queryText: string, lang = 'uz_UZ'): Promise<any[]> {
  if (!yandexApiKey) return [];
  try {
    const url = `https://geocode-maps.yandex.ru/1.x/?apikey=${encodeURIComponent(yandexApiKey)}&format=json&results=6&ll=69.240562,41.311081&spn=1.5,1.5&rspn=0&lang=${lang}&geocode=${encodeURIComponent(queryText)}`;
    const resp = await fetch(url);
    if (!resp.ok) return [];
    const data = await resp.json();
    return data.response?.GeoObjectCollection?.featureMember ?? [];
  }
  catch {
    return [];
  }
}

async function searchAddress(query: string): Promise<SearchResult[]> {
  if (yandexApiKey) {
    try {
      const normalizedApos = normalizeApostrophes(query);
      const cyrillic = toCyrillic(normalizedApos);
      const latin = toLatin(normalizedApos);
      const cleanApos = normalizedApos.replace(/'/g, '');

      const searchQueries = new Set<string>();
      searchQueries.add(query);
      searchQueries.add(normalizedApos);
      if (cyrillic !== query) searchQueries.add(cyrillic);
      if (latin !== query) searchQueries.add(latin);
      if (cleanApos !== query) searchQueries.add(cleanApos);

      const promises: Promise<any[]>[] = [];
      for (const qItem of searchQueries) {
        promises.push(fetchGeocodeItem(qItem, 'uz_UZ'));
        promises.push(fetchGeocodeItem(qItem, 'ru_RU'));
      }

      const resultsNested = await Promise.all(promises);
      const allFeatures = resultsNested.flat();

      const seen = new Set<string>();
      const parsedResults: SearchResult[] = [];

      for (const feature of allFeatures) {
        const geo = feature.GeoObject;
        if (!geo) continue;
        const point = geo.Point?.pos?.split(' ') ?? ['0', '0'];
        const lon = Number(point[0]);
        const lat = Number(point[1]);
        const key = `${lat.toFixed(4)},${lon.toFixed(4)}`;

        if (seen.has(key)) continue;
        seen.add(key);

        parsedResults.push({
          place_id: geo.metaDataProperty?.GeocoderMetaData?.precision || geo.name || key,
          formatted_address: geo.name || geo.metaDataProperty?.GeocoderMetaData?.text || query,
          lat,
          lng: lon,
        });

        if (parsedResults.length >= 8) break;
      }

      if (parsedResults.length > 0) return parsedResults;
    }
    catch {
      // Fall through to Nominatim
    }
  }

  try {
    const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&countrycodes=uz&limit=8&addressdetails=1`, {
      headers: { 'Accept-Language': 'uz,ru,en' },
    });
    if (!res.ok) return [];
    const data = await res.json();
    return data.map((item: any) => ({
      place_id: String(item.place_id),
      formatted_address: item.display_name,
      lat: Number(item.lat),
      lng: Number(item.lon),
    }));
  }
  catch {
    return [];
  }
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
    try {
      searchResults.value = await searchAddress(q);
      showSearchResults.value = searchResults.value.length > 0;
    }
    catch {
      searchResults.value = [];
      showSearchResults.value = false;
    }
  }, 300);
}

function selectSearchResult(item: SearchResult) {
  searchQuery.value = item.formatted_address;
  showSearchResults.value = false;
  const lat = item.lat;
  const lng = item.lng;

  if (map) {
    map.panTo([lat, lng]);
    map.setZoom(15);
  }

  if (yandexMapInstance) {
    yandexMapInstance.panTo([lat, lng], { flying: true });
    yandexMapInstance.setZoom(15, { duration: 200 });
  }

  applySelection(lat, lng, true);
  selectedAddress.value = item.formatted_address;
  selectedCity.value = item.formatted_address.split(',').slice(-3, -1).join(', ') || selectedCity.value;
  emit('update:address', selectedAddress.value);
  emit('update:city', selectedCity.value);
}

function locateMe() {
  if (!import.meta.client || !navigator.geolocation) return;
  isLocating.value = true;
  navigator.geolocation.getCurrentPosition(
    (position) => {
      isLocating.value = false;
      const lat = position.coords.latitude;
      const lon = position.coords.longitude;
      applySelection(lat, lon, true);
      void reverseGeocode(lat, lon);
    },
    () => {
      isLocating.value = false;
      geocodeError.value = 'Joylashuv aniqlanmadi. Ruxsatlarni tekshiring.';
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
  if (!mapEl.value) return;

  try {
    await initializeMap();
  }
  catch (err) {
    console.error('Map init error:', err);
    geocodeError.value = 'Xaritani yuklashda xatolik yuz berdi.';
  }
});

onBeforeUnmount(() => {
  if (searchTimer) clearTimeout(searchTimer);
  if (map) {
    try { map.remove(); } catch {}
    map = null;
  }
  if (yandexMapInstance) {
    try { yandexMapInstance.destroy(); } catch {}
    yandexMapInstance = null;
  }
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
            :key="item.place_id"
            type="button"
            class="flex w-full items-start gap-2 rounded-lg p-2 text-left text-sm transition hover:bg-muted"
            @click="selectSearchResult(item)"
          >
            <Icon name="lucide:map-pin" class="mt-0.5 size-4 text-primary" />
            <div class="min-w-0 flex-1">
              <p class="truncate font-medium text-foreground">{{ item.formatted_address.split(',')[0] }}</p>
              <p class="truncate text-xs text-muted-foreground">{{ item.formatted_address }}</p>
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
      <div class="pointer-events-none absolute bottom-3 left-3 z-20 rounded-full border border-border/80 bg-background/90 px-2.5 py-1 text-[11px] font-mono text-foreground shadow-sm backdrop-blur">
        {{ selectedLat.toFixed(5) }}, {{ selectedLng.toFixed(5) }}
      </div>
    </div>

    <div class="rounded-xl border border-dashed border-border bg-muted/40 p-3">
      <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Tanlangan manzil</p>
      <p class="mt-1 text-sm font-medium text-foreground">{{ selectedAddress || 'Manzil tanlanmagan' }}</p>
      <p v-if="selectedCity" class="mt-1 text-xs text-muted-foreground">{{ selectedCity }}</p>
    </div>

    <div class="flex items-center justify-between gap-3">
      <p v-if="geocoding" class="flex items-center gap-1.5 text-xs text-muted-foreground">
        <Icon name="lucide:loader-2" class="size-3.5 animate-spin text-primary" />
        {{ t('user.map.geocoding') }}
      </p>
      <p v-else-if="geocodeError" class="text-xs text-amber-700">{{ geocodeError }}</p>
      <span v-else class="text-xs text-muted-foreground">Xaritadan tanlash uchun ustiga bosing yoki belgini suring.</span>

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

:deep(.ymaps-2-1-79-map-copyrights-promo),
:deep(.ymaps-2-1-79-copyright),
:deep(.ymaps-2-1-79-copyright__wrap),
:deep(.ymaps-2-1-79-logotype),
:deep([class*="copyright"]),
:deep([class*="logotype"]),
:deep([class*="map-copyrights"]),
:deep([class*="gotoyandex"]),
:deep([class*="logo"]),
:deep([class*="-promo"]),
:deep([class*="controls__control"]),
:deep([class*="balloon"]),
:deep([class*="gototech"]) {
  display: none !important;
  opacity: 0 !important;
  pointer-events: none !important;
  visibility: hidden !important;
  height: 0 !important;
  width: 0 !important;
  overflow: hidden !important;
}
</style>
