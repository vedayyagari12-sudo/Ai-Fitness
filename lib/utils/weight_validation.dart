/// Bounds for a logged bodyweight, in pounds.
///
/// Wide enough to cover essentially any adult, narrow enough to catch the
/// realistic mistakes: a missed digit (18), a doubled one (1800), or a value
/// typed in kilograms into a field labelled lbs.
///
/// The same range is enforced on the backend, since anything reaching the API
/// directly would otherwise write a value that corrupts every derived number
/// — the weight trend, and the TDEE the calorie and protein targets come
/// from.
library;

const double kMinWeightLbs = 80;
const double kMaxWeightLbs = 350;

/// Shown under the input and returned by the API, so the two agree.
const String kWeightRangeMessage =
    'Please enter a weight between 80 and 350 lbs';

/// Validates raw input from the weight field.
///
/// Returns null when the value is acceptable, otherwise the message to show.
/// Empty input returns null so the field isn't scolding before anything has
/// been typed — the save button is gated on [isValidWeightInput] instead.
String? weightInputError(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final lbs = double.tryParse(text);
  if (lbs == null) return 'Enter a number';
  if (lbs.isNaN || lbs.isInfinite) return 'Enter a number';
  if (lbs < kMinWeightLbs || lbs > kMaxWeightLbs) return kWeightRangeMessage;
  return null;
}

/// Whether the save action should be allowed to run.
bool isValidWeightInput(String raw) {
  final lbs = double.tryParse(raw.trim());
  return lbs != null &&
      !lbs.isNaN &&
      !lbs.isInfinite &&
      lbs >= kMinWeightLbs &&
      lbs <= kMaxWeightLbs;
}
