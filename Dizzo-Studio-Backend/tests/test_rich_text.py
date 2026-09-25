from app.services.rich_text import clean_html


def test_pasted_rich_text_keeps_its_formatting_and_nothing_unsafe() -> None:
    pasted = (
        '<meta charset="utf-8"><h1 style="color:red">Sarlavha</h1><p><b>Qalin</b> va <i>qiya</i>'
        '<span style="font-size:20px"> matn</span></p><ul><li>bir</li><li>ikki</li></ul>'
        '<script>alert(1)</script><img src=x onerror=alert(1)><a href="javascript:alert(1)">yomon</a>'
        '<a href="https://dizzo.uz" onclick="x()">yaxshi</a><p onmouseover="x()">oxiri'
    )
    assert clean_html(pasted) == (
        '<h2>Sarlavha</h2><p><strong>Qalin</strong> va <em>qiya</em> matn</p><ul><li>bir</li><li>ikki</li></ul>'
        'yomon<a href="https://dizzo.uz" rel="noopener noreferrer nofollow" target="_blank">yaxshi</a><p>oxiri</p>'
    )


def test_plain_and_empty_text() -> None:
    assert clean_html("1 < 2 & 3") == "1 &lt; 2 &amp; 3"
    assert clean_html("<p><br></p>") == ""
    assert clean_html("") == ""


# Everything the admin editor (TipTap) can produce, as it produces it.
EDITOR = (
    '<h2>Sarlavha</h2><h3>Kichik sarlavha</h3>'
    '<p><strong>qalin</strong> <em>qiya</em> <u>tagi chiziq</u> <s>ustidan chiziq</s> <code>kod</code></p>'
    '<p>birinchi qator<br>ikkinchi qator</p><p></p>'
    '<ul><li><p>nuqtali</p></li><li><p>ro‘yxat</p></li></ul>'
    '<ol><li><p>raqamli</p></li></ol>'
    '<blockquote><p>iqtibos</p></blockquote>'
    '<p><a target="_blank" rel="noopener noreferrer nofollow" href="https://dizzo.uz/catalog">havola</a></p>'
)


def test_everything_the_editor_writes_is_kept_as_is() -> None:
    assert clean_html(EDITOR) == EDITOR.replace(
        '<a target="_blank" rel="noopener noreferrer nofollow" href="https://dizzo.uz/catalog">',
        '<a href="https://dizzo.uz/catalog" rel="noopener noreferrer nofollow" target="_blank">',
    )
    # Cleaning twice changes nothing (the schema and the endpoint both clean).
    once = clean_html(EDITOR)
    assert clean_html(once) == once


def test_tags_the_editor_cannot_make_become_ones_it_can() -> None:
    assert clean_html("<h1>a</h1><h4>b</h4><h6>c</h6><div>d</div><pre>e</pre>") == (
        "<h2>a</h2><h3>b</h3><h3>c</h3><p>d</p><p>e</p>"
    )
    assert clean_html('<p style="text-align:center;color:red" class="x"><span style="color:red">a</span></p>') == "<p>a</p>"
    assert clean_html('<img src="https://x/y.png"><table><tr><td>a</td></tr></table>') == "a"


def test_links_are_safe() -> None:
    for bad in ("javascript:alert(1)", "JaVaScRiPt:x", "data:text/html,x", "vbscript:x", "/relative", ""):
        assert clean_html(f'<a href="{bad}">t</a>') == "t"
    assert clean_html('<a href="mailto:a@b.uz">m</a>') == (
        '<a href="mailto:a@b.uz" rel="noopener noreferrer nofollow" target="_blank">m</a>'
    )
    assert clean_html('<a href="https://x.uz/?a=1&b=&quot;2">q</a>') == (
        '<a href="https://x.uz/?a=1&amp;b=&quot;2" rel="noopener noreferrer nofollow" target="_blank">q</a>'
    )


def test_source_formatting_between_blocks_is_dropped_but_text_spaces_stay() -> None:
    assert clean_html("<ul>\n  <li>a</li>\n  <li>b</li>\n</ul>\n<p>c  d</p>") == "<ul><li>a</li><li>b</li></ul><p>c  d</p>"
    assert clean_html("<p><strong>a</strong> <em>b</em></p>") == "<p><strong>a</strong> <em>b</em></p>"
    # Plain text (an older description) keeps its line breaks.
    assert clean_html("bir\nikki") == "bir\nikki"


def test_descriptions_are_cleaned_by_the_admin_schemas() -> None:
    from app.schemas.catalog import ProductPatch, VariantPatch

    dirty = '<p onclick="x()">a</p><script>b</script>'
    assert ProductPatch(description=dirty).description == "<p>a</p>"
    assert VariantPatch(description=dirty).description == "<p>a</p>"
    assert VariantPatch().description is None
