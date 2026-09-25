// Search over the elements library, generous on purpose: anything related
// comes back, the closest first. Every query word is scored against an
// element's name and its search words (Uzbek, Russian, English): the whole
// name, a word of it, the start of a word, anywhere inside one, and — for a
// typo — a word one or two letters off. An element matching more of the
// query words ranks higher; one that matches none is left out.
import { foldText } from '~/lib/design/stickers';

export interface Searchable {
  label: string; // folded
  labelWords: string[];
  tokens: string[]; // folded search words, unique
}

export function searchable(label: string, words: string): Searchable {
  const l = foldText(label);
  const labelWords = l.split(/[\s,.;:!?()«»"“”-]+/).filter(Boolean);
  const tokens = [...new Set([...labelWords, ...foldText(words).split(/[\s,.;:!?()«»"“”-]+/).filter(Boolean)])];
  return { label: l, labelWords, tokens };
}

/** Levenshtein distance, giving up (Infinity) once it passes `max`. */
function distance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return Infinity;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const row = [i];
    let best = i;
    for (let j = 1; j <= b.length; j++) {
      const v = Math.min(prev[j]! + 1, row[j - 1]! + 1, prev[j - 1]! + (a[i - 1] === b[j - 1] ? 0 : 1));
      row.push(v);
      best = Math.min(best, v);
    }
    if (best > max) return Infinity;
    prev = row;
  }
  return prev[b.length]!;
}

/** Common Uzbek endings ("yuraklar", "mushukni"): the word without them too. */
function variants(word: string): string[] {
  const out = [word];
  const stem = word.replace(/(lari|larni|larga|lar|ning|ni|ga|da|dan)$/, '');
  if (stem !== word && stem.length >= 3) out.push(stem);
  return out;
}

function wordScore(w: string, s: Searchable): number {
  let best = 0;
  for (const v of variants(w)) {
    if (s.label === v) return 100;
    if (s.label.startsWith(v)) best = Math.max(best, 85);
    for (const lw of s.labelWords) {
      if (lw === v) best = Math.max(best, 75);
      else if (lw.startsWith(v)) best = Math.max(best, 62);
    }
    if (best >= 62) continue;
    for (const t of s.tokens) {
      if (t === v) best = Math.max(best, 55);
      else if (t.startsWith(v)) best = Math.max(best, 40);
      else if (v.length >= 3 && t.includes(v)) best = Math.max(best, 25);
      else if (v.length >= 4 && t.length >= 4) {
        const max = v.length >= 7 ? 2 : 1;
        const d = distance(v, t.slice(0, v.length + max), max);
        if (d <= max) best = Math.max(best, d === 1 ? 14 : 8);
      }
    }
    if (best === 0 && v.length >= 3 && s.label.includes(v)) best = 25;
  }
  return best;
}

/** How well an element fits the query (0: not at all). */
export function matchScore(words: string[], s: Searchable): number {
  let total = 0;
  let matched = 0;
  for (const w of words) {
    const score = wordScore(w, s);
    if (score > 0) matched++;
    total += score;
  }
  if (!matched) return 0;
  // All the words found beats some words found strongly.
  return total + (matched === words.length ? 60 * matched : 0);
}

export const queryWords = (q: string) => foldText(q).split(/\s+/).filter(Boolean);
