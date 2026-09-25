// The storefront's rich-text cleaner (app/utils/richText.ts), the same
// cases as the backend's tests/test_rich_text.py.
//   node --experimental-strip-types --test scripts/rich-text.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cleanRichText as clean } from '../app/utils/richText.ts';

const LINK = 'rel="noopener noreferrer nofollow" target="_blank"';

test('pasted rich text keeps its formatting and nothing unsafe', () => {
  const pasted = '<meta charset="utf-8"><h1 style="color:red">Sarlavha</h1><p><b>Qalin</b> va <i>qiya</i>'
    + '<span style="font-size:20px"> matn</span></p><ul><li>bir</li><li>ikki</li></ul>'
    + '<script>alert(1)</script><img src=x onerror=alert(1)><a href="javascript:alert(1)">yomon</a>'
    + '<a href="https://dizzo.uz" onclick="x()">yaxshi</a><p onmouseover="x()">oxiri';
  assert.equal(clean(pasted),
    '<h2>Sarlavha</h2><p><strong>Qalin</strong> va <em>qiya</em> matn</p><ul><li>bir</li><li>ikki</li></ul>'
    + `yomon<a href="https://dizzo.uz" ${LINK}>yaxshi</a><p>oxiri</p>`);
});

test('everything the editor writes is kept as is', () => {
  const editor = '<h2>Sarlavha</h2><h3>Kichik sarlavha</h3>'
    + '<p><strong>qalin</strong> <em>qiya</em> <u>tagi chiziq</u> <s>ustidan chiziq</s> <code>kod</code></p>'
    + '<p>birinchi qator<br>ikkinchi qator</p><p></p>'
    + '<ul><li><p>nuqtali</p></li><li><p>ro‘yxat</p></li></ul>'
    + '<ol><li><p>raqamli</p></li></ol>'
    + '<blockquote><p>iqtibos</p></blockquote>'
    + `<p><a target="_blank" rel="noopener noreferrer nofollow" href="https://dizzo.uz/catalog">havola</a></p>`;
  const once = clean(editor);
  assert.equal(once, editor.replace('<a target="_blank" rel="noopener noreferrer nofollow" href="https://dizzo.uz/catalog">',
    `<a href="https://dizzo.uz/catalog" ${LINK}>`));
  assert.equal(clean(once), once);
});

test('tags the editor cannot make become ones it can', () => {
  assert.equal(clean('<h1>a</h1><h4>b</h4><h6>c</h6><div>d</div><pre>e</pre>'), '<h2>a</h2><h3>b</h3><h3>c</h3><p>d</p><p>e</p>');
  assert.equal(clean('<p style="text-align:center" class="x"><span style="color:red">a</span></p>'), '<p>a</p>');
  assert.equal(clean('<img src="https://x/y.png"><table><tr><td>a</td></tr></table>'), 'a');
});

test('links are safe', () => {
  for (const bad of ['javascript:alert(1)', 'JaVaScRiPt:x', '&#106;avascript:x', ' javascript:x', 'data:text/html,x', '/relative', '']) {
    assert.equal(clean(`<a href="${bad}">t</a>`), 't', bad);
  }
  assert.equal(clean('<a href=\'mailto:a@b.uz\'>m</a>'), `<a href="mailto:a@b.uz" ${LINK}>m</a>`);
  assert.equal(clean('<a title=">" href="https://x.uz/?a=1&b=2">q</a>'), `<a href="https://x.uz/?a=1&amp;b=2" ${LINK}>q</a>`);
  assert.equal(clean('<a href=https://x.uz onclick=x>q</a>'), `<a href="https://x.uz" ${LINK}>q</a>`);
});

test('nothing breaks out of the allow-list', () => {
  // Only inert text comes out: every "<" left is one of ours or escaped.
  assert.equal(clean('<scr<script>ipt>alert(1)</script>'), 'ipt>alert(1)');
  assert.equal(clean('<p <img src=x onerror=alert(1)>>a'), '<p>>a</p>');
  assert.equal(clean('<style>p{}</style><!-- <script>x</script> -->a'), 'a');
  assert.equal(clean('<svg><script>x</script></svg>b'), 'b');
  assert.equal(clean('<a href="x>y'), '&lt;a href="x>y');
  assert.equal(clean('<p>a</ul></p></strong>'), '<p>a</p>');
  assert.equal(clean('<strong><p>a</strong>b'), '<strong><p>a</p></strong>b');
});

test('plain text and empty text', () => {
  assert.equal(clean('1 < 2 & 3'), '1 &lt; 2 & 3');
  assert.equal(clean('bir\nikki'), 'bir\nikki');
  assert.equal(clean(''), '');
});
