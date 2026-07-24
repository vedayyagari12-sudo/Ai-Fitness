/// Data backing the readiness card on the TODAY screen.
/// Ring progresses are 0..1. The score is DAILY — train today (40%) +
/// calories vs target (35%) + protein vs target (25%) — so it resets to 0
/// every morning and 100 is achievable every day.
class ReadinessData {
  const ReadinessData({
    required this.score,
    required this.caloriesProgress,
    required this.proteinProgress,
    required this.sessionsProgress,
    required this.fueledValue,
    required this.caloriesLabel,
    required this.loadValue,
    required this.loadLabel,
    required this.proteinValue,
    required this.proteinTarget,
    required this.bodyFatValue,
    required this.bodyFatDelta,
    required this.trainingDetail,
    required this.fuelDetail,
    required this.proteinDetail,
  });

  // Center
  final int score;

  // Ring sweeps (0..1)
  final double caloriesProgress; // outer (lime)
  final double proteinProgress; // middle (cyan)
  final double sessionsProgress; // inner (pink) — 1.0 once trained today

  // Corner stats
  final String fueledValue; // "84%"
  final String caloriesLabel; // "1,840 kcal"
  final String loadValue; // "246"
  final String loadLabel; // "push day"
  final String proteinValue; // "142g"
  final String proteinTarget; // "of 160g"
  final String bodyFatValue; // "18.2%"
  final String bodyFatDelta; // "-0.6%"

  // Plain-English detail lines for the "how is this calculated?" sheet
  final String trainingDetail; // "1 of 4 sessions this week"
  final String fuelDetail; // "634 of 2,200 kcal today"
  final String proteinDetail; // "19g of 126g today"

  static const empty = ReadinessData(
    score: 0,
    caloriesProgress: 0,
    proteinProgress: 0,
    sessionsProgress: 0,
    fueledValue: '0%',
    caloriesLabel: '0 kcal',
    loadValue: '0',
    loadLabel: 'rest day',
    proteinValue: '0g',
    proteinTarget: 'of —',
    bodyFatValue: '—',
    bodyFatDelta: '',
    trainingDetail: 'No sessions yet this week',
    fuelDetail: 'Nothing logged today',
    proteinDetail: 'Nothing logged today',
  );
}
