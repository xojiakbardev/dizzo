import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../domain/order_status.dart';

export '../../domain/order_status.dart' show StatusTone;

/// A small rounded status label (orders, production, reviews).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone, this.dense = false});

  final String label;
  final StatusTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (tone) {
      StatusTone.neutral => c.inkMuted,
      StatusTone.warn => c.warning,
      StatusTone.success => c.success,
      StatusTone.info => c.accent,
      StatusTone.danger => c.danger,
      StatusTone.brand => c.brand,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const Gap(6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? context.text.labelSmall : context.text.labelMedium)
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
