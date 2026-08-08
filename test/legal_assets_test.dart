import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The legal pages are both bundled into the app and published on GitHub
/// Pages, so they live in docs/ and are declared as an asset folder. If that
/// declaration or a load path drifts, the in-app viewer shows a blank screen
/// — and Play requires those screens to work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pages = {
    'docs/privacy_policy.html': 'Privacy Policy',
    'docs/terms_of_service.html': 'Terms of Service',
    'docs/delete-account.html': 'Delete Your Physiqo AI Account',
  };

  pages.forEach((path, expectedTitle) {
    test('$path is bundled and readable', () async {
      final html = await rootBundle.loadString(path);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains(expectedTitle));
    });
  });

  test('legal pages carry a working contact address', () async {
    for (final path in pages.keys) {
      final html = await rootBundle.loadString(path);
      expect(
        html,
        contains('physiqoapp@gmail.com'),
        reason: '$path has no contact address',
      );
      expect(
        html,
        isNot(contains('aifitness.app')),
        reason: '$path still points at the old address, which does not exist',
      );
    }
  });

  test(
    'the deletion page states the retention promise and the photo fact',
    () async {
      final html = await rootBundle.loadString('docs/delete-account.html');
      // Both are commitments Play reviewers look for explicitly.
      expect(html, contains('within 30 days'));
      expect(html, contains('never stored'));
      expect(html, contains('Account Deletion Request'));
      // The in-app route must match the app's actual navigation.
      expect(html, contains('Profile → Delete Account'));
    },
  );

  test('privacy policy links to the deletion page', () async {
    final html = await rootBundle.loadString('docs/privacy_policy.html');
    expect(html, contains('delete-account.html'));
  });

  test('the contact address is never reachable only through mailto:', () async {
    // mailto: does nothing for anyone without a mail client configured,
    // which is most people on webmail. Every page must also render the
    // address as plain, selectable text.
    for (final path in pages.keys) {
      final html = await rootBundle.loadString(path);
      expect(
        html,
        contains('<span class="selectable">physiqoapp@gmail.com</span>'),
        reason: '$path only offers the address behind a mailto: link',
      );
    }
  });

  test(
    'the deletion page explains what to do if the button does nothing',
    () async {
      final html = await rootBundle.loadString('docs/delete-account.html');
      expect(html, contains('email us directly at'));
    },
  );
}
