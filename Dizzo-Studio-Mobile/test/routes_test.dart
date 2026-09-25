import 'package:dizzo/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

String? web(String link) => Routes.fromWeb(Uri.parse(link));

void main() {
  test('dizzo.uz links map to app locations', () {
    expect(web('https://dizzo.uz/products/krujka?variant=3&color=7'), '/product/krujka?variant=3&color=7');
    expect(web('https://dizzo.uz/studio/futbolka'), '/editor/futbolka');
    expect(web('https://dizzo.uz/catalog'), Routes.products);
    expect(web('https://www.dizzo.uz/user/orders/42'), '/orders/42');
    expect(web('https://dizzo.uz/user/feedback'), Routes.reviews);
    expect(web('https://dizzo.uz/gallery'), Routes.home);
  });

  test('app paths are left alone', () {
    for (final path in ['/', '/products', '/product/krujka', '/orders/5', '/splash?from=%2F', '/admin']) {
      expect(web(path), isNull, reason: path);
    }
  });
}
