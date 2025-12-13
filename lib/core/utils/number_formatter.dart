import 'package:intl/intl.dart';

class NumberFormatter {
  /// Formats a number to a compact string representation (e.g., 1k, 1.5M).
  /// 
  /// Examples:
  /// - 100 -> "100"
  /// - 1200 -> "1.2k"
  /// - 1500000 -> "1.5M"
  static String formatCompact(num value) {
    if (value < 1000) {
      return value.toString();
    }
    return NumberFormat.compact(locale: 'en_US').format(value);
  }

  /// Formats a price with currency (optional) in a compact way.
  static String formatPrice(num price, {String? currency}) {
    final formatted = formatCompact(price);
    if (currency != null) {
      return '$formatted $currency';
    }
    return formatted;
  }
}
