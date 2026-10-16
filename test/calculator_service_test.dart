import 'package:flutter_test/flutter_test.dart';
import 'package:searchly/services/calculator_service.dart';

void main() {
  group('CalculatorService Tests', () {
    test('isLikelyMath identifies valid math expressions', () {
      expect(CalculatorService.isLikelyMath('2 + 2'), isTrue);
      expect(CalculatorService.isLikelyMath('10 * 5.5'), isTrue);
      expect(CalculatorService.isLikelyMath('(100 + 50) / 2'), isTrue);
      expect(CalculatorService.isLikelyMath('sqrt(144)'), isTrue);
      expect(CalculatorService.isLikelyMath('20% of 500'), isTrue);
      expect(CalculatorService.isLikelyMath('calc 45 - 5'), isTrue);
    });

    test('isLikelyMath rejects non-math queries and commands', () {
      expect(CalculatorService.isLikelyMath('call Mom'), isFalse);
      expect(CalculatorService.isLikelyMath('alarm 7am'), isFalse);
      expect(CalculatorService.isLikelyMath('wm Hello there'), isFalse);
      expect(CalculatorService.isLikelyMath('Spotify'), isFalse);
      expect(CalculatorService.isLikelyMath(''), isFalse);
    });

    test('evaluate handles basic arithmetic and operator precedence', () {
      expect(CalculatorService.evaluate('2 + 2'), '4');
      expect(CalculatorService.evaluate('10 - 4 * 2'), '2');
      expect(CalculatorService.evaluate('(10 - 4) * 2'), '12');
      expect(CalculatorService.evaluate('100 / 4'), '25');
      expect(CalculatorService.evaluate('2 ^ 3'), '8');
    });

    test('evaluate handles math functions and percentage', () {
      expect(CalculatorService.evaluate('sqrt(144)'), '12');
      expect(CalculatorService.evaluate('20% of 500'), '100');
      expect(CalculatorService.evaluate('abs(-42)'), '42');
      expect(CalculatorService.evaluate('calc 50 + 50'), '100');
    });

    test('evaluate handles constants and trigonometry', () {
      expect(CalculatorService.evaluate('sin(90)'), '1');
      expect(CalculatorService.evaluate('cos(0)'), '1');
      expect(CalculatorService.evaluate('pi * 2'), '6.283185');
    });

    test('evaluate returns null on invalid or division by zero expressions', () {
      expect(CalculatorService.evaluate('10 / 0'), isNull);
      expect(CalculatorService.evaluate('invalid text'), isNull);
    });
  });
}
