import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/login_screen.dart';

/// The panel shown after signup is the point where a stalled account either
/// recovers or the user gives up. Two things it must say, because they are
/// the two reasons people get stuck: the mail is often delivered to spam
/// rather than not delivered at all, and the link opens a web page, so the
/// user has to come back and log in again themselves.
void main() {
  Widget panel({
    String email = 'someone@example.com',
    String message = '',
    bool isLoading = false,
    int resendCooldown = 0,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: VerificationPanel(
          email: email,
          message: message,
          isLoading: isLoading,
          resendCooldown: resendCooldown,
          onResend: () {},
          onBack: () {},
        ),
      ),
    ),
  );

  /// The panel is built from TextSpan trees, so `find.text` misses most of
  /// it. This flattens every span to the string a reader actually sees.
  String visibleText(WidgetTester tester) {
    final buffer = StringBuffer();
    for (final widget in tester.allWidgets.whereType<Text>()) {
      final span = widget.textSpan;
      buffer.write(span != null ? span.toPlainText() : (widget.data ?? ''));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// The style actually applied to [phrase], found by walking the span tree.
  TextStyle? styleOf(WidgetTester tester, String phrase) {
    for (final widget in tester.allWidgets.whereType<Text>()) {
      final root = widget.textSpan;
      if (root == null) continue;
      TextStyle? hit;
      root.visitChildren((span) {
        if (span is TextSpan && (span.text ?? '').contains(phrase)) {
          hit = span.style;
          return false;
        }
        return true;
      });
      if (hit != null) return hit;
    }
    return null;
  }

  testWidgets('tells the user their mail may be in spam', (tester) async {
    await tester.pumpWidget(panel());
    final text = visibleText(tester);

    expect(text, contains('spam or junk folder'));
    // The reason matters: without it "check spam" reads as boilerplate people
    // skip past rather than a specific warning about this app.
    expect(text, contains('new app'));
  });

  testWidgets('the spam wording is emphasised, not buried', (tester) async {
    await tester.pumpWidget(panel());

    final style = styleOf(tester, 'spam or junk folder');
    expect(style, isNotNull, reason: 'the phrase is not its own span');
    expect(
      style!.fontWeight!.value,
      greaterThanOrEqualTo(FontWeight.w700.value),
      reason: 'it sat in an 11px muted footnote before and got missed',
    );
  });

  testWidgets('"log in again" is bold so the next step is obvious', (
    tester,
  ) async {
    await tester.pumpWidget(panel());

    expect(visibleText(tester), contains('log in again'));

    final style = styleOf(tester, 'log in again');
    expect(style, isNotNull, reason: 'the phrase is not its own span');
    expect(
      style!.fontWeight!.value,
      greaterThanOrEqualTo(FontWeight.w700.value),
      reason:
          'the verification link lands on a web page, not in the app — '
          'this is the cue to come back here',
    );
  });

  testWidgets('shows the address the link was sent to', (tester) async {
    await tester.pumpWidget(panel(email: 'typo@gmial.com'));
    // A mistyped address is the other reason nothing arrives, so it has to be
    // readable back to the user.
    expect(visibleText(tester), contains('typo@gmial.com'));
  });

  testWidgets('the resend button is disabled while cooling down', (
    tester,
  ) async {
    await tester.pumpWidget(panel(resendCooldown: 42));

    expect(visibleText(tester), contains('Resend in 42s'));
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('the resend button works once the cooldown clears', (
    tester,
  ) async {
    await tester.pumpWidget(panel());

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
    expect(visibleText(tester), contains('Resend verification email'));
  });

  testWidgets('the panel lays out without overflowing a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      panel(
        message:
            'Verification email sent — check your inbox, and your '
            'spam or junk folder.',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
