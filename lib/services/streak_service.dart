import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/streak_state.dart';

/// Computes activity streaks. A day is "kept" if the user logged >=1 meal OR
/// completed >=1 workout that calendar day (local time). The streak is the run
/// of consecutive kept days ending today or yesterday — an un-kept *today*
/// does not break it, only a fully-passed empty day does (Step 3 spec).
class StreakService {
  StreakService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static DateTime _dayOf(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Future<Set<DateTime>> _keptDays(String userId) async {
    final meals = await _client
        .from('meal_logs')
        .select('logged_at')
        .eq('user_id', userId);
    final workouts = await _client
        .from('workout_logs')
        .select('completed_at')
        .eq('user_id', userId);

    final kept = <DateTime>{};
    for (final m in meals as List) {
      final raw = m['logged_at'];
      if (raw != null) kept.add(_dayOf(DateTime.parse(raw as String)));
    }
    for (final w in workouts as List) {
      final raw = w['completed_at'];
      if (raw != null) kept.add(_dayOf(DateTime.parse(raw as String)));
    }
    return kept;
  }

  int _streakFrom(Set<DateTime> kept) {
    final today = _dayOf(DateTime.now());
    var cursor = kept.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (kept.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<int> getCurrentStreak(String userId) async {
    return _streakFrom(await _keptDays(userId));
  }

  Future<bool> isTodayKept(String userId) async {
    final kept = await _keptDays(userId);
    return kept.contains(_dayOf(DateTime.now()));
  }

  /// Emits the current streak and re-emits whenever `meal_logs` or
  /// `workout_logs` change for this user.
  Stream<StreakState> watchStreak(String userId) {
    final controller = StreamController<StreakState>();

    Future<void> push() async {
      try {
        final kept = await _keptDays(userId);
        if (!controller.isClosed) {
          controller.add(
            StreakState(
              count: _streakFrom(kept),
              isTodayKept: kept.contains(_dayOf(DateTime.now())),
            ),
          );
        }
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    final mealSub = _client
        .from('meal_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => push());
    final workoutSub = _client
        .from('workout_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => push());

    controller.onCancel = () async {
      await mealSub.cancel();
      await workoutSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }
}
