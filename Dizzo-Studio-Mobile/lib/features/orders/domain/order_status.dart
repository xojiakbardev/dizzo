import '../../../core/l10n/app_language.dart';
import 'order_models.dart';

/// How a status reads: grey, amber, green, red or brand.
enum StatusTone { neutral, warn, success, info, danger, brand }

/// Label and tone of an order status (the web's `lib/orderStatus.ts`).
({String label, StatusTone tone}) orderStatusMeta(AppLocalizations l, String status) => switch (status) {
      OrderStatus.newOrder => (label: l.orderStatusNew, tone: StatusTone.neutral),
      OrderStatus.paymentPending => (label: l.orderStatusPaymentPending, tone: StatusTone.warn),
      OrderStatus.paid => (label: l.orderStatusPaid, tone: StatusTone.success),
      OrderStatus.moderated => (label: 'Moderatsiya qilindi', tone: StatusTone.brand),
      OrderStatus.readyForProduction => (label: l.orderStatusReadyForProduction, tone: StatusTone.info),
      OrderStatus.inProduction => (label: l.orderStatusInProduction, tone: StatusTone.brand),
      OrderStatus.qualityCheck => (label: l.orderStatusQualityCheck, tone: StatusTone.info),
      OrderStatus.readyForPickup => (label: l.orderStatusReadyForPickup, tone: StatusTone.success),
      OrderStatus.readyForDelivery => (label: l.orderStatusReadyForDelivery, tone: StatusTone.info),
      OrderStatus.completed => (label: l.orderStatusCompleted, tone: StatusTone.success),
      OrderStatus.cancelled => (label: l.orderStatusCancelled, tone: StatusTone.danger),
      _ => (label: status, tone: StatusTone.neutral),
    };

/// An order item's production step.
({String label, StatusTone tone}) productionStatusMeta(AppLocalizations l, String status) => switch (status) {
      'PRINTING' => (label: l.productionPrinting, tone: StatusTone.brand),
      'PRINTED' => (label: l.productionPrinted, tone: StatusTone.info),
      'PACKED' => (label: l.productionPacked, tone: StatusTone.success),
      _ => (label: l.productionQueued, tone: StatusTone.neutral),
    };

/// Which of the customer's five steps a status is on (-1: cancelled).
int orderStep(String status) => switch (status) {
      OrderStatus.newOrder || OrderStatus.paymentPending => 0,
      OrderStatus.paid => 1,
      OrderStatus.moderated || OrderStatus.readyForProduction || OrderStatus.inProduction || OrderStatus.qualityCheck => 2,
      OrderStatus.readyForPickup || OrderStatus.readyForDelivery => 3,
      OrderStatus.completed => 4,
      _ => -1,
    };

/// Short names of the five steps (the tracker; the web uses the same).
List<String> orderStepLabels(AppLocalizations l) =>
    [l.orderStepAccepted, l.orderStepPayment, l.orderStepProduction, l.orderStepReady, l.orderStepDone];

/// One short line under the tracker: what happens next (null: nothing to say).
String? orderNextStep(AppLocalizations l, String status, {required bool pickup}) => switch (status) {
      OrderStatus.newOrder => l.orderNextNew,
      OrderStatus.paymentPending => l.orderNextPaymentPending,
      OrderStatus.paid => l.orderNextPaid,
      OrderStatus.moderated || OrderStatus.readyForProduction || OrderStatus.inProduction => l.orderNextInProduction,
      OrderStatus.qualityCheck => l.orderNextQualityCheck,
      OrderStatus.readyForPickup => l.orderNextReadyForPickup,
      OrderStatus.readyForDelivery => l.orderNextReadyForDelivery,
      _ => null,
    };

/// The payment state as a chip (null for a cancelled order).
({String label, StatusTone tone})? orderPaymentMeta(AppLocalizations l, String status) => switch (status) {
      OrderStatus.cancelled => null,
      OrderStatus.newOrder => (label: l.paymentUnpaid, tone: StatusTone.neutral),
      OrderStatus.paymentPending => (label: l.orderStatusPaymentPending, tone: StatusTone.warn),
      _ => (label: l.orderStatusPaid, tone: StatusTone.success),
    };

/// While the items are being made, each shows its own production step.
bool orderShowsProduction(String status) =>
    status == OrderStatus.readyForProduction ||
    status == OrderStatus.inProduction ||
    status == OrderStatus.qualityCheck;

/// Dizzo's Telegram, for questions about an order.
const supportTelegramUrl = 'https://t.me/dizzo_uz';
