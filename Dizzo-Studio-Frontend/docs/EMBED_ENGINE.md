# Embedded engine (`/embed/engine`)

The mobile app draws the editor natively, but the 3D preview, the mockup
pictures and the print files must be the web's exactly. So the app hosts the
web's rendering engine in a WebView: `https://dizzo.uz/embed/engine`.

The page has no chrome (no navbar, footer or sign-in), is client-only,
`noindex`, and runs the same code as the Studio:

| What | Shared code |
| --- | --- |
| 3D scene, framing, presets, mockups | `app/lib/three/studioScene.ts` |
| Area textures on the model | `paintPreview` / `previewCanvas` in `app/lib/design/render.ts` (also used by `StudioPreview.vue`) |
| Print files | `printJobs` (`app/lib/design/output.ts`) + `renderPrintFile` (`render.ts`) — same as the cart in `useStudio.ts` |
| Measurement (`areas_cm2`) | `measureAreas` (`output.ts`) — same as the Studio's autosave |
| Problems | `designProblems` / `designMethodOf` (`app/lib/design/document.ts`) — same as the Studio |

The engine code (three.js included) is loaded lazily after the page shows;
the page itself is a few KB. The renderer's pixel ratio is capped at 1.5,
as in the Studio.

## URL

```
/embed/engine[?transparent=1][&chunk=<chars>]
```

- `transparent=1` — start with no backdrop (same as `setBackground({transparent: true})`).
- `chunk` — the chunk size in characters (default `8000000`, minimum `65536`), see [Big messages](#big-messages).

Pinch-zooming the page itself is disabled (`user-scalable=no`); pinches go to the 3D view.

## Transport

### Host → page

The page defines `window.dizzoEngine` before anything else loads:

```js
window.dizzoEngine.version   // 1
window.dizzoEngine.call(jsonString)   // or a plain object
```

The request:

```json
{ "id": "42", "method": "load", "params": { "productSlug": "krujka" } }
```

- `id` — any JSON value; echoed back. Use strings.
- `params` — an object; can be left out for methods that take no params.

From Flutter (`webview_flutter`):

```dart
controller.runJavaScript('window.dizzoEngine.call(${jsonEncode(jsonEncode(request))})');
```

(`jsonEncode` twice: the request becomes a JSON string literal.) Use
`runJavaScript`, not `runJavaScriptReturningResult`: `call` returns a
Promise (of the response, handy in a browser console), which the host ignores.

Calls are **queued and run one at a time** in arrival order. Calls made
before the engine is up wait for it, so the host may call as soon as the
page has loaded. Waiting for the `ready` event is still the cleanest way.

### Page → host

Every message is one JSON string sent to:

1. `DizzoBridge.postMessage(string)` — the JavaScript channel the host
   injects (`controller.addJavaScriptChannel('DizzoBridge', onMessageReceived: …)`);
2. otherwise, inside an iframe, `window.parent.postMessage(string, '*')`;
3. otherwise the console (`console.info('[dizzo-engine]', …)`, with long strings shortened).

Every message is also dispatched in the page as
`window.dispatchEvent(new CustomEvent('dizzo-engine', { detail: message }))`.

Responses (exactly one per call):

```json
{ "id": "42", "ok": true,  "result": { … } }
{ "id": "42", "ok": false, "error": "variant 7 is not on sale" }
```

An unreadable request is answered with `"id": null`.

Events (not asked for):

| Event | Payload | When |
| --- | --- | --- |
| `ready` | `{"event":"ready","version":1,"chunkChars":8000000}` | the engine is up and takes calls |
| `loaded` | `{"event":"loaded","productSlug","variantId","colorId","shapeId"}` | after a successful `load` (sent just before its response) |
| `error` | `{"event":"error","message","fatal"}` | `fatal: true` — the engine could not start (no WebGL…); every call then fails. `fatal: false` — an uncaught error in the page |
| `view` | `{"event":"view","phase":"start"\|"end","zoom":130,"area":"front"}` | the user starts / ends turning or pinching the product. `zoom`: % of the framed view (100 = framed) |

### Big messages

Data URLs are big (a print file can be tens of MB). A message whose JSON
text is longer than `chunkChars` (default 8 000 000 characters) is sent as
several messages, in order:

```json
{ "chunk": { "id": 3, "index": 0, "count": 4 }, "data": "{\"id\":\"42\",\"ok\":true,\"result\":{\"files\":[{…" }
{ "chunk": { "id": 3, "index": 1, "count": 4 }, "data": "…" }
…
```

The host collects pieces by `chunk.id`, and once it has all `count` of
them joins their `data` in `index` order and parses the result as one
message. Pieces never split a UTF-16 surrogate pair. All the JSON is
ASCII apart from what the document/product text contains, so
characters ≈ bytes. Chunk ids are counted from 1 per page load.

Lower the size with `?chunk=` if the platform channel struggles (Android's
JavascriptInterface and Flutter's platform channel copy each string).

## Methods

Sizes are pixels; lengths are millimetres (`…Mm`); colours `#rrggbb`.
Every method except `load`, `setBackground` and `ping` needs a product
loaded, and fails with `no product loaded: call load first` otherwise.

### `load`

```json
{ "productSlug": "krujka", "variantId": 12, "colorId": 40, "size": "M" }
```

Fetches the public product (`GET /api/catalog/products/<slug>/`), picks the
variant (default: the first on sale), the colour (default: the first) and
the clothing size (default: the first in stock; see `setSize`), builds the
shape in its material and colour and frames the first area (or the area
shown before, if the new shape has it). The current document is kept and
painted again.

Result (also returned by `setAppearance`):

```jsonc
{
  "productSlug": "krujka",
  "productName": "Krujka",
  "variantId": 12,
  "colorId": 40,
  "colorHex": "#ffffff",
  "material": "ceramic_glossy",      // Material
  "methods": ["uv", "engrave"],       // the variant's methods
  "engraveTint": "#6f6a66",           // how engraving shows on this material (paint engrave layers in it)
  "shapeId": 5,
  "shapeKind": "model",              // cylinder | plane | disc | model
  "sizes": [ { "label": "M", "surcharge": "0.00", "is_available": true, "print_scale": "0.80" }, … ],
  "size": "M",                       // the one chosen; null on a product without sizes
  "printScale": 0.8,                 // its share of every print area (see `setSize`)
  "shapeChanged": true,
  "shownArea": "front",
  "presets": [ { "index": 0, "area": "front" }, { "index": 1, "area": null }, … ],  // up to 4
  "areas": [
    {
      "key": "front",
      "name": "Old tomoni",
      "widthMm": 200, "heightMm": 90,
      "placementNote": "",
      "sortOrder": 0,
      "pairKey": null, "pairMirror": false,
      "face": { "shape": "rect", "cornerRadiusMm": 0 },   // "round": only the circle is printed (clock dial)
      "dial": false,                                        // a clock face (new designs get numerals)
      "surfaceColor": "#ffffff",   // colour under the area on the model (sampled like the Studio)
      "methods": [
        {
          "method": "uv",
          "available": true,       // the variant offers it
          "zone": { "xMm": 5, "yMm": 5, "wMm": 190, "hMm": 80 },   // already cut to the chosen size

          "maxWidthMm": null, "maxHeightMm": null,
          "stripWidthMm": null,   // engraving strip that slides across the zone
          "stripXMm": null,       // its left edge for the document set so far (see "Strips")
          "minFontMm": null,
          "colorsAllowed": true,
          "dpi": 300,
          "printPx": { "width": 2362, "height": 1063 }   // size of its print file
        }
      ],
      "raw": { … }                 // the PrintArea exactly as the API sends it
    }
  ]
}
```

Errors: `productSlug is required`, `variant N is not on sale`,
`colour N is not on sale for variant M`, API errors (`API request failed with status 404`),
model download errors.

### `setDocument`

```json
{ "document": { "version": 1, "layers": [ … ], "links": [ … ], "strips": [ … ] } }
```

The `DesignDocument` of `app/lib/design/document.ts` (the backend's
`app/schemas/design.py`) — the same JSON the web saves. Layers are drawn in
array order; synced areas (`links`) get their copies; a layer whose area the
shape lacks is ignored. Every area is painted with no editing marks.
Images and stickers are fetched (CORS) and fonts loaded before painting;
a picture that can't be loaded fails the call.

Result:

```jsonc
{
  "strips": [ { "area": "wrap", "method": "engrave", "x_mm": 96.5 } ],  // the document's, settled (see "Strips")
  "placedCount": 3,                        // effective layers (copies included)
  "usedAreas": ["front"],                  // areas with something to print
  "printTargets": [ { "area": "front", "method": "uv" } ],
  "problems": { "l123": ["bosma zonasidan chiqib ketgan"] },  // by layer id, Uzbek, as the Studio shows them
  "problemCount": 1,                       // the web refuses the cart when > 0 (or when placedCount is 0)
  "croppedCount": 0                        // layers partly outside their zone (cropped, allowed)
}
```

#### Strips

A method with `stripWidthMm` (laser engraving round a mug) prints only a
strip that wide, as tall as its zone. Where it sits is part of the
document: `strips: [{ area, method, x_mm }]`, `x_mm` its left edge in area
millimetres (the zone's space), at most one per area and method, only for
areas whose own layers use that method. Optional: a document without an
entry has the strip centred on the area's layers on that method (older
designs print as before).

The app edits it with the same rules as the web (`app/lib/design/document.ts`,
the backend's `app/services/design_rules.py`):

- `followStrip(x, span, zone, width)`: with the layers' extent inside the
  zone `span = [lo, hi]` — if `hi − lo ≤ width`: if `lo < x`, `x = lo`; else if
  `hi > x + width`, `x = hi − width`. Then `x` is clamped to
  `[zone.x0, zone.x1 − width]`. Nothing in the zone, or a span wider than
  the strip: `x` is only clamped (the strip never jumps).
- Text: a text whose (rotated) box would be wider than the strip after an
  edit steps its size down until it fits (not below the minimum font).
- `settleStrips(document, areas)`: after every change — an area whose layers
  first use a strip method gets `x` centred on them (clamped), an existing
  one goes through `followStrip`, one with no such layers left is dropped.
- `placeInZone(layer, method, layers)` / `keepInStrip`: a moved, turned or
  added layer is shifted across so that it stays in the zone and it and
  the area's other layers on the method span no more than `width`
  (`x0 ≥ max(zone.x0, othersHi − width)`, `x1 ≤ min(zone.x1, othersLo + width)`);
  a layer that can't fit is left where it is. A drag computes the layer from
  the pointer's offset at pointer-down, so a layer held at an edge comes back
  under the finger; a snap is dropped when it alone would push the strip.
- `placeInStrip(layer, area, method, layers, strips)`: a layer that arrives
  (added, duplicated, placed, converted to the method) is moved into the
  strip where it is now, so the strip doesn't move for it (an area's first
  layer stays and the strip is centred on it). `fitIntoStrips` does this
  for a whole converted design or template, layer by layer.

`setDocument` settles the strips itself (and again when `setAppearance`
changes the shape) and paints, measures and renders print files with them;
the result's `strips` is what it used. The backend refuses (422) a strip for
an area or method the variant lacks, or outside the zone, and a print
file painted outside the stored strip.

### `setSize`

```json
{ "size": "S" }
```

The clothing size. A shape's print area is measured for the LARGEST size
(40 × 40 cm on a t-shirt is the maximum); a smaller size prints a
proportionally smaller picture — `print_scale` of the area's width and
height, in a box centred on the same anchor. Setting the size shrinks the
zones in `areas`, the decal on the 3D model, what `measure` counts and the
sheets `renderPrintFiles` draws, all at once. Layer millimetres never
change with it, so a design never moves when the size does; it is only
told whether it still fits.

Set it before rendering print files: the backend checks each sheet against
the size the item is added to the cart with, to the pixel.

```jsonc
{
  "size": "S",
  "printScale": 0.75,
  "printAreaMm": { "w": 300, "h": 300 },   // the biggest area at this size — what to show next to the picker
  "problems": { "l3": ["…"] },              // by layer id, including "does not fit this size"
  "problemCount": 1
}
```

Errors: `size "XS" is not on sale for this variant`.

### `setAppearance`

```json
{ "variantId": 13, "colorId": 41 }
```

Both optional: `variantId` defaults to the current one; `colorId` to the
current colour if the variant has it, else its first. A variant on another
shape rebuilds the model (`shapeChanged: true`). Result: as `load`.

The host is responsible for the document fitting the new shape (the web's
`fitToShape`: layers of missing areas are parked with `area: null`).

### `showArea`

`{ "key": "back" }` → `{ "area": "back" }`. Frames the whole product from
the side the area faces. Until the user turns the product, the view is
framed again when the WebView changes size.

### `resetView`

No params → `{ "area": "front" }`. Back to the shown area's framing.

### `viewPreset`

`{ "index": 2 }` → `{ "index": 2, "area": null }`. One of the `presets` from `load`.

### `captureFrames`

```json
{ "size": 900, "areas": ["front"] }
```

The cart's five mockups: square JPEG (quality 0.9) data URLs on the
backdrop, the first one straight at the first used area — the web cart's
pictures exactly. `size`: 64…4096, default 900 (the cart's). `areas`
(optional): the areas to look at; default the document's used areas, or
the shown area when nothing is placed (as the Studio does).

Result: `{ "size": 900, "areas": ["front"], "frames": ["data:image/jpeg;base64,…", …] }`
(up to 5; ~80–250 KB each at 900 px).

### `captureView`

`{ "size": 1600 }` → `{ "size": 1600, "image": "data:image/png;base64,…" }`

The product as seen now (same side, same way up), centred in a square
transparent PNG with a tenth of the size free on each side — the Studio's
"stage as it stands" picture. `size`: 64…4096, default 1600 (~0.5–2 MB).

### `renderPrintFiles`

No params. The print files exactly as the web cart builds them: one PNG
per (area, method) the document uses, transparent, with every layer cropped
to its zone. The sheet is the area's full size at the method's DPI on the
largest size, and that size's share of it (`setSize`) on any smaller one —
`widthMm`/`heightMm` are always the millimetres of the size chosen, and
that is what the factory prints.

```jsonc
{
  "size": "S",
  "printScale": 0.75,
  "files": [
    {
      "area": "front", "method": "uv",
      "width": 1771, "height": 797, "dpi": 300,
      "widthMm": 150, "heightMm": 67.5,
      "printScale": 0.75,
      "bytes": 1834211,
      "dataUrl": "data:image/png;base64,…"
    }
  ],
  "problemCount": 0
}
```

Upload each file as the web does (`useMediaUpload`: `POST /api/media/uploads/`
ticket, PUT, `POST /api/media/<id>/complete/`; kind `print`) and
send `files: [{area, method, media_id}]` with the cart item. The backend
checks the pixel size. Files are rendered even when `problemCount > 0`; the
host should not add such a design to the cart. Big designs: a 300 dpi A3
area is ~3500×5000 px, a PNG of 5–40 MB → chunked (see above). Expect
seconds of work on a phone.

### `measure`

No params → `{ "areasCm2": { "uv": "112.40" } }`

Painted area per method in cm², two decimals, as the web sends
`areas_cm2` to `/api/catalog/quote/` and the design endpoints.

### `setBackground`

`{ "transparent": true }` → `{ "transparent": true }`. With `true` the
backdrop and page background are dropped, so a transparent WebView shows
the app behind the product (on Android also set the WebView's background
colour to transparent). With `false` (default) the Studio's grey-blue
backdrop is shown. Mockups (`captureFrames`) always have the backdrop;
`captureView` is always transparent.

### `ping`

No params → `{ "version": 1, "chunkChars": 8000000 }`.

## Touch

One finger turns the product, a pinch zooms (0.3…12 units), panning is
off. There are no editing gestures. The canvas has `touch-action: none`.

## Typical flow

```
← {"event":"ready",…}
→ load {productSlug, variantId, colorId}          ← loaded + result (areas for the native editor)
→ setDocument {document}                           (after each edit, debounced by the host)
→ showArea {key}                                   (when the native editor switches area)
→ setAppearance {variantId, colorId}
→ setSize {size}                     (a product sold by size: before any print file)
… add to cart:
→ setDocument {document}   (the latest)
→ measure                  → areas_cm2
→ renderPrintFiles         → upload each, kind "print"
→ captureFrames {size: 900} → upload each, kind "design" (mockups)
→ POST /api/cart/items/ { …, files, mockups }
```

## Testing on a desktop

**Harness page:** `http://localhost:3000/embed/harness` (or
`https://dizzo.uz/embed/harness`). It shows the engine in a phone-sized
iframe with buttons for every method, logs every message (chunks joined —
add `?chunk=100000` to see chunking) and shows the returned pictures.
`?slug=krujka` pre-fills the product; "sample document" makes a text layer
in the first area.

**Console:** open `/embed/engine` and call it directly — responses are
logged and also returned:

```js
await dizzoEngine.call({ id: '1', method: 'load', params: { productSlug: 'krujka' } })
await dizzoEngine.call({ id: '2', method: 'setDocument', params: { document: {
  version: 1, links: [],
  layers: [{ id: 't1', area: 'front', method: 'uv', kind: 'text', x_mm: 100, y_mm: 45, w_mm: 60, h_mm: 20, rotation: 0,
    text: { content: 'Dizzo', font: 'Montserrat', size_mm: 14, color: '#d24419', align: 'center', bold: true, italic: false } }],
} } })
const { result } = await dizzoEngine.call({ id: '3', method: 'captureFrames', params: { size: 600 } })
window.open(result.frames[0])
// Every message, as the app would get it:
window.addEventListener('dizzo-engine', e => console.log(e.detail))
```

(Use an area key from `load`'s `areas`.)
