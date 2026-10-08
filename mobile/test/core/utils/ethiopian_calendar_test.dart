import 'package:fikir/core/utils/ethiopian_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EthiopianDate', () {
    test('converts Gregorian to Ethiopian date correctly for known dates', () {
      // Meskerem 1, 2016 EC is September 12, 2023 GC
      final g1 = DateTime.utc(2023, 9, 12);
      final e1 = EthiopianDate.fromGregorian(g1);
      expect(e1.year, equals(2016));
      expect(e1.month, equals(1));
      expect(e1.day, equals(1));
      expect(e1.monthNameEnglish, equals('Meskerem'));
      expect(e1.monthNameAmharic, equals('መስከረም'));

      // Meskerem 1, 2017 EC is September 11, 2024 GC
      final g2 = DateTime.utc(2024, 9, 11);
      final e2 = EthiopianDate.fromGregorian(g2);
      expect(e2.year, equals(2017));
      expect(e2.month, equals(1));
      expect(e2.day, equals(1));

      // Meskerem 1, 2018 EC is September 11, 2025 GC
      final g3 = DateTime.utc(2025, 9, 11);
      final e3 = EthiopianDate.fromGregorian(g3);
      expect(e3.year, equals(2018));
      expect(e3.month, equals(1));
      expect(e3.day, equals(1));
    });

    test('converts Ethiopian date back to Gregorian date correctly', () {
      const eDate = EthiopianDate(year: 2016, month: 1, day: 1);
      final gDate = eDate.toGregorian();
      expect(gDate.year, equals(2023));
      expect(gDate.month, equals(9));
      expect(gDate.day, equals(12));
    });

    test('round-trip conversion preservation', () {
      final dates = [
        DateTime.utc(1990),
        DateTime.utc(2000, 5, 28),
        DateTime.utc(2010, 11, 23),
        DateTime.utc(2020, 2, 29), // Leap year
        DateTime.utc(2024, 9, 11),
        DateTime.utc(2026, 10, 8),
      ];

      for (final date in dates) {
        final eth = EthiopianDate.fromGregorian(date);
        final roundTrip = eth.toGregorian();
        expect(roundTrip.year, equals(date.year));
        expect(roundTrip.month, equals(date.month));
        expect(roundTrip.day, equals(date.day));
      }
    });

    test('handles 13th month (Pagume) days and leap year', () {
      // 2015 EC was a leap year in Ethiopian calendar (2015 % 4 == 3)
      const leapPagume = EthiopianDate(year: 2015, month: 13, day: 6);
      expect(leapPagume.isLeapYear, isTrue);
      expect(leapPagume.maxDaysInMonth, equals(6));

      // 2016 EC was not a leap year
      const normalPagume = EthiopianDate(year: 2016, month: 13, day: 5);
      expect(normalPagume.isLeapYear, isFalse);
      expect(normalPagume.maxDaysInMonth, equals(5));
    });

    test('formats in English and Amharic', () {
      const date = EthiopianDate(year: 2017, month: 1, day: 1);
      expect(date.format(), equals('Meskerem 1, 2017'));
      expect(date.format(useAmharicMonth: true), equals('መስከረም 1, 2017'));
    });
  });
}
