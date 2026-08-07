import 'package:physiqo_ai/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// MainScreen uses `extendBody: true`, so tab content is laid out behind the
/// bottom nav bar. The SCAN/BODY/TRAIN tabs use `SafeArea(bottom: false)` so
/// their background paints through, which means their scroll views have to
/// pad for the nav bar themselves or the last item is covered by it.
void main() {
  testWidgets('clearance reports the inset when SafeArea did not consume it', (
    tester,
  ) async {
    double? clearance;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 112)),
        child: MaterialApp(
          home: SafeArea(
            bottom: false,
            child: Builder(
              builder: (context) {
                clearance = navBarClearance(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(clearance, 112);
  });

  testWidgets('clearance is zero once a SafeArea has consumed the inset', (
    tester,
  ) async {
    double? clearance;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 112)),
        child: MaterialApp(
          home: SafeArea(
            child: Builder(
              builder: (context) {
                clearance = navBarClearance(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(
      clearance,
      0,
      reason: 'adding it unconditionally must not double-pad',
    );
  });

  testWidgets('a padded list keeps its last item clear of the nav bar', (
    tester,
  ) async {
    const navBar = 112.0;
    const screenHeight = 600.0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, screenHeight),
          padding: EdgeInsets.only(bottom: navBar),
        ),
        child: MaterialApp(
          home: SafeArea(
            bottom: false,
            child: Builder(
              builder: (context) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  32 + navBarClearance(context),
                ),
                children: [
                  for (var i = 0; i < 12; i++)
                    SizedBox(height: 80, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Scroll to the very bottom, then confirm the final row sits above where
    // the nav bar starts rather than underneath it.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    final lastRow = tester.getRect(find.text('row 11'));
    expect(
      lastRow.bottom,
      lessThanOrEqualTo(screenHeight - navBar),
      reason: 'last row is hidden behind the bottom nav bar',
    );
  });
}
