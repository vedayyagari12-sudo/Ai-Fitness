class OnboardingData {
  String? goal;
  String? gender;
  int? age;
  double? heightCm;
  double? weightKg;
  String? workoutFrequency;
  String? equipment;
  String? hearAboutSource;
  bool? triedOtherApps;
  String? fitnessLevel;
  String? initialPhysiqueImagePath;

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'gender': gender,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'workout_frequency': workoutFrequency,
        'equipment': equipment,
        'hear_about_source': hearAboutSource,
        'tried_other_apps': triedOtherApps,
        'fitness_level': fitnessLevel,
        'initial_physique_image_path': initialPhysiqueImagePath,
      };
}
