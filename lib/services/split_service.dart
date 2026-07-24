import 'package:shared_preferences/shared_preferences.dart';

/// The user's preferred training split — drives which focus the AI session
/// generator uses each day. Stored locally as a device preference.
enum TrainingSplit { auto, ppl, upperLower, fullBody }

class SplitService {
  SplitService._();

  static const _key = 'training_split';

  static Future<TrainingSplit> getSplit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return TrainingSplit.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => TrainingSplit.auto,
    );
  }

  static Future<void> setSplit(TrainingSplit split) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, split.name);
  }

  static String label(TrainingSplit s) => switch (s) {
    TrainingSplit.ppl => 'Push / Pull / Legs',
    TrainingSplit.upperLower => 'Upper / Lower',
    TrainingSplit.fullBody => 'Full Body',
    TrainingSplit.auto => 'Auto (balanced)',
  };

  /// Focus used when a split schedules recovery for the day.
  static const rest = 'Rest';

  /// Weekly rotation for a split, Monday first. Rest days are real parts of
  /// the plan — muscle is built during recovery, not just training.
  static List<String> rotation(TrainingSplit split) => switch (split) {
    // Classic 6-on / 1-off push-pull-legs.
    TrainingSplit.ppl => const [
      'Push',
      'Pull',
      'Legs',
      'Push',
      'Pull',
      'Legs',
      rest,
    ],
    // 4-day upper/lower with recovery mid-week and on the weekend.
    TrainingSplit.upperLower => const [
      'Upper Body',
      'Lower Body',
      rest,
      'Upper Body',
      'Lower Body',
      rest,
      rest,
    ],
    // 3x/week full body with a rest day between each session.
    TrainingSplit.fullBody => const [
      'Full Body',
      rest,
      'Full Body',
      rest,
      'Full Body',
      rest,
      rest,
    ],
    // Balanced rotation with two recovery days.
    TrainingSplit.auto => const [
      'Push',
      'Pull',
      'Legs',
      rest,
      'Upper Body',
      'Full Body',
      rest,
    ],
  };

  /// Today's session focus for a split (Mon = first entry).
  /// Returns [rest] when the split schedules a recovery day.
  static String focusForToday(TrainingSplit split) {
    final r = rotation(split);
    return r[(DateTime.now().weekday - 1) % r.length];
  }

  static bool isRestDay(TrainingSplit split) => focusForToday(split) == rest;
}
