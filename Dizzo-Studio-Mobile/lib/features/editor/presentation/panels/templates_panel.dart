import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/widgets.dart';
import '../../data/editor_api.dart';
import '../../domain/editor_models.dart';

/// "Galereya": ready designs checked against the current variant.
class TemplatesPanel extends ConsumerStatefulWidget {
  const TemplatesPanel({super.key, required this.slug, required this.variantId, required this.onPick});

  final String slug;
  final int? variantId;
  final ValueChanged<DesignTemplate> onPick;

  @override
  ConsumerState<TemplatesPanel> createState() => _TemplatesPanelState();
}

class _TemplatesPanelState extends ConsumerState<TemplatesPanel> {

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final async = ref.watch(templatesProvider(widget.slug));
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => GridView.builder(
        padding: EdgeInsets.symmetric(horizontal: pad),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          crossAxisSpacing: Insets.sm,
          mainAxisSpacing: Insets.sm,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const Skeleton(borderRadius: Radii.brMd),
      ),
      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(templatesProvider(widget.slug))),
      data: (all) {
        final list = [for (final t in all) if (t.variantIds.contains(widget.variantId)) t];
        if (list.isEmpty) {
          return EmptyState(title: context.l10n.editorTemplatesEmpty, icon: Icons.dashboard_outlined, compact: true);
        }
        final shown = list;
        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(pad, Insets.xs, pad, Insets.xl),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: Insets.sm,
                  mainAxisSpacing: Insets.sm,
                  childAspectRatio: 0.82,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final t = shown[i];
                  return InkWell(
                    borderRadius: Radii.brMd,
                    onTap: () => widget.onPick(t),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: context.colors.plate, borderRadius: Radii.brMd),
                            child: AppImage(t.previewUrl, borderRadius: Radii.brMd),
                          ),
                        ),
                        Gap.xs,
                        Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
