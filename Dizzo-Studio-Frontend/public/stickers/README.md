# Stickers

Generated files: one SVG per sticker and `index.json` (name, group, Uzbek
name, Uzbek/Russian/English search words, view-box size, curated popularity
rank). The Studio's "Elementlar" panel reads `index.json`; the renderer
(`app/lib/design/render.ts`) draws `/stickers/<name>.svg` into the editor,
the 3D preview and the print files.

- Emoji: [Microsoft Fluent Emoji Flat](https://github.com/microsoft/fluentui-emoji)
  (MIT), matched to Unicode names with emojibase-data; search words from
  Unicode CLDR annotations (uz, ru, en).
- `yuz-*` (face parts) and `bayroq-ozbekiston` are drawn by hand for Dizzo.

Icons (`more.json` and `packs/<pack>.json`, name -> SVG, about 150 a pack)
are drawn from the packs; single-colour ones are recoloured by the Studio:

- `mdi-*`: [Material Design Icons](https://github.com/Templarian/MaterialDesign) (Apache-2.0)
- `tb-*`: [Tabler Icons](https://github.com/tabler/tabler-icons) (MIT)
- `ph-*`: [Phosphor Icons](https://github.com/phosphor-icons/core) (MIT), regular and fill
- `fc-*`: [Flat Color Icons](https://github.com/icons8/flat-color-icons) (MIT), many-coloured

All come from their Iconify JSON packages; brand logos are left out.
Search words add Uzbek and Russian from CLDR and a short word list.

`names.ru.json` and `names.en.json` map a sticker's name to its Russian and
English name wherever it differs from the index's Uzbek `l` (emoji from CLDR,
face parts and translated icon names by hand); `loadStickerIndex()` applies
the page's language. Icons whose name is still English stay as they are.

A sticker's file name is the graphic name stored in designs, so never rename
or remove one that may be in use.
