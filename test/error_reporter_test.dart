import 'package:physiqo_ai/services/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The API layer returns null/empty on failure so screens can render an empty
/// state instead of crashing. That makes "request failed" and "no data yet"
/// look identical, which is how a silently rejected write went unnoticed.
/// Reporting is what tells them apart, so it has to actually fire.
void main() {
  setUp(ErrorReporter.reset);
  tearDown(ErrorReporter.reset);

  test('records a failure with its context', () {
    ErrorReporter.report(Exception('boom'), context: 'getDashboard');

    expect(ErrorReporter.recent, hasLength(1));
    expect(ErrorReporter.recent.first, contains('getDashboard'));
    expect(ErrorReporter.recent.first, contains('boom'));
  });

  test('hands the failure to an attached crash reporter', () {
    final seen = <String>[];
    ErrorReporter.onReport = (error, stack, context) => seen.add(context);

    ErrorReporter.report(Exception('x'), context: 'logBodyweight');
    ErrorReporter.report(Exception('y'), context: 'getStreak');

    expect(seen, ['logBodyweight', 'getStreak']);
  });

  test('keeps newest first and stays bounded', () {
    for (var i = 0; i < 30; i++) {
      ErrorReporter.report(Exception('e$i'), context: 'ctx$i');
    }

    expect(ErrorReporter.recent.first, contains('ctx29'));
    expect(
      ErrorReporter.recent.length,
      lessThanOrEqualTo(20),
      reason: 'breadcrumbs must not grow without bound',
    );
  });

  test('a throwing crash reporter cannot break the caller', () {
    ErrorReporter.onReport = (_, _, _) => throw StateError('reporter down');

    // The app must not fail because its telemetry did.
    expect(
      () => ErrorReporter.report(Exception('x'), context: 'ctx'),
      returnsNormally,
    );
  });
}
