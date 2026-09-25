// "Video darsliklar": short videos on using the site — mirrors
// app/schemas/tutorial.py. The landing lists the published ones.
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import type { Translations } from '~/types/catalog';

export interface Tutorial {
  id: number;
  title: string;
  cover_url: string;
  cover_width: number | null;
  cover_height: number | null;
  /** YouTube / Telegram / MP4 link; null until the video is recorded. */
  video_url: string | null;
}

export interface AdminTutorial extends Tutorial {
  /** { ru: { title }, en: { title } }; Uzbek is `title`. */
  translations?: Translations<{ title: string }>;
  cover_media_id: string;
  sort_order: number;
  is_published: boolean;
  created_at: string;
}

export interface TutorialPayload {
  title: string;
  translations?: Translations<{ title: string }>;
  cover_media_id: string;
  cover_width?: number | null;
  cover_height?: number | null;
  video_url?: string | null;
  is_published?: boolean;
}

const KEYS = {
  public: ['tutorials', 'public'] as const,
  admin: ['tutorials', 'admin'] as const,
};

export function useTutorials() {
  const api = useApi();
  return useQuery({
    queryKey: KEYS.public,
    // An older backend has no such route: show nothing rather than an error.
    queryFn: () => api.get<Tutorial[]>('/tutorials/').catch(() => [] as Tutorial[]),
    staleTime: 5 * 60_000,
  });
}

export type TutorialPlayer =
  | { kind: 'youtube'; src: string; id: string }
  | { kind: 'iframe'; src: string }
  | { kind: 'video'; src: string }
  | { kind: 'link'; src: string };

/** How a tutorial's link plays in the lightbox: YouTube and Telegram posts
 *  embed, a video file plays in <video>, anything else opens in a new tab. */
export function tutorialPlayer(url: string): TutorialPlayer {
  let u: URL;
  try {
    u = new URL(url);
  }
  catch {
    return { kind: 'link', src: url };
  }
  const host = u.hostname.replace(/^(www|m)\./, '');
  const yt = host === 'youtu.be'
    ? u.pathname.slice(1)
    : host === 'youtube.com'
      ? (u.searchParams.get('v') ?? u.pathname.match(/^\/(?:shorts|embed|live)\/([\w-]+)/)?.[1])
      : undefined;
  if (yt && /^[\w-]{6,20}$/.test(yt)) {
    return { kind: 'youtube', src: `https://www.youtube.com/watch?v=${yt}`, id: yt };
  }
  const tg = (host === 't.me' || host === 'telegram.me') && u.pathname.match(/^\/([\w]+\/\d+)\/?$/)?.[1];
  if (tg) return { kind: 'iframe', src: `https://t.me/${tg}?embed=1&mode=tme` };
  if (/\.(mp4|webm|mov|m4v)$/i.test(u.pathname)) return { kind: 'video', src: url };
  return { kind: 'link', src: url };
}

// ── Admin ──
export function useAdminTutorials() {
  const api = useApi();
  const isAdmin = useIsAdmin();
  return useQuery({
    queryKey: KEYS.admin,
    queryFn: () => api.get<AdminTutorial[]>('/admin/tutorials/'),
    enabled: isAdmin,
  });
}

/** Admin changes; every one refreshes the admin list and the landing's. */
export function useAdminTutorialActions() {
  const api = useApi();
  const queryClient = useQueryClient();
  const busy = ref(false);
  async function run<T>(action: () => Promise<T>): Promise<T> {
    busy.value = true;
    try {
      return await action();
    }
    finally {
      busy.value = false;
      await queryClient.invalidateQueries({ queryKey: ['tutorials'] });
    }
  }
  return {
    busy,
    create: (body: TutorialPayload) => run(() => api.post<AdminTutorial>('/admin/tutorials/', body)),
    update: (id: number, body: Partial<TutorialPayload>) =>
      run(() => api.patch<AdminTutorial>(`/admin/tutorials/${id}/`, body)),
    remove: (id: number) => run(() => api.delete(`/admin/tutorials/${id}/`)),
    reorder: (ids: number[]) => run(async () => {
      queryClient.setQueryData<AdminTutorial[]>(KEYS.admin, old =>
        old && ids.map(id => old.find(i => i.id === id)!).filter(Boolean));
      const list = await api.put<AdminTutorial[]>('/admin/tutorials/order/', { ids });
      queryClient.setQueryData(KEYS.admin, list);
      return list;
    }),
  };
}
