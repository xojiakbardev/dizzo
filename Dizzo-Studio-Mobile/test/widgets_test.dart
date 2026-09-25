import 'package:dizzo/core/theme/app_theme.dart';
import 'package:dizzo/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/l10n.dart';

Widget wrap(Widget child) => MaterialApp(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('BrandLoader animates without errors through a full loop', (tester) async {
    await tester.pumpWidget(wrap(const Center(child: BrandLoader())));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.bySemanticsLabel('Yuklanmoqda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BrandLoader keeps a calm loop when animations are disabled', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: wrap(const BrandLoader()),
    ));
    // Only the sparks' opacity changes; it still shows it is loading.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(BrandLoader), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ProductCard shows name and from-price', (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 180,
      child: ProductCard(name: 'Krujka', imageUrl: null, price: Money.parse('49000.00')),
    )));
    expect(find.text('Krujka'), findsOneWidget);
    expect(find.textContaining('49 000', findRichText: true), findsOneWidget);
    expect(find.textContaining('dan', findRichText: true), findsOneWidget);
  });

  testWidgets('EmptyState has a title and an action, no description', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(EmptyState(
      title: 'Savat bo‘sh',
      actionLabel: 'Mahsulot tanlash',
      onAction: () => tapped = true,
    )));
    expect(find.byType(Text), findsNWidgets(2));
    await tester.tap(find.text('Mahsulot tanlash'));
    expect(tapped, isTrue);
  });

  testWidgets('AppButton shows a spinner and ignores taps while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(AppButton(label: 'Kirish', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
  });
}
