import 'package:fikir/core/utils/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneUtils Ethiopian Normalization & Validation', () {
    test('normalizes 09 Ethio Telecom numbers to E.164', () {
      expect(
        PhoneUtils.normalizeEthiopianPhone('0911223344'),
        equals('+251911223344'),
      );
      expect(
        PhoneUtils.normalizeEthiopianPhone('0912 345 678'),
        equals('+251912345678'),
      );
      expect(
        PhoneUtils.normalizeEthiopianPhone('911223344'),
        equals('+251911223344'),
      );
    });

    test('normalizes 07 Safaricom Ethiopia numbers to E.164', () {
      expect(
        PhoneUtils.normalizeEthiopianPhone('0711223344'),
        equals('+251711223344'),
      );
      expect(
        PhoneUtils.normalizeEthiopianPhone('711223344'),
        equals('+251711223344'),
      );
      expect(
        PhoneUtils.normalizeEthiopianPhone('+251711223344'),
        equals('+251711223344'),
      );
    });

    test('accepts international +251 and 251 formats', () {
      expect(
        PhoneUtils.normalizeEthiopianPhone('+251911223344'),
        equals('+251911223344'),
      );
      expect(
        PhoneUtils.normalizeEthiopianPhone('251911223344'),
        equals('+251911223344'),
      );
    });

    test('rejects non-mobile and invalid formats', () {
      // Landline in Addis Ababa (011...)
      expect(PhoneUtils.normalizeEthiopianPhone('0111223344'), isNull);
      // Invalid carrier prefix (08...)
      expect(PhoneUtils.normalizeEthiopianPhone('0811223344'), isNull);
      // Too short
      expect(PhoneUtils.normalizeEthiopianPhone('09112233'), isNull);
      // Too long
      expect(PhoneUtils.normalizeEthiopianPhone('091122334455'), isNull);
      // Characters
      expect(PhoneUtils.normalizeEthiopianPhone('abcdefg'), isNull);
    });

    test('isValidEthiopianPhone returns boolean correctly', () {
      expect(PhoneUtils.isValidEthiopianPhone('0911223344'), isTrue);
      expect(PhoneUtils.isValidEthiopianPhone('0711223344'), isTrue);
      expect(PhoneUtils.isValidEthiopianPhone('0111223344'), isFalse);
    });

    test('formatForDisplay formats with spaces', () {
      expect(PhoneUtils.formatForDisplay('0911223344'), equals('0911 223 344'));
    });
  });
}
