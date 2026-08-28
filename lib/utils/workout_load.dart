import '../data/bodyweight_load.dart';

/// Sanity bounds for a weight typed into a set.
///
/// Deliberately wider than the 80-350 lb bodyweight range: that one brackets
/// a plausible human, this one brackets a plausible lift, and the two are
/// different questions. Zero is explicitly allowed and is not an error — an
/// unweighted push-up genuinely carries no external load, and the bodyweight
/// coefficient supplies the rest.
const double kMinLiftLbs = 0;

/// A little above the heaviest recorded raw deadlift, so a real lift is never
/// rejected while a typo (a bodyweight pasted into a plate field, an extra
/// digit) still is.
const double kMaxLiftLbs = 1500;

const String kLiftRangeMessage = 'Enter a weight between 0 and 1500 lbs';

/// Null when [text] is acceptable, otherwise the reason it is not.
///
/// An empty field returns null: it is not yet wrong, it is just not filled
/// in. Callers decide separately whether empty is allowed to be saved.
String? liftWeightInputError(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed);
  if (value == null) return 'Numbers only';
  if (value.isNaN || value.isInfinite) return 'Numbers only';
  if (value < kMinLiftLbs) return 'Weight cannot be negative';
  if (value > kMaxLiftLbs) return kLiftRangeMessage;
  return null;
}

bool isValidLiftWeight(String text) =>
    text.trim().isNotEmpty && liftWeightInputError(text) == null;

/// One exercise's contribution to session load.
class ExerciseLoad {
  const ExerciseLoad({required this.lbs, required this.needsBodyweight});

  /// Total volume-load in pounds: weight per rep x sets x reps.
  final double lbs;

  /// True when this is a bodyweight movement but no bodyweight has ever been
  /// logged, so its real load could not be computed. The caller should prompt
  /// rather than substitute a default — a guessed bodyweight silently makes
  /// every historical load figure wrong in a way nobody can see.
  final bool needsBodyweight;
}

/// Load for a single exercise.
///
/// External weight ADDS to the bodyweight portion rather than replacing it:
/// a weighted pull-up moves the body *and* the belt, and treating the belt as
/// the whole load would report a 25 lb weighted pull-up as lighter than an
/// unweighted one.
///
/// [bodyweightLbs] null means the user has never logged a weight.
ExerciseLoad exerciseLoad({
  required String exerciseName,
  required int sets,
  required int reps,
  double externalWeightLbs = 0,
  double? bodyweightLbs,
}) {
  final volume = sets * reps;
  if (volume <= 0) {
    return const ExerciseLoad(lbs: 0, needsBodyweight: false);
  }

  final external = externalWeightLbs.isFinite && externalWeightLbs > 0
      ? externalWeightLbs
      : 0.0;

  final coefficient = bodyweightCoefficientFor(exerciseName);
  if (coefficient == null) {
    // An ordinary weighted lift.
    return ExerciseLoad(lbs: external * volume, needsBodyweight: false);
  }

  final bw = bodyweightLbs;
  if (bw == null || !bw.isFinite || bw <= 0) {
    // Bodyweight movement, but we do not know the body's weight. Report only
    // what is actually known (any added plates) and flag the gap.
    return ExerciseLoad(lbs: external * volume, needsBodyweight: true);
  }

  final perRep = bw * coefficient.fraction + external;
  return ExerciseLoad(lbs: perRep * volume, needsBodyweight: false);
}

/// A whole session's load, and whether any part of it is unknown.
class SessionLoad {
  const SessionLoad({required this.lbs, required this.needsBodyweight});

  final double lbs;

  /// True when at least one bodyweight exercise could not be costed.
  final bool needsBodyweight;
}

/// Sums [exerciseLoad] across a session.
SessionLoad sessionLoad(Iterable<ExerciseLoad> loads) {
  var total = 0.0;
  var missing = false;
  for (final l in loads) {
    total += l.lbs;
    missing = missing || l.needsBodyweight;
  }
  return SessionLoad(lbs: total, needsBodyweight: missing);
}
