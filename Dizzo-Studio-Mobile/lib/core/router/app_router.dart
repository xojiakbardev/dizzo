import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/designs/presentation/designs_screen.dart';
import '../../features/editor/presentation/editor_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/my_reviews_screen.dart';
import '../l10n/locale_controller.dart';
import '../widgets/brand_loader.dart';
import 'app_shell.dart';
import 'routes.dart';

// The router is the app's composition root, so it (alone in core) imports
// feature screens.

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(welcomeSeenProvider, (_, _) => refresh.value++);
  ref.listen(appLanguageLoadedProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    // A dizzo.uz link: its web path first becomes the app's.
    final web = Routes.fromWeb(state.uri);
    if (web != null) return web;
    final auth = ref.read(authControllerProvider);
    final welcomeSeen = ref.read(welcomeSeenProvider);
    final languageLoaded = ref.read(appLanguageLoadedProvider);
    final loc = state.matchedLocation;
    final here = state.uri.toString();

    // Startup: hold on the splash until the session and language are known.
    if (!auth.isResolved || welcomeSeen == null || !languageLoaded) {
      return loc == Routes.splash ? null : Uri(path: Routes.splash, queryParameters: {'from': here}).toString();
    }
    if (loc == Routes.splash) {
      final from = state.uri.queryParameters['from'];
      final target = (from == null || from.startsWith(Routes.splash)) ? Routes.home : from;
      if (!auth.isAuthenticated && !welcomeSeen) return Routes.welcomeFrom(target);
      if (!auth.isAuthenticated && Routes.requiresAuth(Uri.parse(target).path)) {
        return Routes.welcomeFrom(target);
      }
      return target;
    }
    if (loc == Routes.welcome && auth.isAuthenticated) {
      return state.uri.queryParameters['from'] ?? Routes.home;
    }
    if (!auth.isAuthenticated && Routes.requiresAuth(loc)) {
      return Routes.welcomeFrom(here);
    }
    return null;
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: redirect,
    // An unknown path (an old or foreign link) opens the home tab instead of
    // go_router's error page.
    onException: (_, _, router) => router.go(Routes.home),
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (_, _) => const NoTransitionPage(child: BrandLoaderScreen()),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (_, state) => WelcomeScreen(from: state.uri.queryParameters['from']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.products, builder: (_, _) => const CatalogScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.designs, builder: (_, _) => const DesignsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: Routes.productPattern,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ProductScreen(
            slug: state.pathParameters['slug']!,
            heroTag: state.extra is String ? state.extra! as String : null,
            variantId: int.tryParse(q['variant'] ?? ''),
            colorId: int.tryParse(q['color'] ?? ''),
            size: q['size'],
          );
        },
      ),
      GoRoute(
        path: Routes.editorPattern,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return EditorScreen(
            slug: state.pathParameters['slug']!,
            variantId: int.tryParse(q['variant'] ?? ''),
            colorId: int.tryParse(q['color'] ?? ''),
            size: q['size'],
            designId: q['design'],
            templateId: int.tryParse(q['from'] ?? ''),
          );
        },
      ),
      GoRoute(path: Routes.checkout, builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: Routes.orders,
        builder: (_, _) => const OrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: Routes.reviews, builder: (_, _) => const MyReviewsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
