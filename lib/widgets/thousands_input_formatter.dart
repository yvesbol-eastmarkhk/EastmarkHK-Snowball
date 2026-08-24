import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats a numeric text field live as the user types: adds comma
/// thousands separators (e.g. "10000" -> "10,000") while still allowing a
/// decimal point and digits after it to be entered normally.
class ThousandsInputFormatter extends TextInputFormatter {
  static final NumberFormat _wholeFormat = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final raw = newValue.text.replaceAll(',', '');

    // Only allow digits and at most one decimal point.
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) {
      return oldValue;
    }

    final parts = raw.split('.');
    final wholePart = parts[0];
    final hasDecimalPoint = parts.length > 1;
    final decimalPart = parts.length > 1 ? parts[1] : '';

    final wholeFormatted =
        wholePart.isEmpty ? '' : _wholeFormat.format(int.parse(wholePart));

    final newText = hasDecimalPoint
        ? '$wholeFormatted.$decimalPart'
        : wholeFormatted;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// Strips comma separators back out so the string can be parsed as a number.
double? parseFormattedNumber(String text) {
  return double.tryParse(text.replaceAll(',', ''));
}
