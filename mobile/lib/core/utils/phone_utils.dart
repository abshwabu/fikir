class PhoneUtils {
  PhoneUtils._();

  /// Normalizes an Ethiopian phone input to E.164 format (`+2519xxxxxxxx` or `+2517xxxxxxxx`).
  ///
  /// Accepts formats:
  /// - `09xxxxxxxx` -> `+2519xxxxxxxx`
  /// - `07xxxxxxxx` -> `+2517xxxxxxxx`
  /// - `9xxxxxxxx`  -> `+2519xxxxxxxx`
  /// - `7xxxxxxxx`  -> `+2517xxxxxxxx`
  /// - `+2519xxxxxxx` -> `+2519xxxxxxx`
  /// - `2519xxxxxxxx` -> `+2519xxxxxxxx`
  ///
  /// Returns null if the phone number is invalid or not an Ethiopian mobile number.
  static String? normalizeEthiopianPhone(String input) {
    var cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('+251')) {
      cleaned = cleaned.substring(4);
    } else if (cleaned.startsWith('251')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Now cleaned should be 9 digits starting with 9 or 7
    if (!RegExp(r'^[97]\d{8}$').hasMatch(cleaned)) {
      return null;
    }

    return '+251$cleaned';
  }

  /// Checks whether an input string is a valid Ethiopian mobile phone number.
  static bool isValidEthiopianPhone(String input) {
    return normalizeEthiopianPhone(input) != null;
  }

  /// Formats raw digits for display in the Ethiopian phone input field (e.g. `0911 234 567`).
  static String formatForDisplay(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i == 4 || i == 7) {
        buffer.write(' ');
      }
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }
}
