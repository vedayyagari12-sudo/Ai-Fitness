import 'package:flutter_test/flutter_test.dart';

/// Signup/verification branching, pinned as pure predicates.
///
/// The login screen talks to Supabase directly, so the flow itself can't be
/// driven in a unit test without a live project. What can be pinned is the
/// decision logic — and that is exactly where the bug was: Supabase does not
/// raise when you sign up with an address that already exists.

/// True when a signUp response describes an address that is already
/// registered. Supabase returns an ordinary success for that case (so it
/// can't be used to enumerate accounts); the tell is an empty identity list.
bool isAlreadyRegistered({required List<dynamic>? identities}) =>
    identities?.isEmpty ?? false;

/// Which message a failed sign-in should produce.
String signInMessage({required String code, required String rawMessage}) {
  final msg = rawMessage.toLowerCase();
  if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
    return 'Please verify your email first — check your inbox.';
  }
  if (code == 'invalid_credentials' || msg.contains('invalid login')) {
    return 'Wrong email or password.';
  }
  return rawMessage;
}

void main() {
  group('already-registered detection', () {
    test('empty identities means the address is taken', () {
      // The failure that mattered: without this, signup reports "check your
      // email" for a message Supabase never sends.
      expect(isAlreadyRegistered(identities: []), isTrue);
    });

    test('a real new signup has an identity', () {
      expect(
        isAlreadyRegistered(
          identities: [
            {'provider': 'email'},
          ],
        ),
        isFalse,
      );
    });

    test('a null identity list is not treated as taken', () {
      // Older responses omit the field; guessing "taken" there would block
      // legitimate signups outright.
      expect(isAlreadyRegistered(identities: null), isFalse);
    });
  });

  group('sign-in messages', () {
    test(
      'unverified email gets the verification prompt, not a generic error',
      () {
        expect(
          signInMessage(
            code: 'email_not_confirmed',
            rawMessage: 'Email not confirmed',
          ),
          contains('verify your email first'),
        );
      },
    );

    test('matches on the message when no code is supplied', () {
      // Older GoTrue builds send no code, so the text is the only signal.
      expect(
        signInMessage(code: '', rawMessage: 'Email not confirmed'),
        contains('verify your email first'),
      );
    });

    test('bad credentials stay distinct from unverified', () {
      final m = signInMessage(
        code: 'invalid_credentials',
        rawMessage: 'Invalid login credentials',
      );
      expect(m, 'Wrong email or password.');
      expect(m, isNot(contains('verify')));
    });

    test('an unrecognised failure is passed through rather than swallowed', () {
      expect(
        signInMessage(
          code: 'over_request_rate_limit',
          rawMessage: 'Too many requests',
        ),
        'Too many requests',
      );
    });
  });
}
