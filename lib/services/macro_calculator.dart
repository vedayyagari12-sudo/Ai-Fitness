import 'dart:math' as math;

import '../models/user_profile.dart';

// Re-export so callers/tests can `import 'macro_calculator.dart'` and get the
// profile types alongside the calculator (Step 2 spec).
export '../models/user_profile.dart';

/// Result of a Mifflin-St Jeor macro computation. All values are whole numbers.
class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.bmr,
    required this.tdee,
  });

  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int bmr;
  final int tdee;
}

class MacroCalculator {
  const MacroCalculator();

  MacroTargets calculate(UserProfile profile) {
    final base =
        10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.age;
    final bmr = profile.sex == Sex.male ? base + 5 : base - 161;
    final tdee = bmr * profile.activity.multiplier;
    final calories = tdee * profile.goal.multiplier;

    final proteinG = profile.weightKg * (profile.goal == Goal.cut ? 2.2 : 1.8);
    final fatG = (calories * 0.25) / 9;
    final carbsG = math.max(0, (calories - proteinG * 4 - fatG * 9) / 4);

    return MacroTargets(
      calories: calories.round(),
      proteinG: proteinG.round(),
      carbsG: carbsG.round(),
      fatG: fatG.round(),
      bmr: bmr.round(),
      tdee: tdee.round(),
    );
  }
}
