/// Data backing the readiness card on the TODAY screen.
/// Ring progresses are 0..1; score is the % of the weekly workout goal met.
class ReadinessData {
  const ReadinessData({
    required this.score,
    required this.caloriesProgress,
    required this.proteinProgress,
    required this.bodyFatProgress,
    required this.fueledValue,
    required this.caloriesLabel,
    required this.loadValue,
    required this.loadLabel,
    required this.proteinValue,
    required this.proteinTarget,
    required this.bodyFatValue,
    required this.bodyFatDelta,
  });

  // Center
  final int score;

  // Ring sweeps (0..1)
  final double caloriesProgress; // outer (lime)
  final double proteinProgress; // middle (cyan)
  final double bodyFatProgress; // inner (pink)

  // Corner stats
  final String fueledValue; // "84%"
  final String caloriesLabel; // "1,840 kcal"
  final String loadValue; // "246"
  final String loadLabel; // "push day"
  final String proteinValue; // "142g"
  final String proteinTarget; // "of 160g"
  final String bodyFatValue; // "18.2%"
  final String bodyFatDelta; // "-0.6%"

  static const empty = ReadinessData(
    score: 0,
    caloriesProgress: 0,
    proteinProgress: 0,
    bodyFatProgress: 0,
    fueledValue: '0%',
    caloriesLabel: '0 kcal',
    loadValue: '0',
    loadLabel: 'rest day',
    proteinValue: '0g',
    proteinTarget: 'of —',
    bodyFatValue: '—',
    bodyFatDelta: '',
  );
}
