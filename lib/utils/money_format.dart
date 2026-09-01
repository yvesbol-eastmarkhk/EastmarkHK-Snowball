import 'package:intl/intl.dart';

import '../data/currencies.dart';

/// Amounts always use comma thousands and a dot decimal, independent of
/// the device locale — same rule as the input fields.
class MoneyFormat {
  MoneyFormat._();

  static final NumberFormat number = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _inputWhole = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _inputDecimal = NumberFormat('#,##0.##', 'en_US');

  static String amount(double value, String code) {
    return '${currencySymbol(code)} ${number.format(value)}';
  }

  /// Text to drop into a thousands-formatted field.
  static String input(double value) {
    if (value == 0) return '';
    if (value == value.roundToDouble()) {
      return _inputWhole.format(value);
    }
    return _inputDecimal.format(value);
  }

  static String pdfFileName(String clientName) {
    final slug = clientName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final part = slug.isEmpty ? 'client' : slug;
    return 'eastmarkhk_${part}_growth.pdf';
  }
}
