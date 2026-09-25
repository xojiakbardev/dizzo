import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/widgets/sign_in_prompt.dart';
import '../data/reviews_api.dart';
import 'widgets/review_widgets.dart';

/// "Fikrlarim": the reviews the customer left on completed orders.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myReviewsProvider);
    try {
      await ref.read(myReviewsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.reviewsTitle)),
        body: SignInPrompt(icon: Icons.rate_review_outlined, title: context.l10n.reviewsSignIn),
      );
    }
    final reviews = ref.watch(myReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reviewsTitle)),
      body: reviews.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => SkeletonScope(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xl),
            itemCount: 3,
            separatorBuilder: (_, _) => Gap.md,
            itemBuilder: (_, _) => const ContentWidth(
              maxWidth: Breakpoints.formMaxWidth + 240,
              child: ReviewCardSkeleton(),
            ),
          ),
        ),
        error: (e, _) => ErrorState(error: e, onRetry: () => _refresh(ref)),
        data: (items) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: items.isEmpty
              ? LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: c.maxHeight,
                      child: EmptyState(
                        icon: Icons.rate_review_outlined,
                        title: context.l10n.reviewsEmpty,
                        actionLabel: context.l10n.profileMyOrders,
                        onAction: () => context.push(Routes.orders),
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Gap.md,
                  itemBuilder: (context, i) {
                    final r = items[i];
                    return ContentWidth(
                      maxWidth: Breakpoints.formMaxWidth + 240,
                      child: ReviewCard(
                        review: r,
                        onOpenOrder: r.orderNumber == null ? null : () => context.push(Routes.order(r.orderNumber!)),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
