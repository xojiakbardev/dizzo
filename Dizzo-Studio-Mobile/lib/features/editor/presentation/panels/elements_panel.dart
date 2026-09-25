import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/widgets/widgets.dart';
import '../../data/editor_api.dart';
import '../../data/sticker_library.dart';
import '../../domain/editor_models.dart';
import '../../domain/element_search.dart';
import '../../domain/graphics.dart';

/// One thing in "Elementlar": a sticker, a shape or an icon.
class ElementItem {
  ElementItem({
    required this.library,
    required this.name,
    required this.label,
    required this.group,
    required this.rank,
    required String keywords,
    this.sticker,
    this.def,
  }) : search = Searchable(label, keywords);

  final String library;
  final String name;
  final String label;
  final String group;
  final int rank;
  final Searchable search;
  final StickerItem? sticker;
  final GraphicDef? def;
}

final _vectorItems = [
  for (final (i, s) in shapes.indexed)
    ElementItem(
      library: 'shape',
      name: s.name,
      label: s.label,
      group: 'shakllar',
      rank: 1000 + i,
      keywords: 'shakl фигура shape ${s.name} ${_otherLanguageLabels(s)}',
      def: s,
    ),
  for (final (i, d) in iconDefs.indexed)
    ElementItem(library: 'icon', name: d.name, label: d.label, group: 'ikonkalar', rank: 2000 + i, keywords: d.keywords, def: d),
];

/// A graphic's names in every app language, so search finds it in any.
String _otherLanguageLabels(GraphicDef d) =>
    [for (final lang in AppLanguage.values) graphicLabel(d, lookupAppLocalizations(lang.locale))].join(' ');

final _elementItemsProvider = FutureProvider<List<ElementItem>>((ref) async {
  StickerIndex? index;
  try {
    index = await ref.watch(stickerIndexProvider.future);
  } catch (_) {}
  return [
    for (final s in index?.items ?? const <StickerItem>[])
      ElementItem(
        library: 'sticker',
        name: s.name,
        label: s.label,
        group: s.group,
        rank: s.rank ?? 500,
        keywords: s.keywords,
        sticker: s,
      ),
    ..._vectorItems,
  ];
});

/// "Elementlar": stickers, shapes and icons with search, most used first.
class ElementsPanel extends ConsumerStatefulWidget {
  const ElementsPanel({super.key, required this.enabled, required this.onPick, required this.ink});

  final bool enabled;
  final ValueChanged<ElementItem> onPick;

  /// Colour of single-colour previews.
  final Color ink;

  @override
  ConsumerState<ElementsPanel> createState() => _ElementsPanelState();
}

class _ElementsPanelState extends ConsumerState<ElementsPanel> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _searched = '';
  String _tab = 'ommabop';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  List<ElementItem> _shown(List<ElementItem> items, Map<String, int> uses) {
    int usesOf(ElementItem i) => uses['${i.library}:${i.name}'] ?? 0;
    int byPopularity(ElementItem a, ElementItem b) {
      final d = usesOf(b) - usesOf(a);
      return d != 0 ? d : a.rank - b.rank;
    }

    final words = queryWords(_searched);
    if (words.isNotEmpty) {
      final found = <(ElementItem, int)>[];
      for (final i in items) {
        final score = matchScore(words, i.search);
        if (score > 0) found.add((i, score));
      }
      found.sort((a, b) {
        final d = b.$2 - a.$2;
        return d != 0 ? d : byPopularity(a.$1, b.$1);
      });
      return [for (final f in found) f.$1];
    }
    if (_tab == 'ommabop') {
      return items.where((i) => usesOf(i) > 0 || i.rank < 500).toList()..sort(byPopularity);
    }
    if (_tab == 'hammasi') return [...items]..sort(byPopularity);
    return items.where((i) => i.group == _tab).toList()..sort(byPopularity);
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final c = context.colors;
    final items = ref.watch(_elementItemsProvider);
    final uses = ref.watch(popularGraphicsProvider).value ?? const <String, int>{};
    final groups = ref.watch(stickerIndexProvider).value?.groups ?? const <StickerGroup>[];
    final t = context.l10n;
    final tabs = [
      StickerGroup('ommabop', t.editorElementsPopular),
      StickerGroup('hammasi', t.editorElementsAll),
      ...groups,
      StickerGroup('shakllar', t.editorElementsShapes),
      StickerGroup('ikonkalar', t.editorElementsIcons),
    ];
    final list = _shown(items.value ?? _vectorItems, uses);
    final library = ref.watch(stickerLibraryProvider);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: t.editorElementsSearch,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t.editorElementsClear,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _query.clear();
                        _searched = '';
                      }),
                    ),
            ),
            onChanged: (v) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 180), () {
                if (mounted) setState(() => _searched = v);
              });
            },
          ),
        ),
        if (_searched.trim().isEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: Insets.sm),
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => Gap.xs,
              itemBuilder: (context, i) => ChoiceChip(
                label: Text(tabs[i].label),
                selected: tabs[i].key == _tab,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _tab = tabs[i].key),
              ),
            ),
          )
        else
          Gap.sm,
        if (items.hasError && list.isEmpty)
          Expanded(child: EmptyState(title: t.editorElementsLoadFailed, compact: true))
        else if (list.isEmpty && !items.isLoading)
          Expanded(child: EmptyState(title: t.editorElementsNothingFound, icon: Icons.search_off_rounded, compact: true))
        else
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.xl),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 76,
                crossAxisSpacing: Insets.sm,
                mainAxisSpacing: Insets.sm,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final item = list[i];
                return Tooltip(
                  message: item.def != null ? graphicLabel(item.def!, t) : item.label,
                  child: InkWell(
                    borderRadius: Radii.brMd,
                    onTap: widget.enabled ? () => widget.onPick(item) : null,
                    child: Ink(
                      decoration: BoxDecoration(color: c.plate, borderRadius: Radii.brMd),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _Thumb(item: item, library: library, ink: widget.ink),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.library, required this.ink});

  final ElementItem item;
  final StickerLibrary library;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final def = item.def;
    if (def != null) return CustomPaint(painter: _GraphicThumb(def, ink), size: Size.infinite);
    final name = item.name;
    return ValueListenableBuilder(
      valueListenable: library.revision,
      builder: (context, _, _) {
        final svg = library.svg(name);
        if (svg == null) {
          unawaited(library.ensure([name]));
          return const SizedBox.expand();
        }
        return SvgPicture.string(
          svg,
          fit: BoxFit.contain,
          colorFilter: isMonoSticker(name) ? ColorFilter.mode(ink, BlendMode.srcIn) : null,
        );
      },
    );
  }
}

class _GraphicThumb extends CustomPainter {
  _GraphicThumb(this.def, this.color);

  final GraphicDef def;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = (size.width / def.width) < (size.height / def.height) ? size.width / def.width : size.height / def.height;
    canvas.translate((size.width - def.width * k) / 2, (size.height - def.height * k) / 2);
    canvas.scale(k);
    final paint = Paint()..color = color;
    for (final p in graphicPaths(def)) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_GraphicThumb old) => old.def != def || old.color != color;
}
