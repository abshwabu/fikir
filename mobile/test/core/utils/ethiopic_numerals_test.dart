import 'package:fikir/core/utils/ethiopic_numerals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EthiopicNumerals', () {
    test('converts single digits correctly', () {
      expect(EthiopicNumerals.toEthiopic(1), equals('፩'));
      expect(EthiopicNumerals.toEthiopic(2), equals('፪'));
      expect(EthiopicNumerals.toEthiopic(3), equals('፫'));
      expect(EthiopicNumerals.toEthiopic(4), equals('፬'));
      expect(EthiopicNumerals.toEthiopic(5), equals('፭'));
      expect(EthiopicNumerals.toEthiopic(6), equals('፮'));
      expect(EthiopicNumerals.toEthiopic(7), equals('፯'));
      expect(EthiopicNumerals.toEthiopic(8), equals('፰'));
      expect(EthiopicNumerals.toEthiopic(9), equals('፱'));
    });

    test('converts tens correctly', () {
      expect(EthiopicNumerals.toEthiopic(10), equals('፲'));
      expect(EthiopicNumerals.toEthiopic(12), equals('፲፪'));
      expect(EthiopicNumerals.toEthiopic(20), equals('፳'));
      expect(EthiopicNumerals.toEthiopic(25), equals('፳፭'));
      expect(EthiopicNumerals.toEthiopic(50), equals('፶'));
      expect(EthiopicNumerals.toEthiopic(99), equals('፺፱'));
    });

    test('converts hundreds and thousands', () {
      expect(EthiopicNumerals.toEthiopic(100), equals('፻'));
      expect(EthiopicNumerals.toEthiopic(200), equals('፪፻'));
      expect(EthiopicNumerals.toEthiopic(2025), equals('፳፻፳፭'));
    });

    test('returns standard string when non-positive or when useEthiopic is false', () {
      expect(EthiopicNumerals.toEthiopic(0), equals('0'));
      expect(EthiopicNumerals.format(25), equals('25'));
      expect(EthiopicNumerals.format(25, useEthiopic: true), equals('፳፭'));
    });
  });
}
