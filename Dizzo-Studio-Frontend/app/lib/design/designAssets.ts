// Curated design graphics library for Studio (Love, Party, Cats, Teddy, Cartoons)
import type { ImageSource } from '~/lib/design/document';

export type AssetCategory = 'all' | 'fonlar' | 'ramkalar' | 'love' | 'party' | 'mushuklar' | 'teddy' | 'multfilm' | 'uploads';

export interface CuratedAsset extends ImageSource {
  id: string;
  name: string;
  category: 'fonlar' | 'ramkalar' | 'love' | 'party' | 'mushuklar' | 'teddy' | 'multfilm' | 'boshqa';
  type: 'sticker' | 'photo';
}

export const ASSET_CATEGORIES: Array<{ key: AssetCategory; label: string; icon: string }> = [
  { key: 'all', label: 'Barchasi', icon: 'lucide:layout-grid' },
  { key: 'fonlar', label: 'Fonlar', icon: 'lucide:wallpaper' },
  { key: 'ramkalar', label: 'Ramkalar', icon: 'lucide:frame' },
  { key: 'love', label: 'Sevgi', icon: 'lucide:heart' },
  { key: 'party', label: 'Party', icon: 'lucide:party-popper' },
  { key: 'mushuklar', label: 'Mushuklar', icon: 'lucide:cat' },
  { key: 'teddy', label: 'Teddy', icon: 'lucide:sparkles' },
  { key: 'multfilm', label: 'Multfilm', icon: 'lucide:smile' },
  { key: 'uploads', label: 'Yuklanganlar', icon: 'lucide:folder-open' },
];

export const CURATED_ASSETS: CuratedAsset[] = [
  // Love
  {
    id: '58a40915-900d-4876-9c6d-5d1444e8e575',
    name: 'Qo\'shaloq yuraklar',
    category: 'love',
    url: 'https://storage.dizzo.uz/designs/u1/58a40915-900d-4876-9c6d-5d1444e8e575.png',
    media_id: '58a40915-900d-4876-9c6d-5d1444e8e575',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: '0c7e0682-887a-4983-a50c-5407abc99fcb',
    name: 'Soyabon ostidagi juftlik',
    category: 'love',
    url: 'https://storage.dizzo.uz/designs/u1/0c7e0682-887a-4983-a50c-5407abc99fcb.png',
    media_id: '0c7e0682-887a-4983-a50c-5407abc99fcb',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: '91fc1a99-2a19-44fa-8cb4-d78314cecc49',
    name: 'Baxtli juftlik fotosi',
    category: 'love',
    url: 'https://storage.dizzo.uz/designs/u1/91fc1a99-2a19-44fa-8cb4-d78314cecc49.jpg',
    media_id: '91fc1a99-2a19-44fa-8cb4-d78314cecc49',
    px_w: 900,
    px_h: 900,
    type: 'photo',
  },

  // Party
  {
    id: 'de7af9ef-a40c-4186-8283-5cd2344b8781',
    name: 'Tug\'ilgan kun torti',
    category: 'party',
    url: 'https://storage.dizzo.uz/designs/u1/de7af9ef-a40c-4186-8283-5cd2344b8781.png',
    media_id: 'de7af9ef-a40c-4186-8283-5cd2344b8781',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: 'caf22467-d83c-45fc-9e3f-6c9492e0cd21',
    name: 'Bayram sharlari',
    category: 'party',
    url: 'https://storage.dizzo.uz/designs/u1/caf22467-d83c-45fc-9e3f-6c9492e0cd21.png',
    media_id: 'caf22467-d83c-45fc-9e3f-6c9492e0cd21',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: '56c130ee-b800-4a74-9653-b5fb8bc20e2c',
    name: 'Tug\'ilgan kun fotosi',
    category: 'party',
    url: 'https://storage.dizzo.uz/designs/u1/56c130ee-b800-4a74-9653-b5fb8bc20e2c.jpg',
    media_id: '56c130ee-b800-4a74-9653-b5fb8bc20e2c',
    px_w: 900,
    px_h: 900,
    type: 'photo',
  },

  // Mushuklar
  {
    id: 'a35df5fe-c109-4810-bdc2-f64652997854',
    name: 'Yumshoq oq mushukcha',
    category: 'mushuklar',
    url: 'https://storage.dizzo.uz/designs/u1/a35df5fe-c109-4810-bdc2-f64652997854.png',
    media_id: 'a35df5fe-c109-4810-bdc2-f64652997854',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: 'a6706c94-50fb-44fb-86a3-52c403e9bd86',
    name: 'Gulchambarli mushukcha',
    category: 'mushuklar',
    url: 'https://storage.dizzo.uz/designs/u1/a6706c94-50fb-44fb-86a3-52c403e9bd86.png',
    media_id: 'a6706c94-50fb-44fb-86a3-52c403e9bd86',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: 'afe7962a-4e2d-4c66-91e3-56a9fba1beb0',
    name: 'Yurakdagi mushukcha',
    category: 'mushuklar',
    url: 'https://storage.dizzo.uz/designs/u1/afe7962a-4e2d-4c66-91e3-56a9fba1beb0.jpg',
    media_id: 'afe7962a-4e2d-4c66-91e3-56a9fba1beb0',
    px_w: 720,
    px_h: 720,
    type: 'photo',
  },

  // Teddy
  {
    id: '7c15aab7-9e3c-404a-9875-2a83f35f6ccc',
    name: 'Yurakli ayiqcha',
    category: 'teddy',
    url: 'https://storage.dizzo.uz/designs/u1/7c15aab7-9e3c-404a-9875-2a83f35f6ccc.png',
    media_id: '7c15aab7-9e3c-404a-9875-2a83f35f6ccc',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: '5c96f418-e36b-4d14-a40e-f60a411dbea2',
    name: 'Oy ustidagi ayiqcha',
    category: 'teddy',
    url: 'https://storage.dizzo.uz/designs/u1/5c96f418-e36b-4d14-a40e-f60a411dbea2.png',
    media_id: '5c96f418-e36b-4d14-a40e-f60a411dbea2',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },

  // Multfilm
  {
    id: 'aff47f72-cc73-49e8-bae3-0d0aa26c2e3f',
    name: 'Chibi superqahramon',
    category: 'multfilm',
    url: 'https://storage.dizzo.uz/designs/u1/aff47f72-cc73-49e8-bae3-0d0aa26c2e3f.png',
    media_id: 'aff47f72-cc73-49e8-bae3-0d0aa26c2e3f',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: '862fce46-e630-4f8b-a8a1-6d41cbf95b62',
    name: 'Sehrgar anime qiz',
    category: 'multfilm',
    url: 'https://storage.dizzo.uz/designs/u1/862fce46-e630-4f8b-a8a1-6d41cbf95b62.png',
    media_id: '862fce46-e630-4f8b-a8a1-6d41cbf95b62',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
  {
    id: 'a7b9d829-5b71-4243-959c-e863b2c67e9f',
    name: 'Kichik ajdarcha',
    category: 'multfilm',
    url: 'https://storage.dizzo.uz/designs/u1/a7b9d829-5b71-4243-959c-e863b2c67e9f.png',
    media_id: 'a7b9d829-5b71-4243-959c-e863b2c67e9f',
    px_w: 800,
    px_h: 800,
    type: 'sticker',
  },
];
