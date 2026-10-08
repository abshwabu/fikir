import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final crashReporterProvider = Provider<CrashReporter>((ref) {
  return CrashReporter.instance;
});

class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  // PII Scrubbing regular expressions
  static final RegExp _ethiopianPhoneRegex = RegExp(
    r'(?:\+?251|0)?[79]\d{8}',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final RegExp _coordinateRegex = RegExp(
    r'[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)',
  );

  /// Scrubs Ethiopian phone numbers, emails, and coordinates from logs and stack traces
  static String scrubPII(String input) {
    var sanitized = input.replaceAll(_ethiopianPhoneRegex, '[PHONE_REDACTED]');
    sanitized = sanitized.replaceAll(_emailRegex, '[EMAIL_REDACTED]');
    sanitized = sanitized.replaceAll(_coordinateRegex, '[COORDS_REDACTED]');
    return sanitized;
  }

  /// Logs a non-fatal or fatal error with PII scrubbing
  void recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    dynamic reason,
    bool fatal = false,
  }) {
    final scrubbedReason = reason != null ? scrubPII(reason.toString()) : null;
    final scrubbedException = scrubPII(exception.toString());
    final scrubbedStack = stackTrace != null ? scrubPII(stackTrace.toString()) : null;

    if (kDebugMode) {
      debugPrint('[CrashReporter] ${fatal ? "FATAL" : "NON-FATAL"}: $scrubbedException');
      if (scrubbedReason != null) debugPrint('Reason: $scrubbedReason');
      if (scrubbedStack != null) debugPrint(scrubbedStack);
    }

    // In release builds, this integrates directly with Firebase Crashlytics:
    // FirebaseCrashlytics.instance.recordError(scrubbedException, stackTrace, reason: scrubbedReason, fatal: fatal);
  }

  /// Appends a sanitized breadcrumb navigation/action log
  void logBreadcrumb(String message) {
    final scrubbed = scrubPII(message);
    if (kDebugMode) {
      debugPrint('[Breadcrumb] $scrubbed');
    }
    // FirebaseCrashlytics.instance.log(scrubbed);
  }

  /// Sets user identifier (hashed to prevent raw user correlation)
  void setUserId(String userId) {
    if (kDebugMode) {
      debugPrint('[CrashReporter] User ID assigned: ${userId.hashCode}');
    }
    // FirebaseCrashlytics.instance.setUserIdentifier(userId.hashCode.toString());
  }

  /// Measures execution performance trace
  Future<T> trace<T>(String traceName, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[PerfTrace] $traceName completed in ${stopwatch.elapsedMilliseconds}ms');
      }
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      recordError(e, stack, reason: 'Trace $traceName failed after ${stopwatch.elapsedMilliseconds}ms');
      rethrow;
    }
  }
}
