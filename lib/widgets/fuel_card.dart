import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/macro_split.dart';
import 'macro_donut.dart';

/// Today's macro split — the ring, what each macro weighs, and one line about
/// the shape of the day.
///
/// Deliberately narrow in what it reports. The readiness card above it already
/// owns calories-against-target and protein-against-target, so repeating
/// either here would just be the same number twice on one screen. What is new
/// is the *composition*: carbs and fat appear nowhere else on the dashboard,
/// and the ratio between the three appears nowhere in the app at all.
class FuelCard extends StatelessWidget {
  const FuelCard({
    super.key,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.goal = 'maintain',
  });

  final double proteinG;
  final double carbsG;
  final double fatG;

  /// Drives the takeaway line — protein matters more on a cut.
  final String goal;

  @override
  Widget build(BuildContext context) {
    final split = MacroSplit.fromGrams(
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: kHeroCardGradient(kSteel),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
        boxShadow: kGlassShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S FUEL", style: kLabelSmall),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MacroDonut(split: split, size: 116),
              const SizedBox(width: 16),
              // Takes whatever the donut leaves: 124dp at a 320dp screen.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(
                      'PROTEIN',
                      split.proteinG,
                      split.proteinPercent,
                      MacroDonut.proteinColor,
                      split.isEmpty,
                    ),
                    const SizedBox(height: 12),
                    _legendRow(
                      'CARBS',
                      split.carbsG,
                      split.carbsPercent,
                      MacroDonut.carbsColor,
                      split.isEmpty,
                    ),
                    const SizedBox(height: 12),
                    _legendRow(
                      'FAT',
                      split.fatG,
                      split.fatPercent,
                      MacroDonut.fatColor,
                      split.isEmpty,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            split.isEmpty
                ? 'Scan a meal to see how today splits between protein, '
                      'carbs and fat.'
                : split.takeaway(goal),
            style: TextStyle(
              fontSize: 12.5,
              color: kTextSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// One macro: swatch, name, then grams and share.
  ///
  /// The name is a text label rather than colour alone, so the ring stays
  /// readable if the three hues are hard to tell apart.
  Widget _legendRow(
    String name,
    double grams,
    int percent,
    Color colour,
    bool empty,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A rounded square rather than a dot — the calorie chart's legend
        // already uses circles for a different thing.
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: empty ? kChartEmpty : colour,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kLabelSmall.copyWith(fontSize: 9.5),
              ),
              const SizedBox(height: 1),
              Text(
                empty ? '—' : '${grams.round()}g · $percent%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
