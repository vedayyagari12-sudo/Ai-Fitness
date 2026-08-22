/// Energy per gram. Fat carries more than twice what protein and carbs do,
/// which is the whole reason this split is computed in calories rather than
/// grams: 60g of fat and 60g of carbs are the same bar by weight and wildly
/// different shares of the day.
const double kcalPerGramProtein = 4;
const double kcalPerGramCarbs = 4;
const double kcalPerGramFat = 9;

/// Today's macros expressed as shares of the calories they contribute.
///
/// Pure so the arithmetic can be tested without a widget tree, and so the
/// donut and its legend can never disagree about what the numbers are.
class MacroSplit {
  const MacroSplit._({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  final double proteinG;
  final double carbsG;
  final double fatG;

  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;

  /// Whole percentages that always total exactly 100 when there is any food
  /// logged — see [_apportion].
  final int proteinPercent;
  final int carbsPercent;
  final int fatPercent;

  double get totalKcal => proteinKcal + carbsKcal + fatKcal;

  /// True when there is nothing to draw. Callers must branch on this before
  /// building a chart: a pie with no positive values renders as an invisible
  /// ring, and an empty section list throws outright.
  bool get isEmpty => !(totalKcal > 0);

  /// Sanitises its inputs rather than trusting them. Macro grams come from an
  /// AI estimate of a photo, so a missing field, a negative, or a NaN are all
  /// reachable — and NaN in particular would poison every downstream
  /// comparison silently.
  factory MacroSplit.fromGrams({
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    double clean(double v) => (v.isFinite && v > 0) ? v : 0;

    final p = clean(proteinG), c = clean(carbsG), f = clean(fatG);
    final pk = p * kcalPerGramProtein;
    final ck = c * kcalPerGramCarbs;
    final fk = f * kcalPerGramFat;
    final shares = _apportion([pk, ck, fk]);

    return MacroSplit._(
      proteinG: p,
      carbsG: c,
      fatG: f,
      proteinKcal: pk,
      carbsKcal: ck,
      fatKcal: fk,
      proteinPercent: shares[0],
      carbsPercent: shares[1],
      fatPercent: shares[2],
    );
  }

  /// Whole percentages that sum to exactly 100, by largest remainder.
  ///
  /// Rounding each share independently is the obvious approach and it visibly
  /// fails: 33.3/33.3/33.3 renders as "33% + 33% + 33%" next to a ring that is
  /// plainly full. This hands the leftover points to the largest fractions.
  static List<int> _apportion(List<double> parts) {
    final total = parts.fold<double>(0, (a, b) => a + b);
    if (!(total > 0)) return List<int>.filled(parts.length, 0);

    final exact = [for (final p in parts) p / total * 100];
    final floors = [for (final e in exact) e.floor()];
    var remaining = 100 - floors.fold<int>(0, (a, b) => a + b);

    // Ties broken by index, not left to the sort. Dart's List.sort is not
    // stable, so an exact tie — 100g each of protein and carbs, which is an
    // ordinary day — could hand the spare point to a different macro on each
    // rebuild and make the legend flicker between 24% and 23%.
    final order = List<int>.generate(parts.length, (i) => i)
      ..sort((a, b) {
        final byRemainder = (exact[b] - floors[b]).compareTo(
          exact[a] - floors[a],
        );
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });
    for (var i = 0; i < remaining && i < order.length; i++) {
      floors[order[i]]++;
    }
    return floors;
  }

  /// One plain-English line about the split, in the register the trend card
  /// already uses. Returns empty when there is nothing to say about.
  ///
  /// [goal] is the user's training goal ("cut", "bulk", "maintain"…); protein
  /// matters more on a cut, so the threshold moves with it.
  String takeaway(String goal) {
    if (isEmpty) return '';

    final g = goal.toLowerCase();
    final cutting =
        g.contains('cut') || g.contains('lose') || g.contains('shred');
    final proteinFloor = cutting ? 30 : 25;

    if (fatPercent >= 45) {
      return 'Fat is carrying $fatPercent% of today — high for most goals.';
    }
    if (proteinPercent < 15) {
      return 'Protein is light at $proteinPercent% — worth topping up.';
    }
    if (proteinPercent >= proteinFloor) {
      return cutting
          ? 'Protein at $proteinPercent% — a good share while cutting.'
          : 'Protein at $proteinPercent% of today, which is a solid share.';
    }
    return '$proteinPercent% protein · $carbsPercent% carbs · $fatPercent% fat.';
  }
}
