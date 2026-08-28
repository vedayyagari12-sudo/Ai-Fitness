/// The daily readiness score, as a pure function of the day's inputs.
///
/// Extracted from the dashboard so the weighting and the rest-day rule can be
/// tested without standing up a screen — the score is the most prominent
/// number in the app, and it has already been wrong once (see the ring-reset
/// investigation), so it is worth pinning.
library;

/// Weights of the three things a normal training day is scored on. They sum
/// to 1.0, so a perfect day is 100 before any bonus.
const double kTrainedWeight = 0.40;
const double kCaloriesWeight = 0.35;
const double kProteinWeight = 0.25;

/// Credit for a scheduled rest day.
///
/// Rest is part of a training plan, not an absence of one — a programmed rest
/// day used to score the same zero as skipping a session you meant to do,
/// which reads as a punishment for following your own plan. It is set to
/// match [kTrainedWeight] so resting on a rest day is worth what training on
/// a training day is worth, and no more.
const int kRestDayBonus = 40;

/// Today's score out of 100.
///
/// [trained], [caloriesProgress] and [proteinProgress] are 0..1.
/// [isScheduledRestDay] must be false unless the user actually has a training
/// split saved — an unset split means there is no schedule to have rested
/// from, so there is nothing to credit.
int readinessScore({
  required double trained,
  required double caloriesProgress,
  required double proteinProgress,
  bool isScheduledRestDay = false,
}) {
  double clamp01(double v) => v.isFinite ? v.clamp(0.0, 1.0) : 0.0;

  final base =
      (clamp01(trained) * kTrainedWeight +
          clamp01(caloriesProgress) * kCaloriesWeight +
          clamp01(proteinProgress) * kProteinWeight) *
      100;

  final withBonus = base + (isScheduledRestDay ? kRestDayBonus : 0);
  // Capped, so the bonus can never push the ring past a full turn — a score
  // over 100 would draw an arc that laps itself.
  return withBonus.round().clamp(0, 100);
}
