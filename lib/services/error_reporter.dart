import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Single place every swallowed failure is funnelled through.
///
/// The API layer deliberately returns null/empty on failure so a screen can
/// render an empty state instead of crashing. That is the right behaviour for
/// the UI and the wrong behaviour for diagnosis: a request that fails and one
/// that legitimately has no data become indistinguishable, which is how a
/// silently rejected database write survived unnoticed for weeks.
///
/// Reporting here keeps the UI behaviour and makes the failure observable.
/// [onReport] is the hook a crash reporter (Sentry, Crashlytics) attaches to —
/// wiring one up is then a single line in main(), with every call site
/// already in place.
class ErrorReporter {
  ErrorReporter._();

  /// Set by a crash reporter at startup. Left null, failures are logged
  /// locally and nothing leaves the device.
  static void Function(Object error, StackTrace? stack, String context)?
  onReport;

  /// The most recent failures, newest first. Small on purpose — this is a
  /// breadcrumb trail for a support conversation, not a log store.
  static final List<String> recent = [];
  static const _maxRecent = 20;

  static void report(
    Object error, {
    StackTrace? stack,
    required String context,
  }) {
    final line = '[$context] $error';
    recent.insert(0, '${DateTime.now().toIso8601String()} $line');
    if (recent.length > _maxRecent) recent.removeLast();

    // `log` rather than print: it survives release builds and shows up in
    // logcat with a searchable tag.
    developer.log(line, name: 'physiqo.error', error: error, stackTrace: stack);
    if (kDebugMode) debugPrint('Physiqo AI error $line');

    // Guarded: a crash reporter that throws (offline, misconfigured DSN,
    // rate-limited) must not take down the code path that was merely trying
    // to record a problem.
    try {
      onReport?.call(error, stack, context);
    } catch (reporterError) {
      developer.log(
        'error reporter itself failed: $reporterError',
        name: 'physiqo.error',
      );
    }
  }

  @visibleForTesting
  static void reset() {
    recent.clear();
    onReport = null;
  }
}
