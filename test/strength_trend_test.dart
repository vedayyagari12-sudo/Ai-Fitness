import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/strength_trend.dart';

/// The chart previously plotted the best estimate from any lift each week,
/// so consecutive bars could describe different exercises — a heavy squat
/// week beside a curl week read as a collapse in strength. Following one
/// lift is what makes the line mean anything.
void main() {
  final now = DateTime(2026, 8, 13);

  Map<String, dynamic> set(
    String exercise,
    double weight,
    int reps,
    int daysAgo,
  ) => {
    'exercise': exercise,
    'weight': weight,
    'reps': reps,
    'created_at': now.subtract(Duration(days: daysAgo)).toIso8601String(),
  };

  test('follows one lift rather than mixing them', () {
    final trend = strengthTrend([
      set('Bench Press', 185, 5, 1),
      set('Bicep Curl', 40, 10, 1),
      set('Bench Press', 180, 5, 8),
      set('Bench Press', 175, 5, 15),
    ], now: now);

    expect(trend.exercise, 'Bench Press');
    // The curl must not appear anywhere in the series.
    expect(trend.weekly.where((v) => v > 0 && v < 100), isEmpty);
  });

  test('prefers the lift with the most weeks of history', () {
    // A heavier lift done once is a worse trend than a lighter one done for
    // four weeks running.
    final trend = strengthTrend([
      set('Deadlift', 405, 3, 1),
      set('Overhead Press', 95, 5, 1),
      set('Overhead Press', 95, 5, 8),
      set('Overhead Press', 90, 5, 15),
      set('Overhead Press', 90, 5, 22),
    ], now: now);

    expect(trend.exercise, 'Overhead Press');
    expect(trend.weeksLogged, 4);
  });

  test('breaks a tie toward the heavier lift', () {
    // Equal history: the compound is almost always the one being tracked on
    // purpose, the accessory just happens to be logged as often.
    final trend = strengthTrend([
      set('Squat', 315, 5, 1),
      set('Squat', 305, 5, 8),
      set('Lateral Raise', 20, 12, 1),
      set('Lateral Raise', 20, 12, 8),
    ], now: now);

    expect(trend.exercise, 'Squat');
  });

  test('a week without that lift is a zero, not a substituted lift', () {
    // The gap is honest: it says "you did not do this lift", where the old
    // behaviour silently swapped in whatever else was heaviest.
    final trend = strengthTrend([
      set('Bench Press', 185, 5, 1),
      set('Bench Press', 180, 5, 15),
      set('Deadlift', 405, 3, 8), // the skipped week
    ], now: now);

    expect(trend.exercise, 'Bench Press');
    expect(trend.weekly[trend.weekly.length - 2], 0);
  });

  test('treats different capitalisations as the same lift', () {
    final trend = strengthTrend([
      set('bench press', 185, 5, 1),
      set('Bench Press', 180, 5, 8),
      set('BENCH PRESS', 175, 5, 15),
    ], now: now);

    expect(trend.weeksLogged, 3);
  });

  test('takes the best set within a week, not the last', () {
    final trend = strengthTrend([
      set('Squat', 225, 5, 1),
      set('Squat', 315, 5, 2), // heavier, same week
    ], now: now);

    expect(trend.weekly.last, closeTo(epley1rm(315, 5), 0.001));
  });

  group('rows that cannot produce an estimate', () {
    test('are skipped without throwing', () {
      final trend = strengthTrend([
        {'exercise': 'Bench Press', 'weight': null, 'reps': 5},
        {'exercise': 'Bench Press', 'weight': 185, 'reps': null},
        {'exercise': '', 'weight': 185, 'reps': 5},
        {'weight': 185, 'reps': 5, 'created_at': 'not-a-date'},
        set('Squat', 0, 5, 1),
        set('Squat', 225, 0, 1),
        set('Bench Press', 185, 5, 1),
      ], now: now);

      expect(trend.exercise, 'Bench Press');
      expect(trend.weeksLogged, 1);
    });

    test('no usable rows yields an empty trend, not a crash', () {
      final trend = strengthTrend([], now: now);
      expect(trend.isEmpty, isTrue);
      expect(trend.exercise, isEmpty);
      expect(trend.weekly.length, 8);
    });
  });

  test('ignores anything older than the window', () {
    final trend = strengthTrend([
      set('Bench Press', 185, 5, 1),
      set('Bench Press', 999, 5, 400), // long past the 8-week window
    ], now: now);

    expect(trend.weeksLogged, 1);
    expect(trend.weekly.reduce((a, b) => a > b ? a : b), lessThan(500));
  });

  test('the series is oldest-first', () {
    final trend = strengthTrend([
      set('Squat', 200, 5, 22),
      set('Squat', 300, 5, 1),
    ], now: now);

    final firstLogged = trend.weekly.indexWhere((v) => v > 0);
    expect(trend.weekly[firstLogged], lessThan(trend.weekly.last));
  });

  test('Epley matches the formula shown in the app', () {
    // 185 x (1 + 8/30) = 234.33
    expect(epley1rm(185, 8), closeTo(234.33, 0.01));
  });
}
