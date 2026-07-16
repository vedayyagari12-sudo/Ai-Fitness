/// Weight unit conversion. The database keeps kilograms (weight_kg columns);
/// the UI shows pounds everywhere.
const double kLbsPerKg = 2.20462;

double kgToLbs(num kg) => kg * kLbsPerKg;
double lbsToKg(num lbs) => lbs / kLbsPerKg;

/// "181.0" — one decimal, for display.
String lbsLabel(num lbs) => lbs.toStringAsFixed(1);
