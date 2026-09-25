// Seed script to generate and save production-grade layered templates for Dizzo.uz
const fs = require('fs');

const API_BASE = 'https://api.dizzo.uz/api';

const CATALOG = [
  {
    product_id: 1,
    name: 'Krujka',
    slug: 'krujka',
    area: 'atrofi',
    w_mm: 203,
    h_mm: 85,
    method: 'uv',
    variants: [
      { id: 1, name: 'Oddiy oq', colors: [{ id: 1, name: 'Oq', hex: '#ffffff' }] },
      { id: 2, name: 'Ichi rangli', colors: [
        { id: 2, name: 'Qora', hex: '#000000' },
        { id: 46, name: 'To‘q sariq', hex: '#ff6600' },
        { id: 3, name: 'Qizil', hex: '#ff0000' },
        { id: 4, name: 'Ko\'k', hex: '#0000ff' },
        { id: 5, name: 'Yashil', hex: '#16db17' },
      ]},
      { id: 3, name: 'Xameleon', colors: [{ id: 7, name: 'Qora', hex: '#1c1c1e' }] },
      { id: 4, name: 'Soft-touch matoviy', colors: [
        { id: 12, name: 'Qora', hex: '#000000' },
        { id: 48, name: 'Sariq', hex: '#b6ac16' },
        { id: 49, name: 'Zaytun rang', hex: '#5d9570' },
        { id: 13, name: 'To\'q qizil', hex: '#961923' },
        { id: 14, name: 'Toq ko\'k', hex: '#233e91' },
        { id: 15, name: 'To\'q yashil', hex: '#087033' },
        { id: 16, name: 'Toʻq sariq', hex: '#f56114' },
      ]},
      { id: 5, name: 'Matoviy shisha', colors: [{ id: 17, name: 'Shaffof', hex: '#ffffff' }] },
      { id: 6, name: 'Toza shaffof shisha', colors: [{ id: 18, name: 'Shaffof', hex: '#ffffff' }] },
    ]
  },
  {
    product_id: 6,
    name: 'Kepka',
    slug: 'kepka',
    area: 'old',
    w_mm: 120,
    h_mm: 60,
    method: 'uv',
    variants: [
      { id: 12, name: 'Oddiy kepka', colors: [
        { id: 41, name: 'Oq', hex: '#ffffff' },
        { id: 42, name: 'Qora', hex: '#000000' },
      ]},
      { id: 13, name: 'Tekis kozirekli', colors: [
        { id: 43, name: 'Oq', hex: '#ffffff' },
        { id: 44, name: 'Qora', hex: '#111111' },
      ]}
    ]
  },
  {
    product_id: 5,
    name: 'Hudi',
    slug: 'hudi',
    area: 'old',
    w_mm: 277,
    h_mm: 349,
    method: 'uv',
    variants: [
      { id: 11, name: 'Kapyushonli hudi', colors: [
        { id: 37, name: 'Oq', hex: '#ffffff' },
        { id: 38, name: 'Qora', hex: '#111111' },
        { id: 39, name: 'To\'q ko\'k', hex: '#1e3a8a' },
        { id: 40, name: 'Bardoviy qizil', hex: '#8a1c2b' },
      ]}
    ]
  },
  {
    product_id: 3,
    name: 'Futbolka',
    slug: 'futbolka',
    area: 'old',
    w_mm: 400,
    h_mm: 400,
    method: 'uv',
    variants: [
      { id: 9, name: 'Klassik futbolka', colors: [
        { id: 29, name: 'Oq', hex: '#ffffff' },
        { id: 30, name: 'Qora', hex: '#000000' },
        { id: 31, name: 'To\'q ko\'k', hex: '#010196' },
        { id: 32, name: 'Bardoviy qizil', hex: '#960101' },
      ]}
    ]
  },
  {
    product_id: 4,
    name: 'Uzun yengli futbolka',
    slug: 'futbolka-uzun-yeng',
    area: 'old',
    w_mm: 400,
    h_mm: 400,
    method: 'uv',
    variants: [
      { id: 10, name: 'Uzun yengli futbolka', colors: [
        { id: 33, name: 'Oq', hex: '#ffffff' },
        { id: 34, name: 'Qora', hex: '#111111' },
        { id: 35, name: 'To\'q ko\'k', hex: '#1e3a8a' },
        { id: 36, name: 'Bardoviy qizil', hex: '#8a1c2b' },
      ]}
    ]
  },
  {
    product_id: 2,
    name: 'Devor soati',
    slug: 'soat',
    area: 'siferblat',
    w_mm: 280,
    h_mm: 280,
    method: 'uv',
    variants: [
      { id: 7, name: 'Dumaloq soat Ø30 sm', colors: [
        { id: 19, name: 'Qora', hex: '#000000' },
        { id: 21, name: 'Qizil', hex: '#ff0000' },
        { id: 22, name: 'Ko\'k', hex: '#0000ff' },
        { id: 23, name: 'Yashil', hex: '#16db17' },
      ]}
    ]
  },
  {
    product_id: 7,
    name: 'Vizitka',
    slug: 'vizitka',
    area: 'old',
    w_mm: 90,
    h_mm: 50,
    method: 'uv',
    variants: [
      { id: 14, name: 'Oq vizitka', colors: [
        { id: 45, name: 'Oq', hex: '#ffffff' }
      ]}
    ]
  }
];

// Contrast-aware color palettes based on product color
function getPalettes(bgHex) {
  const isDark = bgHex === '#000000' || bgHex === '#111111' || bgHex === '#1c1c1e' || bgHex === '#1e3a8a' || bgHex === '#8a1c2b' || bgHex === '#960101' || bgHex === '#010196' || bgHex === '#233e91' || bgHex === '#087033' || bgHex === '#961923';
  if (isDark) {
    return {
      primary: '#ffffff',
      gold: '#d4af37',
      muted: '#a1a1aa',
      accent: '#f4ebd0',
      soft: '#e4e4e7',
    };
  } else {
    return {
      primary: '#18181b',
      gold: '#b8860b',
      muted: '#71717a',
      accent: '#3f3f46',
      soft: '#52525b',
    };
  }
}

// 9 Luxury Concept Blueprints for each product type
function generateConcepts(productSlug, pW, pH, area, palette) {
  const cx = pW / 2;
  const cy = pH / 2;
  
  if (productSlug === 'soat') {
    // Clock-specific concepts with dials and branding
    return [
      {
        name: 'AURELIA · Minimal Roman Dial',
        category: 'Minimal Luxury',
        concept: 'Klassik rim raqamlari bilan oltin markaziy monogramma',
        ruName: 'AURELIA · Римский Минимал',
        enName: 'AURELIA · Minimal Roman Dial',
        layers: [
          {
            id: 'dial-1', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Playfair Display', size_mm: 14, color: palette.gold, bold: false, italic: false, numerals: 'roman', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-brand', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 45, w_mm: 80, h_mm: 12, rotation: 0,
            text: { content: 'D I Z Z O', font: 'Montserrat', size_mm: 7, color: palette.primary, align: 'center', bold: true, italic: false }
          },
          {
            id: 'txt-sub', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy + 45, w_mm: 90, h_mm: 8, rotation: 0,
            text: { content: 'CHRONOMÈTRE · TASHKENT', font: 'Montserrat', size_mm: 4, color: palette.muted, align: 'center', bold: false, italic: false }
          }
        ]
      },
      {
        name: 'BAUHAUS 1926 · Geometric Dial',
        category: 'Modern Art',
        concept: 'Minimalist arxitektura va toza sans-serif soat siferblati',
        ruName: 'BAUHAUS 1926 · Геометрический Циферблат',
        enName: 'BAUHAUS 1926 · Geometric Dial',
        layers: [
          {
            id: 'dial-2', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Montserrat', size_mm: 13, color: palette.primary, bold: true, italic: false, numerals: 'arabic', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-bh-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 40, w_mm: 90, h_mm: 10, rotation: 0,
            text: { content: 'ATELIER ZERO', font: 'Montserrat', size_mm: 6.5, color: palette.gold, align: 'center', bold: true, italic: false }
          }
        ]
      },
      {
        name: 'SOLARIS · Pure Minimalist Ticks',
        category: 'Minimal Luxury',
        concept: 'Raqamlarsiz faqat nozik chiziqlar va nafis tipografiya',
        ruName: 'SOLARIS · Чистый Минимализм',
        enName: 'SOLARIS · Pure Minimalist Ticks',
        layers: [
          {
            id: 'dial-3', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Montserrat', size_mm: 10, color: palette.muted, bold: false, italic: false, numerals: 'none', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-sol', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 42, w_mm: 70, h_mm: 10, rotation: 0,
            text: { content: 'S O L A R I S', font: 'Montserrat', size_mm: 7.5, color: palette.primary, align: 'center', bold: true, italic: false }
          },
          {
            id: 'txt-loc', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy + 42, w_mm: 80, h_mm: 8, rotation: 0,
            text: { content: '41.2995° N · 69.2401° E', font: 'Montserrat', size_mm: 4.2, color: palette.gold, align: 'center', bold: false, italic: false }
          }
        ]
      },
      {
        name: 'ROYAL HERITAGE · Serene Gold',
        category: 'Gift',
        concept: 'Nafis serif raqamlar va hashamatli monogramma',
        ruName: 'ROYAL HERITAGE · Королевское Наследие',
        enName: 'ROYAL HERITAGE · Serene Gold',
        layers: [
          {
            id: 'dial-4', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Lora', size_mm: 14, color: palette.gold, bold: false, italic: true, numerals: 'roman', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-roy-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 46, w_mm: 60, h_mm: 12, rotation: 0,
            text: { content: 'M · N', font: 'Playfair Display', size_mm: 9, color: palette.primary, align: 'center', bold: true, italic: false }
          },
          {
            id: 'txt-roy-2', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy + 46, w_mm: 80, h_mm: 8, rotation: 0,
            text: { content: 'ESTABLISHED 2026', font: 'Montserrat', size_mm: 4, color: palette.muted, align: 'center', bold: false, italic: false }
          }
        ]
      },
      {
        name: 'CHRONO LINE · Swiss Precision',
        category: 'Corporate',
        concept: 'Shveysariya soatsozlik uslubidagi muvozanatli tartib',
        ruName: 'CHRONO LINE · Швейцарская Точность',
        enName: 'CHRONO LINE · Swiss Precision',
        layers: [
          {
            id: 'dial-5', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Oswald', size_mm: 13, color: palette.primary, bold: true, italic: false, numerals: 'arabic', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-sw-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 40, w_mm: 70, h_mm: 10, rotation: 0,
            text: { content: 'CHRONO', font: 'Oswald', size_mm: 7, color: palette.gold, align: 'center', bold: true, italic: false }
          },
          {
            id: 'txt-sw-2', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy + 40, w_mm: 70, h_mm: 7, rotation: 0,
            text: { content: 'AUTOMATIC', font: 'Montserrat', size_mm: 4, color: palette.muted, align: 'center', bold: false, italic: false }
          }
        ]
      },
      {
        name: 'VINTAGE BOTANIC · Herbarium Clock',
        category: 'Botanical',
        concept: 'Klassik flora va osoyishta tabiat ilhomi',
        ruName: 'VINTAGE BOTANIC · Часы Гербарий',
        enName: 'VINTAGE BOTANIC · Herbarium Clock',
        layers: [
          {
            id: 'dial-6', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'PT Serif', size_mm: 13, color: palette.muted, bold: false, italic: true, numerals: 'roman', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-bot-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 45, w_mm: 90, h_mm: 10, rotation: 0,
            text: { content: 'TEMPO SERENO', font: 'Playfair Display', size_mm: 6.5, color: palette.gold, align: 'center', bold: false, italic: true }
          }
        ]
      },
      {
        name: 'NORDIC HARMONY · Scandinavian Quiet',
        category: 'Minimal Luxury',
        concept: 'Skandinavcha sokinlik va toza chiziqlar',
        ruName: 'NORDIC HARMONY · Скандинавское Спокойствие',
        enName: 'NORDIC HARMONY · Scandinavian Quiet',
        layers: [
          {
            id: 'dial-7', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Comfortaa', size_mm: 12, color: palette.primary, bold: false, italic: false, numerals: 'arabic', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-nh-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 38, w_mm: 70, h_mm: 8, rotation: 0,
            text: { content: 'L Y K K E', font: 'Comfortaa', size_mm: 6, color: palette.gold, align: 'center', bold: true, italic: false }
          }
        ]
      },
      {
        name: 'ARCHIVE NO. 26 · Studio Edition',
        category: 'Corporate',
        concept: 'Eksklyuziv sana va studiya raqamli cheklangan tiraj',
        ruName: 'ARCHIVE NO. 26 · Лимитированное Издание',
        enName: 'ARCHIVE NO. 26 · Studio Edition',
        layers: [
          {
            id: 'dial-8', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Montserrat', size_mm: 12, color: palette.primary, bold: false, italic: false, numerals: 'roman', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-arc-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 44, w_mm: 90, h_mm: 10, rotation: 0,
            text: { content: 'EDITION № 026', font: 'Oswald', size_mm: 6, color: palette.gold, align: 'center', bold: true, italic: false }
          },
          {
            id: 'txt-arc-2', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy + 44, w_mm: 90, h_mm: 8, rotation: 0,
            text: { content: 'DIZZO CRAFT STUDIO', font: 'Montserrat', size_mm: 4, color: palette.muted, align: 'center', bold: false, italic: false }
          }
        ]
      },
      {
        name: 'ZENITH · Pure Celestial',
        category: 'Minimal Luxury',
        concept: 'Kosmik koordinatalar va astronomik aniqlik',
        ruName: 'ZENITH · Чистый Зенит',
        enName: 'ZENITH · Pure Celestial',
        layers: [
          {
            id: 'dial-9', area, method: 'uv', kind: 'dial',
            x_mm: cx, y_mm: cy, w_mm: pW, h_mm: pH, rotation: 0,
            dial: { font: 'Montserrat', size_mm: 11, color: palette.muted, bold: false, italic: false, numerals: 'none', ticks: true, face: 'round', corner_radius_mm: 0 }
          },
          {
            id: 'txt-zen-1', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy - 40, w_mm: 70, h_mm: 10, rotation: 0,
            text: { content: 'Z E N I T H', font: 'Montserrat', size_mm: 7, color: palette.gold, align: 'center', bold: true, italic: false }
          },
          {
            id: 'txt-zen-2', area, method: 'uv', kind: 'text',
            x_mm: cx, y_mm: cy + 40, w_mm: 80, h_mm: 8, rotation: 0,
            text: { content: 'OBSERVATORY TIME', font: 'Montserrat', size_mm: 4, color: palette.primary, align: 'center', bold: false, italic: false }
          }
        ]
      }
    ];
  }

  // Standard products (Krujka, Kepka, Hudi, Futbolka, Uzun yeng, Vizitka)
  const scale = pW / 200; // relative scale factor
  const titleSize = Math.max(6, Math.min(22, 10 * scale));
  const subSize = Math.max(3.5, Math.min(10, 4.5 * scale));
  const gap = Math.max(7, Math.min(22, 10 * scale));

  return [
    {
      name: 'MAISON · Monogram Luxury',
      category: 'Minimal Luxury',
      concept: 'Hashamatli bosh harf va ostida toza familiya/ism monogrammasi',
      ruName: 'MAISON · Роскошная Монограмма',
      enName: 'MAISON · Monogram Luxury',
      layers: [
        {
          id: 'l-mono-big', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.9, w_mm: pW * 0.45, h_mm: titleSize * 1.5, rotation: 0,
          text: { content: 'M', font: 'Playfair Display', size_mm: titleSize * 1.6, color: palette.gold, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-mono-name', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.5, w_mm: pW * 0.65, h_mm: subSize * 1.8, rotation: 0,
          text: { content: 'M I R Z O E V', font: 'Montserrat', size_mm: subSize * 1.2, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-mono-sub', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 1.2, w_mm: pW * 0.6, h_mm: subSize * 1.3, rotation: 0,
          text: { content: 'PRIVATE ARCHIVE · 2026', font: 'Montserrat', size_mm: subSize * 0.85, color: palette.muted, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'AURA · Minimal Typographic',
      category: 'Minimal Luxury',
      concept: 'Keng oraliqli premium harflar va eksklyuziv status qatori',
      ruName: 'AURA · Минимал Типографика',
      enName: 'AURA · Minimal Typographic',
      layers: [
        {
          id: 'l-aura-1', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.4, w_mm: pW * 0.6, h_mm: titleSize * 1.2, rotation: 0,
          text: { content: 'A U R A', font: 'Montserrat', size_mm: titleSize * 1.1, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-aura-2', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.6, w_mm: pW * 0.7, h_mm: subSize * 1.4, rotation: 0,
          text: { content: 'TIMELESS AESTHETICS', font: 'Montserrat', size_mm: subSize * 0.95, color: palette.gold, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'ATELIER NO. 7 · Pure Geometry',
      category: 'Modern Art',
      concept: 'Bauhaus ilhomi: arxitekturaviy toza chiziq va studiya imzosi',
      ruName: 'ATELIER NO. 7 · Чистая Геометрия',
      enName: 'ATELIER NO. 7 · Pure Geometry',
      layers: [
        {
          id: 'l-at-num', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.8, w_mm: pW * 0.35, h_mm: titleSize * 1.3, rotation: 0,
          text: { content: '07', font: 'Oswald', size_mm: titleSize * 1.3, color: palette.gold, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-at-title', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.4, w_mm: pW * 0.65, h_mm: subSize * 1.6, rotation: 0,
          text: { content: 'ATELIER DE DESIGN', font: 'Montserrat', size_mm: subSize * 1.1, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-at-sub', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 1.1, w_mm: pW * 0.55, h_mm: subSize * 1.2, rotation: 0,
          text: { content: 'LIMITED PRODUCTION', font: 'Montserrat', size_mm: subSize * 0.8, color: palette.muted, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'SILENCE · Editorial Philosophy',
      category: 'Quotes',
      concept: 'Yuqori moda jurnali editorial uslubidagi nozik iqtibos',
      ruName: 'SILENCE · Философия Тишины',
      enName: 'SILENCE · Editorial Philosophy',
      layers: [
        {
          id: 'l-sil-main', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.4, w_mm: pW * 0.6, h_mm: titleSize * 1.2, rotation: 0,
          text: { content: 'S I L E N C E', font: 'Lora', size_mm: titleSize, color: palette.primary, align: 'center', bold: false, italic: true }
        },
        {
          id: 'l-sil-quote', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.6, w_mm: pW * 0.75, h_mm: subSize * 1.5, rotation: 0,
          text: { content: '“THE ULTIMATE FORM OF LUXURY”', font: 'Montserrat', size_mm: subSize * 0.85, color: palette.gold, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'COORDINATES · Origin Tashkent',
      category: 'Gift',
      concept: 'Shaxsiy koordinatalar va sevimli maskan lokatsiyasi',
      ruName: 'COORDINATES · Ташкент Локация',
      enName: 'COORDINATES · Origin Tashkent',
      layers: [
        {
          id: 'l-crd-loc', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.6, w_mm: pW * 0.7, h_mm: titleSize * 1.1, rotation: 0,
          text: { content: 'T A S H K E N T', font: 'Montserrat', size_mm: titleSize * 0.9, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-crd-val', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.4, w_mm: pW * 0.65, h_mm: subSize * 1.4, rotation: 0,
          text: { content: '41.2995° N, 69.2401° E', font: 'Oswald', size_mm: subSize * 1.1, color: palette.gold, align: 'center', bold: false, italic: false }
        },
        {
          id: 'l-crd-sub', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 1.1, w_mm: pW * 0.5, h_mm: subSize * 1.2, rotation: 0,
          text: { content: 'WHERE THE STORY BEGINS', font: 'Montserrat', size_mm: subSize * 0.75, color: palette.muted, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'BOTANIQUE · Organic Reserve',
      category: 'Botanical',
      concept: 'Nafis tabiat uyg‘unligi va botanika estetikasidagi tipografiya',
      ruName: 'BOTANIQUE · Органический Резерв',
      enName: 'BOTANIQUE · Organic Reserve',
      layers: [
        {
          id: 'l-bot-1', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.5, w_mm: pW * 0.65, h_mm: titleSize * 1.2, rotation: 0,
          text: { content: 'B O T A N I Q U E', font: 'Playfair Display', size_mm: titleSize * 0.95, color: palette.primary, align: 'center', bold: false, italic: true }
        },
        {
          id: 'l-bot-2', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.5, w_mm: pW * 0.7, h_mm: subSize * 1.4, rotation: 0,
          text: { content: 'FLORA · NATURE RESERVE · 2026', font: 'Montserrat', size_mm: subSize * 0.8, color: palette.gold, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'EXECUTIVE · The Capital Club',
      category: 'Corporate',
      concept: 'Biznes va korporativ elita uchun lakonik shveysar uslubi',
      ruName: 'EXECUTIVE · Клуб Капитала',
      enName: 'EXECUTIVE · The Capital Club',
      layers: [
        {
          id: 'l-exe-1', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.6, w_mm: pW * 0.65, h_mm: titleSize * 1.2, rotation: 0,
          text: { content: 'E X E C U T I V E', font: 'Montserrat', size_mm: titleSize * 0.9, color: palette.gold, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-exe-2', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.3, w_mm: pW * 0.7, h_mm: subSize * 1.5, rotation: 0,
          text: { content: 'GLOBAL VENTURES & ADVISORY', font: 'Montserrat', size_mm: subSize * 0.9, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-exe-3', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 1.0, w_mm: pW * 0.5, h_mm: subSize * 1.2, rotation: 0,
          text: { content: 'CONFIDENTIAL', font: 'Montserrat', size_mm: subSize * 0.75, color: palette.muted, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'NOCTURNE · Midnight Roast',
      category: 'Quotes',
      concept: 'Tungi ijod va kofe madaniyati uchun zamonaviy dizayn',
      ruName: 'NOCTURNE · Полуночный Обжиг',
      enName: 'NOCTURNE · Midnight Roast',
      layers: [
        {
          id: 'l-noc-1', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.4, w_mm: pW * 0.6, h_mm: titleSize * 1.2, rotation: 0,
          text: { content: 'NOCTURNE', font: 'Playfair Display', size_mm: titleSize * 1.05, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-noc-2', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.6, w_mm: pW * 0.7, h_mm: subSize * 1.4, rotation: 0,
          text: { content: 'DARK ROAST · PURE INSPIRATION', font: 'Montserrat', size_mm: subSize * 0.85, color: palette.gold, align: 'center', bold: false, italic: false }
        }
      ]
    },
    {
      name: 'DIZZO ARCHIVE · Heritage Craft',
      category: 'Minimal Luxury',
      concept: 'Dizzo brendining o‘ziga xos hunarmandlik va sifat muhri',
      ruName: 'DIZZO ARCHIVE · Наследие Мастерства',
      enName: 'DIZZO ARCHIVE · Heritage Craft',
      layers: [
        {
          id: 'l-diz-mark', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy - gap * 0.7, w_mm: pW * 0.55, h_mm: titleSize * 1.3, rotation: 0,
          text: { content: 'D I Z Z O', font: 'Montserrat', size_mm: titleSize * 1.15, color: palette.primary, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-diz-craft', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 0.3, w_mm: pW * 0.6, h_mm: subSize * 1.4, rotation: 0,
          text: { content: 'CRAFT STUDIO & ATELIER', font: 'Montserrat', size_mm: subSize * 0.95, color: palette.gold, align: 'center', bold: true, italic: false }
        },
        {
          id: 'l-diz-sub', area, method: 'uv', kind: 'text',
          x_mm: cx, y_mm: cy + gap * 1.0, w_mm: pW * 0.5, h_mm: subSize * 1.2, rotation: 0,
          text: { content: 'SERIES 01 · TASHKENT', font: 'Montserrat', size_mm: subSize * 0.75, color: palette.muted, align: 'center', bold: false, italic: false }
        }
      ]
    }
  ];
}

module.exports = { CATALOG, getPalettes, generateConcepts };
