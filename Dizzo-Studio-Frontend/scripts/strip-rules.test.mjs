// The laser strip's rules (app/lib/design/document.ts), the same cases as
// the backend's tests/test_laser_strip.py.
//   node --experimental-strip-types --test scripts/strip-rules.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fitIntoStrips, followStrip, placeInStrip, placeInZone, printZone, settleStrips } from '../app/lib/design/document.ts';

// The mug's engraving zone: 75,15 100×50 mm, a 40 mm strip.
const method = {
  method: 'engrave', zone_x_mm: '75', zone_y_mm: '15', zone_w_mm: '100', zone_h_mm: '50',
  max_width_mm: null, max_height_mm: null, strip_width_mm: '40', min_font_mm: '2', colors_allowed: false, dpi: 600,
};
const area = { key: 'wrap', name: 'O‘rab olish', width_mm: '226', height_mm: '79', methods: [method] };
const zone = { x0: 75, y0: 15, x1: 175, y1: 65 };
const text = (id, x, w) => ({ id, area: 'wrap', method: 'engrave', kind: 'text', x_mm: x, y_mm: 40, w_mm: w, h_mm: 10, rotation: 0 });
const span = (lo, hi) => ({ lo, hi });
const nothing = span(Infinity, -Infinity);

test('the strip stays until the design reaches its edge', () => {
  assert.equal(followStrip(100, span(110, 130), zone, 40), 100);
  assert.equal(followStrip(100, span(100, 140), zone, 40), 100);
  assert.equal(followStrip(100, span(95, 120), zone, 40), 95);
  assert.equal(followStrip(100, span(120, 150), zone, 40), 110);
  assert.equal(followStrip(100, span(60, 70), zone, 40), 75);
  assert.equal(followStrip(100, span(170, 190), zone, 40), 135);
  assert.equal(followStrip(100, nothing, zone, 40), 100);
  assert.equal(followStrip(300, nothing, zone, 40), 135);
  assert.equal(followStrip(100, span(100, 160), zone, 40), 100); // wider than the strip: it stays
  assert.equal(followStrip(160, span(100, 160), zone, 40), 135);
});

test('a stored strip is where it was left, else centred', () => {
  const layers = [text('a', 110, 10), text('b', 130, 10)];
  assert.equal(printZone(area, method, layers, []).x0, 100);
  assert.equal(printZone(area, method, layers, [{ area: 'wrap', method: 'engrave', x_mm: 95 }]).x0, 95);
  assert.equal(printZone(area, method, layers, [{ area: 'wrap', method: 'engrave', x_mm: 60 }]).x0, 75);
  assert.equal(printZone(area, method, layers, [{ area: 'wrap', method: 'engrave', x_mm: 170 }]).x0, 135);
});

test('settling adds, follows and drops strips', () => {
  const doc = { version: 1, links: [], layers: [text('a', 110, 10), text('b', 130, 10)] };
  const added = settleStrips(doc, [area]);
  assert.deepEqual(added.strips, [{ area: 'wrap', method: 'engrave', x_mm: 100 }]);
  assert.equal(settleStrips(added, [area]), added); // nothing to change: the same document

  // Moved inside the strip: it stays; past its edge: it follows.
  const inside = { ...added, layers: [text('a', 106, 10), text('b', 130, 10)] };
  assert.equal(settleStrips(inside, [area]).strips[0].x_mm, 100);
  const past = { ...added, layers: [text('a', 110, 10), text('b', 140, 10)] };
  assert.equal(settleStrips(past, [area]).strips[0].x_mm, 105);

  assert.deepEqual(settleStrips({ ...added, layers: [] }, [area]).strips, []);
  assert.equal(settleStrips(added, []), added); // no shape yet: left alone
});

test('a moved layer keeps the design in one strip and in the zone', () => {
  const others = [text('a', 110, 10)]; // 105–115: the other layer may reach 145 at most
  assert.equal(placeInZone(text('b', 160, 10), method, others).x_mm, 140);
  assert.equal(placeInZone(text('b', 130, 10), method, others).x_mm, 130);
  assert.equal(placeInZone(text('b', 70, 10), method, others).x_mm, 80); // the zone's edge
  assert.equal(placeInZone(text('b', 200, 10), method, []).x_mm, 170); // alone: anywhere in the zone
  // An older design that can't fit is left as it is.
  assert.equal(placeInZone(text('b', 160, 50), method, others).x_mm, 160);
});

test('an arriving layer goes into the strip where it is now', () => {
  const others = [text('a', 110, 10)];
  const strips = [{ area: 'wrap', method: 'engrave', x_mm: 100 }]; // 100–140
  assert.equal(placeInStrip(text('b', 150, 10), area, method, others, strips).x_mm, 135);
  assert.equal(placeInStrip(text('b', 90, 10), area, method, others, strips).x_mm, 105);
  assert.equal(placeInStrip(text('b', 120, 10), area, method, others, strips).x_mm, 120);
  // The area's first layer stays: the strip will be centred on it.
  assert.equal(placeInStrip(text('b', 160, 10), area, method, [], []).x_mm, 160);
  // Converted layers end up in one strip.
  const fitted = fitIntoStrips([text('a', 80, 10), text('b', 170, 10)], [area], []);
  assert.deepEqual(fitted.map(l => l.x_mm), [80, 110]);
});
