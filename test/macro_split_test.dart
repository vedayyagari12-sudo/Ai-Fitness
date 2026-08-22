import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/macro_split.dart';

/// The donut and its legend are drawn from the same object, so if this
/// arithmetic is wrong the chart lies consistently — which is worse than
/// obviously broken. Macro grams also arrive from an AI estimate of a photo,
/// so bad input is a normal case here rather than a hypothetical.
void main() {
  MacroSplit split(double p, double c, double f) =>
      MacroSplit.fromGrams(proteinG: p, carbsG: c, fatG: f);

  group('energy, not weight', () {
    test('fat is weighted at 9 kcal/g, protein and carbs at 4', () {
      final s = split(100, 100, 100);
      expect(s.proteinKcal, 400);
      expect(s.carbsKcal, 400);
      expect(s.fatKcal, 900);
      expect(s.totalKcal, 1700);
    });

    test('equal grams do NOT give equal shares', () {
      // The reason the split is computed in calories at all: by weight these
      // three look identical, and a third of the ring each would be wrong.
      final s = split(100, 100, 100);
      expect(s.fatPercent, greaterThan(s.proteinPercent));
      // 23.53/23.53/52.94 cannot round to three whole numbers that are both
      // equal and total 100, so one spare point has to be handed out. It goes
      // to the earlier macro, deterministically — see the tie-break note.
      expect(s.proteinPercent, 24);
      expect(s.carbsPercent, 23);
    });

    test('an exact tie resolves the same way every time', () {
      // Dart's List.sort is not stable, so without an explicit tie-break the
      // spare point could land on a different macro each rebuild and the
      // legend would flicker.
      final runs = {
        for (var i = 0; i < 50; i++)
          '${split(100, 100, 100).proteinPercent}/'
              '${split(100, 100, 100).carbsPercent}',
      };
      expect(runs, hasLength(1), reason: 'apportionment is not deterministic');
    });

    test('a realistic day lands where you would expect', () {
      final s = split(180, 210, 62); // 720 + 840 + 558 = 2118 kcal
      expect(s.totalKcal, closeTo(2118, 0.01));
      expect(s.proteinPercent, 34);
      expect(s.carbsPercent, 40);
      expect(s.fatPercent, 26);
    });
  });

  group('percentages always total 100', () {
    test('a three-way tie does not render as 33/33/33', () {
      // Rounding each share on its own gives 33+33+33 = 99 beside a visibly
      // full ring. Largest-remainder hands the spare point out.
      final s = split(100, 100, 100 * 4 / 9);
      expect(
        s.proteinPercent + s.carbsPercent + s.fatPercent,
        100,
        reason: '${s.proteinPercent}/${s.carbsPercent}/${s.fatPercent}',
      );
    });

    test('holds across many awkward ratios', () {
      for (var p = 0; p <= 300; p += 7) {
        for (var c = 0; c <= 300; c += 11) {
          for (var f = 0; f <= 120; f += 13) {
            final s = split(p.toDouble(), c.toDouble(), f.toDouble());
            if (s.isEmpty) continue;
            expect(
              s.proteinPercent + s.carbsPercent + s.fatPercent,
              100,
              reason:
                  'p=$p c=$c f=$f gave '
                  '${s.proteinPercent}/${s.carbsPercent}/${s.fatPercent}',
            );
          }
        }
      }
    });

    test('a single macro takes the whole ring', () {
      final s = split(150, 0, 0);
      expect(s.proteinPercent, 100);
      expect(s.carbsPercent, 0);
      expect(s.fatPercent, 0);
    });
  });

  group('bad input cannot reach the chart', () {
    test('nothing logged reads as empty', () {
      expect(split(0, 0, 0).isEmpty, isTrue);
    });

    test('NaN is treated as no data, not as a value', () {
      // The dangerous one: NaN compares false against everything, so an
      // unguarded `total <= 0` would let it through and every downstream
      // comparison would quietly misbehave.
      final s = split(double.nan, double.nan, double.nan);
      expect(s.isEmpty, isTrue);
      expect(s.totalKcal.isNaN, isFalse);
    });

    test('infinity is discarded', () {
      final s = split(double.infinity, 50, 10);
      expect(s.proteinG, 0);
      expect(s.totalKcal, closeTo(50 * 4 + 10 * 9, 0.01));
    });

    test('negative grams are discarded rather than subtracted', () {
      final s = split(-40, 100, 20);
      expect(s.proteinG, 0);
      expect(s.totalKcal, closeTo(100 * 4 + 20 * 9, 0.01));
      expect(s.isEmpty, isFalse);
    });

    test('a partial log still renders', () {
      // Plenty of logged meals carry calories and protein but no carb or fat
      // breakdown.
      final s = split(40, 0, 0);
      expect(s.isEmpty, isFalse);
      expect(s.proteinPercent, 100);
    });
  });

  group('takeaway', () {
    test('says nothing when there is nothing logged', () {
      expect(split(0, 0, 0).takeaway('bulk'), isEmpty);
    });

    test('flags a fat-heavy day', () {
      expect(
        split(20, 20, 90).takeaway('maintain'),
        contains('Fat is carrying'),
      );
    });

    test('flags a protein-light day', () {
      expect(split(5, 300, 40).takeaway('bulk'), contains('Protein is light'));
    });

    test('the protein bar is higher when cutting', () {
      // 27% protein: praised on a bulk, not yet praised on a cut.
      const p = 67.5, c = 125.0, f = 25.5;
      expect(split(p, c, f).takeaway('bulk'), contains('solid share'));
      expect(split(p, c, f).takeaway('cut'), isNot(contains('good share')));
    });

    test('never leaves the sentence unpunctuated or empty when fed', () {
      for (final goal in ['cut', 'bulk', 'maintain', 'athletic', '']) {
        final t = split(120, 200, 60).takeaway(goal);
        expect(t, isNotEmpty);
        expect(t.trim(), endsWith('.'));
      }
    });
  });
}
