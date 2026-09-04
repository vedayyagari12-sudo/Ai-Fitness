import 'package:flutter/material.dart';

import 'package:physiqo_ai/theme/app_theme.dart';

/// Supporting cards for the store shots.
///
/// The charts and rings in these screenshots are the app's own widgets; these
/// are the surrounding panels, built from the same theme tokens (hero-card
/// gradient, glass border, label and stat text styles) so they sit in the
/// shipped visual language rather than beside it.

class ShotScoreCard extends StatelessWidget {
  const ShotScoreCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: kHeroCardGradient(kSteel),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kGlassBorder),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PHYSIQUE SCORE', style: kLabelSmall),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('74', style: kStatHero.copyWith(color: kBrand)),
            Text(
              '/100',
              style: TextStyle(
                color: kTextMuted,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+6 since last',
                style: TextStyle(
                  color: kGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            ShotMiniStat(label: 'BODY FAT', value: '16.4%'),
            SizedBox(width: 20),
            ShotMiniStat(label: 'SYMMETRY', value: '8.1'),
            SizedBox(width: 20),
            ShotMiniStat(label: 'V-TAPER', value: '7.6'),
          ],
        ),
      ],
    ),
  );
}

class ShotMiniStat extends StatelessWidget {
  const ShotMiniStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: kLabelSmall.copyWith(fontSize: 9)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: kTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class ShotMealCard extends StatelessWidget {
  const ShotMealCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: kHeroCardGradient(kSteel),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kGlassBorder),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.restaurant_rounded, size: 15, color: kTabScan),
            const SizedBox(width: 7),
            Text('SCANNED MEAL', style: kLabelSmall),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Grilled chicken, rice & broccoli',
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('653', style: kStatLarge.copyWith(color: kTextPrimary)),
            const SizedBox(width: 6),
            Text(
              'kcal',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '52P / 64C / 21F',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ShotWorkoutMeta extends StatelessWidget {
  const ShotWorkoutMeta({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: kHeroCardGradient(kSteel),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kGlassBorder),
    ),
    padding: const EdgeInsets.all(16),
    child: const Row(
      children: [
        ShotMiniStat(label: 'EXERCISES', value: '6'),
        SizedBox(width: 20),
        ShotMiniStat(label: 'EST. TIME', value: '52 min'),
        SizedBox(width: 20),
        ShotMiniStat(label: 'TOTAL LOAD', value: '14,850 lb'),
      ],
    ),
  );
}

class ShotExerciseRow extends StatelessWidget {
  const ShotExerciseRow({
    super.key,
    required this.name,
    required this.sets,
    required this.load,
  });

  final String name;
  final String sets;
  final String load;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: kBgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kGlassBorder),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                load,
                style: TextStyle(
                  color: kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kTabTrain.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            sets,
            style: TextStyle(
              color: kTabTrain,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
