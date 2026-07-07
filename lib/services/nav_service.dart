import 'package:flutter/foundation.dart';

/// Cross-tab navigation: any screen can switch the active main tab
/// (e.g. "Start session" on TODAY, focus-areas banner on SCAN → TRAIN).
/// 0 = TODAY, 1 = SCAN, 2 = BODY, 3 = TRAIN.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);
