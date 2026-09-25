import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';

/// "149 000 so‘m", optionally prefixed ("dan" suffix for from-prices).
///
/// The currency is drawn smaller and lighter than the number.
class PriceText extends StatelessWidget {
  const PriceText(
    this.value, {
    super.key,
    this.style,
    this.from = false,
    this.color,
  });

  final Money value;
  final TextStyle? style;

  /// Adds "dan" / "от" / "from": the cheapest option of a product.
  final bool from;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? context.text.titleMedium!).copyWith(
      color: color ?? context.colors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final small = base.copyWith(
      fontSize: (base.fontSize ?? 16) * 0.78,
      fontWeight: FontWeight.w600,
      color: (color ?? context.colors.ink).withValues(alpha: 0.62),
    );
    final l = context.l10n;
    // "{price} dan" / "от {price}" / "from {price}": the words around it.
    final parts = from ? l.priceFrom('\u0000').split('\u0000') : const ['', ''];
    final before = parts.first.trim();
    final after = parts.last.trim();
    return Text.rich(
      TextSpan(
        children: [
          if (before.isNotEmpty) TextSpan(text: '$before ', style: small),
          TextSpan(text: value.format(withCurrency: false), style: base),
          TextSpan(text: ' ${l.currencySum}', style: small),
          if (after.isNotEmpty) TextSpan(text: ' $after', style: small),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
