/// Every route path in one place. Navigate with these helpers, never with
/// string literals: `context.push(Routes.product(slug))`.
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';

  // Bottom-navigation tabs.
  static const home = '/';
  static const products = '/products';
  static const designs = '/designs';
  static const cart = '/cart';
  static const profile = '/profile';

  // Full-screen pages (above the tab bar).
  static const productPattern = '/product/:slug';

  /// A product page. Query: the chosen `variant`, `color` (ids) and `size`
  /// (label), as on the web, so a shared or restored link shows the same
  /// choice.
  static String product(String slug, {Map<String, String> query = const {}}) => Uri(
        path: '/product/${Uri.encodeComponent(slug)}',
        queryParameters: query.isEmpty ? null : query,
      ).toString();

  /// The design editor (Studio). Query: `variant`, `color` (ids), and
  /// optionally `size` (a size label), `design` (a saved design to reopen)
  /// and `from` (a gallery design to start from).
  static const editorPattern = '/editor/:slug';
  static String editor(String slug, {int? variant, int? color, String? size, String? design, int? from}) {
    final query = {
      if (variant != null) 'variant': '$variant',
      if (color != null) 'color': '$color',
      if (size != null && size.isNotEmpty) 'size': size,
      'design': ?design,
      if (from != null) 'from': '$from',
    };
    return Uri(
      path: '/editor/${Uri.encodeComponent(slug)}',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static const checkout = '/checkout';
  static const orders = '/orders';
  static const orderPattern = '/orders/:id';
  static String order(Object id) => '/orders/$id';

  /// "Fikrlarim": the customer's reviews.
  static const reviews = '/reviews';

  /// Account-only pages: guests are sent to [welcome] first.
  static bool requiresAuth(String location) =>
      location == checkout || location == orders || location.startsWith('$orders/') || location == reviews;

  /// A dizzo.uz link (App Link / Universal Link) as an app location, or null
  /// when [uri] is already an app path. Web pages the app has no screen for
  /// open the home tab. The query (variant, color, size…) is kept.
  static String? fromWeb(Uri uri) {
    final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    String keep(String path) => uri.hasQuery ? '$path?${uri.query}' : path;
    if (s.length == 2 && s[0] == 'products') return keep(product(s[1]));
    if (s.length == 2 && s[0] == 'studio') return keep(editor(s[1]));
    if (s.isEmpty) return null;
    return switch (s) {
      ['catalog'] => products,
      ['gallery'] || ['login'] || ['register'] || ['litsenziyalar'] => home,
      ['user', 'cart'] => cart,
      ['user', 'checkout'] => checkout,
      ['user', 'designs'] => designs,
      ['user', 'feedback'] => reviews,
      ['user', 'profile'] => profile,
      ['user', 'orders'] => orders,
      ['user', 'orders', final id] => order(id),
      _ => null,
    };
  }

  static String welcomeFrom(String from) =>
      Uri(path: welcome, queryParameters: {'from': from}).toString();
}
