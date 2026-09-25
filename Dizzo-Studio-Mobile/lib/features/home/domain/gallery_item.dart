import '../../../core/utils/json.dart';

/// A finished customer work or a gallery design (`GET /gallery/`).
/// Designs have a negative [orderItemId] and a [templateId] to start from.
class GalleryItem {
  const GalleryItem({
    required this.orderItemId,
    required this.productName,
    required this.customerName,
    required this.imageUrl,
    this.createdAt,
    this.title,
    this.productSlug,
    this.templateId,
    this.variantId,
    this.colorId,
  });

  factory GalleryItem.fromJson(Json json) => GalleryItem(
        orderItemId: json.integer('order_item_id'),
        productName: json.str('product_name'),
        customerName: json.str('customer_name'),
        imageUrl: json.str('preview_image_url'),
        createdAt: json.date('created_at'),
        title: json.strOrNull('title'),
        productSlug: json.strOrNull('product_slug'),
        templateId: json['template_id'] is int ? json['template_id'] as int : null,
        variantId: json['variant_id'] is int ? json['variant_id'] as int : null,
        colorId: json['color_id'] is int ? json['color_id'] as int : null,
      );

  final int orderItemId;
  final String productName;
  final String customerName;
  final String imageUrl;
  final DateTime? createdAt;
  final String? title;
  final String? productSlug;
  final int? templateId;
  final int? variantId;
  final int? colorId;

  /// Opens in the editor: a gallery design with its product.
  bool get canOpen => templateId != null && (productSlug?.isNotEmpty ?? false);

  /// The caption: the sample's title, else the product.
  String get heading => (title?.trim().isNotEmpty ?? false) ? title!.trim() : productName;
}
