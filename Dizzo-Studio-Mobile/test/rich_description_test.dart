import 'package:dizzo/core/theme/app_theme.dart';
import 'package:dizzo/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/l10n.dart';

/// Everything the admin editor (TipTap) can write, as the backend keeps it
/// (Dizzo-Backend tests/test_rich_text.py uses the same sample).
const editorSample = '<h2>Sarlavha</h2><h3>Kichik sarlavha</h3>'
    '<p><strong>qalin</strong> <em>qiya</em> <u>tagi chiziq</u> <s>ustidan chiziq</s> <code>kod</code></p>'
    '<p>birinchi qator<br>ikkinchi qator</p><p></p>'
    '<ul><li><p>nuqtali</p></li><li><p>ro‘yxat</p></li></ul>'
    '<ol><li><p>raqamli</p></li></ol>'
    '<blockquote><p>iqtibos</p></blockquote>'
    '<p><a href="https://dizzo.uz/catalog" rel="noopener noreferrer nofollow" target="_blank">havola</a></p>';

Widget wrap(Widget child) => MaterialApp(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light,
      home: Scaffold(body: SizedBox(width: 390, child: SingleChildScrollView(child: child))),
    );

/// The style [text] is drawn with: its span's style over its parents'.
TextStyle styleOf(WidgetTester tester, String text) {
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    TextStyle? hit;
    void walk(InlineSpan span, TextStyle inherited) {
      final style = inherited.merge(span.style);
      if (span is TextSpan) {
        if (span.text != null && span.text!.contains(text)) hit ??= style;
        for (final c in span.children ?? const <InlineSpan>[]) {
          walk(c, style);
        }
      }
    }

    walk(rt.text, const TextStyle());
    if (hit != null) return hit!;
  }
  throw StateError('no text "$text"');
}

Rect rectOf(WidgetTester tester, String text) =>
    tester.getRect(find.textContaining(text, findRichText: true).first);

void main() {
  final colors = DizzoColors.light;

  testWidgets('renders every editor feature with the web .rich-text styles', (tester) async {
    await tester.pumpWidget(wrap(const RichDescription(editorSample)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Headings: 1.15em / 800 and 1.02em / 700 of the 14 px body.
    final h2 = styleOf(tester, 'Sarlavha');
    expect(h2.fontSize, closeTo(14 * 1.15, 0.01));
    expect(h2.fontWeight, FontWeight.w800);
    final h3 = styleOf(tester, 'Kichik sarlavha');
    expect(h3.fontSize, closeTo(14 * 1.02, 0.01));
    expect(h3.fontWeight, FontWeight.w700);

    // Body text in the ink colour, as the web's text-foreground.
    expect(styleOf(tester, 'birinchi qator').color, colors.ink);
    expect(styleOf(tester, 'birinchi qator').fontSize, 14);

    // Marks.
    expect(styleOf(tester, 'qalin').fontWeight, FontWeight.bold);
    expect(styleOf(tester, 'qiya').fontStyle, FontStyle.italic);
    expect(styleOf(tester, 'tagi chiziq').decoration, TextDecoration.underline);
    expect(styleOf(tester, 'ustidan chiziq').decoration, TextDecoration.lineThrough);
    final code = styleOf(tester, 'kod');
    expect(code.fontFamily, 'monospace');
    expect(code.fontSize, closeTo(14 * 0.92, 0.01));

    // A line break is a new line inside the same paragraph.
    final para = tester.widget<RichText>(find.textContaining('birinchi qator', findRichText: true).first);
    expect(para.text.toPlainText(), contains('birinchi qator\nikkinchi qator'));

    // Lists: two disc markers, a "1." marker, items indented.
    final discs = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'HtmlListMarker');
    expect(discs, findsNWidgets(2));
    expect(find.textContaining('1.', findRichText: true), findsWidgets);
    expect(rectOf(tester, 'nuqtali').left, greaterThan(rectOf(tester, 'birinchi qator').left));

    // Quote: muted and indented past its 3 px rule.
    expect(styleOf(tester, 'iqtibos').color, colors.inkMuted);
    expect(rectOf(tester, 'iqtibos').left, greaterThan(rectOf(tester, 'birinchi qator').left + 3));

    // Link: brand colour, underlined.
    final link = styleOf(tester, 'havola');
    expect(link.color, colors.brand);
    expect(link.decoration, TextDecoration.underline);

    // Order is kept, top to bottom.
    final order = ['Sarlavha', 'Kichik sarlavha', 'qalin', 'birinchi qator', 'nuqtali', 'raqamli', 'iqtibos', 'havola'];
    for (var i = 1; i < order.length; i++) {
      expect(rectOf(tester, order[i]).top, greaterThan(rectOf(tester, order[i - 1]).top), reason: order[i]);
    }
  });

  testWidgets('an empty paragraph keeps its blank line', (tester) async {
    Future<double> gap(String html) async {
      await tester.pumpWidget(wrap(RichDescription(html)));
      await tester.pumpAndSettle();
      return rectOf(tester, 'ikki').top - rectOf(tester, 'bir').bottom;
    }

    final without = await gap('<p>bir</p><p>ikki</p>');
    final withBlank = await gap('<p>bir</p><p></p><p>ikki</p>');
    expect(withBlank - without, greaterThan(14));
  });

  testWidgets('a long word wraps inside a phone-wide column', (tester) async {
    await tester.pumpWidget(wrap(RichDescription('<p>${'a' * 300}</p><ul><li><p>${'b' * 300}</p></li></ul>')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RichDescription)).width, lessThanOrEqualTo(390));
  });

  test('plain text becomes paragraphs; HTML is kept', () {
    expect(RichDescription.prepare('bir\nikki & 3 < 4'), '<p>bir</p><p>ikki &amp; 3 &lt; 4</p>');
    expect(RichDescription.prepare('a &amp; b'), '<p>a &amp; b</p>');
    expect(RichDescription.prepare('<p>a<br></p><p></p>'), '<p>a<br><br></p><p><br></p>');
    expect(RichDescription.prepare('   '), '');
  });

  test('only web, mail and phone links leave the app', () async {
    expect(RichDescription.openSchemes, {'http', 'https', 'mailto', 'tel'});
    // Unsafe links are swallowed (true = handled, nothing opened).
    expect(await RichDescription.openLink('javascript:alert(1)'), isTrue);
    expect(await RichDescription.openLink('file:///etc/passwd'), isTrue);
  });

  test('styles mirror the web rules', () {
    expect(RichDescription.stylesFor('p', colors), {'margin': '0'});
    expect(RichDescription.stylesFor('p', colors, afterSibling: true), {'margin': '0.6em 0 0 0'});
    expect(RichDescription.stylesFor('p', colors, afterSibling: true, parent: 'li'), {'margin': '0'});
    expect(RichDescription.stylesFor('ul', colors)!['padding'], '0 0 0 1.3em');
    expect(RichDescription.stylesFor('ol', colors)!['padding'], '0 0 0 1.4em');
    expect(RichDescription.stylesFor('li', colors, afterSibling: true), {'margin-top': '0.2em'});
    expect(RichDescription.stylesFor('strong', colors), isNull);
  });
}
