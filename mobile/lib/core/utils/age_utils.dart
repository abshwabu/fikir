class AgeUtils {
  AgeUtils._();

  static const int minimumAge = 18;

  /// Calculates the current age in whole years from a [birthdate].
  static int calculateAge(DateTime birthdate, [DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    var age = now.year - birthdate.year;
    if (now.month < birthdate.month ||
        (now.month == birthdate.month && now.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  /// Returns true if the user with [birthdate] is at least 18 years old.
  static bool isAtLeast18(DateTime birthdate, [DateTime? currentDate]) {
    return calculateAge(birthdate, currentDate) >= minimumAge;
  }

  /// Returns the maximum allowed birthdate for someone who is at least 18 today.
  static DateTime maxAllowedBirthdate([DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    return DateTime(now.year - minimumAge, now.month, now.day);
  }

  /// Returns the minimum allowed birthdate (e.g. 100 years ago).
  static DateTime minAllowedBirthdate([DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    return DateTime(now.year - 100, now.month, now.day);
  }
}
