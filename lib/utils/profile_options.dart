/// Canonical option lists for profile settings.
///
/// Onboarding and the profile screen each had their own copy, and they had
/// drifted into different vocabularies: onboarding stored "Resistance Bands"
/// and "Barbell Only", which the profile picker did not offer at all, and
/// onboarding's lowest training frequency was "0-2" while the profile
/// offered "1-2". A value chosen during onboarding therefore matched nothing
/// in the picker — it showed as unselected, and the setting looked lost.
///
/// One list, used by both.
library;

/// Equipment the user has access to, as stored in user_profiles.equipment.
const List<(String label, String value)> kEquipmentOptions = [
  ('Full Gym', 'Full Gym'),
  ('Dumbbells Only', 'Dumbbells Only'),
  ('Barbell Only', 'Barbell Only'),
  ('Resistance Bands', 'Resistance Bands'),
  ('Home — No Equipment', 'Home — No Equipment'),
];

/// Sessions per week, as stored in user_profiles.workout_frequency.
const List<(String label, String value)> kFrequencyOptions = [
  ('0–2', '0-2'),
  ('3–5', '3-5'),
  ('6+', '6+'),
];

const List<(String label, String value)> kFitnessLevelOptions = [
  ('Beginner', 'Beginner'),
  ('Intermediate', 'Intermediate'),
  ('Advanced', 'Advanced'),
];

/// Values written by earlier builds, mapped onto the canonical ones.
///
/// Without this an existing account keeps a value that no longer appears in
/// any list, so the picker shows nothing selected and the setting reads as
/// unset however many times it is saved.
const Map<String, String> _legacyEquipment = {
  'Home — Dumbbells': 'Dumbbells Only',
  'Home - Dumbbells': 'Dumbbells Only',
  'Bodyweight Only': 'Home — No Equipment',
  'Bodyweight': 'Home — No Equipment',
  'Home — No Equipment ': 'Home — No Equipment',
  'Bands and bodyweight': 'Resistance Bands',
};

const Map<String, String> _legacyFrequency = {
  '1-2': '0-2',
  '1–2': '0-2',
  '0–2': '0-2',
  '3–5': '3-5',
};

/// Maps a stored value onto the canonical one, so a legacy value still shows
/// as selected. Unrecognised values are returned unchanged rather than
/// discarded — losing a real setting is worse than displaying an odd one.
String normaliseEquipment(String? stored) {
  final value = (stored ?? '').trim();
  if (value.isEmpty) return '';
  if (_legacyEquipment.containsKey(value)) return _legacyEquipment[value]!;
  return value;
}

String normaliseFrequency(String? stored) {
  final value = (stored ?? '').trim();
  if (value.isEmpty) return '';
  if (_legacyFrequency.containsKey(value)) return _legacyFrequency[value]!;
  return value;
}

/// Whether a stored value corresponds to a real option, after normalising.
bool isKnownOption(List<(String, String)> options, String value) =>
    options.any((o) => o.$2 == value);
