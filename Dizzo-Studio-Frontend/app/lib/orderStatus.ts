// Order statuses: labels follow the current language, read at call time.
type StatusTone = 'neutral' | 'warn' | 'success' | 'info' | 'danger' | 'brand';

const tr = (key: string) => useNuxtApp().$i18n.t(key);

const STATUS_META: Record<string, { className: string; tone: StatusTone }> = {
  NEW: { className: 'bg-sky-50 text-sky-700 border-sky-200 dark:bg-sky-950/40 dark:text-sky-300 dark:border-sky-800/50', tone: 'info' },
  PAYMENT_PENDING: { className: 'bg-amber-50 text-amber-700 border-amber-200', tone: 'warn' },
  PAID: { className: 'bg-emerald-50 text-emerald-700 border-emerald-200', tone: 'success' },
  MODERATED: { className: 'bg-teal-50 text-teal-700 border-teal-200 dark:bg-teal-950/40 dark:text-teal-300 dark:border-teal-800/50', tone: 'brand' },
  READY_FOR_PRODUCTION: { className: 'bg-blue-50 text-blue-700 border-blue-200', tone: 'info' },
  IN_PRODUCTION: { className: 'bg-indigo-50 text-indigo-700 border-indigo-200', tone: 'brand' },
  QUALITY_CHECK: { className: 'bg-purple-50 text-purple-700 border-purple-200', tone: 'info' },
  READY_FOR_PICKUP: { className: 'bg-teal-50 text-teal-700 border-teal-200', tone: 'success' },
  READY_FOR_DELIVERY: { className: 'bg-cyan-50 text-cyan-700 border-cyan-200', tone: 'info' },
  COMPLETED: { className: 'bg-emerald-50 text-emerald-700 border-emerald-200', tone: 'success' },
  CANCELLED: { className: 'bg-rose-50 text-rose-700 border-rose-200', tone: 'danger' },
};

export function getOrderStatusMeta(status: string): { label: string; className: string; tone: StatusTone } {
  const meta = STATUS_META[status];
  if (!meta) return { label: status, className: 'bg-slate-100 text-slate-700 border-slate-200', tone: 'neutral' };
  return { label: tr(`user.orderStatus.${status}`), ...meta };
}

type ProductionStatus = 'PENDING' | 'PRINTING' | 'PRINTED' | 'PACKED';

/** Production step labels, in the current language (read on access). */
export const PRODUCTION_LABELS: Readonly<Record<ProductionStatus, string>> = {
  get PENDING() { return tr('user.production.PENDING'); },
  get PRINTING() { return tr('user.production.PRINTING'); },
  get PRINTED() { return tr('user.production.PRINTED'); },
  get PACKED() { return tr('user.production.PACKED'); },
};

// The customer's order page (and the app's, lib/features/orders/domain/order_status.dart).

const STEP_KEYS = ['received', 'payment', 'production', 'ready', 'completed'] as const;

/** The five steps' short names, in order, in the current language. */
export function orderStepLabels(): string[] {
  return STEP_KEYS.map(k => tr(`user.steps.${k}`));
}

/** Which step a status is on (-1: cancelled). */
export function orderStep(status: string): number {
  switch (status) {
    case 'NEW': case 'PAYMENT_PENDING': return 0;
    case 'PAID': return 1;
    case 'MODERATED': case 'READY_FOR_PRODUCTION': case 'IN_PRODUCTION': case 'QUALITY_CHECK': return 2;
    case 'READY_FOR_PICKUP': case 'READY_FOR_DELIVERY': return 3;
    case 'COMPLETED': return 4;
    default: return -1;
  }
}

/** One short line under the tracker: what happens next. */
export function orderNextStep(status: string): string | null {
  switch (status) {
    case 'NEW': case 'PAYMENT_PENDING': case 'PAID': case 'MODERATED': case 'QUALITY_CHECK':
    case 'READY_FOR_PICKUP': case 'READY_FOR_DELIVERY':
      return tr(`user.nextStep.${status}`);
    case 'READY_FOR_PRODUCTION': case 'IN_PRODUCTION': return tr('user.nextStep.IN_PRODUCTION');
    default: return null;
  }
}

/** The payment state as a chip (null for a cancelled order). */
export function orderPaymentMeta(status: string): { label: string; tone: StatusTone } | null {
  if (status === 'CANCELLED') return null;
  if (status === 'NEW') return { label: tr('user.payment.unpaid'), tone: 'neutral' };
  if (status === 'PAYMENT_PENDING') return { label: tr('user.payment.pending'), tone: 'warn' };
  return { label: tr('user.payment.paid'), tone: 'success' };
}

/** While the items are being made, each shows its own production step. */
export function orderShowsProduction(status: string): boolean {
  return status === 'READY_FOR_PRODUCTION' || status === 'IN_PRODUCTION' || status === 'QUALITY_CHECK';
}

/** Dizzo's Telegram, for questions about an order. */
export const SUPPORT_TELEGRAM_URL = 'https://t.me/dizzo_uz';
