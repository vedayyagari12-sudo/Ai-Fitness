import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/units.dart';
import 'package:physiqo_ai/utils/weight_validation.dart';

/// A bad bodyweight does not stay in one place: it feeds the trend chart and
/// the TDEE that the calorie and protein targets are derived from, so one
/// mistyped digit skews the whole dashboard.
void main() {
  group('rejects out-of-range values', () {
    for (final lbs in ['79', '79.9', '0', '1', '351', '350.1', '1800']) {
      test('$lbs lbs', () {
        expect(isValidWeightInput(lbs), isFalse, reason: '$lbs was accepted');
        expect(weightInputError(lbs), kWeightRangeMessage);
      });
    }

    test('a negative value', () {
      expect(isValidWeightInput('-5'), isFalse);
    });

    test('a weight typed in kilograms', () {
      // 75 kg is a normal person, and a plausible thing to type into a field
      // labelled lbs — but as pounds it is a child.
      expect(isValidWeightInput('75'), isFalse);
    });
  });

  group('accepts realistic values', () {
    for (final lbs in ['80', '81', '120', '200', '250.5', '349', '350']) {
      test('$lbs lbs', () {
        expect(isValidWeightInput(lbs), isTrue, reason: '$lbs was rejected');
        expect(weightInputError(lbs), isNull);
      });
    }

    test('surrounding whitespace is tolerated', () {
      expect(isValidWeightInput(' 185 '), isTrue);
    });
  });

  group('non-numeric input', () {
    for (final raw in ['abc', '12kg', '--', '.', '1.2.3']) {
      test('"$raw" cannot be saved', () {
        expect(isValidWeightInput(raw), isFalse);
        expect(weightInputError(raw), isNotNull);
      });
    }

    test('an empty field is not an error yet, but cannot be saved', () {
      // Scolding before anything has been typed is noise; the save button is
      // what actually holds the line.
      expect(weightInputError(''), isNull);
      expect(isValidWeightInput(''), isFalse);
    });
  });

  group('the boundaries survive the kg round trip', () {
    // The app converts to kg before sending and the backend converts back,
    // so an exact boundary must not fall outside the range on the way.
    for (final lbs in [80.0, 350.0]) {
      test('$lbs lbs still reads as $lbs after kg conversion', () {
        final roundTripped = kgToLbs(lbsToKg(lbs));
        expect(roundTripped, closeTo(lbs, 0.05));
      });
    }
  });

  test('the message names both bounds', () {
    // It has to tell the user what to do, not just that they are wrong.
    expect(kWeightRangeMessage, contains('80'));
    expect(kWeightRangeMessage, contains('350'));
  });
}
