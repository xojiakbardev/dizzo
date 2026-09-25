<script setup lang="ts">
const props = defineProps<{
  city: string;
  latitude: number | null;
  longitude: number | null;
}>();
const emit = defineEmits<{
  'update:address': [value: string];
  'update:city': [value: string];
  'update:latitude': [value: number];
  'update:longitude': [value: number];
}>();

const { t, locale } = useI18n();
const runtimeConfig = useRuntimeConfig();
const yandexApiKey = runtimeConfig.public.yandexMapsApiKey as string | undefined;
const DEFAULT_CENTER: [number, number] = [41.311081, 69.240562];
const geocoding = ref(false);
const geocodeError = ref<string | null>(null);
const mapEl = ref<HTMLDivElement | null>(null);

let mapInstance: any = null;
let marker: any = null;

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

async function reverseGeocode(lat: number, lon: number) {
  geocoding.value = true;
  geocodeError.value = null;

  try {
    if (!yandexApiKey) throw new Error('missing-yandex-api-key');
    const response = await fetch(`https://geocode-maps.yandex.ru/1.x/?apikey=${encodeURIComponent(yandexApiKey)}&format=json&geocode=${lon},${lat}`);
    if (!response.ok) throw new Error('geocode failed');
    const data = await response.json();
    const pos = data.response?.GeoObjectCollection?.featureMember?.[0]?.GeoObject;
    const formatted = pos?.metaDataProperty?.GeocoderMetaData?.text || pos?.name || `${lat.toFixed(5)}, ${lon.toFixed(5)}`;
    const city = pos?.metaDataProperty?.GeocoderMetaData?.Address?.Components?.find((item: any) => item.kind === 'locality')?.name
      || pos?.metaDataProperty?.GeocoderMetaData?.Address?.Components?.find((item: any) => item.kind === 'province')?.name
      || props.city;
    emit('update:address', formatted);
    emit('update:city', city || props.city);
  }
  catch {
    geocodeError.value = t('user.map.geocodeError');
    emit('update:address', `${lat.toFixed(5)}, ${lon.toFixed(5)}`);
  }
  finally {
    geocoding.value = false;
  }
}

function placePin(lat: number, lon: number) {
  if (!mapInstance) return;
  emit('update:latitude', Number(lat.toFixed(6)));
  emit('update:longitude', Number(lon.toFixed(6)));

  if (!marker) {
    marker = new (window as any).ymaps.Placemark([lat, lon], {}, makeBrandPin());
    mapInstance.geoObjects.add(marker);
  }
  else {
    marker.geometry.setCoordinates([lat, lon]);
  }

  mapInstance.panTo([lat, lon], { flying: true });
  void reverseGeocode(lat, lon);
}

function detectLocation() {
  if (!import.meta.client || !navigator.geolocation) return;
  navigator.geolocation.getCurrentPosition((position) => {
    const { latitude, longitude } = position.coords;
    mapInstance?.panTo([latitude, longitude], { flying: true });
    placePin(latitude, longitude);
  });
}

onMounted(async () => {
  if (!mapEl.value) return;
  try {
    await ensureYandexMaps();
    const ymaps = (window as any).ymaps;
    const start: [number, number] = props.latitude != null && props.longitude != null
      ? [props.latitude, props.longitude]
      : DEFAULT_CENTER;
    mapInstance = new ymaps.Map(mapEl.value, {
      center: start,
      zoom: 13,
      controls: [],
    }, { suppressMapOpenBlock: true });

    mapInstance.events.add('click', (event: any) => {
      const coords = event.get('coords');
      placePin(Number(coords[0]), Number(coords[1]));
    });

    if (props.latitude != null && props.longitude != null) {
      placePin(props.latitude, props.longitude);
    }
  }
  catch {
    geocodeError.value = 'Yandex Maps yuklanmadi. NUXT_PUBLIC_YANDEX_MAPS_API_KEY ni tekshiring.';
  }
});

onBeforeUnmount(() => {
  mapInstance?.destroy?.();
  mapInstance = null;
});
</script>

<template>
  <div class="space-y-2.5">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="min-w-0 flex-1 basis-56 text-xs text-muted-foreground">
        {{ t('user.map.hint') }}
      </p>
      <UiButton
        type="button"
        variant="outline"
        size="sm"
        @click="detectLocation"
      >
        <Icon
          name="lucide:locate-fixed"
          class="text-sm"
        />
        {{ t('user.map.locate') }}
      </UiButton>
    </div>
    <div
      ref="mapEl"
      class="isolate h-72 w-full animate-pulse overflow-hidden rounded-xl border border-border bg-slate-900/[0.07] sm:h-80 [&.leaflet-container]:animate-none"
    />
    <p
      v-if="geocoding"
      class="flex items-center gap-1.5 text-xs text-muted-foreground"
    >
      <Icon
        name="lucide:loader-2"
        class="animate-spin text-sm"
      /> {{ t('user.map.geocoding') }}
    </p>
    <p
      v-else-if="geocodeError"
      class="text-xs text-amber-700"
    >
      {{ geocodeError }}
    </p>
  </div>
</template>
