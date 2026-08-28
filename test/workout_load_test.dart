import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/data/bodyweight_load.dart';
import 'package:physiqo_ai/utils/workout_load.dart';

/// Bodyweight exercises used to contribute nothing to training load, because
/// nothing is typed into a weight field for them. These pin both halves of
/// the fix: that a name in any spelling reaches the right coefficient, and
/// that a missing bodyweight is reported rather than guessed at.
void main() {
  group('name matching', () {
    test('the same movement spelled every plausible way lands together', () {
      const spellings = [
        'Push-Up',
        'Push-Ups',
        'push up',
        'pushup',
        'PUSHUP',
        'Push  Ups',
        'push_ups',
      ];
      final keys = spellings.map(normaliseExerciseName).toSet();
      expect(keys, {'push up'}, reason: 'spellings did not converge: $keys');
    });

    test('a qualified name still resolves to its base movement', () {
      // The catalogue and the AI both produce names like these.
      for (final name in [
        'Wide Grip Pull-Ups',
        'Bulgarian Split Squat',
        'Goblet Squat',
        'Walking Lunges',
        'Weighted Dips',
      ]) {
        expect(
          bodyweightCoefficientFor(name),
          isNotNull,
          reason: '"$name" was not recognised as a bodyweight movement',
        );
      }
    });

    test('a plural "s" is dropped without mangling words that end in ss', () {
      // "Press" must not become "pres".
      expect(normaliseExerciseName('Bench Press'), 'bench press');
      expect(normaliseExerciseName('Overhead Press'), 'overhead press');
      expect(normaliseExerciseName('Squats'), 'squat');
      expect(normaliseExerciseName('Dips'), 'dip');
    });

    test('a barbell lift is not mistaken for a bodyweight one', () {
      for (final name in [
        'Bench Press',
        'Deadlift',
        'Barbell Row',
        'Bicep Curl',
        'Leg Press',
      ]) {
        expect(
          isBodyweightExercise(name),
          isFalse,
          reason: '"$name" should not carry a bodyweight coefficient',
        );
      }
    });

    test('empty and junk names resolve to nothing rather than throwing', () {
      for (final name in ['', '   ', '---', '123']) {
        expect(bodyweightCoefficientFor(name), isNull);
      }
    });
  });

  group('the coefficient table itself', () {
    test('every coefficient is a plausible fraction of a body', () {
      kBodyweightCoefficients.forEach((key, c) {
        expect(
          c.fraction,
          inInclusiveRange(0.1, 1.0),
          reason: '$key is $c.fraction of bodyweight, which cannot be right',
        );
      });
    });

    test('every entry carries a source', () {
      // The point of the source string is that a number can be checked and
      // corrected later. An entry without one is an invented number.
      kBodyweightCoefficients.forEach((key, c) {
        expect(c.source.trim(), isNotEmpty, reason: '$key has no source');
      });
    });

    test('anything not measured or definitional is flagged as such', () {
      // A reader should be able to tell a force-plate result from a guess.
      final squat = kBodyweightCoefficients['squat']!;
      expect(squat.evidence, LoadEvidence.derived);
      final lunge = kBodyweightCoefficients['lunge']!;
      expect(lunge.evidence, LoadEvidence.estimate);
      expect(lunge.isEstimate, isTrue);
    });

    test('the push-up matches the published measurement', () {
      // Ebben et al. 2011 measured 64% of body mass.
      expect(kBodyweightCoefficients['push up']!.fraction, 0.64);
      expect(
        kBodyweightCoefficients['push up']!.evidence,
        LoadEvidence.measured,
      );
    });

    test('hanging and supported movements are full bodyweight', () {
      for (final k in ['pull up', 'chin up', 'dip']) {
        expect(kBodyweightCoefficients[k]!.fraction, 1.00, reason: k);
      }
    });

    test('the plank is deliberately absent', () {
      // Load here is weight x sets x reps, and a plank has a duration rather
      // than reps — a 60s hold read as 60 reps would out-score a heavy squat
      // session. Isometrics need time-under-tension, not a coefficient.
      expect(bodyweightCoefficientFor('Plank'), isNull);
      expect(bodyweightCoefficientFor('Side Plank'), isNull);
    });
  });

  group('load', () {
    test('a bodyweight exercise costs bodyweight x coefficient x volume', () {
      final l = exerciseLoad(
        exerciseName: 'Push-Ups',
        sets: 3,
        reps: 10,
        bodyweightLbs: 180,
      );
      expect(l.lbs, closeTo(180 * 0.64 * 30, 0.01));
      expect(l.needsBodyweight, isFalse);
    });

    test('external weight ADDS to bodyweight, it does not replace it', () {
      // A 25lb weighted pull-up must not score lower than an unweighted one.
      final plain = exerciseLoad(
        exerciseName: 'Pull-Ups',
        sets: 3,
        reps: 8,
        bodyweightLbs: 180,
      );
      final weighted = exerciseLoad(
        exerciseName: 'Pull-Ups',
        sets: 3,
        reps: 8,
        externalWeightLbs: 25,
        bodyweightLbs: 180,
      );
      expect(weighted.lbs, greaterThan(plain.lbs));
      expect(weighted.lbs, closeTo((180 * 1.0 + 25) * 24, 0.01));
    });

    test('an unknown bodyweight is reported, never guessed', () {
      final l = exerciseLoad(
        exerciseName: 'Push-Ups',
        sets: 3,
        reps: 10,
        bodyweightLbs: null,
      );
      expect(l.needsBodyweight, isTrue);
      expect(l.lbs, 0, reason: 'a default bodyweight must not be invented');
    });

    test('added plates still count when bodyweight is unknown', () {
      final l = exerciseLoad(
        exerciseName: 'Weighted Dips',
        sets: 3,
        reps: 8,
        externalWeightLbs: 45,
        bodyweightLbs: null,
      );
      expect(l.lbs, closeTo(45 * 24, 0.01));
      expect(l.needsBodyweight, isTrue, reason: 'still incomplete');
    });

    test('an ordinary lift is unaffected by any of this', () {
      final l = exerciseLoad(
        exerciseName: 'Bench Press',
        sets: 4,
        reps: 8,
        externalWeightLbs: 185,
        bodyweightLbs: 180,
      );
      expect(l.lbs, closeTo(185 * 32, 0.01));
      expect(l.needsBodyweight, isFalse);
    });

    test('zero sets or reps costs nothing rather than erroring', () {
      for (final (s, r) in [(0, 10), (3, 0), (0, 0)]) {
        final l = exerciseLoad(
          exerciseName: 'Push-Ups',
          sets: s,
          reps: r,
          bodyweightLbs: 180,
        );
        expect(l.lbs, 0);
      }
    });

    test('nonsense bodyweight is treated as unknown, not used', () {
      for (final bad in [0.0, -50.0, double.nan, double.infinity]) {
        final l = exerciseLoad(
          exerciseName: 'Push-Ups',
          sets: 3,
          reps: 10,
          bodyweightLbs: bad,
        );
        expect(l.needsBodyweight, isTrue, reason: 'bodyweight was $bad');
      }
    });
  });

  group('session total', () {
    test('sums exercises and carries the missing-bodyweight flag up', () {
      final loads = [
        exerciseLoad(
          exerciseName: 'Bench Press',
          sets: 3,
          reps: 10,
          externalWeightLbs: 135,
        ),
        exerciseLoad(exerciseName: 'Push-Ups', sets: 3, reps: 10),
      ];
      final total = sessionLoad(loads);
      expect(total.lbs, closeTo(135 * 30, 0.01));
      expect(
        total.needsBodyweight,
        isTrue,
        reason: 'one exercise could not be costed, so the total is incomplete',
      );
    });

    test('a fully-costed session reports nothing missing', () {
      final total = sessionLoad([
        exerciseLoad(
          exerciseName: 'Squats',
          sets: 5,
          reps: 5,
          bodyweightLbs: 180,
        ),
      ]);
      expect(total.needsBodyweight, isFalse);
      expect(total.lbs, greaterThan(0));
    });

    test('an empty session is zero, not an error', () {
      final total = sessionLoad(const []);
      expect(total.lbs, 0);
      expect(total.needsBodyweight, isFalse);
    });
  });

  group('weight input bounds', () {
    test('zero is allowed — an unweighted movement is not an error', () {
      expect(liftWeightInputError('0'), isNull);
    });

    test('ordinary lifts pass', () {
      for (final v in ['45', '135', '225.5', '405', '1500']) {
        expect(liftWeightInputError(v), isNull, reason: v);
      }
    });

    test('negatives are rejected', () {
      expect(liftWeightInputError('-10'), isNotNull);
    });

    test('an absurd value is rejected', () {
      expect(liftWeightInputError('9999'), kLiftRangeMessage);
    });

    test('non-numeric input is rejected', () {
      for (final v in ['abc', '12kg', '1.2.3', '--']) {
        expect(liftWeightInputError(v), isNotNull, reason: v);
      }
    });

    test('an empty field is not yet an error, but is not valid to save', () {
      expect(liftWeightInputError(''), isNull);
      expect(isValidLiftWeight(''), isFalse);
    });

    test('surrounding whitespace is tolerated', () {
      expect(isValidLiftWeight('  135  '), isTrue);
    });
  });
}
