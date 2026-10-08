class EthiopicNumerals {
  EthiopicNumerals._();

  static const List<String> _ones = [
    '', '፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱',
  ];

  static const List<String> _tens = [
    '', '፲', '፳', '፴', '፵', '፶', '፷', '፸', '፹', '፺',
  ];

  static const String _hundred = '፻';
  static const String _tenThousand = '፼';

  /// Converts a positive integer to its Ethiopic (Ge'ez) numeral representation.
  /// If [number] is 0 or negative, returns the string as-is.
  static String toEthiopic(int number) {
    if (number <= 0) return number.toString();

    return _convertPair(number);
  }

  static String _convertUnder100(int n) {
    if (n <= 0) return '';
    final t = n ~/ 10;
    final o = n % 10;
    return '${_tens[t]}${_ones[o]}';
  }

  static String _convertPair(int n) {
    if (n < 100) {
      return _convertUnder100(n);
    }

    if (n < 10000) {
      final h = n ~/ 100;
      final r = n % 100;
      final hStr = (h == 1) ? _hundred : '${_convertUnder100(h)}$_hundred';
      final rStr = _convertUnder100(r);
      return '$hStr$rStr';
    }

    final tt = n ~/ 10000;
    final r = n % 10000;
    final ttStr = (tt == 1) ? _tenThousand : '${_convertPair(tt)}$_tenThousand';
    final rStr = (r > 0) ? _convertPair(r) : '';
    return '$ttStr$rStr';
  }

  /// Formats a string by optionally converting any digits to Ethiopic numerals.
  static String format(int number, {bool useEthiopic = false}) {
    if (!useEthiopic) return number.toString();
    return toEthiopic(number);
  }
}
