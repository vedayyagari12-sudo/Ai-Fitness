import 'package:fitness_app/screens/onboarding/onboarding_flow.dart';
import 'package:fitness_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks the onboarding flow — which every new signup now sees — on a small
/// phone, asserting no step overflows. Runs at 320x568 (smallest supported
/// phone) and again with large system text.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> walkSteps(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(home: OnboardingFlow(onComplete: () {})),
      ),
    );
    // The welcome step animates continuously, so settle() would never return.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: 'welcome step overflowed');

    // The test font is wider than the real one, so at 320dp these steps
    // legitimately scroll — reach the control before tapping it.
    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(finder, warnIfMissed: false);
    }

    await tapVisible(find.text('Get Started'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));

    // Steps 1-7 are answer-then-continue. Step 8 (physique scan) is the last
    // and its Continue writes to Supabase, so it's rendered but not completed.
    for (var step = 1; step <= 8; step++) {
      expect(tester.takeException(), isNull, reason: 'step $step overflowed');
      if (step == 8) break;

      final tiles = find.byType(SelectionTile);
      if (tiles.evaluate().isNotEmpty) {
        // Tap the tile's label, not the tile: at a large text size a tile can
        // be taller than the scroll viewport, putting its centre off-screen.
        await tapVisible(
          find.descendant(of: tiles.first, matching: find.byType(Text)).first,
        );
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        // Body stats: three numeric fields gate the Continue button.
        final fields = find.byType(TextField);
        if (fields.evaluate().isNotEmpty) {
          await tester.enterText(fields.at(0), '30');
          await tester.enterText(fields.at(1), '180');
          await tester.enterText(fields.at(2), '185');
          await tester.pump(const Duration(milliseconds: 400));
        }
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'step $step overflowed after answering',
      );

      // The Continue button only exists once the step has an answer, so its
      // absence means the answer above didn't take.
      final continueButton = find.byType(ContinueButton);
      expect(
        continueButton,
        findsOneWidget,
        reason: 'step $step has no enabled Continue button',
      );
      await tapVisible(continueButton);
      // Two frames: one to run the AnimatedSwitcher transition, one for it to
      // drop the outgoing step (whose widgets would otherwise be found first).
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('onboarding steps do not overflow on a small phone', (
    tester,
  ) async {
    await walkSteps(tester);
  });

  testWidgets('onboarding steps do not overflow with large text', (
    tester,
  ) async {
    await walkSteps(tester, textScale: 1.3);
  });
}
