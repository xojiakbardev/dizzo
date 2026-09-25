import { i18nT } from '~/lib/i18n';
// Uploads straight to Cloudflare R2: the backend validates the file and
// hands back a presigned PUT (R2 enforces the signed type and size), the
// browser PUTs the bytes, then the backend confirms the object exists.
// Nothing is stored as base64 any more — only the returned URL.

export type MediaPurpose = 'design' | 'catalog' | 'model' | 'print' | 'avatar';

export interface MediaItem {
  id: string;
  url: string;
  purpose: MediaPurpose;
  content_type: string;
  size_bytes: number;
  status: 'pending' | 'ready';
  guest: boolean;
}

interface UploadTicket {
  id: string;
  upload_url: string;
  upload_method: 'PUT';
  upload_headers: Record<string, string>;
  url: string;
  expires_in: number;
}

// Must match the backend's accepted types and limits (app/api/v1/media.py).
export const MEDIA_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
export const DESIGN_IMAGE_MAX_MB = 10;

// Guest uploads live under tmp/ on R2 until claimed after login. Their ids
// (and the URLs the editor drafts reference) are kept here so the claim can
// rewrite those drafts to the new URLs.
const GUEST_MEDIA_KEY = 'enjoy:guest-media';
const EDITOR_DRAFT_PREFIX = 'enjoy:editor:';

interface GuestMediaRef {
  id: string;
  url: string;
}

function readGuestMedia(): GuestMediaRef[] {
  try {
    return JSON.parse(window.localStorage.getItem(GUEST_MEDIA_KEY) ?? '[]') as GuestMediaRef[];
  }
  catch {
    return [];
  }
}

function writeGuestMedia(items: GuestMediaRef[]) {
  try {
    if (items.length) window.localStorage.setItem(GUEST_MEDIA_KEY, JSON.stringify(items));
    else window.localStorage.removeItem(GUEST_MEDIA_KEY);
  }
  catch {
    // Browser storage unavailable — the upload still works, it just can't be claimed later.
  }
}

function rewriteEditorDrafts(moves: Map<string, string>) {
  try {
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i);
      if (!key?.startsWith(EDITOR_DRAFT_PREFIX)) continue;
      let value = window.localStorage.getItem(key) ?? '';
      for (const [from, to] of moves) value = value.split(from).join(to);
      window.localStorage.setItem(key, value);
    }
  }
  catch {
    // Browser storage unavailable — there are no local drafts to rewrite.
  }
}

/** Drop studio drafts left on this computer (logout / another person). */
export function clearEditorDrafts() {
  try {
    const keys: string[] = [];
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i);
      if (key?.startsWith(EDITOR_DRAFT_PREFIX)) keys.push(key);
    }
    for (const key of keys) window.localStorage.removeItem(key);
  }
  catch {
    // Browser storage unavailable — nothing to clear.
  }
}

export function useMediaUpload() {
  const api = useApi();

  async function upload(file: Blob, purpose: MediaPurpose): Promise<MediaItem> {
    const ticket = await api.post<UploadTicket>('/media/uploads/', {
      purpose,
      content_type: file.type,
      size_bytes: file.size,
    });
    const response = await fetch(ticket.upload_url, {
      method: ticket.upload_method,
      headers: ticket.upload_headers,
      body: file,
    });
    if (!response.ok) {
      throw new Error(i18nT('common.errors.fileSave', { status: response.status }));
    }
    const media = await api.post<MediaItem>(`/media/${ticket.id}/complete/`);
    if (media.guest) writeGuestMedia([...readGuestMedia().filter(m => m.id !== media.id), { id: media.id, url: media.url }]);
    return media;
  }

  return { upload };
}

// Called right after a successful login/registration. Moves this browser's
// guest uploads into the account and points local editor drafts at their
// new URLs. On failure the list is kept, so the next login retries it.
export async function claimGuestMedia(api: ReturnType<typeof useApi>): Promise<void> {
  const pending = readGuestMedia();
  if (!pending.length) return;
  const claimed = await api.post<MediaItem[]>('/media/claim/', { ids: pending.map(m => m.id) });
  rewriteEditorDrafts(new Map(pending.map((m, i) => [m.url, claimed[i]!.url])));
  writeGuestMedia([]);
}

export async function dataUrlToBlob(dataUrl: string): Promise<Blob> {
  return (await fetch(dataUrl)).blob();
}
