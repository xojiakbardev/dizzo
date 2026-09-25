import 'dart:ui' show Color;

import '../../../core/utils/json.dart';
import '../../../core/utils/money.dart';
import '../../cart/domain/cart_models.dart';
import '../../catalog/domain/catalog_models.dart';

// Mirrors the backend's order payloads (app/services/orders.py) and the
// web's `OrderSummary` / `OrderDetail` (app/types/commerce.ts).

abstract final class OrderStatus {
  static const newOrder = 'NEW';
  static const paymentPending = 'PAYMENT_PENDING';
  static const paid = 'PAID';
  static const moderated = 'MODERATED';
  static const readyForProduction = 'READY_FOR_PRODUCTION';
  static const inProduction = 'IN_PRODUCTION';
  static const qualityCheck = 'QUALITY_CHECK';
  static const readyForPickup = 'READY_FOR_PICKUP';
  static const readyForDelivery = 'READY_FOR_DELIVERY';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
}

abstract final class DeliveryMethod {
  static const delivery = 'DELIVERY';
  static const pickup = 'PICKUP';
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    this.deliveryMethod = DeliveryMethod.delivery,
    this.createdAt,
  });

  factory OrderSummary.fromJson(Json json) => OrderSummary(
        id: json.integer('id'),
        orderNumber: json.str('order_number'),
        status: json.str('status', OrderStatus.newOrder),
        deliveryMethod: json.str('delivery_method', DeliveryMethod.delivery),
        totalAmount: Money.parse(json['total_amount']),
        itemCount: json.integer('item_count'),
        createdAt: json.date('created_at'),
      );

  final int id;
  final String orderNumber;
  final String status;
  final String deliveryMethod;
  final Money totalAmount;

  /// Pieces (sum of quantities).
  final int itemCount;
  final DateTime? createdAt;
}

class OrderStats {
  const OrderStats({
    this.totalOrders = 0,
    this.paymentPending = 0,
    this.inProduction = 0,
    this.done = 0,
    this.totalSpent = Money.zero,
  });

  factory OrderStats.fromJson(Json json) => OrderStats(
        totalOrders: json.integer('total_orders'),
        paymentPending: json.integer('payment_pending_orders'),
        inProduction: json.integer('in_production_orders'),
        done: json.integer('done_orders'),
        totalSpent: Money.parse(json['total_spent']),
      );

  final int totalOrders;
  final int paymentPending;
  final int inProduction;
  final int done;

  /// Sum of completed orders.
  final Money totalSpent;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productSlug = '',
    this.variantName = '',
    this.colorName = '',
    this.colorHex = '',
    this.size = '',
    this.productionStatus = 'PENDING',
    this.printLines = const [],
    this.mockups = const [],
  });

  factory OrderItem.fromJson(Json json) => OrderItem(
        id: json.integer('id'),
        productName: json.str('product_name'),
        productSlug: json.str('product_slug'),
        variantName: json.str('variant_name'),
        colorName: json.str('color_name'),
        colorHex: json.str('color_hex'),
        size: json.str('size'),
        quantity: json.integer('quantity', 1),
        unitPrice: Money.parse(json['unit_price']),
        totalPrice: Money.parse(json['total_price']),
        productionStatus: json.str('production_status', 'PENDING'),
        printLines: json.obj('quote').list('methods', PrintLine.fromJson),
        mockups: json.strings('mockups'),
      );

  final int id;
  final String productName;
  final String productSlug;
  final String variantName;
  final String colorName;
  final String colorHex;
  final String size;
  final int quantity;
  final Money unitPrice;
  final Money totalPrice;

  /// PENDING, PRINTING, PRINTED, PACKED.
  final String productionStatus;
  final List<PrintLine> printLines;
  final List<String> mockups;

  Color? get color => colorHex.isEmpty ? null : parseHexColor(colorHex);
}

class OrderPayment {
  const OrderPayment({required this.method, required this.status, required this.amount});

  factory OrderPayment.fromJson(Json json) => OrderPayment(
        method: json.str('payment_method'),
        status: json.str('status'),
        amount: Money.parse(json['amount']),
      );

  final String method;
  final String status;
  final Money amount;
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.subtotal = Money.zero,
    this.shippingCost = Money.zero,
    this.discountAmount = Money.zero,
    this.deliveryMethod = DeliveryMethod.delivery,
    this.latitude,
    this.longitude,
    this.shippingName = '',
    this.shippingPhone = '',
    this.shippingAddress = '',
    this.shippingCity = '',
    this.customerNotes = '',
    this.trackingNumber = '',
    this.carrier = '',
    this.items = const [],
    this.payments = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory OrderDetail.fromJson(Json json) => OrderDetail(
        id: json.integer('id'),
        orderNumber: json.str('order_number'),
        status: json.str('status', OrderStatus.newOrder),
        subtotal: Money.parse(json['subtotal']),
        shippingCost: Money.parse(json['shipping_cost']),
        discountAmount: Money.parse(json['discount_amount']),
        totalAmount: Money.parse(json['total_amount']),
        deliveryMethod: json.str('delivery_method', DeliveryMethod.delivery),
        latitude: json['latitude'] == null ? null : json.dbl('latitude'),
        longitude: json['longitude'] == null ? null : json.dbl('longitude'),
        shippingName: json.str('shipping_name'),
        shippingPhone: json.str('shipping_phone'),
        shippingAddress: json.str('shipping_address'),
        shippingCity: json.str('shipping_city'),
        customerNotes: json.str('customer_notes'),
        trackingNumber: json.str('tracking_number'),
        carrier: json.str('carrier'),
        items: json.list('items', OrderItem.fromJson),
        payments: json.list('payments', OrderPayment.fromJson),
        createdAt: json.date('created_at'),
        updatedAt: json.date('updated_at'),
      );

  final int id;
  final String orderNumber;
  final String status;
  final Money subtotal;
  final Money shippingCost;
  final Money discountAmount;
  final Money totalAmount;
  final String deliveryMethod;
  final double? latitude;
  final double? longitude;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String shippingCity;
  final String customerNotes;
  final String trackingNumber;
  final String carrier;
  final List<OrderItem> items;
  final List<OrderPayment> payments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPickup => deliveryMethod == DeliveryMethod.pickup;

  /// Only an order nobody has confirmed yet can be cancelled by the customer.
  bool get canCancel => status == OrderStatus.newOrder;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;
  int get pieces => items.fold(0, (a, i) => a + i.quantity);
}

/// `POST /checkout/` answer.
class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    this.order,
  });

  factory CheckoutResult.fromJson(Json json) {
    final order = json.objOrNull('order');
    return CheckoutResult(
      orderId: json.integer('order_id'),
      orderNumber: json.str('order_number'),
      totalAmount: Money.parse(json['total_amount']),
      status: json.str('status', OrderStatus.newOrder),
      order: order == null ? null : OrderDetail.fromJson(order),
    );
  }

  final int orderId;
  final String orderNumber;
  final Money totalAmount;
  final String status;
  final OrderDetail? order;
}
