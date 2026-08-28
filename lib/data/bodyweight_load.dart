/// How much of a person's own bodyweight each bodyweight movement actually
/// moves, so those exercises contribute a real number to training load
/// instead of zero.
///
/// ── WHERE THESE NUMBERS COME FROM ───────────────────────────────────────────
///
/// Every entry carries its own [LoadEvidence] and a source string, because
/// they are not all the same kind of claim and should not be trusted equally.
///
///  · MEASURED — taken from a published force-plate study.
///      push-up 0.64: Ebben WP, Wurm B, VanderZanden TL, et al. "Kinetic
///      analysis of several variations of push-ups." J Strength Cond Res.
///      2011;25(10):2891-2894. Peak vertical ground reaction force for the
///      standard push-up measured 64% of body mass (the knee-flexed variation
///      measured 49%). n=23, no sex difference found.
///
///  · DEFINITIONAL — true by what the movement is, not by measurement. In a
///      pull-up or a dip the entire body hangs from or is supported by the
///      arms, so the load is the whole body mass. Nothing is estimated here.
///
///  · DERIVED — computed from published body-segment mass fractions rather
///      than measured directly. A bodyweight squat lifts everything above the
///      knees; the shanks and feet stay on the floor and are not lifted.
///      Using Dempster's segment masses (Dempster WT, "Space Requirements of
///      the Seated Operator", WADC-TR-55-159, 1955, as tabulated in Winter DA,
///      "Biomechanics and Motor Control of Human Movement"), foot is ~1.45%
///      and shank ~4.65% of total body mass, so both legs below the knee come
///      to ~12%, leaving ~0.88.
///
///  · ESTIMATE — no well-established figure was found. Deliberately
///      conservative, flagged as such, and safe to correct.
///
/// If you are revising these, change the number AND the evidence/source
/// together. A value whose source no longer matches it is worse than no
/// value, because it looks vetted.
///
/// ── WHAT IS DELIBERATELY ABSENT ─────────────────────────────────────────────
///
/// The plank is not here, and that is not an oversight. Load in this app is
/// `weight x sets x reps`, and a plank has no reps — it has a duration. A
/// 60-second hold entered as "60 reps" would produce a load figure larger
/// than a heavy squat session, which is worse than contributing nothing.
/// Isometric holds need their own treatment (time under tension), not a
/// coefficient bolted onto a rep-based formula.
library;

/// How much confidence a coefficient deserves. Surfaced rather than hidden
/// so a future reader can tell a force-plate measurement from a guess.
enum LoadEvidence {
  /// From a published force-plate measurement.
  measured,

  /// True by the mechanics of the movement — the whole body is supported.
  definitional,

  /// Computed from published body-segment mass fractions.
  derived,

  /// No established figure found; conservative and correctable.
  estimate,
}

class BodyweightCoefficient {
  const BodyweightCoefficient({
    required this.fraction,
    required this.evidence,
    required this.source,
  });

  /// Portion of bodyweight moved, per repetition.
  final double fraction;
  final LoadEvidence evidence;

  /// Short human-readable provenance, shown in the info sheet.
  final String source;

  bool get isEstimate => evidence == LoadEvidence.estimate;
}

/// Keyed by [normaliseExerciseName], so "Push-Ups", "pushup" and "push up"
/// all reach the same entry.
const Map<String, BodyweightCoefficient> kBodyweightCoefficients = {
  'push up': BodyweightCoefficient(
    fraction: 0.64,
    evidence: LoadEvidence.measured,
    source:
        'Ebben et al., J Strength Cond Res 2011 — measured 64% of body '
        'mass on a force plate',
  ),
  'pull up': BodyweightCoefficient(
    fraction: 1.00,
    evidence: LoadEvidence.definitional,
    source: 'The whole body hangs from the arms',
  ),
  'chin up': BodyweightCoefficient(
    fraction: 1.00,
    evidence: LoadEvidence.definitional,
    source: 'The whole body hangs from the arms',
  ),
  'dip': BodyweightCoefficient(
    fraction: 1.00,
    evidence: LoadEvidence.definitional,
    source: 'The whole body is supported on the arms',
  ),
  'squat': BodyweightCoefficient(
    fraction: 0.88,
    evidence: LoadEvidence.derived,
    source:
        'Bodyweight minus both shanks and feet (~12%), from Dempster '
        'segment masses',
  ),
  'lunge': BodyweightCoefficient(
    fraction: 0.65,
    evidence: LoadEvidence.estimate,
    source:
        'Conservative estimate — no established figure found. A lunge '
        'loads the front leg with the rear assisting, so it sits below a '
        'two-legged squat, but the split varies by depth and stance',
  ),
};

/// Canonical key for an exercise name.
///
/// Lower-cases, replaces every run of non-letters with a single space, and
/// drops a plural "s" from the last word. That is what makes "Push-Ups",
/// "push_up", "PUSHUP" and "push  up" all land on `push up`.
///
/// The plural rule deliberately skips words ending in "ss" or "us" so
/// "Press" does not become "pres".
String normaliseExerciseName(String raw) {
  final cleaned = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return '';

  final words = cleaned.split(' ');
  final last = words.last;
  if (last.length > 2 &&
      last.endsWith('s') &&
      !last.endsWith('ss') &&
      !last.endsWith('us')) {
    words[words.length - 1] = last.substring(0, last.length - 1);
  }
  var key = words.join(' ');

  // "pushup" written solid is one word after cleaning, so the two-word keys
  // above would miss it. Split the known compounds back apart rather than
  // duplicating every entry in the table.
  const solid = {
    'pushup': 'push up',
    'pullup': 'pull up',
    'chinup': 'chin up',
    'situp': 'sit up',
  };
  key = solid[key] ?? key;
  return key;
}

/// The coefficient for [exerciseName], or null when the movement is not a
/// bodyweight one this table knows about.
///
/// Matches on the whole normalised name first, then on any word-boundary
/// occurrence of a known key, so "Wide Grip Pull-Ups" and "Bulgarian Split
/// Squat" still resolve. Longer keys are tried first so a name containing
/// two keys picks the more specific one.
BodyweightCoefficient? bodyweightCoefficientFor(String exerciseName) {
  final key = normaliseExerciseName(exerciseName);
  if (key.isEmpty) return null;

  final exact = kBodyweightCoefficients[key];
  if (exact != null) return exact;

  final candidates = kBodyweightCoefficients.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final candidate in candidates) {
    // Word-boundary match, so "squat" matches "goblet squat" but not some
    // longer word that merely contains the letters.
    final pattern = RegExp('\\b${RegExp.escape(candidate)}\\b');
    if (pattern.hasMatch(key)) return kBodyweightCoefficients[candidate];
  }
  return null;
}

/// True when [exerciseName] is a bodyweight movement this app can load.
bool isBodyweightExercise(String exerciseName) =>
    bodyweightCoefficientFor(exerciseName) != null;
