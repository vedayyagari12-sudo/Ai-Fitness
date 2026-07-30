import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/onboarding_data.dart';

class AppStateService {
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _onboardingDataKey = 'onboarding_data';
  static const _seenMilestonesKey = 'seen_milestones';

  static bool _guestMode = false;
  static bool get isGuestMode => _guestMode;
  static void setGuestMode(bool value) => _guestMode = value;

  // Every piece of onboarding state is per-account: two people (or one person
  // with two accounts) sharing a device must each get their own onboarding.
  static String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  static String _key(String base) {
    final uid = _uid;
    return uid == null ? base : '${base}_$uid';
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(_onboardingCompleteKey)) ?? false;
  }

  static Future<void> completeOnboarding(OnboardingData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_onboardingCompleteKey), true);
    await prefs.setString(_key(_onboardingDataKey), jsonEncode(data.toJson()));
  }

  // Sets the completion flag only — used when profile found in Supabase on reinstall.
  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_onboardingCompleteKey), true);
  }

  /// Wipes this device's legacy (unscoped) onboarding keys. Those were written
  /// before the state was namespaced per account and would otherwise let a
  /// brand-new signup inherit the previous user's "already onboarded" flag.
  static Future<void> clearLegacyOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompleteKey);
    await prefs.remove(_onboardingDataKey);
  }

  static Future<OnboardingData?> getOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(_onboardingDataKey));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return OnboardingData()
      ..goal = map['goal'] as String?
      ..gender = map['gender'] as String?
      ..age = map['age'] as int?
      ..heightCm = (map['height_cm'] as num?)?.toDouble()
      ..weightKg = (map['weight_kg'] as num?)?.toDouble()
      ..workoutFrequency = map['workout_frequency'] as String?
      ..equipment = map['equipment'] as String?
      ..hearAboutSource = map['hear_about_source'] as String?
      ..triedOtherApps = map['tried_other_apps'] as bool?
      ..fitnessLevel = map['fitness_level'] as String?
      ..initialPhysiqueImagePath =
          map['initial_physique_image_path'] as String?;
  }

  static Future<Set<int>> getSeenMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(_seenMilestonesKey)) ?? [];
    return list.map(int.parse).toSet();
  }

  static Future<void> markMilestoneSeen(int milestone) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = await getSeenMilestones();
    seen.add(milestone);
    await prefs.setStringList(
      _key(_seenMilestonesKey),
      seen.map((e) => e.toString()).toList(),
    );
  }
}
