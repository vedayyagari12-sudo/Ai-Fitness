import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/services/auth_links.dart';

/// The redirect URL has to match the Android intent filter, the iOS URL
/// scheme and Supabase's allow-list. If any drifts, verification silently
/// falls back to opening a browser — which looks like nothing happening.
void main() {
  test('the redirect URL matches the scheme and host we register', () {
    final uri = Uri.parse(kEmailRedirectUrl);
    expect(uri.scheme, kAuthLinkScheme);
    expect(uri.host, kAuthLinkHost);
    // Pinned literally: these three values are duplicated in
    // AndroidManifest.xml and Info.plist, which no test can read.
    expect(kEmailRedirectUrl, 'physiqoai://verified');
  });

  group('the platform config agrees with the Dart constant', () {
    // These live in files no other test reads. If they drift apart the link
    // opens a browser instead of the app, which looks to the user like the
    // link is simply broken.
    test('the Android intent filter registers the scheme and host', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains('android:scheme="$kAuthLinkScheme"'),
        reason: 'no intent filter for $kAuthLinkScheme',
      );
      expect(manifest, contains('android:host="$kAuthLinkHost"'));
      expect(manifest, contains('android.intent.category.BROWSABLE'));
      // Without singleTop a running app gets a second copy of itself rather
      // than the link.
      expect(manifest, contains('android:launchMode="singleTop"'));
    });

    test('the iOS URL scheme is registered', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('CFBundleURLSchemes'));
      expect(
        plist,
        contains('<string>$kAuthLinkScheme</string>'),
        reason: 'Info.plist does not declare $kAuthLinkScheme',
      );
    });
  });

  group('recognising our link', () {
    test('accepts the redirect, with or without tokens attached', () {
      expect(isEmailVerificationLink(Uri.parse(kEmailRedirectUrl)), isTrue);
      expect(
        isEmailVerificationLink(
          Uri.parse('physiqoai://verified#access_token=abc&type=signup'),
        ),
        isTrue,
      );
    });

    test('ignores links meant for something else', () {
      for (final other in [
        'https://example.com/verified',
        'physiqoai://reset-password',
        'otherapp://verified',
      ]) {
        expect(
          isEmailVerificationLink(Uri.parse(other)),
          isFalse,
          reason: '$other should not be treated as verification',
        );
      }
    });
  });

  group('reading a failed link', () {
    test('a link carrying tokens reports no error', () {
      expect(
        verificationLinkError(
          Uri.parse('physiqoai://verified#access_token=abc&expires_in=3600'),
        ),
        isNull,
      );
    });

    test('an expired link is explained in plain language', () {
      // Supabase puts the failure on the redirect rather than refusing to
      // open the app, so without reading it a dead link is indistinguishable
      // from a working one.
      final msg = verificationLinkError(
        Uri.parse(
          'physiqoai://verified#error=access_denied'
          '&error_description=Email+link+is+invalid+or+has+expired',
        ),
      );
      expect(msg, isNotNull);
      expect(msg, contains('expired'));
    });

    test('reads an error from the query string too', () {
      // Which half of the URL carries it depends on the flow.
      final msg = verificationLinkError(
        Uri.parse('physiqoai://verified?error_description=Token+has+expired'),
      );
      expect(msg, contains('expired'));
    });

    test('an already-used link says so', () {
      final msg = verificationLinkError(
        Uri.parse('physiqoai://verified#error_description=Token+already+used'),
      );
      expect(msg, contains('already used'));
    });

    test('an unrecognised error is surfaced rather than swallowed', () {
      final msg = verificationLinkError(
        Uri.parse('physiqoai://verified#error=server_error'),
      );
      expect(msg, 'server_error');
    });

    test('a malformed fragment does not throw', () {
      expect(
        () => verificationLinkError(Uri.parse('physiqoai://verified#%%%')),
        returnsNormally,
      );
    });
  });
}
