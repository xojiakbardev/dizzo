// One map kit for every map on the site (delivery address picker, pickup
// branches, admin branch location): Google Maps when a key is configured,
// OpenStreetMap (Leaflet + Nominatim) otherwise — and also when Google
// refuses the key (billing off, referrer not allowed), so a map always shows.
// The same goes for address search and for naming a dropped pin.

export interface LatLng { lat: number; lng: number }
export interface PlaceInfo { address: string; city: string }
export interface Suggestion {
  id: string;
  title: string;
  subtitle: string;
  resolve: () => Promise<(LatLng & PlaceInfo) | null>;
}
export type PinKind = 'pin' | 'branch';
export interface MapPin {
  setPosition: (point: LatLng) => void;
  setSelected: (selected: boolean) => void;
  remove: () => void;
}
export interface MapView {
  provider: 'google' | 'leaflet';
  panTo: (point: LatLng, zoom?: number) => void;
  onClick: (handler: (point: LatLng) => void) => void;
  addPin: (point: LatLng, options?: {
    kind?: PinKind;
    selected?: boolean;
    draggable?: boolean;
    onClick?: () => void;
    onDragEnd?: (point: LatLng) => void;
  }) => MapPin;
  destroy: () => void;
}

export const TASHKENT: LatLng = { lat: 41.311081, lng: 69.240562 };
const TIMEOUT_MS = 12_000;
const BRAND = '#ed5123';

const PIN_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="0 0 24 24"><path fill="${BRAND}" stroke="#ffffff" stroke-width="1.2" d="M12 22s-8-7.6-8-12a8 8 0 1 1 16 0c0 4.4-8 12-8 12zm0-9.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/></svg>`;
function branchSvg(selected: boolean) {
  const [bg, ring, ink] = selected ? [BRAND, '#f97316', '#ffffff'] : ['#ffffff', '#0f172a', BRAND];
  return `<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none"><rect x="4" y="4" width="16" height="16" rx="8" fill="${bg}" stroke="${ring}" stroke-width="1.5"/><path d="M7 14.5V9.5C7 8.67 7.67 8 8.5 8H15.5C16.33 8 17 8.67 17 9.5V14.5C17 15.33 16.33 16 15.5 16H8.5C7.67 16 7 15.33 7 14.5Z" fill="${ink}"/><path d="M9.5 12.5h5M12 10v5" stroke="${bg}" stroke-width="1.5" stroke-linecap="round"/></svg>`;
}
function iconOf(kind: PinKind, selected: boolean) {
  return kind === 'branch'
    ? { svg: branchSvg(selected), size: 40, anchorY: 20 }
    : { svg: PIN_SVG, size: 34, anchorY: 34 };
}

// ── Google ──────────────────────────────────────────────────────────────

let googleLoading: Promise<any> | null = null;
// Google answers a refused key only after the map is drawn (gm_authFailure);
// from then on everything uses OpenStreetMap and open maps are rebuilt.
let googleRefused = false;
const refusalListeners = new Set<() => void>();

let cachedConfig: { key?: string; mapId?: string } | null = null;

// Read once, while a component sets up its map: search and pin naming run
// later from timers and map events, outside the Nuxt context
// useRuntimeConfig() needs.
function config() {
  if (cachedConfig) return cachedConfig;
  let pub: Record<string, unknown> | undefined;
  try {
    pub = useRuntimeConfig().public;
  }
  catch {
    pub = (window as any).__NUXT__?.config?.public;
  }
  cachedConfig = { key: pub?.googleMapsApiKey as string | undefined, mapId: pub?.googleMapsMapId as string | undefined };
  return cachedConfig;
}

function googleUsable() {
  return import.meta.client && Boolean(config().key) && !googleRefused;
}

/** Called by a map to be rebuilt (on OpenStreetMap) if Google refuses the key. */
export function onMapProviderLost(rebuild: () => void): () => void {
  refusalListeners.add(rebuild);
  return () => refusalListeners.delete(rebuild);
}

function refuseGoogle() {
  if (googleRefused) return;
  googleRefused = true;
  refusalListeners.forEach(rebuild => rebuild());
}

function loadGoogle(): Promise<any> {
  if (googleLoading) return googleLoading;
  const w = window as any;
  googleLoading = new Promise((resolve, reject) => {
    if (w.google?.maps?.importLibrary) return resolve(w.google.maps);
    const timer = window.setTimeout(() => reject(new Error('google-maps-timeout')), TIMEOUT_MS);
    w.__dizzoMapsReady = () => {
      window.clearTimeout(timer);
      resolve(w.google.maps);
    };
    w.gm_authFailure = refuseGoogle;
    const lang = (document.documentElement.lang || 'uz').slice(0, 2);
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(config().key!)}&v=weekly&loading=async&callback=__dizzoMapsReady&language=${lang}&region=UZ`;
    script.async = true;
    script.onerror = () => {
      window.clearTimeout(timer);
      reject(new Error('google-maps-script-failed'));
    };
    document.head.appendChild(script);
  });
  // A failed attempt may be retried by the next map (after reconnecting).
  googleLoading.catch(() => {
    googleLoading = null;
  });
  return googleLoading;
}

async function googleMap(el: HTMLElement, center: LatLng, zoom: number): Promise<MapView> {
  const gmaps = await loadGoogle();
  const { Map } = await gmaps.importLibrary('maps');
  const { mapId } = config();
  // Advanced markers need a Map ID; without one the classic marker is used.
  const markerLib = mapId ? await gmaps.importLibrary('marker') : null;
  const map = new Map(el, {
    center,
    zoom,
    mapId: mapId || undefined,
    disableDefaultUI: true,
    zoomControl: true,
    gestureHandling: 'greedy',
    clickableIcons: false,
  });
  // Some refusals (ApiTargetBlockedMapError: the key may not use the Maps
  // JavaScript API) never call gm_authFailure and leave a grey map; a map
  // that draws no tiles in time counts as refused too.
  let drawn = false;
  map.addListener('tilesloaded', () => {
    drawn = true;
  });
  window.setTimeout(() => {
    if (!drawn && el.isConnected) refuseGoogle();
  }, 10_000);

  return {
    provider: 'google',
    panTo(point, nextZoom) {
      map.panTo(point);
      if (nextZoom) map.setZoom(nextZoom);
    },
    onClick(handler) {
      map.addListener('click', (event: any) => {
        if (event.latLng) handler({ lat: event.latLng.lat(), lng: event.latLng.lng() });
      });
    },
    addPin(point, options = {}) {
      const kind = options.kind ?? 'pin';
      let selected = Boolean(options.selected);
      let marker: any;
      const content = () => {
        const icon = iconOf(kind, selected);
        const node = document.createElement('div');
        node.innerHTML = icon.svg;
        node.style.transform = `translateY(${icon.size - icon.anchorY}px)`;
        node.style.cursor = options.onClick || options.draggable ? 'pointer' : '';
        return node;
      };
      const classicIcon = () => {
        const icon = iconOf(kind, selected);
        return {
          url: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(icon.svg)}`,
          scaledSize: new gmaps.Size(icon.size, icon.size),
          anchor: new gmaps.Point(icon.size / 2, icon.anchorY),
        };
      };
      if (markerLib) {
        marker = new markerLib.AdvancedMarkerElement({
          map, position: point, content: content(), gmpDraggable: Boolean(options.draggable),
        });
        if (options.onClick) marker.addListener('gmp-click', options.onClick);
      }
      else {
        marker = new gmaps.Marker({ map, position: point, icon: classicIcon(), draggable: Boolean(options.draggable) });
        if (options.onClick) marker.addListener('click', options.onClick);
      }
      if (options.onDragEnd) {
        marker.addListener('dragend', () => {
          const pos = markerLib ? marker.position : marker.getPosition();
          const lat = typeof pos.lat === 'function' ? pos.lat() : pos.lat;
          const lng = typeof pos.lng === 'function' ? pos.lng() : pos.lng;
          options.onDragEnd!({ lat, lng });
        });
      }
      return {
        setPosition(next) {
          if (markerLib) marker.position = next;
          else marker.setPosition(next);
        },
        setSelected(next) {
          selected = next;
          if (markerLib) {
            marker.content = content();
            marker.zIndex = next ? 10 : 1;
          }
          else {
            marker.setIcon(classicIcon());
            marker.setZIndex(next ? 10 : 1);
          }
        },
        remove() {
          if (markerLib) marker.map = null;
          else marker.setMap(null);
        },
      };
    },
    destroy() {
      gmaps.event.clearInstanceListeners(map);
      el.innerHTML = '';
    },
  };
}

// ── OpenStreetMap ───────────────────────────────────────────────────────

async function leafletMap(el: HTMLElement, center: LatLng, zoom: number): Promise<MapView> {
  const leafletModule = await import('leaflet');
  const L = (leafletModule as any).default || leafletModule;
  await import('leaflet/dist/leaflet.css');
  const map = L.map(el, { zoomControl: false, attributionControl: true }).setView([center.lat, center.lng], zoom);
  L.control.zoom({ position: 'topright' }).addTo(map);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap',
  }).addTo(map);
  // The box may still be settling (a dialog opening, a tab showing).
  window.setTimeout(() => map.invalidateSize(), 250);

  const divIcon = (kind: PinKind, selected: boolean) => {
    const icon = iconOf(kind, selected);
    return L.divIcon({
      className: 'custom-dizzo-marker',
      html: icon.svg,
      iconSize: [icon.size, icon.size],
      iconAnchor: [icon.size / 2, icon.anchorY],
    });
  };

  return {
    provider: 'leaflet',
    panTo(point, nextZoom) {
      if (nextZoom) map.setView([point.lat, point.lng], nextZoom);
      else map.panTo([point.lat, point.lng]);
    },
    onClick(handler) {
      map.on('click', (event: any) => handler({ lat: event.latlng.lat, lng: event.latlng.lng }));
    },
    addPin(point, options = {}) {
      const kind = options.kind ?? 'pin';
      const marker = L.marker([point.lat, point.lng], {
        icon: divIcon(kind, Boolean(options.selected)),
        draggable: Boolean(options.draggable),
      }).addTo(map);
      if (options.onClick) marker.on('click', options.onClick);
      if (options.onDragEnd) {
        marker.on('dragend', () => {
          const pos = marker.getLatLng();
          options.onDragEnd!({ lat: pos.lat, lng: pos.lng });
        });
      }
      return {
        setPosition: next => marker.setLatLng([next.lat, next.lng]),
        setSelected: (next) => {
          marker.setIcon(divIcon(kind, next));
          marker.setZIndexOffset(next ? 1000 : 0);
        },
        remove: () => marker.remove(),
      };
    },
    destroy() {
      map.remove();
    },
  };
}

/** A map in `el`: Google when usable, else OpenStreetMap. */
export async function createMapView(el: HTMLElement, center: LatLng = TASHKENT, zoom = 13): Promise<MapView> {
  if (googleUsable()) {
    try {
      return await googleMap(el, center, zoom);
    }
    catch (error) {
      console.warn('Google Maps unavailable, using OpenStreetMap:', error);
      el.innerHTML = '';
    }
  }
  return leafletMap(el, center, zoom);
}

// ── Geocoding ───────────────────────────────────────────────────────────

function cityOf(components: Array<{ types: string[]; long_name?: string; longText?: string }> | undefined) {
  const named = (type: string) => {
    const found = components?.find(item => item.types.includes(type));
    return found?.long_name ?? found?.longText ?? '';
  };
  return named('locality') || named('administrative_area_level_2') || named('administrative_area_level_1');
}

async function nominatimReverse(point: LatLng): Promise<PlaceInfo | null> {
  const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lng}&zoom=18&addressdetails=1`, {
    headers: { 'Accept-Language': 'uz,ru,en' },
  });
  if (!res.ok) return null;
  const data = await res.json();
  if (!data.display_name) return null;
  const a = data.address ?? {};
  const city = a.city || a.town || a.county || a.state || '';
  const street = [a.road || a.pedestrian, a.house_number].filter(Boolean).join(', ');
  return {
    address: [street, a.neighbourhood || a.suburb || a.quarter, city].filter(Boolean).join(', ') || data.display_name,
    city,
  };
}

/** The address of a point on the map; null when nothing could name it. */
export async function reverseGeocode(point: LatLng): Promise<PlaceInfo | null> {
  if (googleUsable()) {
    try {
      const gmaps = await loadGoogle();
      const { Geocoder } = await gmaps.importLibrary('geocoding');
      const { results } = await new Geocoder().geocode({ location: point });
      // The first answer is often a bare Plus Code ("76XR+R25, Toshkent"):
      // the nearest real address reads better to a courier.
      const best = results?.find((item: any) => !item.types?.includes('plus_code')) ?? results?.[0];
      if (best) return { address: best.formatted_address, city: cityOf(best.address_components) };
    }
    catch {
      // Falls through to OpenStreetMap.
    }
  }
  try {
    return await nominatimReverse(point);
  }
  catch {
    return null;
  }
}

let sessionToken: any = null;

/** Address suggestions in Uzbekistan for what the customer typed. */
export async function searchPlaces(query: string, near: LatLng = TASHKENT): Promise<Suggestion[]> {
  if (googleUsable()) {
    try {
      const gmaps = await loadGoogle();
      const { AutocompleteSuggestion, AutocompleteSessionToken } = await gmaps.importLibrary('places');
      // One session per search-and-pick: Google bills it as one lookup.
      sessionToken ??= new AutocompleteSessionToken();
      const { suggestions } = await AutocompleteSuggestion.fetchAutocompleteSuggestions({
        input: query,
        sessionToken,
        includedRegionCodes: ['uz'],
        locationBias: { center: near, radius: 50_000 },
      });
      return suggestions
        .map((item: any) => item.placePrediction)
        .filter(Boolean)
        .slice(0, 8)
        .map((prediction: any) => ({
          id: prediction.placeId,
          title: prediction.mainText?.text ?? prediction.text.text,
          subtitle: prediction.secondaryText?.text ?? prediction.text.text,
          async resolve() {
            const place = prediction.toPlace();
            await place.fetchFields({ fields: ['location', 'formattedAddress', 'addressComponents'] });
            sessionToken = null;
            if (!place.location) return null;
            return {
              lat: place.location.lat(),
              lng: place.location.lng(),
              address: place.formattedAddress ?? prediction.text.text,
              city: cityOf(place.addressComponents),
            };
          },
        }));
    }
    catch {
      // Falls through to OpenStreetMap.
    }
  }
  try {
    // viewbox (not bounded) ranks places near the pin first: "Amir Temur"
    // is a street in every city.
    const box = [near.lng - 0.4, near.lat + 0.4, near.lng + 0.4, near.lat - 0.4].join(',');
    const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&countrycodes=uz&limit=8&addressdetails=1&viewbox=${box}`, {
      headers: { 'Accept-Language': 'uz,ru,en' },
    });
    if (!res.ok) return [];
    const list = await res.json();
    return list.map((item: any) => {
      const a = item.address ?? {};
      const result = {
        lat: Number(item.lat),
        lng: Number(item.lon),
        address: item.display_name as string,
        city: a.city || a.town || a.county || a.state || '',
      };
      return {
        id: String(item.place_id),
        title: item.display_name.split(',')[0],
        subtitle: item.display_name,
        resolve: async () => result,
      };
    });
  }
  catch {
    return [];
  }
}
