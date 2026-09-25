import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../domain/design_document.dart';
import '../render/design_fonts.dart';

class TextPreset {
  const TextPreset(String content, this.font, {this.bold = false, this.italic = false, this.px = 20})
      : _content = content,
        _text = null;

  /// A preset whose words follow the app language.
  const TextPreset.l10n(String Function(AppLocalizations) text, this.font, {this.bold = false, this.italic = false, this.px = 20})
      : _content = '',
        _text = text;

  final String _content;
  final String Function(AppLocalizations)? _text;

  String get content => _text?.call(l10nNow) ?? _content;

  String contentIn(AppLocalizations l) => _text?.call(l) ?? _content;
  final String font;
  final bool bold;
  final bool italic;

  /// Preview size.
  final double px;
}

String _plain(AppLocalizations l) => l.editorTextPlaceholder;
String _heading(AppLocalizations l) => l.editorTextHeading;
String _subheading(AppLocalizations l) => l.editorTextSubheading;
String _bigHeading(AppLocalizations l) => l.editorTextBigHeading;
String _birthday(AppLocalizations l) => l.editorTextBirthday;
String _elegant(AppLocalizations l) => l.editorTextElegant;
String _congrats(AppLocalizations l) => l.editorTextCongrats;
String _goodDays(AppLocalizations l) => l.editorTextGoodDays;
String _bestDad(AppLocalizations l) => l.editorTextBestDad;
String _withLove(AppLocalizations l) => l.editorTextWithLove;

/// The default words of a new text layer.
const plainText = TextPreset.l10n(_plain, 'Open Sans');

const headings = [
  TextPreset.l10n(_heading, 'Montserrat', bold: true, px: 26),
  TextPreset.l10n(_subheading, 'Montserrat', bold: true, px: 17),
  TextPreset.l10n(_bigHeading, 'Oswald', bold: true, px: 22),
  TextPreset.l10n(_birthday, 'Rubik', bold: true, px: 19),
  TextPreset.l10n(_elegant, 'Playfair Display', bold: true, italic: true, px: 22),
  TextPreset.l10n(_congrats, 'Lobster', px: 22),
  TextPreset.l10n(_goodDays, 'Pacifico', px: 19),
  TextPreset.l10n(_bestDad, 'Caveat', bold: true, px: 26),
  TextPreset.l10n(_withLove, 'Comfortaa', bold: true, px: 19),
];

/// "Matn": plain text, ready-made headings, or a sample in every font.
class TextPanel extends StatelessWidget {
  const TextPanel({super.key, required this.enabled, required this.onAdd});

  final bool enabled;
  final ValueChanged<TextPreset> onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.l10n;
    final pad = context.pagePadding;
    return ValueListenableBuilder(
      valueListenable: fontsRevision,
      builder: (context, _, _) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.md),
            sliver: SliverToBoxAdapter(
              child: AppButton(
                label: t.editorTextAdd,
                icon: const Icon(Icons.add_rounded),
                onPressed: enabled ? () => onAdd(plainText) : null,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverList.separated(
              itemCount: headings.length,
              separatorBuilder: (_, _) => Gap.sm,
              itemBuilder: (context, i) {
                final h = headings[i];
                return OutlinedButton(
                  onPressed: enabled ? () => onAdd(h) : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
                  ),
                  child: Text(
                    h.contentIn(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: designTextStyle(h.font, bold: h.bold, italic: h.italic, px: h.px, color: c.ink),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, Insets.lg, pad, Insets.sm),
            sliver: SliverToBoxAdapter(
              child: Text(t.editorTextFonts, style: context.text.labelLarge?.copyWith(color: c.inkMuted)),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.xl),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisExtent: 68,
                crossAxisSpacing: Insets.sm,
                mainAxisSpacing: Insets.sm,
              ),
              itemCount: designFonts.length,
              itemBuilder: (context, i) {
                final f = designFonts[i];
                return OutlinedButton(
                  onPressed: enabled ? () => onAdd(TextPreset(t.editorFontSample, f)) : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.editorFontSample, style: designTextStyle(f, bold: false, italic: false, px: 20, color: c.ink)),
                      Text(f, style: context.text.labelSmall?.copyWith(color: c.inkMuted)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
