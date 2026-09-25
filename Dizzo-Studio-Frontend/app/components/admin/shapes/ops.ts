// What the inspector can ask the shape editor to do with an area.
import type { CatalogMethod } from '~/types/catalog';
import type { DraftArea, DraftMethod, Phase, ZoneRect } from '~/lib/admin/shapeDraft';

export type AlignHow = 'x' | 'y' | 'top' | 'bottom';

export interface AreaOps {
  patch: (uid: string, patch: Partial<Pick<DraftArea, 'name' | 'key' | 'note' | 'tr'>>, group?: string) => void;
  resize: (uid: string, w: number, h: number) => void;
  face: (uid: string, face: { round?: boolean; corner?: number | null; dial?: boolean }) => void;
  align: (uid: string, how: AlignHow) => void;
  nudge: (uid: string, dx: number, dy: number) => void;
  rotate: (uid: string, deg: number) => void;
  place: (uid: string) => void;
  lookAt: (uid: string) => void;
  saveCamera: (uid: string) => void;
  clearCamera: (uid: string) => void;
  duplicate: (uid: string) => void;
  mirrorCopy: (uid: string, across: 'side' | 'front') => void;
  remove: (uid: string) => void;
  pair: (uid: string, partnerKey: string | null, mirror: boolean) => void;
  toggleMethod: (uid: string, method: CatalogMethod) => void;
  method: (uid: string, method: CatalogMethod, patch: Partial<DraftMethod>, group?: string) => void;
  zone: (uid: string, method: CatalogMethod, rect: ZoneRect, phase: Phase) => void;
}
