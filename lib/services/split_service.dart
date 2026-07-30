import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api_service.dart';

/// The user's preferred training split — drives which focus the AI session
/// generator uses each day. Cached locally for fast reads, and synced to the
/// account profile so it follows the user across devices/browser sessions
/// instead of living only in this device's local storage.
enum TrainingSplit { auto, ppl, upperLower, fullBody }

class SplitService {
  SplitService._();

  static const _keyBase = 'training_split';

  /// Per-account key: the split is a property of the user, not the device, so
  /// a second account on the same phone must not inherit the first one's.
  static String get _key {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      return uid == null ? _keyBase : '${_keyBase}_$uid';
    } catch (_) {
      return _keyBase;
    }
  }

  /// Local-first read: instant on repeat visits. On a device/browser with no
  /// local value yet (fresh install, or — on web — a dev server that landed
  /// on a new origin/port and so a fresh localStorage) it falls back to
  /// whatever's saved on the account profile, then caches that locally.
  static Future<TrainingSplit> getSplit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      return TrainingSplit.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => TrainingSplit.auto,
      );
    }
    final remote = await _fetchRemoteSplit();
    if (remote != null) {
      await prefs.setString(_key, remote.name);
      return remote;
    }
    return TrainingSplit.auto;
  }

  static Future<void> setSplit(TrainingSplit split) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, split.name);
    // Best-effort — don't block the UI on this write, and don't fail the
    // local save if it errors (e.g. offline).
    unawaited(upsertUserProfile({'training_split': split.name}));
  }

  static Future<TrainingSplit?> _fetchRemoteSplit() async {
    try {
      final profile = await getUserProfile();
      final raw = profile?['training_split'] as String?;
      if (raw == null) return null;
      for (final s in TrainingSplit.values) {
        if (s.name == raw) return s;
      }
      return null;
    } catch (_) {
      return null;
    }
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
