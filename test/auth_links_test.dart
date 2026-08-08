import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/services/auth_links.dart';

/// The redirect URL has to match the Android intent filter, the iOS URL
/// scheme and Supabase's allow-list. If any drifts, verification silently
/// falls back to opening a browser — which looks like nothing happening.
void main() {
  test('the email redirect is an https page, not the app scheme', () {
    // Mail clients open this, and webmail cannot follow a custom scheme —
    // pointing the email straight at physiqoai:// silently does nothing for
    // anyone reading mail in a browser.
    final uri = Uri.parse(kEmailRedirectUrl);
    expect(uri.scheme, 'https');
    expect(uri.path, endsWith('verified.html'));
  });

  test('the app link matches the scheme and host we register', () {
    final uri = Uri.parse(kAppLinkUrl);
    expect(uri.scheme, kAuthLinkScheme);
    expect(uri.host, kAuthLinkHost);
    // Pinned literally: duplicated in AndroidManifest.xml, Info.plist and
    // docs/verified.html, none of which share this constant.
    expect(kAppLinkUrl, 'physiqoai://verified');
  });

  test('the fallback page forwards auth parameters to the app', () {
    // Supabase appends ?code= (PKCE) or #access_token= (implicit). Dropping
    // them opens the app with nothing to exchange, so no session appears and
    // the link looks broken.
    final page = File('docs/verified.html').readAsStringSync();
    expect(page, contains('physiqoai://verified'));
    expect(
      page,
      contains('window.location.search'),
      reason: 'the PKCE code would be dropped',
    );
    expect(
      page,
      contains('window.location.hash'),
      reason: 'implicit-flow tokens would be dropped',
    );
    expect(page, contains('Email Verified!'));
  });

  test('the fallback page is reachable at the redirect URL', () {
    // The constant and the hosted filename must agree or Supabase redirects
    // to a 404.
    expect(File('docs/verified.html').existsSync(), isTrue);
    expect(kEmailRedirectUrl, endsWith('/verified.html'));
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
    test('accepts the app link, with or without tokens attached', () {
      // The app only ever sees kAppLinkUrl — the https redirect is opened by
      // the browser, which then hands off to this.
      expect(isEmailVerificationLink(Uri.parse(kAppLinkUrl)), isTrue);
      expect(
        isEmailVerificationLink(
          Uri.parse('physiqoai://verified?code=pkce-auth-code'),
        ),
        isTrue,
      );
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
