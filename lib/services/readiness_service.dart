import '../models/readiness_data.dart';

/// Supplies the readiness card's data. Returns hardcoded values matching the
/// reference screenshot for now (Step 6 spec).
class ReadinessService {
  const ReadinessService();

  ReadinessData getToday() {
    return const ReadinessData(
      score: 86,
      caloriesProgress: 0.84, // outer lime ring (84% fueled)
      proteinProgress: 0.89, // middle cyan ring (142 / 160 g)
      bodyFatProgress: 0.62, // inner pink ring
      fueledValue: '84%',
      caloriesLabel: '1,840 kcal',
      loadValue: '246',
      loadLabel: 'push day',
      proteinValue: '142g',
      proteinTarget: 'of 160g',
      bodyFatValue: '18.2%',
      bodyFatDelta: '-0.6 lb',
    );
  }
}
