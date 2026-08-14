import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/profile_options.dart';

/// Onboarding and the profile screen each kept their own copy of these
/// lists, and they had drifted apart: onboarding stored "Resistance Bands"
/// and "Barbell Only", which the profile picker did not offer, and
/// onboarding's lowest frequency was "0-2" against the profile's "1-2". A
/// value chosen during onboarding matched nothing in the picker, so the
/// setting showed as unset no matter how often it was saved.
void main() {
  group('every stored value is offered somewhere', () {
    test('the equipment a user can pick during onboarding is selectable', () {
      // These are the five onboarding wrote; all must survive.
      for (final stored in [
        'Full Gym',
        'Home — No Equipment',
        'Dumbbells Only',
        'Resistance Bands',
        'Barbell Only',
      ]) {
        expect(
          isKnownOption(kEquipmentOptions, normaliseEquipment(stored)),
          isTrue,
          reason: '"$stored" is stored but cannot be selected',
        );
      }
    });

    test('the frequency onboarding writes is selectable', () {
      for (final stored in ['0-2', '3-5', '6+']) {
        expect(
          isKnownOption(kFrequencyOptions, normaliseFrequency(stored)),
          isTrue,
          reason: '"$stored" is stored but cannot be selected',
        );
      }
    });
  });

  group('values written by earlier builds still resolve', () {
    test('old profile-only equipment names map onto real options', () {
      // Someone who set equipment in the old profile picker has one of these
      // stored; without mapping, their setting reads as unset forever.
      for (final legacy in ['Home — Dumbbells', 'Bodyweight Only']) {
        final resolved = normaliseEquipment(legacy);
        expect(
          isKnownOption(kEquipmentOptions, resolved),
          isTrue,
          reason: '"$legacy" does not resolve to a current option',
        );
      }
    });

    test('the old "1-2" frequency resolves to "0-2"', () {
      expect(normaliseFrequency('1-2'), '0-2');
      expect(isKnownOption(kFrequencyOptions, normaliseFrequency('1-2')), true);
    });

    test('an unrecognised value is kept, not discarded', () {
      // Losing a real setting is worse than showing an unfamiliar one.
      expect(normaliseEquipment('Kettlebells'), 'Kettlebells');
    });

    test('empty stays empty so it reads as genuinely unset', () {
      expect(normaliseEquipment(null), '');
      expect(normaliseEquipment('  '), '');
      expect(normaliseFrequency(null), '');
    });
  });

  group('the lists themselves are sane', () {
    test('no duplicate stored values', () {
      for (final list in [
        kEquipmentOptions,
        kFrequencyOptions,
        kFitnessLevelOptions,
      ]) {
        final values = list.map((o) => o.$2).toList();
        expect(values.toSet().length, values.length, reason: '$values');
      }
    });

    test('every option has a label and a value', () {
      for (final list in [
        kEquipmentOptions,
        kFrequencyOptions,
        kFitnessLevelOptions,
      ]) {
        for (final (label, value) in list) {
          expect(label.trim(), isNotEmpty);
          expect(value.trim(), isNotEmpty);
        }
      }
    });

    test('normalising a canonical value leaves it unchanged', () {
      for (final (_, value) in kEquipmentOptions) {
        expect(normaliseEquipment(value), value);
      }
      for (final (_, value) in kFrequencyOptions) {
        expect(normaliseFrequency(value), value);
      }
    });
  });
}
