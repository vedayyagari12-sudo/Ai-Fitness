import 'package:flutter/foundation.dart';

/// Cross-tab navigation: any screen can switch the active main tab
/// (e.g. "Start session" on TODAY, focus-areas banner on SCAN → TRAIN).
/// 0 = TODAY, 1 = SCAN, 2 = BODY, 3 = TRAIN.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);

/// Data-changed ticks. Screens subscribe (addListener in initState,
/// removeListener in dispose) and reload when a write happens elsewhere.
/// Unlike a global callback slot, any number of live listeners is safe.
final ValueNotifier<int> todayTick = ValueNotifier<int>(0);
final ValueNotifier<int> historyTick = ValueNotifier<int>(0);

/// Call after any write that changes TODAY's dashboard numbers
/// (meals, workouts, bodyweight, profile).
void triggerTodayRefresh() => todayTick.value++;

/// Call after any write that changes the workout history list.
void triggerHistoryRefresh() => historyTick.value++;
