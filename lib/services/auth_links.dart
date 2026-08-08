/// Deep link Supabase sends users back to after they confirm their email.
///
/// It must match three places or verification silently falls back to opening
/// a browser:
///   1. the Android intent filter in AndroidManifest.xml
///   2. CFBundleURLSchemes in ios/Runner/Info.plist
///   3. Supabase dashboard → Authentication → URL Configuration →
///      Redirect URLs (Supabase refuses to redirect anywhere unlisted)
///
/// supabase_flutter picks the link up on its own — it listens for incoming
/// links and exchanges the tokens on them for a session — so nothing has to
/// parse this by hand. It only needs passing to the calls that send an email.
const String kEmailRedirectUrl = 'physiqoai://verified';

/// Scheme and host of [kEmailRedirectUrl], for matching incoming links.
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
