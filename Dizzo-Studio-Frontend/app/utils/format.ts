// Auto-imported by Nuxt (app/utils/*) — no manual import needed in components.
// Money and dates in the page's language (uz, ru, en), spelled by hand so the
// server and every browser print the same thing (Intl differs between them
// for Uzbek, which also broke hydration).

type Lang = 'uz' | 'ru' | 'en';

/** The page's language; Uzbek outside a Nuxt context. */
export function currentLang(): Lang {
  try {
    const code = useNuxtApp().$i18n?.locale?.value;
    return code === 'ru' || code === 'en' ? code : 'uz';
  }
  catch {
    return 'uz';
  }
}

const CURRENCY: Record<Lang, string> = { uz: 'UZS', ru: 'UZS', en: 'UZS' };

/** "80 000 UZS" */
export function formatMoney(value: number | string): string {
  const amount = Math.round(typeof value === 'string' ? Number(value) : value);
  const grouped = String(amount).replace(/\B(?=(\d{3})+(?!\d))/g, currentLang() === 'en' ? ',' : ' ');
  return `${grouped} ${CURRENCY[currentLang()]}`;
}

// Month names: Uzbek as the site writes them; Russian in the genitive for
// "1 сентября", the nominative for "сентябрь 2026".
const MONTHS: Record<Lang, string[]> = {
  uz: ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'],
  ru: ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'],
  en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
};
const MONTHS_ALONE: Record<Lang, string[]> = {
  uz: MONTHS.uz,
  ru: ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'],
  en: MONTHS.en,
};

/** "sentabr 2026" / "сентябрь 2026" / "September 2026" */
export function formatMonth(iso: string): string {
  const date = new Date(iso);
  return `${MONTHS_ALONE[currentLang()][date.getMonth()]} ${date.getFullYear()}`;
}

// Dates everywhere read the same, in Tashkent time (so the server and the
// browser agree).
const TASHKENT = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Tashkent', year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
});
function partsOf(value: string | number | Date) {
  const parts = Object.fromEntries(TASHKENT.formatToParts(new Date(value)).map(p => [p.type, p.value]));
  return { day: Number(parts.day), month: Number(parts.month), year: parts.year, time: `${parts.hour}:${parts.minute}` };
}

/** "1-sentabr" / "1 сентября" / "September 1" */
function dayMonth(p: ReturnType<typeof partsOf>): string {
  const lang = currentLang();
  const month = MONTHS[lang][p.month - 1];
  if (lang === 'ru') return `${p.day} ${month}`;
  if (lang === 'en') return `${month} ${p.day}`;
  return `${p.day}-${month}`;
}

/** "1-sentabr 2026 yil" / "1 сентября 2026 г." / "September 1, 2026" */
export function formatDate(value: string | number | Date): string {
  const p = partsOf(value);
  const lang = currentLang();
  if (lang === 'ru') return `${dayMonth(p)} ${p.year} г.`;
  if (lang === 'en') return `${dayMonth(p)}, ${p.year}`;
  return `${dayMonth(p)} ${p.year} yil`;
}

/** "1-sentabr 2026 yil 22:00" */
export function formatDateTime(value: string | number | Date): string {
  return `${formatDate(value)} ${partsOf(value).time}`;
}

/** "1-sentabr 2026, 22:00" (one line under a title) */
export function formatDateTimeShort(value: string | number | Date): string {
  const p = partsOf(value);
  return `${dayMonth(p)} ${p.year}, ${p.time}`;
}

/** "1-sentabr" (chart axes, short lists) */
export function formatDayMonth(value: string | number | Date): string {
  return dayMonth(partsOf(value));
}
