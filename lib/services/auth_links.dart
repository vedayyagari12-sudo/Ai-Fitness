/// Where Supabase sends users after they confirm their email.
///
/// This is an https page, not the app's own scheme, because the link is
/// opened by a mail client — and webmail (Gmail in a browser, most notably)
/// cannot open a custom scheme at all. Pointing the email straight at
/// physiqoai:// works when a native mail app handles it and silently does
/// nothing everywhere else.
///
/// So the email goes to a page we host, and that page immediately forwards
/// to [kAppLinkUrl], carrying the auth parameters with it. If the app is
/// installed the hand-off is invisible; if it is not, the page stays put and
/// explains what to do. See docs/verified.html.
///
/// Must be listed in Supabase → Authentication → URL Configuration →
/// Redirect URLs, or Supabase refuses to redirect here.
const String kEmailRedirectUrl =
    'https://vedayyagari12-sudo.github.io/Ai-Fitness/verified.html';

/// The app's own link, triggered by that page rather than by the email.
///
/// Must match the Android intent filter in AndroidManifest.xml and
/// CFBundleURLSchemes in ios/Runner/Info.plist.
const String kAppLinkUrl = 'physiqoai://verified';

/// Scheme and host of [kAppLinkUrl], for matching incoming links.
const String kAuthLinkScheme = 'physiqoai';
const String kAuthLinkHost = 'verified';

/// True when [uri] is the redirect our verification emails point at.
bool isEmailVerificationLink(Uri uri) =>
    uri.scheme == kAuthLinkScheme && uri.host == kAuthLinkHost;

/// True when the link reports a failure instead of carrying tokens.
///
/// Supabase signals an expired or already-used link by putting `error` /
/// `error_description` on the redirect — as query parameters or in the
/// fragment, depending on the flow — rather than by failing to open the app.
/// Without checking, a dead link looks exactly like a successful one: the
/// app opens, no session appears, and nothing explains why.
String? verificationLinkError(Uri uri) {
  String? read(Map<String, String> params) =>
      params['error_description'] ?? params['error'];

  final fromQuery = read(uri.queryParameters);
  if (fromQuery != null) return _humanise(fromQuery);

  if (uri.fragment.isNotEmpty) {
    try {
      final fragParams = Uri.splitQueryString(uri.fragment);
      final fromFragment = read(fragParams);
      if (fromFragment != null) return _humanise(fromFragment);
    } catch (_) {
      // A fragment that isn't query-encoded carries no error we can read.
    }
  }
  return null;
}

String _humanise(String raw) {
  final text = raw.replaceAll('+', ' ');
  final lower = text.toLowerCase();
  if (lower.contains('expired')) {
    return 'That verification link has expired. Sign in to get a new one.';
  }
  if (lower.contains('already') || lower.contains('used')) {
    return 'That link was already used. Try signing in.';
  }
  return text;
}
