"""Rich text the admin writes (product and variant descriptions): kept as
a small, safe subset of HTML — exactly what the admin editor (TipTap,
Dizzo-Frontend components/shared/RichTextEditor.vue) can produce:
paragraphs (empty ones too), line breaks, bold, italic, underline, strike,
inline code, two heading sizes (h2, h3), lists, quotes and links. Anything
else is mapped onto that set the way the editor would read it (h1 -> h2,
h4-h6 -> h3, div/pre -> p), so the storefront and the app never show
something the editor can't; scripts, styles, event handlers, images and
unsafe links never reach a page."""

from __future__ import annotations

from html import escape
from html.parser import HTMLParser

# Tag -> the tag it is kept as.
ALLOWED = {
    "p": "p", "div": "p", "br": "br", "strong": "strong", "b": "strong", "em": "em", "i": "em", "u": "u",
    "s": "s", "strike": "s", "del": "s", "h1": "h2", "h2": "h2", "h3": "h3", "h4": "h3", "h5": "h3", "h6": "h3",
    "ul": "ul", "ol": "ol", "li": "li", "blockquote": "blockquote", "code": "code", "pre": "p", "a": "a",
}
VOID = {"br"}
BLOCK = {"p", "br", "h2", "h3", "ul", "ol", "li", "blockquote"}
# The same attributes the editor puts on a link: it opens in a new tab and
# the page it opens gets no handle on (or referrer from) ours.
LINK_ATTRS = 'rel="noopener noreferrer nofollow" target="_blank"'
DROP_WITH_CONTENT = {"script", "style", "template", "iframe", "object", "embed", "noscript", "svg", "math", "head", "title"}


class _Cleaner(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.out: list[str] = []
        self.open: list[str] = []
        self.skip = 0  # inside a dropped element
        self.last = ""  # the last tag written ("" = text or nothing yet)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in DROP_WITH_CONTENT:
            self.skip += 1
            return
        if self.skip or tag not in ALLOWED:
            return
        kept = ALLOWED[tag]
        if kept == "a":
            href = next((v for k, v in attrs if k == "href" and v), "")
            if not href.lower().startswith(("https://", "http://", "mailto:", "tel:")):
                return  # a link without a safe target is just its text
            self.out.append(f'<a href="{escape(href, quote=True)}" {LINK_ATTRS}>')
        else:
            self.out.append(f"<{kept}>")
        self.last = kept
        if kept not in VOID:
            self.open.append(kept)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if not self.skip and ALLOWED.get(tag) == "br":
            self.out.append("<br>")
            self.last = "br"

    def handle_endtag(self, tag: str) -> None:
        if tag in DROP_WITH_CONTENT:
            self.skip = max(0, self.skip - 1)
            return
        kept = ALLOWED.get(tag)
        if self.skip or kept is None or kept in VOID or kept not in self.open:
            return
        # Close everything opened after it too, so the result stays well nested.
        while self.open:
            last = self.open.pop()
            self.out.append(f"</{last}>")
            self.last = last
            if last == kept:
                break

    def handle_data(self, data: str) -> None:
        if self.skip:
            return
        # Source formatting between blocks ("</li>\n  <li>") is not text:
        # the pages keep white space as typed, so it would show as blank lines.
        if self.last in BLOCK and not data.strip() and "\n" in data:
            return
        self.out.append(escape(data, quote=False))
        self.last = ""

    def result(self) -> str:
        while self.open:
            self.out.append(f"</{self.open.pop()}>")
        return "".join(self.out).strip()


def clean_html(html: str) -> str:
    """The safe subset of `html` (plain text comes back escaped)."""
    cleaner = _Cleaner()
    cleaner.feed(html or "")
    cleaner.close()
    text = cleaner.result()
    # Nothing but empty paragraphs is nothing.
    return "" if text.replace("<p>", "").replace("</p>", "").replace("<br>", "").strip() == "" else text
