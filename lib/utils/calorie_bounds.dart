/// Shared limits and status rules for daily calories.
///
/// Both live here rather than inline in the chart, because the dashboard, the
/// trend card and the fuel card all have to agree about them — and when they
/// did not, the same day showed two different numbers on one screen.
library;

/// The most calories a single day can report.
///
/// Meals are estimated by an AI reading a photo, so a bad estimate is a
/// normal failure rather than a rare one: one misread plate can return five
/// figures, and an unbounded total then rescales the whole week's chart so
/// every real day is a stub next to it. Clamping keeps one bad scan from
/// destroying the axis.
///
/// 5,400 sits well above any genuine day — a large male athlete bulking
/// hard lands nearer 4,500 — so a clamped value indicates bad data rather
/// than a big appetite.
const double kMaxDailyCalories = 5400;

/// Clamps a daily calorie figure into the reportable range.
///
/// Negative and non-finite values become 0: a negative day is not meaningful
/// and NaN would poison every average and axis it touched.
double clampDailyCalories(double kcal) {
  if (!kcal.isFinite || kcal < 0) return 0;
  return kcal > kMaxDailyCalories ? kMaxDailyCalories : kcal;
}

/// How a day's intake compares to its target.
enum CalorieStatus {
  /// Target reached — including going past it.
  onTarget,

  /// Short, but close enough to read as nearly there.
  close,

  /// Well short of the target.
  offTarget,

  /// Nothing logged that day, which is different from eating nothing.
  notLogged,
}

/// Fraction of the target below which a day stops counting as "close".
const double kCalorieCloseFloor = 0.75;

/// Fraction of the target at or above which a day counts as on target.
///
/// Slightly under 1.0 so landing a few calories short of a target that was
/// itself estimated does not read as a miss.
const double kCalorieOnTargetFloor = 0.95;

/// Classifies a day's intake.
///
/// Exceeding the target is ON TARGET, not a miss. The old rule scored the
/// distance from the target in either direction, so a day that comfortably
/// hit its goal was marked "off target" purely for going over — which reads
/// as a failure for doing the thing the goal asked for. Being over may
/// matter on a cut, but that is a judgement for a coaching message, not for
/// the colour of a bar that only claims to say whether the goal was met.
CalorieStatus calorieStatus(double kcal, double target) {
  if (!kcal.isFinite || kcal <= 0) return CalorieStatus.notLogged;
  if (!target.isFinite || target <= 0) return CalorieStatus.notLogged;

  final ratio = kcal / target;
  if (ratio >= kCalorieOnTargetFloor) return CalorieStatus.onTarget;
  if (ratio >= kCalorieCloseFloor) return CalorieStatus.close;
  return CalorieStatus.offTarget;
}
