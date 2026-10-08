// One Yandex Maps loader for every map on the site. Each map used to inject
// its own script and returned as soon as `window.ymaps` existed, before the
// API was ready, so a second map on the way (checkout → address picker)
// could throw and stay blank. A script that never answers (slow or filtered
// network) also hung forever and the OpenStreetMap fallback never started.
const TIMEOUT_MS = 12_000;

let loading: Promise<any> | null = null;

export function loadYandexMaps(apiKey: string | undefined): Promise<any> {
  if (!import.meta.client) return Promise.reject(new Error('yandex-maps-server'));
  if (!apiKey) return Promise.reject(new Error('missing-yandex-api-key'));
  if (loading) return loading;

  loading = new Promise((resolve, reject) => {
    const timer = window.setTimeout(() => reject(new Error('yandex-maps-timeout')), TIMEOUT_MS);
    const fail = (error: unknown) => {
      window.clearTimeout(timer);
      reject(error instanceof Error ? error : new Error('yandex-maps-script-failed'));
    };
    const whenReady = () => {
      const ymaps = (window as any).ymaps;
      if (!ymaps) return fail(new Error('yandex-maps-script-failed'));
      ymaps.ready(() => {
        window.clearTimeout(timer);
        resolve(ymaps);
      }, fail);
    };

    if ((window as any).ymaps) return whenReady();
    const script = document.createElement('script');
    script.src = `https://api-maps.yandex.ru/2.1/?apikey=${encodeURIComponent(apiKey)}&lang=uz_UZ`;
    script.async = true;
    script.dataset.yandexMaps = 'true';
    script.onload = whenReady;
    script.onerror = () => fail(new Error('yandex-maps-script-failed'));
    document.head.appendChild(script);
  });
  // A failed attempt may be retried on the next map (e.g. after reconnecting).
  loading.catch(() => {
    loading = null;
  });
  return loading;
}
