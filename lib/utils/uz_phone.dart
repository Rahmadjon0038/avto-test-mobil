import 'package:flutter/services.dart';

/// "+998 90 123 45 67", "998901234567", "90 123 45 67" -> "901234567" (9 ta raqam).
String normalizeUzPhoneDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final local = digits.startsWith('998') ? digits.substring(3) : digits;
  return local.length > 9 ? local.substring(0, 9) : local;
}

/// "901234567" -> "90 123 45 67"
String formatUzPhoneDigits(String value) {
  final digits = normalizeUzPhoneDigits(value);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length && i < 9; i++) {
    if (i == 2 || i == 5 || i == 7) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatUzPhoneDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
