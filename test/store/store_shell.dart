import 'package:flutter/material.dart';

import 'package:physiqo_ai/theme/app_theme.dart';
import 'package:physiqo_ai/theme/app_widgets.dart';
import 'package:physiqo_ai/theme/theme_controller.dart';

/// Phone frame for the Play Store screenshots.
///
/// 1080x1920 is the 9:16 shape Play accepts for phone shots; at the test
/// binding's 3.0 device pixel ratio that is 360x640 logical, a real small-
/// phone size the app already has to support.
const Size kShotLogical = Size(360, 640);
const double kShotDpr = 3.0;

/// 1024x500 exactly, rendered at DPR 1.
const Size kFeatureLogical = Size(1024, 500);

/// Wraps screen content the way the app itself does: its own theme, and the
/// real [AmbientBackground] the four tab screens all sit inside.
///
/// The background matters more than it sounds. Every tab wraps its body in
/// AmbientBackground, which paints kPageGradient — a vertical fade from a
/// blue-tinted #1E2736 at the top down through #10131A to #0A0A0A. Rendering
/// onto a flat kBgDeep instead, as an earlier pass did, produced a dead black
/// page that read as a different app from the one on the phone.
Widget storeApp(Widget child, {bool light = false}) {
  AppColors.brightness = light ? Brightness.light : Brightness.dark;
  ThemeController.mode.value = light ? ThemeMode.light : ThemeMode.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    home: Scaffold(
      backgroundColor: kBgDeep,
      body: AmbientBackground(child: child),
    ),
  );
}

/// The app's bottom navigation, rebuilt to match what ships: four tabs, the
/// active one carrying its tab accent plus the short bar above it.
class ShotNavBar extends StatelessWidget {
  const ShotNavBar({super.key, required this.activeIndex});

  final int activeIndex;

  static const _tabs = [
    (Icons.home_rounded, 'TODAY'),
    (Icons.center_focus_strong_rounded, 'SCAN'),
    (Icons.person_rounded, 'BODY'),
    (Icons.fitness_center_rounded, 'TRAIN'),
  ];

  @override
  Widget build(BuildContext context) {
    final accents = [kBrand, kTabScan, kTabBody, kTabTrain];
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border(top: BorderSide(color: kGlassBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 3,
                    width: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i == activeIndex
                            ? accents[i]
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Icon(
                    _tabs[i].$1,
                    size: 20,
                    color: i == activeIndex ? accents[i] : kTextMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _tabs[i].$2,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: i == activeIndex ? accents[i] : kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Screen title row, matching the app's own header treatment.
class ShotHeader extends StatelessWidget {
  const ShotHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}

/// The TODAY tab's real header: date label over a greeting on the left, the
/// streak chip and profile avatar on the right. Mirrors the block in
/// today_screen.dart rather than inventing a title bar.
class ShotGreetingHeader extends StatelessWidget {
  const ShotGreetingHeader({
    super.key,
    required this.dateLabel,
    required this.greeting,
    required this.avatarInitial,
    this.streak,
  });

  final String dateLabel;
  final String greeting;
  final String avatarInitial;
  final Widget? streak;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: kLabelSmall.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(greeting, style: kHeadlineMedium.copyWith(fontSize: 26)),
            ],
          ),
        ),
        Row(
          children: [
            ?streak,
            if (streak != null) const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kBgCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                avatarInitial,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
