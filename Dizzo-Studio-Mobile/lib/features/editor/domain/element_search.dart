import 'dart:math' as math;

// Search over the elements library (the web's `elementSearch.ts`): every
// query word is scored against a name and its search words (Uzbek, Russian,
// English); typos one or two letters off still match.

/// Lowercase, and every Uzbek apostrophe the same.
String foldText(String s) => s.toLowerCase().replaceAll(RegExp('[‘’ʻʼ`\']'), "'");

final _split = RegExp(r'[\s,.;:!?()«»"“”-]+');

class Searchable {
  Searchable(String label, String words)
      : label = foldText(label),
        labelWords = foldText(label).split(_split).where((w) => w.isNotEmpty).toList() {
    tokens = {...labelWords, ...foldText(words).split(_split).where((w) => w.isNotEmpty)}.toList();
  }

  final String label;
  final List<String> labelWords;
  late final List<String> tokens;
}

int _distance(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return 1 << 20;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final row = <int>[i];
    var best = i;
    for (var j = 1; j <= b.length; j++) {
      final v = [prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)].reduce(math.min);
      row.add(v);
      best = math.min(best, v);
    }
    if (best > max) return 1 << 20;
    prev = row;
  }
  return prev[b.length];
}

final _endings = RegExp(r'(lari|larni|larga|lar|ning|ni|ga|da|dan)$');

List<String> _variants(String word) {
  final stem = word.replaceFirst(_endings, '');
  return [word, if (stem != word && stem.length >= 3) stem];
}

int _wordScore(String w, Searchable s) {
  var best = 0;
  for (final v in _variants(w)) {
    if (s.label == v) return 100;
    if (s.label.startsWith(v)) best = math.max(best, 85);
    for (final lw in s.labelWords) {
      if (lw == v) {
        best = math.max(best, 75);
      } else if (lw.startsWith(v)) {
        best = math.max(best, 62);
      }
    }
    if (best >= 62) continue;
    for (final t in s.tokens) {
      if (t == v) {
        best = math.max(best, 55);
      } else if (t.startsWith(v)) {
        best = math.max(best, 40);
      } else if (v.length >= 3 && t.contains(v)) {
        best = math.max(best, 25);
      } else if (v.length >= 4 && t.length >= 4) {
        final max = v.length >= 7 ? 2 : 1;
        final d = _distance(v, t.substring(0, math.min(t.length, v.length + max)), max);
        if (d <= max) best = math.max(best, d == 1 ? 14 : 8);
      }
    }
    if (best == 0 && v.length >= 3 && s.label.contains(v)) best = 25;
  }
  return best;
}

/// How well an element fits the query (0: not at all).
int matchScore(List<String> words, Searchable s) {
  var total = 0;
  var matched = 0;
  for (final w in words) {
    final score = _wordScore(w, s);
    if (score > 0) matched++;
    total += score;
  }
  if (matched == 0) return 0;
  return total + (matched == words.length ? 60 * matched : 0);
}

List<String> queryWords(String q) => foldText(q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
