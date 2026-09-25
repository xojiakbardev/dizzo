import '../../../core/l10n/app_language.dart';
import '../../../core/utils/json.dart';
import '../../orders/domain/order_status.dart';

/// A review the customer left on a completed order (`ReviewOut`,
/// app/schemas/review.py).
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.text,
    this.city = '',
    this.productName = '',
    this.productSlug = '',
    this.photos = const [],
    this.status = 'pending',
    this.orderId,
    this.orderNumber,
    this.createdAt,
  });

  factory Review.fromJson(Json json) => Review(
        id: json.integer('id'),
        rating: json.integer('rating', 5).clamp(1, 5),
        text: json.str('text'),
        city: json.str('city'),
        productName: json.str('product_name'),
        productSlug: json.str('product_slug'),
        photos: json.strings('photos'),
        status: json.str('status', 'pending'),
        orderId: json.intOrNull('order_id'),
        orderNumber: json.strOrNull('order_number'),
        createdAt: json.date('created_at'),
      );

  final int id;
  final int rating;
  final String text;
  final String city;
  final String productName;
  final String productSlug;
  final List<String> photos;

  /// pending, approved, rejected.
  final String status;
  final int? orderId;
  final String? orderNumber;
  final DateTime? createdAt;

  ({String label, StatusTone tone}) statusMeta(AppLocalizations l) => switch (status) {
        'approved' => (label: l.reviewsStatusApproved, tone: StatusTone.success),
        'rejected' => (label: l.reviewsStatusRejected, tone: StatusTone.neutral),
        _ => (label: l.reviewsStatusPending, tone: StatusTone.warn),
      };
}

/// Limits of `ReviewIn`.
abstract final class ReviewRules {
  static const minText = 10;
  static const maxText = 1000;
  static const maxCity = 80;
  static const maxPhotos = 6;
  static const maxPhotoBytes = 10 * 1024 * 1024;
}
