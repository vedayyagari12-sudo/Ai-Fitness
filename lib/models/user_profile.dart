// Profile inputs for the Mifflin-St Jeor macro calculation (Step 2 spec).

enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityMultiplier on ActivityLevel {
  double get multiplier => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };
}

enum Goal { cut, maintain, bulk }

extension GoalMultiplier on Goal {
  double get multiplier => switch (this) {
    Goal.cut => 0.80,
    Goal.maintain => 1.0,
    Goal.bulk => 1.10,
  };
}

class UserProfile {
  const UserProfile({
    required this.age,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.activity,
    required this.goal,
  });

  final int age;
  final Sex sex;
  final double weightKg;
  final double heightCm;
  final ActivityLevel activity;
  final Goal goal;
}
