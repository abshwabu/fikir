import 'package:fikir/core/utils/age_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgeUtils 18+ Age Gate Verification', () {
    final referenceDate = DateTime(2026, 10, 8);

    test('accepts users who are exactly 18 years old today', () {
      final exactly18 = DateTime(2008, 10, 8);
      expect(AgeUtils.isAtLeast18(exactly18, referenceDate), isTrue);
      expect(AgeUtils.calculateAge(exactly18, referenceDate), equals(18));
    });

    test('accepts users who are older than 18', () {
      final age25 = DateTime(2001, 5, 12);
      expect(AgeUtils.isAtLeast18(age25, referenceDate), isTrue);
      expect(AgeUtils.calculateAge(age25, referenceDate), equals(25));
    });

    test('rejects users who are 17 years and 364 days old', () {
      final almost18 = DateTime(2008, 10, 9);
      expect(AgeUtils.isAtLeast18(almost18, referenceDate), isFalse);
      expect(AgeUtils.calculateAge(almost18, referenceDate), equals(17));
    });

    test('rejects minors under 18', () {
      final minor = DateTime(2012);
      expect(AgeUtils.isAtLeast18(minor, referenceDate), isFalse);
      expect(AgeUtils.calculateAge(minor, referenceDate), equals(14));
    });

    test('calculates correct max allowed birthdate', () {
      final maxBirth = AgeUtils.maxAllowedBirthdate(referenceDate);
      expect(maxBirth.year, equals(2008));
      expect(maxBirth.month, equals(10));
      expect(maxBirth.day, equals(8));
    });
  });
}
