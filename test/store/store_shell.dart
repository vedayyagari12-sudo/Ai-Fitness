import 'package:flutter/material.dart';

import 'package:physiqo_ai/theme/app_theme.dart';

/// Phone frame for the Play Store screenshots.
///
/// 1080x1920 is the 9:16 shape Play accepts for phone shots; at the test
/// binding's 3.0 device pixel ratio that is 360x640 logical, a real small-
/// phone size the app already has to support.
const Size kShotLogical = Size(360, 640);
const double kShotDpr = 3.0;

/// 1024x500 exactly, rendered at DPR 1.
const Size kFeatureLogical = Size(1024, 500);

/// Wraps screen content in the app's own dark theme and a Scaffold, so the
/// surfaces, text colours and dividers are the shipped ones rather than
/// anything restated here.
Widget storeApp(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.darkTheme,
  home: Scaffold(backgroundColor: kBgDeep, body: child),
);

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
