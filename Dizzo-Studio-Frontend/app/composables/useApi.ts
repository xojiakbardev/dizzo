import { i18nT } from '~/lib/i18n';
// Typed fetch wrapper around the FastAPI backend. Requests stay
// same-origin (`/api/**`) and are proxied to FastAPI via the `routeRules`
// in nuxt.config.ts, so this composable never needs to know the real
// backend host — dev, docker and prod all just work.

export class ApiError extends Error {
  status: number;
  data: Record<string, unknown>;

  // Shown when the server sent no message of its own: status 0 is a
  // network failure or a timeout.
  static fallbackMessage(status: number): string {
    if (status === 0) return i18nT('common.errors.network');
    if (status >= 500) return i18nT('common.errors.server');
    return i18nT('common.errors.requestFailed', { status });
  }

  constructor(status: number, data: Record<string, unknown>) {
    super(typeof data.detail === 'string' ? data.detail : ApiError.fallbackMessage(status));
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }
}

// Field-level validation errors (`{ email: ['already taken'] }`) take priority
// over the generic `non_field_errors`/`error`/`detail` keys the API falls back to.
export function getApiErrorMessage(error: unknown, fallback: string, fields: string[] = []): string {
  if (!(error instanceof ApiError)) return fallback;
  const data = error.data;

  for (const field of fields) {
    const value = data[field];
    if (typeof value === 'string' && value.trim()) return value;
    if (Array.isArray(value) && typeof value[0] === 'string' && value[0].trim()) return value[0];
  }

  if (Array.isArray(data.non_field_errors) && data.non_field_errors[0]) return data.non_field_errors[0];
  if (typeof data.error === 'string' && data.error.trim()) return data.error;
  if (typeof data.detail === 'string' && data.detail.trim()) return data.detail;
  // FastAPI request validation: detail is a list of { loc, msg }.
  if (Array.isArray(data.detail) && data.detail.length) {
    return (data.detail as Array<{ loc?: unknown[]; msg?: string }>)
      .slice(0, 3)
      .map(item => [item.loc?.slice(1).join('.'), item.msg].filter(Boolean).join(': '))
      .join('; ');
  }

  return fallback;
}

const REQUEST_TIMEOUT_MS = 30_000;
const AUTH_ENDPOINT_RE = /\/auth\/(login|register|token\/refresh|logout|oauth\/(config|google|telegram|telegram-oidc))\/?$/;

// Singleton in-flight refresh promise: concurrent 401s share this single
// refresh call rather than rotating the token multiple times and revoking sessions.
let refreshPromise: Promise<boolean> | null = null;

async function executeTokenRefresh(apiUrl: string): Promise<boolean> {
  if (refreshPromise) {
    return refreshPromise;
  }

  refreshPromise = (async () => {
    try {
      await $fetch('/auth/token/refresh/', {
        baseURL: `${apiUrl}/api`,
        method: 'POST',
        credentials: 'include',
        timeout: REQUEST_TIMEOUT_MS,
      });
      setSignedInFlag(true);
      syncAuthState(true);
      return true;
    }
    catch (error: unknown) {
      const status = (error as { response?: { status?: number } }).response?.status ?? 0;
      if (status >= 400 && status < 500) {
        setSignedInFlag(false);
        syncAuthState(false);
        try {
          await $fetch('/auth/logout/', {
            baseURL: `${apiUrl}/api`,
            method: 'POST',
            credentials: 'include',
            timeout: 5000,
          });
        }
        catch {
          // ignore logout failure on expired session
        }
      }
      return false;
    }
    finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}

export function useApi() {
  const config = useRuntimeConfig();
  // Content and error messages come back in the page's language.
  const locale = useNuxtApp().$i18n?.locale;

  async function request<T>(
    method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
    path: string,
    opts: { body?: unknown; params?: Record<string, unknown>; headers?: Record<string, string> } = {},
    retryAuth = true,
  ): Promise<T> {
    // Auth rides on the backend's HttpOnly cookies (credentials: 'include').
    const headers: Record<string, string> = { 'Accept-Language': locale?.value ?? 'uz', ...opts.headers };

    try {
      return (await $fetch(path, {
        baseURL: `${config.public.apiUrl}/api`,
        method,
        body: opts.body as never,
        query: opts.params,
        headers,
        credentials: 'include',
        timeout: REQUEST_TIMEOUT_MS,
      })) as T;
    }
    catch (error: unknown) {
      const fetchError = error as { response?: { status: number; _data?: Record<string, unknown> } };
      const status = fetchError.response?.status ?? 0;
      const data = fetchError.response?._data ?? {};

      if (status === 401 && retryAuth && !AUTH_ENDPOINT_RE.test(path)) {
        const refreshed = await executeTokenRefresh(config.public.apiUrl);
        if (refreshed) {
          // Token refreshed successfully — retry the original request with the fresh cookie
          return request<T>(method, path, opts, false);
        }
      }

      throw new ApiError(status, data);
    }
  }

  return {
    get: <T>(path: string, params?: Record<string, unknown>) => request<T>('GET', path, { params }),
    post: <T>(path: string, body?: unknown, headers?: Record<string, string>) => request<T>('POST', path, { body, headers }),
    put: <T>(path: string, body?: unknown) => request<T>('PUT', path, { body }),
    patch: <T>(path: string, body?: unknown) => request<T>('PATCH', path, { body }),
    delete: <T>(path: string) => request<T>('DELETE', path),
  };
}
