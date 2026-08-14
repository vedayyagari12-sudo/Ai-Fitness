import 'package:flutter_test/flutter_test.dart';

/// The readiness ring is derived entirely from the dashboard payload, and the
/// API layer returns null on any failure — a timeout, or a 502 while the host
/// wakes from idle. Assigning that null over good data recomputed the ring
/// from an empty map, which is exactly 0%, and left it there until the next
/// successful load. A failed refresh has to be a no-op.
///
/// The merge rule is pinned here as a pure function; the screen applies the
/// same one.
Map<String, dynamic>? mergeDashboard({
  required Map<String, dynamic>? existing,
  required Map<String, dynamic>? incoming,
}) => incoming ?? existing;

/// Whether the screen is showing data older than the latest attempt.
bool isStale({
  required Map<String, dynamic>? shown,
  required bool fetchFailed,
}) => fetchFailed && shown != null;

void main() {
  final good = <String, dynamic>{
    'today_stats': {'calories': 1800.0, 'calorie_target': 3200.0},
  };

  group('a failed refresh keeps what was already loaded', () {
    test('null does not replace good data', () {
      expect(mergeDashboard(existing: good, incoming: null), good);
    });

    test('repeated failures still do not erase it', () {
      var shown = good;
      for (var i = 0; i < 5; i++) {
        shown = mergeDashboard(existing: shown, incoming: null)!;
      }
      expect(shown, good);
    });

    test('and the user is told the numbers are stale', () {
      expect(isStale(shown: good, fetchFailed: true), isTrue);
    });
  });

  group('a successful refresh replaces it', () {
    test('new data wins', () {
      final fresh = {
        'today_stats': {'calories': 2400.0},
      };
      expect(mergeDashboard(existing: good, incoming: fresh), fresh);
    });

    test('a genuinely empty day is still allowed through', () {
      // Zeroes that came back from the server are real: a new day starts at
      // 0% and must be able to show that. Only a *failed* fetch is ignored.
      final emptyDay = {
        'today_stats': {'calories': 0.0, 'calorie_target': 3200.0},
      };
      expect(mergeDashboard(existing: good, incoming: emptyDay), emptyDay);
    });

    test('and nothing is flagged as stale', () {
      expect(isStale(shown: good, fetchFailed: false), isFalse);
    });
  });

  test('a first-ever load that fails shows the empty state, not a warning', () {
    // Nothing to preserve and nothing to call stale — the normal empty
    // dashboard is the right thing to show.
    expect(mergeDashboard(existing: null, incoming: null), isNull);
    expect(isStale(shown: null, fetchFailed: true), isFalse);
  });
}
