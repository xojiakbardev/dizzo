// Resolves backend-relative media/static paths to absolute URLs the
// browser can load directly (bypasses the same-origin API proxy on
// purpose — images are served straight from the backend's public port).
// Anything already absolute — http(s), protocol-relative, data: and blob:
// (pictures drawn in the browser) — or root-relative is used as it is.

const ABSOLUTE = /^(?:[a-z][a-z\d+.-]*:|\/)/i;

export function useMediaUrl() {
  const config = useRuntimeConfig();

  const getMediaUrl = (path?: string | null): string => {
    if (!path) return '';
    if (ABSOLUTE.test(path)) return path;
    const base = config.public.mediaUrl?.replace(/\/+$/, '') ?? '';
    return base ? `${base}/${path.replace(/^\/+/, '')}` : path;
  };

  return { getMediaUrl, getImageUrl: getMediaUrl };
}
