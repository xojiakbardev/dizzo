import '../l10n/app_language.dart';

/// Money as the backend sends it: a decimal string in so‘m ("149000.00").
///
/// The raw string is kept so a value can be sent back unchanged; [amount]
/// is only for display and arithmetic on the screen.
class Money implements Comparable<Money> {
  const Money._(this.raw, this.amount);

  factory Money.parse(Object? value) {
    if (value is Money) return value;
    if (value is num) return Money._(value.toString(), value.toDouble());
    final text = (value ?? '0').toString().trim();
    return Money._(text, double.tryParse(text) ?? 0);
  }

  factory Money.of(num amount) => Money._(amount.toString(), amount.toDouble());

  static const zero = Money._('0', 0);

  final String raw;
  final double amount;

  bool get isZero => amount == 0;

  Money operator +(Money other) => Money.of(amount + other.amount);
  Money operator *(num factor) => Money.of(amount * factor);

  /// "149 000 so‘m" / "149 000 сум" / "149 000 UZS" (non-breaking spaces, so it never wraps mid-number).
  String format({bool withCurrency = true}) =>
      formatSum(amount, withCurrency: withCurrency);

  @override
  int compareTo(Money other) => amount.compareTo(other.amount);

  @override
  bool operator ==(Object other) => other is Money && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;

  @override
  String toString() => format();
}

const _nbsp = ' ';
/// The currency word in the current language (so‘m / сум / UZS).
String get currencyLabel => l10nNow.currencySum;

/// Groups whole so‘m by thousands: `formatSum(149000)` → "149 000 so‘m".
/// [currency] overrides the word (widgets pass `context.l10n.currencySum`).
String formatSum(num value, {bool withCurrency = true, String? currency}) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  final number = '${negative ? '−' : ''}$buffer';
  return withCurrency ? '$number$_nbsp${currency ?? currencyLabel}' : number;
}
