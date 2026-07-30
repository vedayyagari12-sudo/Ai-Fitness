import 'package:fitness_app/services/today_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// TodayCache is process-wide static state. It previously keyed only on the
/// date, so signing out and creating a new account on the same device left
/// the previous user's "trained today" flag and activity list in place — the
/// new account opened TODAY already showing a logged workout.
void main() {
  setUp(TodayCache.reset);

  test('reset clears the trained flag and the cached activity', () {
    TodayCache.markTrainedToday();
    TodayCache.meals = [
      {'id': 'a'},
    ];
    TodayCache.scans = [
      {'id': 'b'},
    ];

    TodayCache.reset();

    expect(TodayCache.trainedToday, isFalse);
    expect(TodayCache.meals, isNull);
    expect(TodayCache.scans, isNull);
  });

  test('markTrainedToday sets the optimistic flag', () {
    expect(TodayCache.trainedToday, isFalse);
    TodayCache.markTrainedToday();
    expect(TodayCache.trainedToday, isTrue);
  });

  test('invalidateActivity drops the lists but keeps the trained flag', () {
    TodayCache.markTrainedToday();
    TodayCache.meals = [
      {'id': 'a'},
    ];

    TodayCache.invalidateActivity();

    expect(TodayCache.meals, isNull);
    expect(TodayCache.scans, isNull);
    expect(
      TodayCache.trainedToday,
      isTrue,
      reason: 'logging a meal must not clear that a workout was done',
    );
  });
}
