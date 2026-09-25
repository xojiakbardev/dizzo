// Rich text (a variant's description) cleaned to what the admin editor can
// write — the same allow-list as the backend (Dizzo-Backend
// services/rich_text.py), so a page never trusts stored HTML on its own:
// paragraphs, line breaks, bold, italic, underline, strike, inline code,
// h2/h3, lists, quotes and http(s)/mailto/tel links (new tab, no opener).
// Anything else keeps only its text; scripts and styles lose that too.

const KEEP: Record<string, string> = {
  p: 'p', div: 'p', pre: 'p', br: 'br', strong: 'strong', b: 'strong', em: 'em', i: 'em', u: 'u',
  s: 's', strike: 's', del: 's', h1: 'h2', h2: 'h2', h3: 'h3', h4: 'h3', h5: 'h3', h6: 'h3',
  ul: 'ul', ol: 'ol', li: 'li', blockquote: 'blockquote', code: 'code', a: 'a',
};
const DROP = new Set(['script', 'style', 'template', 'iframe', 'object', 'embed', 'noscript', 'svg', 'math', 'head', 'title', 'textarea', 'select']);
const SAFE_HREF = /^(?:https?:\/\/|mailto:|tel:)/i;
const TOKEN = /<!--[\s\S]*?(?:-->|$)|<(\/?)([a-z][a-z0-9]*)\b((?:[^>"']|"[^"]*"|'[^']*')*)>|<|[^<]+/gi;
const HREF = /\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/i;

const escapeAttr = (v: string) => v.replace(/&(?!(?:[a-z]+|#\d+|#x[0-9a-f]+);)/gi, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export function cleanRichText(html: string): string {
  const out: string[] = [];
  const open: string[] = [];
  let skip = 0;
  for (const m of (html || '').matchAll(TOKEN)) {
    const [whole, closing, rawName, attrs = ''] = m;
    if (whole.startsWith('<!--')) continue;
    if (!rawName) {
      if (!skip) out.push(whole === '<' ? '&lt;' : whole);
      continue;
    }
    const name = rawName.toLowerCase();
    if (DROP.has(name)) {
      skip = closing ? Math.max(0, skip - 1) : skip + (attrs.trimEnd().endsWith('/') ? 0 : 1);
      continue;
    }
    const kept = KEEP[name];
    if (skip || !kept) continue;
    if (closing) {
      if (kept === 'br' || !open.includes(kept)) continue;
      // Close everything opened after it too, so the result stays well nested.
      for (let last = open.pop(); last !== undefined; last = open.pop()) {
        out.push(`</${last}>`);
        if (last === kept) break;
      }
      continue;
    }
    if (kept === 'br') {
      out.push('<br>');
      continue;
    }
    if (kept === 'a') {
      const h = HREF.exec(attrs);
      const href = (h?.[1] ?? h?.[2] ?? h?.[3] ?? '').trim();
      if (!SAFE_HREF.test(href)) continue; // a link without a safe target is just its text
      out.push(`<a href="${escapeAttr(href)}" rel="noopener noreferrer nofollow" target="_blank">`);
    }
    else {
      out.push(`<${kept}>`);
    }
    open.push(kept);
  }
  while (open.length) out.push(`</${open.pop()}>`);
  return out.join('').trim();
}
