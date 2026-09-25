import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/widgets/item_parts.dart';
import '../../cart/presentation/widgets/mockup_gallery.dart';
import '../../profile/presentation/widgets/sign_in_prompt.dart';
import '../data/designs_api.dart';

/// "Dizaynlarim" tab: saved Studio designs to reopen or delete.
class DesignsScreen extends ConsumerWidget {
  const DesignsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myDesignsProvider);
    try {
      await ref.read(myDesignsProvider.future);
    } catch (_) {}
  }

  void _open(BuildContext context, DesignSummary d) =>
      context.push(Routes.editor(d.productSlug, design: d.id));

  Future<void> _delete(BuildContext context, WidgetRef ref, DesignSummary d) async {
    final ok = await confirmSheet(
      context,
      title: context.l10n.designsDeleteConfirm,
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(myDesignsProvider.notifier).delete(d.id);
      if (context.mounted) showAppSnack(context, context.l10n.designsDeleted);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.navDesigns)),
        body: SignInPrompt(icon: Icons.brush_outlined, title: context.l10n.designsSignIn),
      );
    }
    final designs = ref.watch(myDesignsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navDesigns),
        actions: [
          IconButton(
            tooltip: context.l10n.designsNew,
            onPressed: () => context.go(Routes.products),
            icon: const Icon(Icons.add_rounded),
          ),
          const Gap(Insets.xs),
        ],
      ),
      body: designs.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const _GridSkeleton(),
        error: (e, _) => ErrorState(error: e, onRetry: () => _refresh(ref)),
        data: (items) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.brush_outlined,
                    title: context.l10n.designsEmpty,
                    actionLabel: context.l10n.designsCreate,
                    onAction: () => context.go(Routes.products),
                  ),
                )
              else
                SliverPageBody(
                  padTop: Insets.sm,
                  padBottom: Insets.xl,
                  sliver: _DesignGrid(
                    count: items.length,
                    builder: (i) => DesignCard(
                      design: items[i],
                      onOpen: () => _open(context, items[i]),
                      onDelete: () => _delete(context, ref, items[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grid whose tiles are a square picture plus text sized for the user's
/// text scale.
class _DesignGrid extends StatelessWidget {
  const _DesignGrid({required this.count, required this.builder});

  final int count;
  final Widget Function(int i) builder;

  @override
  Widget build(BuildContext context) {
    final textHeight = MediaQuery.textScalerOf(context).scale(1) * 66 + 20;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = ResponsiveContext.productColumnsFor(width);
        final tileWidth = (width - Insets.md * (columns - 1)) / columns;
        return SliverGrid.builder(
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: Insets.md,
            crossAxisSpacing: Insets.md,
            mainAxisExtent: tileWidth + textHeight,
          ),
          itemBuilder: (_, i) => builder(i),
        );
      },
    );
  }
}

class DesignCard extends StatelessWidget {
  const DesignCard({super.key, required this.design, required this.onOpen, required this.onDelete});

  final DesignSummary design;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.brLg, side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MockupGallery(
                    images: design.previews,
                    borderRadius: BorderRadius.zero,
                    fallbackIcon: Icons.brush_outlined,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: PopupMenuButton<String>(
                      tooltip: context.l10n.designsActions,
                      onSelected: (v) => v == 'open' ? onOpen() : onDelete(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'open',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(context.l10n.designsEdit),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded, color: c.danger),
                            title: Text(context.l10n.commonDelete, style: TextStyle(color: c.danger)),
                          ),
                        ),
                      ],
                      child: const IgnorePointer(
                        child: CircleIconButton(icon: Icons.more_horiz_rounded, onPressed: null, size: 34),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(design.productName, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Gap(2),
                    OptionsLine(variant: design.variantName, colorName: design.colorName, color: design.color),
                    const Spacer(),
                    if (design.updatedAt != null)
                      Text(
                        AppDates.date(design.updatedAt!, context.l10n.localeName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(color: c.inkSubtle),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverPageBody(
            padTop: Insets.sm,
            sliver: _DesignGrid(
              count: 6,
              builder: (_) => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 1, child: Skeleton(borderRadius: Radii.brLg)),
                  Gap(10),
                  Skeleton.line(width: 110, height: 13),
                  Gap(8),
                  Skeleton.line(width: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
