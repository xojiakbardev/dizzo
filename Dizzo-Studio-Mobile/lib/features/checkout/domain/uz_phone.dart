import 'package:flutter/services.dart';

/// Uzbek phone numbers: "+998 90 123 45 67".
abstract final class UzPhone {
  static const prefix = '+998 ';

  /// The 9 local digits of [input] (a leading 998 is dropped).
  static String localDigits(String input) {
    final t = input.trim();
    var d = t.replaceAll(RegExp(r'\D'), '');
    if ((t.startsWith('+998') || d.length > 9) && d.startsWith('998')) d = d.substring(3);
    return d.length > 9 ? d.substring(0, 9) : d;
  }

  static String format(String input) {
    final d = localDigits(input);
    final b = StringBuffer(prefix);
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5 || i == 7) b.write(' ');
      b.write(d[i]);
    }
    return b.toString();
  }

  static bool isComplete(String input) => localDigits(input).length == 9;
}

/// Keeps a text field in the "+998 90 123 45 67" shape.
class UzPhoneFormatter extends TextInputFormatter {
  const UzPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    // Deleting into the fixed prefix removes the last digit instead.
    if (!text.startsWith(UzPhone.prefix) && oldValue.text.startsWith(UzPhone.prefix) && text.length < oldValue.text.length) {
      final d = UzPhone.localDigits(oldValue.text);
      text = d.isEmpty ? '' : d.substring(0, d.length - 1);
    } else if (text.startsWith(UzPhone.prefix)) {
      text = text.substring(UzPhone.prefix.length);
    }
    final formatted = UzPhone.format(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
