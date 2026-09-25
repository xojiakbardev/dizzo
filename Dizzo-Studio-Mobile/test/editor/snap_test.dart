import 'package:dizzo/features/editor/domain/element_search.dart';
import 'package:dizzo/features/editor/domain/print_area.dart';
import 'package:dizzo/features/editor/domain/snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const frame = SnapFrame(zone: Box(10, 10, 190, 90), area: Box(0, 0, 200, 100));

  test('sticks to the zone centre and shows the guides', () {
    // Centre at 99, 51: within 2 mm of the zone centre (100, 50).
    final r = snapMove(const Box(89, 46, 109, 56), const [], frame, 2);
    expect(r.dx, closeTo(1, 1e-9));
    expect(r.dy, closeTo(-1, 1e-9));
    expect(r.guides.where((g) => g.axis == Axis2.x && g.at == 100), isNotEmpty);
    expect(r.guides.where((g) => g.axis == Axis2.y && g.at == 50), isNotEmpty);
  });

  test('sticks to another layer\'s edge', () {
    const other = Box(30, 20, 50, 30);
    final r = snapMove(const Box(51.5, 60, 61.5, 70), const [other], frame, 2);
    expect(r.dx, closeTo(-1.5, 1e-9));
  });

  test('nothing within the threshold: no shift', () {
    final r = snapMove(const Box(30, 30, 40, 40), const [], frame, 1);
    expect(r.snapped, isFalse);
  });

  test('centres between two neighbours with equal gaps', () {
    const a = Box(20, 40, 40, 60);
    const b = Box(100, 40, 120, 60);
    // Box 60..80 would be centred at 70 (gaps 20 and 20); start at 61.
    final r = snapMove(const Box(61, 45, 81, 55), const [a, b], frame, 2);
    expect(r.dx, closeTo(-1, 1e-9));
    expect(r.gaps, hasLength(2));
    expect(r.gaps.first.mm, closeTo(20, 1e-9));
  });

  test('scale snaps an edge onto the zone', () {
    final f = snapScale(const Box(11.5, 40, 188.5, 60), const [], frame, 2);
    expect(f, isNotNull);
    expect(f!, closeTo(90 / 88.5, 1e-9));
  });

  test('angles stick to 45° steps', () {
    expect(snapAngle(43), 45);
    expect(snapAngle(30), 30);
    expect(snapAngle(-178), 180);
    expect(snapAngle(22, fine: true), 15);
  });

  test('element search finds typos and endings', () {
    final heart = Searchable('Yurak', 'yurak sevgi heart love сердце');
    expect(matchScore(queryWords('yuraklar'), heart), greaterThan(0));
    expect(matchScore(queryWords('heartt'), heart), greaterThan(0));
    expect(matchScore(queryWords('mashina'), heart), 0);
    expect(foldText('O‘G‘IL'), "o'g'il");
  });
}
