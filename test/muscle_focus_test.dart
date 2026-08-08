import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/muscle_focus.dart';

/// FOCUS tells someone a muscle of theirs is underdeveloped. That is only
/// knowable from a physique scan, so these pin that it is never claimed
/// without one.
void main() {
  group('without a scan nothing is claimed', () {
    test('training-volume shares never produce a FOCUS area', () {
      // These are shares of the most-trained muscle x10, not quality scores.
      // Treating them as quality is what told people who had never scanned
      // that their arms and core were lagging.
      final flags = focusFlags(
        scoresHighToLow: [10, 8, 6, 4, 2, 1],
        fromScan: false,
      );
      expect(flags.lagging, isEmpty);
      expect(flags.maintain, isEmpty);
    });

    test('a user with no workouts at all is flagged nothing', () {
      // Every share is 0 here, which says nothing about any muscle — the old
      // rule flagged two of them essentially at random.
      final flags = focusFlags(
        scoresHighToLow: [0, 0, 0, 0, 0, 0],
        fromScan: false,
      );
      expect(flags.lagging, isEmpty);
    });

    test('an empty list is handled', () {
      expect(
        focusFlags(scoresHighToLow: const [], fromScan: false).lagging,
        isEmpty,
      );
      expect(
        focusFlags(scoresHighToLow: const [], fromScan: true).lagging,
        isEmpty,
      );
    });
  });

  group('with a scan', () {
    test('flags the weakest muscles', () {
      final flags = focusFlags(
        scoresHighToLow: [9, 8, 7, 5, 4],
        fromScan: true,
      );
      // Indices 4 (score 4) and 3 (score 5) are the two below 7.
      expect(flags.lagging, {3, 4});
    });

    test('caps the number flagged so a plan stays focused', () {
      final flags = focusFlags(
        scoresHighToLow: [6, 5, 4, 3, 2],
        fromScan: true,
      );
      expect(flags.lagging.length, 2);
      // The two weakest, not an arbitrary pair.
      expect(flags.lagging, {3, 4});
    });

    test('a strong physique gets no FOCUS areas', () {
      // Everything at or above the bar: ranking lowest is not a weakness.
      final flags = focusFlags(
        scoresHighToLow: [10, 9, 9, 8, 8],
        fromScan: true,
      );
      expect(flags.lagging, isEmpty);
      expect(
        flags.maintain,
        isNotEmpty,
        reason: 'the lowest-ranked strong muscles are maintenance',
      );
    });

    test('the maintain label never overlaps with lagging', () {
      final flags = focusFlags(
        scoresHighToLow: [9, 8, 7, 6, 3],
        fromScan: true,
      );
      expect(flags.lagging.intersection(flags.maintain), isEmpty);
    });

    test('a single scanned muscle below the bar still flags', () {
      expect(focusFlags(scoresHighToLow: [4], fromScan: true).lagging, {0});
    });

    test('exactly at the threshold is not weak', () {
      // 7.0 is the bar; being on it is fine.
      expect(
        focusFlags(scoresHighToLow: [9, 7], fromScan: true).lagging,
        isEmpty,
      );
    });
  });
}
