import 'package:dizzo/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

const nb = ' ';

void main() {
  group('formatSum', () {
    test('groups thousands with non-breaking spaces and adds so‘m', () {
      expect(formatSum(149000), '149${nb}000${nb}so‘m');
      expect(formatSum(1250000), '1${nb}250${nb}000${nb}so‘m');
      expect(formatSum(0), '0${nb}so‘m');
      expect(formatSum(999), '999${nb}so‘m');
    });

    test('rounds to whole so‘m and can omit the currency', () {
      expect(formatSum(1999.6, withCurrency: false), '2${nb}000');
      expect(formatSum(-5000, withCurrency: false), '−5${nb}000');
    });
  });

  group('Money', () {
    test('parses backend decimal strings and numbers', () {
      final m = Money.parse('149000.00');
      expect(m.amount, 149000);
      expect(m.raw, '149000.00');
      expect(Money.parse(12000).amount, 12000);
      expect(Money.parse(null).isZero, isTrue);
      expect(Money.parse('garbage').isZero, isTrue);
    });

    test('adds and formats', () {
      final total = Money.parse('149000.00') + Money.parse('15000.50');
      expect(total.format(), '164${nb}001${nb}so‘m');
      expect(Money.parse('10') * 3, Money.of(30));
    });
  });
}
