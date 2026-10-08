import 'package:fikir/core/analytics/crash_reporting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashReporter PII Scrubbing Tests', () {
    test('Scrubs Ethiopian phone numbers in various formats', () {
      expect(
        CrashReporter.scrubPII('User with phone +251911223344 failed login'),
        equals('User with phone [PHONE_REDACTED] failed login'),
      );

      expect(
        CrashReporter.scrubPII('OTP sent to 0912345678'),
        equals('OTP sent to [PHONE_REDACTED]'),
      );

      expect(
        CrashReporter.scrubPII('Safaricom number: 0712345678'),
        equals('Safaricom number: [PHONE_REDACTED]'),
      );
    });

    test('Scrubs email addresses and GPS coordinates', () {
      expect(
        CrashReporter.scrubPII('Error for user test@example.com at loc 9.01079, 38.76125'),
        equals('Error for user [EMAIL_REDACTED] at loc [COORDS_REDACTED]'),
      );
    });

    test('Executes trace and preserves result', () async {
      final reporter = CrashReporter.instance;
      final value = await reporter.trace('test_trace', () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 42;
      });

      expect(value, equals(42));
    });
  });
}
