import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/readiness_takeaway.dart';

/// The corner stats on the readiness card already show each ring's raw
/// number; this line exists to answer the question they don't — "so how am
/// I doing overall?" — so every branch has to say something a reader
/// couldn't already get by reading the three numbers separately.
void main() {
  String take({double cal = 0, double pro = 0, double ses = 0}) =>
      readinessTakeaway(calories: cal, protein: pro, sessions: ses);

  group('all three done', () {
    test('exact 1.0 on every ring', () {
      expect(take(cal: 1, pro: 1, ses: 1), contains('checked'));
    });

    test('a touch under 1.0 from float division still reads as done', () {
      // The values are clamped upstream, but 0.999999 landing here should
      // not read as "almost" — the clamp already means the target was hit.
      expect(take(cal: 0.999, pro: 0.998, ses: 1), contains('checked'));
    });

    test('over target on a ring still counts as done', () {
      expect(take(cal: 1.4, pro: 1, ses: 1), contains('checked'));
    });
  });

  group('nothing done', () {
    test(
      'literal zero across the board reads as a fresh start, not a fail',
      () {
        final msg = take(cal: 0, pro: 0, ses: 0);
        expect(msg, contains('Fresh start'));
        expect(msg, isNot(contains('fail')));
      },
    );

    test('short of every target but not literally zero', () {
      final msg = take(cal: 0.2, pro: 0.1, ses: 0);
      expect(msg, isNot(contains('Fresh start')));
      expect(msg, contains('open'));
    });
  });

  group('exactly one thing left — names it', () {
    test('only the session is missing', () {
      final msg = take(cal: 1, pro: 1, ses: 0);
      expect(msg.toLowerCase(), contains('session'));
    });

    test('only calories are missing', () {
      final msg = take(cal: 0.5, pro: 1, ses: 1);
      expect(msg.toLowerCase(), contains('calories'));
    });

    test('only protein is missing', () {
      final msg = take(cal: 1, pro: 0.4, ses: 1);
      expect(msg.toLowerCase(), contains('protein'));
    });
  });

  group('exactly one thing done — says what is left', () {
    test('only trained', () {
      final msg = take(cal: 0, pro: 0, ses: 1);
      expect(msg.toLowerCase(), contains('trained'));
    });

    test('only calories', () {
      final msg = take(cal: 1, pro: 0, ses: 0);
      expect(msg.toLowerCase(), contains('calories'));
    });

    test('only protein', () {
      final msg = take(cal: 0, pro: 1, ses: 0);
      expect(msg.toLowerCase(), contains('protein'));
    });
  });

  test('every reachable branch returns non-empty, sentence-like text', () {
    for (final cal in [0.0, 1.0]) {
      for (final pro in [0.0, 1.0]) {
        for (final ses in [0.0, 1.0]) {
          final msg = take(cal: cal, pro: pro, ses: ses);
          expect(msg, isNotEmpty, reason: 'cal=$cal pro=$pro ses=$ses');
          expect(
            msg,
            isNot('1 of 3 today — keep going.'),
            reason:
                'cal=$cal pro=$pro ses=$ses reached the fallback the source '
                'comment claims is unreachable for a single-boolean state',
          );
        }
      }
    }
  });

  test('a negative value is treated the same as zero, not as extra credit', () {
    // Ring progress is clamped before this ever runs, but the function
    // should not misbehave if a caller forgets to.
    final msg = take(cal: -0.5, pro: 0, ses: 0);
    expect(msg, contains('Fresh start'));
  });
}
