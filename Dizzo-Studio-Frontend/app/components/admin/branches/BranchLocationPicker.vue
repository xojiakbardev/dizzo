<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue';

const props = defineProps<{
  latitude: number | null;
  longitude: number | null;
  address?: string;
  city?: string;
}>();

const emit = defineEmits<{
  'update:latitude': [value: number];
  'update:longitude': [value: number];
  'update:address': [value: string];
  'update:city': [value: string];
}>();

const runtimeConfig = useRuntimeConfig();
const yandexApiKey = runtimeConfig.public.yandexMapsApiKey as string | undefined;
const DEFAULT_CENTER: [number, number] = [41.311081, 69.240562];

const mapEl = ref<HTMLDivElement | null>(null);
let mapInstance: any = null;
let marker: any = null;
let activeProvider: 'yandex' | 'leaflet' | null = null;

const searchQuery = ref('');
const isSearching = ref(false);
const searchResults = ref<Array<{ place_id: number | string; lat: number; lon: number; display_name: string }>>([]);
const showSearchResults = ref(false);
let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

const geocoding = ref(false);
const geocodeError = ref<string | null>(null);
const isLocating = ref(false);

function makeBrandPin() {
  return {
    iconLayout: 'default#image',
    iconImageHref: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24"><path fill="#ed5123" d="M12 22s-8-7.6-8-12a8 8 0 1 1 16 0c0 4.4-8 12-8 12zm0-9.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/></svg>`)}`,
    iconImageSize: [28, 28],
    iconImageOffset: [-14, -28],
  };
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

function emitCoordinates(lat: number, lon: number) {
  emit('update:latitude', Number(lat.toFixed(6)));
  emit('update:longitude', Number(lon.toFixed(6)));
}

async function reverseGeocode(lat: number, lon: number) {
  geocoding.value = true;
  geocodeError.value = null;

  try {
    if (yandexApiKey) {
      try {
        const response = await fetch(`https://geocode-maps.yandex.ru/1.x/?apikey=${encodeURIComponent(yandexApiKey)}&format=json&lang=uz_UZ&geocode=${lon},${lat}`);
        if (response.ok) {
          const data = await response.json();
          const geo = data.response?.GeoObjectCollection?.featureMember?.[0]?.GeoObject;
          const formatted = geo?.metaDataProperty?.GeocoderMetaData?.text || geo?.name || `${lat.toFixed(5)}, ${lon.toFixed(5)}`;
          const cityName = geo?.metaDataProperty?.GeocoderMetaData?.Address?.Components?.find((item: any) => item.kind === 'locality')?.name
            || geo?.metaDataProperty?.GeocoderMetaData?.Address?.Components?.find((item: any) => item.kind === 'province')?.name
            || props.city
            || 'Toshkent';

          emit('update:address', formatted);
          if (cityName) emit('update:city', cityName);
          return;
        }
      } catch {
        // Fallback to OSM
      }
    }

    const osmUrl = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1`;
    const osmResp = await fetch(osmUrl, {
      headers: { 'Accept-Language': 'uz,ru,en' },
    });
    if (osmResp.ok) {
      const osmData = await osmResp.json();
      const addr = osmData.address || {};
      const cityName = addr.city || addr.town || addr.county || addr.state || props.city || 'Toshkent';
      const parts = [
        addr.road || addr.pedestrian || addr.suburb || addr.neighbourhood,
        addr.house_number,
        cityName,
      ].filter(Boolean);
      const formatted = parts.length > 0 ? parts.join(', ') : (osmData.display_name || `${lat.toFixed(5)}, ${lon.toFixed(5)}`);
      emit('update:address', formatted);
      emit('update:city', cityName);
      return;
    }

    emit('update:address', `${lat.toFixed(5)}, ${lon.toFixed(5)}`);
  }
  catch {
    geocodeError.value = 'Manzil nomini aniqlab bo\'lmadi';
    emit('update:address', `${lat.toFixed(5)}, ${lon.toFixed(5)}`);
  }
  finally {
    geocoding.value = false;
  }
}

function placeMarker(lat: number, lon: number, triggerReverseGeocode = true) {
  emitCoordinates(lat, lon);

  if (activeProvider === 'leaflet') {
    if (!mapInstance) return;
    const L = (window as any).L;
    if (marker) {
      marker.setLatLng([lat, lon]);
    } else if (L) {
      const icon = L.divIcon({
        className: 'custom-brand-pin',
        html: `<div style="display:flex;align-items:center;justify-content:center;transform:translate(-50%,-100%);cursor:grab;">
          <svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="0 0 24 24"><path fill="#ed5123" stroke="#ffffff" stroke-width="1.2" d="M12 22s-8-7.6-8-12a8 8 0 1 1 16 0c0 4.4-8 12-8 12zm0-9.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/></svg>
        </div>`,
        iconSize: [34, 34],
        iconAnchor: [17, 34],
      });
      marker = L.marker([lat, lon], { icon, draggable: true }).addTo(mapInstance);
      marker.on('dragend', () => {
        const pos = marker.getLatLng();
        emitCoordinates(pos.lat, pos.lng);
        void reverseGeocode(pos.lat, pos.lng);
      });
    }
    mapInstance.panTo([lat, lon]);
    if (triggerReverseGeocode) void reverseGeocode(lat, lon);
    return;
  }

  if (!mapInstance) return;

  if (marker) {
    marker.geometry.setCoordinates([lat, lon]);
  }
  else {
    marker = new (window as any).ymaps.Placemark([lat, lon], {}, makeBrandPin());
    mapInstance.geoObjects.add(marker);
    marker.events.add('dragend', () => {
      const pos = marker.geometry.getCoordinates();
      emitCoordinates(pos[0], pos[1]);
      void reverseGeocode(pos[0], pos[1]);
    });
  }

  mapInstance.panTo([lat, lon], { flying: true });
  if (triggerReverseGeocode) void reverseGeocode(lat, lon);
}

function normalizeApostrophes(text: string): string {
  return text.replace(/[`ʻʼʽ’‘]/g, '\'');
}

function toCyrillic(str: string): string {
  const text = normalizeApostrophes(str);
  const digraphs: Array<[RegExp, (m: string) => string]> = [
    [/yo/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ё' : 'ё'],
    [/yu/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ю' : 'ю'],
    [/ya/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Я' : 'я'],
    [/ch/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ч' : 'ч'],
    [/sh/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ш' : 'ш'],
    [/ye/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Е' : 'е'],
    [/o'/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ў' : 'ў'],
    [/g'/gi, (m) => m.charAt(0) === m.charAt(0).toUpperCase() ? 'Ғ' : 'ғ'],
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

async function fetchYandexGeocode(queryText: string, lang = 'uz_UZ'): Promise<any[]> {
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

function onSearchInput() {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  const q = searchQuery.value.trim();

  if (q.length < 2) {
    searchResults.value = [];
    showSearchResults.value = false;
    return;
  }

  searchDebounceTimer = setTimeout(async () => {
    isSearching.value = true;
    try {
      if (yandexApiKey) {
        // Variantlar: Asl matn, Kirill, Lotin, Apostrofsiz
        const normalizedApos = normalizeApostrophes(q);
        const cyrillic = toCyrillic(normalizedApos);
        const latin = toLatin(normalizedApos);
        const cleanApos = normalizedApos.replace(/'/g, '');

        const searchQueries = new Set<string>();
        searchQueries.add(q);
        searchQueries.add(normalizedApos);
        if (cyrillic !== q) searchQueries.add(cyrillic);
        if (latin !== q) searchQueries.add(latin);
        if (cleanApos !== q) searchQueries.add(cleanApos);

        const promises: Promise<any[]>[] = [];
        for (const queryItem of searchQueries) {
          promises.push(fetchYandexGeocode(queryItem, 'uz_UZ'));
          promises.push(fetchYandexGeocode(queryItem, 'ru_RU'));
        }

        const resultsNested = await Promise.all(promises);
        const allFeatures = resultsNested.flat();

        const seen = new Set<string>();
        const parsedResults: typeof searchResults.value = [];

        for (const feature of allFeatures) {
          const geo = feature.GeoObject;
          if (!geo) continue;
          const point = geo.Point?.pos?.split(' ') ?? ['0', '0'];
          const lon = Number(point[0]);
          const lat = Number(point[1]);
          const key = `${lat.toFixed(4)},${lon.toFixed(4)}`;

          if (seen.has(key)) continue;
          seen.add(key);

          const displayName = geo.metaDataProperty?.GeocoderMetaData?.text || geo.name || q;
          parsedResults.push({
            place_id: geo.metaDataProperty?.GeocoderMetaData?.id || key,
            lat,
            lon,
            display_name: displayName,
          });

          if (parsedResults.length >= 8) break;
        }

        searchResults.value = parsedResults;
        showSearchResults.value = searchResults.value.length > 0;
      } else {
        // Nominatim OpenStreetMap fallback
        const osmUrl = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&countrycodes=uz&limit=8`;
        const res = await fetch(osmUrl, {
          headers: { 'Accept-Language': 'uz,ru,en' },
        });
        if (res.ok) {
          const list = await res.json();
          searchResults.value = list.map((item: any) => ({
            place_id: item.place_id,
            lat: parseFloat(item.lat),
            lon: parseFloat(item.lon),
            display_name: item.display_name,
          }));
          showSearchResults.value = searchResults.value.length > 0;
        }
      }
    }
    catch {
      searchResults.value = [];
      showSearchResults.value = false;
    }
    finally {
      isSearching.value = false;
    }
  }, 300);
}

function selectSearchResult(item: { lat: number; lon: number; display_name: string }) {
  showSearchResults.value = false;
  searchQuery.value = item.display_name;

  if (mapInstance) {
    if (activeProvider === 'leaflet') {
      mapInstance.setView([item.lat, item.lon], 15);
    } else {
      mapInstance.panTo([item.lat, item.lon], { flying: true });
      mapInstance.setZoom(15, { duration: 200 });
    }
  }

  placeMarker(item.lat, item.lon, false);
  emit('update:address', item.display_name);
}

function locateMe() {
  if (!import.meta.client || !navigator.geolocation) return;
  isLocating.value = true;

  navigator.geolocation.getCurrentPosition(
    (pos) => {
      isLocating.value = false;
      const { latitude, longitude } = pos.coords;
      if (mapInstance) {
        if (activeProvider === 'leaflet') {
          mapInstance.panTo([latitude, longitude]);
        } else {
          mapInstance.panTo([latitude, longitude], { flying: true });
        }
      }
      placeMarker(latitude, longitude, true);
    },
    () => {
      isLocating.value = false;
      geocodeError.value = 'Geolokatsiyani aniqlab bo\'lmadi. Brauzer ruxsatini tekshiring.';
    },
    { enableHighAccuracy: true, timeout: 8000 },
  );
}

async function initializeLeafletMap() {
  if (!mapEl.value) return;
  const L = await import('leaflet');
  await import('leaflet/dist/leaflet.css');
  (window as any).L = L;

  const initialLat = props.latitude ?? DEFAULT_CENTER[0];
  const initialLng = props.longitude ?? DEFAULT_CENTER[1];

  mapInstance = L.map(mapEl.value, {
    center: [initialLat, initialLng],
    zoom: props.latitude != null ? 15 : 12,
    zoomControl: true,
  });

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors',
  }).addTo(mapInstance);

  activeProvider = 'leaflet';

  mapInstance.on('click', (event: any) => {
    placeMarker(event.latlng.lat, event.latlng.lng);
  });

  placeMarker(initialLat, initialLng, true);
}

onMounted(async () => {
  if (!mapEl.value) return;

  if (yandexApiKey) {
    try {
      await ensureYandexMaps();
      const ymaps = (window as any).ymaps;
      const initialLat = props.latitude ?? DEFAULT_CENTER[0];
      const initialLng = props.longitude ?? DEFAULT_CENTER[1];

      mapInstance = new ymaps.Map(mapEl.value, {
        center: [initialLat, initialLng],
        zoom: props.latitude != null ? 15 : 12,
        controls: [],
      }, { suppressMapOpenBlock: true });

      activeProvider = 'yandex';

      mapInstance.events.add('click', (event: any) => {
        const coords = event.get('coords');
        placeMarker(Number(coords[0]), Number(coords[1]));
      });

      if (props.latitude != null && props.longitude != null) {
        placeMarker(props.latitude, props.longitude, true);
      }
      else {
        placeMarker(DEFAULT_CENTER[0], DEFAULT_CENTER[1], true);
      }
      return;
    }
    catch (err) {
      console.warn('Yandex Maps loading failed, falling back to Leaflet/OSM:', err);
    }
  }

  // Fallback to Leaflet + OpenStreetMap
  try {
    await initializeLeafletMap();
  } catch (err) {
    console.error('Leaflet map initialization failed:', err);
    geocodeError.value = 'Xarita yuklanmadi. Internet aloqasini tekshiring.';
  }
});

watch(() => [props.latitude, props.longitude], ([newLat, newLng]) => {
  if (newLat != null && newLng != null && mapInstance && marker) {
    if (activeProvider === 'leaflet') {
      marker.setLatLng([newLat, newLng]);
      mapInstance.panTo([newLat, newLng]);
    } else {
      marker.geometry.setCoordinates([newLat, newLng]);
      mapInstance.panTo([newLat, newLng], { flying: true });
    }
  }
}, { immediate: true });

onBeforeUnmount(() => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  if (activeProvider === 'leaflet' && mapInstance?.remove) {
    mapInstance.remove();
  } else if (mapInstance?.destroy) {
    mapInstance.destroy();
  }
  mapInstance = null;
  marker = null;
});
</script>

<template>
  <div class="space-y-2">
    <div class="relative z-30 flex items-center gap-2">
      <div class="relative flex-1">
        <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-muted-foreground">
          <Icon v-if="!isSearching" name="lucide:search" class="size-4" />
          <Icon v-else name="lucide:loader-2" class="size-4 animate-spin text-primary" />
        </div>
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Manzil yoki joy nomini qidiring (masalan: Amir Temur, Chilonzor...)"
          class="h-9 w-full rounded-lg border border-border bg-background pl-9 pr-8 text-xs text-foreground placeholder:text-muted-foreground/70 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
          @input="onSearchInput"
          @focus="showSearchResults = searchResults.length > 0"
        />
        <button
          v-if="searchQuery"
          type="button"
          class="absolute inset-y-0 right-0 flex items-center pr-2.5 text-muted-foreground hover:text-foreground"
          @click="searchQuery = ''; searchResults = []; showSearchResults = false"
        >
          <Icon name="lucide:x" class="size-3.5" />
        </button>

        <div v-if="showSearchResults && searchResults.length" class="absolute left-0 right-0 top-full mt-1.5 max-h-60 overflow-y-auto rounded-xl border border-border bg-popover/95 p-1.5 shadow-2xl backdrop-blur-md">
          <button
            v-for="item in searchResults"
            :key="item.place_id"
            type="button"
            class="flex w-full items-start gap-2 rounded-lg p-2 text-left text-xs transition-colors hover:bg-muted"
            @click="selectSearchResult(item)"
          >
            <Icon name="lucide:map-pin" class="mt-0.5 size-4 shrink-0 text-primary" />
            <div class="min-w-0 flex-1">
              <p class="truncate font-medium text-foreground">{{ item.display_name.split(',')[0] }}</p>
              <p class="truncate text-[11px] text-muted-foreground">{{ item.display_name }}</p>
            </div>
          </button>
        </div>
      </div>

      <UiButton
        type="button"
        variant="outline"
        size="sm"
        class="h-9 shrink-0 gap-1.5 px-3 text-xs"
        :disabled="isLocating"
        title="Mening hozirgi joylashuvimni aniqlash"
        @click="locateMe"
      >
        <Icon v-if="isLocating" name="lucide:loader-2" class="size-3.5 animate-spin text-primary" />
        <Icon v-else name="lucide:locate-fixed" class="size-3.5 text-primary" />
        <span class="hidden sm:inline">Joylashuvim</span>
      </UiButton>
    </div>

    <div class="relative overflow-hidden rounded-xl border border-border shadow-inner">
      <div ref="mapEl" class="isolate h-64 w-full bg-slate-900/[0.05] sm:h-72" />

      <div v-if="latitude != null && longitude != null" class="pointer-events-none absolute bottom-3 left-3 z-[1000] flex items-center gap-1.5 rounded-full border border-border/80 bg-background/90 px-2.5 py-1 text-[11px] font-mono font-medium text-foreground shadow-sm backdrop-blur">
        <span class="size-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
        <span>{{ latitude.toFixed(5) }}, {{ longitude.toFixed(5) }}</span>
      </div>
    </div>

    <div class="flex items-center justify-between text-[11px] text-muted-foreground">
      <div class="flex items-center gap-1.5">
        <Icon name="lucide:info" class="size-3.5 text-primary" />
        <span>Xarita ustiga bosing yoki belgini kerakli joyga suring</span>
      </div>

      <div v-if="geocoding" class="flex items-center gap-1 text-primary">
        <Icon name="lucide:loader-2" class="size-3 animate-spin" />
        <span>Manzil aniqlanmoqda...</span>
      </div>
      <div v-else-if="geocodeError" class="text-amber-600 dark:text-amber-400">
        {{ geocodeError }}
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Yandex logo, copyright, promo va barcha Yandex controls larni butunlay yashirish */
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
