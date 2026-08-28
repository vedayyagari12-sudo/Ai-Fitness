import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/readiness_score.dart';

/// The score is the most prominent number in the app and has been wrong
/// before, so the weighting and the rest-day rule are pinned here rather
/// than living inline in a screen.
void main() {
  group('the ordinary day', () {
    test('doing nothing scores nothing', () {
      expect(
        readinessScore(trained: 0, caloriesProgress: 0, proteinProgress: 0),
        0,
      );
    });

    test('a perfect day is exactly 100', () {
      expect(
        readinessScore(trained: 1, caloriesProgress: 1, proteinProgress: 1),
        100,
      );
    });

    test('each component is worth its stated weight', () {
      expect(
        readinessScore(trained: 1, caloriesProgress: 0, proteinProgress: 0),
        40,
      );
      expect(
        readinessScore(trained: 0, caloriesProgress: 1, proteinProgress: 0),
        35,
      );
      expect(
        readinessScore(trained: 0, caloriesProgress: 0, proteinProgress: 1),
        25,
      );
    });

    test('the three weights add up to a whole day', () {
      expect(
        kTrainedWeight + kCaloriesWeight + kProteinWeight,
        closeTo(1, 1e-9),
      );
    });
  });

  group('the rest-day credit', () {
    test('a scheduled rest day earns the bonus', () {
      final resting = readinessScore(
        trained: 0,
        caloriesProgress: 0,
        proteinProgress: 0,
        isScheduledRestDay: true,
      );
      expect(resting, kRestDayBonus);
    });

    test('resting is worth what training is worth, not more', () {
      // The bonus deliberately matches the training weight: following the
      // plan on a rest day should score like following it on a training day.
      final trainedOnATrainingDay = readinessScore(
        trained: 1,
        caloriesProgress: 0,
        proteinProgress: 0,
      );
      final restedOnARestDay = readinessScore(
        trained: 0,
        caloriesProgress: 0,
        proteinProgress: 0,
        isScheduledRestDay: true,
      );
      expect(restedOnARestDay, trainedOnATrainingDay);
    });

    test('it stacks with food but never exceeds 100', () {
      final score = readinessScore(
        trained: 1,
        caloriesProgress: 1,
        proteinProgress: 1,
        isScheduledRestDay: true,
      );
      expect(
        score,
        100,
        reason: 'a score over 100 would draw a ring arc that laps itself',
      );
    });

    test('a full food day plus the bonus is capped', () {
      // 35 + 25 + 40 = 100 exactly; anything above must still clamp.
      expect(
        readinessScore(
          trained: 0.5,
          caloriesProgress: 1,
          proteinProgress: 1,
          isScheduledRestDay: true,
        ),
        100,
      );
    });

    test('no bonus is applied when it is not a rest day', () {
      final a = readinessScore(
        trained: 0,
        caloriesProgress: 0.5,
        proteinProgress: 0.5,
      );
      final b = readinessScore(
        trained: 0,
        caloriesProgress: 0.5,
        proteinProgress: 0.5,
        isScheduledRestDay: false,
      );
      expect(a, b);
      expect(a, lessThan(kRestDayBonus));
    });
  });

  group('bad input cannot distort the score', () {
    test('progress above 1 is clamped rather than compounding', () {
      // Eating twice your target is not a 200% day.
      expect(
        readinessScore(trained: 1, caloriesProgress: 5, proteinProgress: 5),
        100,
      );
    });

    test('negative progress is treated as zero', () {
      expect(
        readinessScore(trained: -1, caloriesProgress: -1, proteinProgress: -1),
        0,
      );
    });

    test('NaN and infinity do not poison the total', () {
      final score = readinessScore(
        trained: double.nan,
        caloriesProgress: double.infinity,
        proteinProgress: 1,
      );
      expect(score, isNot(isNaN));
      expect(score, inInclusiveRange(0, 100));
    });
  });
}
