import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/calorie_bounds.dart';

/// Two rules the dashboard depends on, both of which were visibly wrong on a
/// real screenshot: a day that beat its calorie goal was coloured as a miss,
/// and one bad meal estimate could set the scale for the whole week.
void main() {
  group('hitting the goal counts, including going past it', () {
    const target = 2766.0;

    test('exactly on target', () {
      expect(calorieStatus(target, target), CalorieStatus.onTarget);
    });

    test('over target is ON target, not a miss', () {
      // The reported bug: 4,090 against a 2,766 target was pink. Eating past
      // a bulking goal is the goal being met, not failed.
      for (final kcal in [2900.0, 3500.0, 4090.0, 5400.0]) {
        expect(
          calorieStatus(kcal, target),
          CalorieStatus.onTarget,
          reason: '$kcal kcal against a $target target',
        );
      }
    });

    test('however far over, it never degrades', () {
      // The old rule scored distance from the target in EITHER direction, so
      // the further over you went the worse it looked.
      expect(calorieStatus(target * 3, target), CalorieStatus.onTarget);
    });

    test('a few calories short still reads as on target', () {
      // The target is itself an estimate; missing it by 1% is not a miss.
      expect(calorieStatus(target * 0.97, target), CalorieStatus.onTarget);
    });

    test('meaningfully short is close', () {
      expect(calorieStatus(target * 0.85, target), CalorieStatus.close);
    });

    test('well short is under', () {
      // 380 against 2,766 — the SUN bar in the screenshot.
      expect(calorieStatus(380, target), CalorieStatus.offTarget);
    });

    test('nothing logged is its own state, not a zero-calorie day', () {
      expect(calorieStatus(0, target), CalorieStatus.notLogged);
    });

    test('no target means nothing can be judged', () {
      expect(calorieStatus(2000, 0), CalorieStatus.notLogged);
    });

    test('non-finite input never classifies as a hit', () {
      expect(calorieStatus(double.nan, target), CalorieStatus.notLogged);
      expect(calorieStatus(2000, double.nan), CalorieStatus.notLogged);
    });
  });

  group('the daily ceiling', () {
    test('an ordinary day passes through untouched', () {
      for (final v in [0.0, 380.0, 2766.0, 4090.0, 5400.0]) {
        expect(clampDailyCalories(v), v, reason: '$v');
      }
    });

    test('an absurd estimate is capped', () {
      // A misread photo returning five figures would otherwise rescale the
      // whole week's chart and leave every real day a stub beside it.
      expect(clampDailyCalories(50000), kMaxDailyCalories);
      expect(clampDailyCalories(5401), kMaxDailyCalories);
    });

    test('the ceiling is above any genuine day', () {
      // A large athlete bulking hard lands near 4,500, so the cap should not
      // be reachable by real eating.
      expect(kMaxDailyCalories, greaterThan(4500));
    });

    test('negative and non-finite become zero rather than propagating', () {
      expect(clampDailyCalories(-100), 0);
      // Non-finite reads as "no data", not as "an enormous day". Infinity is
      // not a large number, it is the absence of one, and showing it as a
      // maxed-out day would assert something about the user's eating that
      // nothing in the data supports.
      expect(clampDailyCalories(double.nan), 0);
      expect(clampDailyCalories(double.infinity), 0);
    });

    test('a capped day still classifies as on target', () {
      // Clamping must not turn a big day into a miss.
      expect(
        calorieStatus(clampDailyCalories(99999), 2766),
        CalorieStatus.onTarget,
      );
    });
  });
}
