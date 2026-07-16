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

  /// Today's session focus for a split (Mon = first entry).
  static String focusForToday(TrainingSplit split) {
    final rotation = switch (split) {
      TrainingSplit.ppl => const [
          'Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs', 'Full Body',
        ],
      TrainingSplit.upperLower => const [
          'Upper Body', 'Lower Body', 'Upper Body', 'Lower Body',
          'Upper Body', 'Lower Body', 'Full Body',
        ],
      TrainingSplit.fullBody => const [
          'Full Body', 'Full Body', 'Full Body', 'Full Body',
          'Full Body', 'Full Body', 'Full Body',
        ],
      TrainingSplit.auto => const [
          'Push', 'Pull', 'Legs', 'Upper Body', 'Push', 'Full Body', 'Pull',
        ],
    };
    return rotation[(DateTime.now().weekday - 1) % rotation.length];
  }
}
