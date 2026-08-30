import 'package:flutter_test/flutter_test.dart';

/// The rule behind syncOnboardingToProfile, isolated from Supabase.
///
/// That function runs on EVERY app launch as a recovery path for someone
/// whose first sync never landed. It used to upsert all eight onboarding
/// answers unconditionally, so every launch quietly restored the original
/// answers over anything the user had since changed in Settings — equipment,
/// fitness level and weekly sessions appeared to save, saved correctly, and
/// were gone again on the next open, with no error anywhere because nothing
/// had failed.
///
/// The fix is that it seeds blanks and never overwrites. The merge itself is
/// what has to hold, so it is pinned here.
Map<String, dynamic> seedMissing(
  Map<String, dynamic> seed,
  Map<String, dynamic> existing,
) => {
  for (final entry in seed.entries)
    if (entry.value != null && existing[entry.key] == null)
      entry.key: entry.value,
};

void main() {
  const onboarding = {
    'goal': 'bulk',
    'gender': 'male',
    'age': 25,
    'height_cm': 180.0,
    'weight_kg': 80.0,
    'workout_frequency': '3-5',
    'equipment': 'Full Gym',
    'fitness_level': 'Beginner',
  };

  test('a brand-new profile is seeded with everything', () {
    final result = seedMissing(onboarding, {});
    expect(result.length, onboarding.length);
    expect(result['equipment'], 'Full Gym');
  });

  test('a setting the user has changed is never overwritten', () {
    // The reported bug, exactly: onboarding said "Full Gym", the user later
    // chose "Dumbbells Only", and the next launch put "Full Gym" back.
    final existing = {
      'equipment': 'Dumbbells Only',
      'fitness_level': 'Advanced',
      'workout_frequency': '6+',
    };
    final result = seedMissing(onboarding, existing);

    expect(result.containsKey('equipment'), isFalse);
    expect(result.containsKey('fitness_level'), isFalse);
    expect(result.containsKey('workout_frequency'), isFalse);
  });

  test('blanks are still filled while edited values are left alone', () {
    // A partially-complete profile: seed what is missing, touch nothing else.
    final existing = {'equipment': 'Dumbbells Only', 'age': null};
    final result = seedMissing(onboarding, existing);

    expect(result.containsKey('equipment'), isFalse);
    expect(result['age'], 25);
    expect(result['goal'], 'bulk');
  });

  test('a fully-populated profile produces no write at all', () {
    final existing = Map<String, dynamic>.from(onboarding);
    expect(seedMissing(onboarding, existing), isEmpty);
  });

  test('a null onboarding answer never overwrites a real value', () {
    // Someone who skipped a question during onboarding must not have that
    // blank pushed over an answer they gave later in Settings.
    final seed = {...onboarding, 'equipment': null};
    final existing = {'equipment': 'Dumbbells Only'};
    final result = seedMissing(seed, existing);
    expect(result.containsKey('equipment'), isFalse);
  });

  test('a null onboarding answer is not written to a blank profile either', () {
    final seed = {...onboarding, 'equipment': null};
    final result = seedMissing(seed, {});
    expect(
      result.containsKey('equipment'),
      isFalse,
      reason: 'writing an explicit null would clear the column',
    );
  });

  test('a value the user deliberately cleared is re-seeded, not respected', () {
    // Known and accepted: null on the profile is indistinguishable from
    // "never set", so clearing a field lets onboarding fill it again. The
    // app offers no way to clear one of these settings, so this is
    // unreachable today — recorded here so the limit is a decision rather
    // than a surprise.
    final result = seedMissing(onboarding, {'equipment': null});
    expect(result['equipment'], 'Full Gym');
  });
}
