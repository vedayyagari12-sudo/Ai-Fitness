import 'package:supabase_flutter/supabase_flutter.dart';

/// Cache for the TODAY dashboard's "recent activity" panel — the meal/scan
/// list backing the meal-detail sheet and the "see all" sheet, plus an
/// optimistic "trained today" flag.
///
/// Two problems this solves:
///  - Reopening "See all" shouldn't hit the network every time — cache the
///    fetched meals/scans and only refetch after a write invalidates it.
///  - After finishing a workout, TODAY should show "Workout logged"
///    immediately. Waiting on a full dashboard refetch means racing
///    Supabase's read-after-write lag, which can leave the old "start a
///    workout" card on screen for a moment even though the save succeeded.
///    `trainedToday` is set the instant the save call returns, so the UI
///    updates before the dashboard round-trip even finishes.
class TodayCache {
  TodayCache._();

  static String? _dayKey;
  static String? _userKey;
  static bool trainedToday = false;
  static List<Map<String, dynamic>>? meals;
  static List<Map<String, dynamic>>? scans;

  static String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static String get _uid {
    // Tolerates Supabase not being initialised (tests, very early startup) —
    // this is cache scoping, never a reason to crash a screen.
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    } catch (_) {
      return 'anon';
    }
  }

  /// Drop yesterday's "trained" flag so each day starts fresh, and drop
  /// *everything* when the signed-in account changes — this is process-wide
  /// state, so without the account check a new signup on the same device
  /// inherits the previous user's "workout logged" flag and activity list.
  static void ensureToday() {
    if (_userKey != _uid) {
      _userKey = _uid;
      _dayKey = _today;
      reset();
      return;
    }
    if (_dayKey != _today) {
      _dayKey = _today;
      trainedToday = false;
    }
  }

  /// Wipes every cached value. Called on an account change and on sign-out.
  static void reset() {
    trainedToday = false;
    meals = null;
    scans = null;
  }

  static void markTrainedToday() {
    ensureToday();
    trainedToday = true;
  }

  /// Call after any write that changes the meal/scan list (new meal
  /// logged, new physique scan saved) so the next read refetches.
  static void invalidateActivity() {
    meals = null;
    scans = null;
  }
}
