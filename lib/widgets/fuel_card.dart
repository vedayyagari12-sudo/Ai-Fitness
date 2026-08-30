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
    this.loggedCalories,
  });

  final double proteinG;
  final double carbsG;
  final double fatG;

  /// Today's calories as logged. Shown in the ring's centre so this card
  /// agrees with the readiness ring and the calorie chart — see MacroDonut.
  final double? loggedCalories;

  /// Drives the takeaway line — protein matters more on a cut.
  final String goal;

  /// The ring at the narrowest phone this app supports (320dp — 16dp page
  /// padding, 16dp card padding either side = 256dp of content, 62% of
  /// that = 158.72). Rounded up to a clean number the clamp actually
  /// engages at, so 320dp has one guaranteed, documented ring size rather
  /// than whatever the formula happens to produce there — same reasoning
  /// as [ReadinessCard]'s own floor.
  static const double _minDiameter = 160.0;

  /// Cap on wide phones/tablets/desktop web — AmbientBackground already caps
  /// page content at 560dp. Held a little under the readiness ring's own
  /// 224dp ceiling: this card also has to fit a centre number, three stat
  /// columns and a takeaway line under the ring, where the readiness card
  /// spreads its stats above and below.
  static const double _maxDiameter = 200.0;

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
          // Centred and sized off the card's own width rather than sharing a
          // Row with the legend beside it — the old layout pinned the ring
          // to a fixed 116dp regardless of how wide the card actually was,
          // so any phone wider than the narrowest one left a strip of
          // untouched card down the side of it. Nothing sits beside the
          // ring now, so it can actually use the width it is given.
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final diameter = (constraints.maxWidth * 0.62).clamp(
                  _minDiameter,
                  _maxDiameter,
                );
                return MacroDonut(
                  split: split,
                  size: diameter,
                  loggedCalories: loggedCalories,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _legendStat(
                  'PROTEIN',
                  split.proteinG,
                  split.proteinPercent,
                  MacroDonut.proteinColor,
                  split.isEmpty,
                ),
              ),
              Expanded(
                child: _legendStat(
                  'CARBS',
                  split.carbsG,
                  split.carbsPercent,
                  MacroDonut.carbsColor,
                  split.isEmpty,
                  center: true,
                ),
              ),
              Expanded(
                child: _legendStat(
                  'FAT',
                  split.fatG,
                  split.fatPercent,
                  MacroDonut.fatColor,
                  split.isEmpty,
                  alignEnd: true,
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

  /// One macro's numbers, in the corner-stat idiom the readiness card above
  /// this one already uses (swatch, label, value) rather than the old
  /// legend-beside-the-ring row — three of these fill the width the bigger
  /// ring freed up instead of crowding beside it.
  Widget _legendStat(
    String name,
    double grams,
    int percent,
    Color colour,
    bool empty, {
    bool center = false,
    bool alignEnd = false,
  }) {
    final cross = center
        ? CrossAxisAlignment.center
        : alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final mainAlign = center
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        // FittedBox rather than trusting the Row to fit exactly: at 9.5px
        // with letterSpacing, "PROTEIN" is close enough to its column's
        // width that text-metric rounding pushed it a fraction of a pixel
        // over on some configurations — the same fix ReadinessCard's own
        // stat values already use for the identical reason.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: center
              ? Alignment.center
              : alignEnd
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: mainAlign,
            children: [
              // A rounded square rather than a dot — the calorie chart's
              // legend already uses circles for a different thing.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: empty ? kChartEmpty : colour,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(name, style: kLabelSmall.copyWith(fontSize: 9.5)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          empty ? '—' : '${grams.round()}g',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: center
              ? TextAlign.center
              : alignEnd
              ? TextAlign.right
              : TextAlign.left,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
        Text(
          empty ? '' : '$percent%',
          textAlign: center
              ? TextAlign.center
              : alignEnd
              ? TextAlign.right
              : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kTextMuted,
          ),
        ),
      ],
    );
  }
}
