/// Weekly estimated 1-rep max for a single exercise.
///
/// The chart used to plot the best estimate from *any* lift each week, which
/// is not a trend: a week topped by a heavy squat sitting beside one topped
/// by a curl reads as a collapse in strength that never happened, and the
/// number described a different exercise every bar.
///
/// So one lift is chosen and followed. A week the user didn't perform it is
/// a genuine zero — a gap in that lift's history, not a drop in strength.
library;

/// A weekly series for one exercise, oldest week first.
class StrengthTrend {
  const StrengthTrend({required this.exercise, required this.weekly});

  /// The lift being followed. Empty when nothing qualified.
  final String exercise;

  /// Best estimate per week, oldest → newest. 0 where the lift wasn't done.
  final List<double> weekly;

  bool get isEmpty => exercise.isEmpty || weekly.every((v) => v <= 0);

  /// How many weeks actually contain this lift — what makes a trend worth
  /// reading, and the basis for choosing between candidate exercises.
  int get weeksLogged => weekly.where((v) => v > 0).length;
}

/// Epley: est. 1RM = weight x (1 + reps / 30).
///
/// Weights are logged in lbs already, unlike bodyweight which is stored in
/// kg, so no conversion happens here.
double epley1rm(double weight, int reps) => weight * (1 + reps / 30);

/// Picks the exercise worth following and returns its weekly bests.
///
/// Chooses the lift with the most weeks of history, since that yields the
/// longest readable trend. Ties break toward the heavier lift, which is
/// usually the compound the user actually cares about rather than an
/// accessory logged just as often.
///
/// [rows] are raw workout maps with `exercise`, `weight`, `reps` and
/// `created_at`. Rows missing any of those cannot produce an estimate and
/// are skipped.
StrengthTrend strengthTrend(
  List<dynamic> rows, {
  int weeks = 8,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();

  // exercise -> weekly best estimate
  final byExercise = <String, List<double>>{};

  for (final raw in rows) {
    if (raw is! Map) continue;
    final row = raw.cast<String, dynamic>();

    final name = (row['exercise'] as String?)?.trim() ?? '';
    final weight = (row['weight'] as num?)?.toDouble();
    final reps = (row['reps'] as num?)?.toInt();
    final created = DateTime.tryParse((row['created_at'] as String?) ?? '');
    if (name.isEmpty ||
        weight == null ||
        weight <= 0 ||
        reps == null ||
        reps <= 0 ||
        created == null) {
      continue;
    }

    final weeksAgo = today.difference(created).inDays ~/ 7;
    if (weeksAgo < 0 || weeksAgo >= weeks) continue;

    // Same lift under different capitalisation is the same lift.
    final key = name.toLowerCase();
    final series = byExercise.putIfAbsent(
      key,
      () => List<double>.filled(weeks, 0),
    );
    final idx = weeks - 1 - weeksAgo; // oldest first
    final est = epley1rm(weight, reps);
    if (est > series[idx]) series[idx] = est;
  }

  if (byExercise.isEmpty) {
    return StrengthTrend(exercise: '', weekly: List<double>.filled(weeks, 0));
  }

  // Display name: keep the spelling the user actually logged most recently.
  final displayNames = <String, String>{};
  for (final raw in rows) {
    if (raw is! Map) continue;
    final name = (raw['exercise'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) displayNames[name.toLowerCase()] = name;
  }

  String bestKey = byExercise.keys.first;
  var bestWeeks = -1;
  var bestPeak = -1.0;
  for (final entry in byExercise.entries) {
    final logged = entry.value.where((v) => v > 0).length;
    final peak = entry.value.reduce((a, b) => a > b ? a : b);
    if (logged > bestWeeks || (logged == bestWeeks && peak > bestPeak)) {
      bestKey = entry.key;
      bestWeeks = logged;
      bestPeak = peak;
    }
  }

  return StrengthTrend(
    exercise: displayNames[bestKey] ?? bestKey,
    weekly: byExercise[bestKey]!,
  );
}
