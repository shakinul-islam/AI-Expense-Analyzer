/// Multi-currency helper.
class CurrencyHelper {
  static const Map<String, String> _symbols = {
    'BDT': '৳',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'JPY': '¥',
  };

  static const List<String> supportedCurrencies = [
    'BDT', 'USD', 'EUR', 'GBP', 'INR', 'CAD', 'AUD', 'JPY'
  ];

  static String symbol(String? code) {
    if (code == null) return '৳';
    return _symbols[code.toUpperCase()] ?? code;
  }

  /// Formats amount with symbol. Example: ৳ 1,234.50
  static String format(num amount, String? code, {int decimals = 0}) {
    final sym = symbol(code);
    final fixed = amount.toStringAsFixed(decimals);
    // Add thousand separators
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final formatted = parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
    return '$sym $formatted';
  }
}