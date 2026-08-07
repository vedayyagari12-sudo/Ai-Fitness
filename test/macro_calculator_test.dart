import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/services/macro_calculator.dart';

void main() {
  const calc = MacroCalculator();

  // Recompute the spec formula independently to assert against.
  ({int calories, int protein, int carbs, int fat, int bmr, int tdee}) expected(
    UserProfile p,
  ) {
    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
    final bmr = p.sex == Sex.male ? base + 5 : base - 161;
    final tdee = bmr * p.activity.multiplier;
    final cals = tdee * p.goal.multiplier;
    final protein = p.weightKg * (p.goal == Goal.cut ? 2.2 : 1.8);
    final fat = (cals * 0.25) / 9;
    final carbs = (cals - protein * 4 - fat * 9) / 4;
    return (
      calories: cals.round(),
      protein: protein.round(),
      carbs: (carbs < 0 ? 0.0 : carbs).round(),
      fat: fat.round(),
      bmr: bmr.round(),
      tdee: tdee.round(),
    );
  }

  test('male cut', () {
    const p = UserProfile(
      age: 30,
      sex: Sex.male,
      weightKg: 80,
      heightCm: 180,
      activity: ActivityLevel.moderate,
      goal: Goal.cut,
    );
    final r = calc.calculate(p);
    final e = expected(p);
    expect(r.bmr, e.bmr);
    expect(r.tdee, e.tdee);
    expect(r.calories, e.calories);
    expect(r.proteinG, e.protein);
    expect(r.fatG, e.fat);
    expect(r.carbsG, e.carbs);
    // Cut uses 2.2 g/kg protein.
    expect(r.proteinG, (80 * 2.2).round());
  });

  test('female maintain', () {
    const p = UserProfile(
      age: 28,
      sex: Sex.female,
      weightKg: 60,
      heightCm: 165,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
    );
    final r = calc.calculate(p);
    final e = expected(p);
    expect(r.calories, e.calories);
    expect(r.proteinG, (60 * 1.8).round());
    expect(r.tdee, e.tdee);
  });

  test('male bulk', () {
    const p = UserProfile(
      age: 22,
      sex: Sex.male,
      weightKg: 75,
      heightCm: 178,
      activity: ActivityLevel.active,
      goal: Goal.bulk,
    );
    final r = calc.calculate(p);
    final e = expected(p);
    expect(r.calories, e.calories);
    expect(r.proteinG, (75 * 1.8).round());
    // Bulk surplus: calories above TDEE.
    expect(r.calories, greaterThan(r.tdee));
  });

  test('low-weight edge case never returns negative carbs', () {
    const p = UserProfile(
      age: 70,
      sex: Sex.female,
      weightKg: 35,
      heightCm: 150,
      activity: ActivityLevel.sedentary,
      goal: Goal.cut,
    );
    final r = calc.calculate(p);
    expect(r.carbsG, greaterThanOrEqualTo(0));
  });
}
