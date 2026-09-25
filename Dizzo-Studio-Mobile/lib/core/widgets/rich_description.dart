import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// A variant's description as the admin wrote it in the web
/// editor (TipTap): paragraphs (empty ones too), line breaks, bold, italic,
/// underline, strike, inline code, two heading sizes, lists, quotes, links.
/// The backend keeps only that subset (services/rich_text.py); the styles
/// here mirror the web's `.rich-text` rules (Dizzo-Frontend main.css) so
/// the text reads the same on the site and in the app. Links open outside
/// the app.
class RichDescription extends StatelessWidget {
  const RichDescription(this.html, {super.key, this.style});

  final String html;

  /// Base text style; defaults to bodyMedium in the ink colour.
  final TextStyle? style;

  /// Links the app hands to the system (browser, mail, phone).
  static const openSchemes = {'http', 'https', 'mailto', 'tel'};

  /// [value] as the HTML the widget shows: plain text (an older
  /// description) becomes one paragraph per line; an empty paragraph keeps
  /// its blank line and a line break at the end of a block still makes a
  /// new line, as they do in the editor.
  static String prepare(String value) => _asHtml(value)
      .replaceAllMapped(
        RegExp(r'<br\s*/?>(</(?:p|h2|h3|li)>)', caseSensitive: false),
        (m) => '<br><br>${m[1]}',
      )
      .replaceAll(RegExp(r'<p>\s*</p>'), '<p><br></p>');

  static String _asHtml(String value) {
    final text = value.trim();
    if (text.isEmpty || RegExp(r'<[a-z][^>]*>', caseSensitive: false).hasMatch(text)) {
      return text;
    }
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => '<p>${_escape(line)}</p>')
        .join();
  }

  static String _escape(String s) => s
      .replaceAll(RegExp(r'&(?!(?:[a-z]+|#\d+);)', caseSensitive: false), '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// The CSS for a [tag] (after a sibling element or not, inside [parent]),
  /// as `.rich-text` sets it on the web.
  static Map<String, String>? stylesFor(
    String? tag,
    DizzoColors colors, {
    bool afterSibling = false,
    String? parent,
  }) {
    final styles = <String, String>{};
    const blocks = {'p', 'h2', 'h3', 'ul', 'ol', 'blockquote'};
    if (blocks.contains(tag)) {
      // `.rich-text > * + *` and `blockquote > * + *`: 0.6em between blocks.
      final spaced = afterSibling && parent != 'li';
      styles['margin'] = spaced ? '0.6em 0 0 0' : '0';
    }
    switch (tag) {
      case 'h2':
        styles.addAll({'font-size': '1.15em', 'font-weight': '800', 'line-height': '1.3'});
      case 'h3':
        styles.addAll({'font-size': '1.02em', 'font-weight': '700', 'line-height': '1.35'});
      case 'ul':
        styles['padding'] = '0 0 0 1.3em';
      case 'ol':
        styles['padding'] = '0 0 0 1.4em';
      case 'li':
        if (afterSibling) styles['margin-top'] = '0.2em';
      case 'blockquote':
        styles.addAll({
          'border-left': '3px solid ${_hex(colors.line)}',
          'padding': '0 0 0 0.9em',
          'color': _hex(colors.inkMuted),
        });
      case 'a':
        styles.addAll({'color': _hex(colors.brand), 'text-decoration': 'underline'});
      case 'code':
        styles.addAll({
          'font-family': 'monospace',
          'font-size': '0.92em',
          'background-color': _hex(colors.plate),
        });
    }
    return styles.isEmpty ? null : styles;
  }

  static Future<bool> openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !openSchemes.contains(uri.scheme.toLowerCase())) return true;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shown = prepare(html);
    if (shown.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return HtmlWidget(
      shown,
      textStyle: style ?? context.text.bodyMedium?.copyWith(color: colors.ink),
      renderMode: RenderMode.column,
      customStylesBuilder: (e) => stylesFor(
        e.localName,
        colors,
        afterSibling: e.previousElementSibling != null,
        parent: e.parent?.localName,
      ),
      onTapUrl: openLink,
    );
  }
}
