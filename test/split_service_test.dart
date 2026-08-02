import 'package:fitness_app/services/split_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The split drives what the AI programs each day, so its structure is a
/// training decision, not just data. These pin the properties that make a
/// rotation sound: every muscle trained at least twice a week, and never on
/// consecutive days.
void main() {
  /// Which muscle groups a day's focus actually trains.
  const trains = {
    'Push': {'chest', 'shoulders', 'triceps'},
    'Pull': {'back', 'biceps'},
    'Legs': {'legs'},
    'Upper Body': {'chest', 'shoulders', 'triceps', 'back', 'biceps'},
    'Lower Body': {'legs'},
    'Full Body': {'chest', 'shoulders', 'triceps', 'back', 'biceps', 'legs'},
  };

  Map<String, List<int>> daysTrainedPerMuscle(TrainingSplit split) {
    final rotation = SplitService.rotation(split);
    final result = <String, List<int>>{};
    for (var day = 0; day < rotation.length; day++) {
      for (final muscle in trains[rotation[day]] ?? const <String>{}) {
        result.putIfAbsent(muscle, () => []).add(day);
      }
    }
    return result;
  }

  for (final split in TrainingSplit.values) {
    test('${split.name} rotation is a full week with rest built in', () {
      final rotation = SplitService.rotation(split);
      expect(rotation.length, 7);
      expect(
        rotation.where((d) => d == SplitService.rest).length,
        greaterThanOrEqualTo(1),
        reason: 'a split with no rest day is not a plan anyone should follow',
      );
      // Every training day must be a focus the generator understands.
      for (final day in rotation) {
        if (day == SplitService.rest) continue;
        expect(
          trains.containsKey(day),
          isTrue,
          reason: '"$day" is not a known training focus',
        );
      }
    });
  }

  test('auto trains every major muscle twice a week', () {
    final schedule = daysTrainedPerMuscle(TrainingSplit.auto);

    for (final muscle in ['chest', 'back', 'shoulders', 'legs', 'biceps']) {
      expect(
        schedule[muscle]?.length ?? 0,
        greaterThanOrEqualTo(2),
        reason:
            '$muscle is trained ${schedule[muscle]?.length ?? 0}x — two '
            'sessions a week is the floor for building muscle',
      );
    }
  });

  test('auto never trains the same muscle on consecutive days', () {
    final schedule = daysTrainedPerMuscle(TrainingSplit.auto);

    schedule.forEach((muscle, days) {
      for (var i = 1; i < days.length; i++) {
        expect(
          days[i] - days[i - 1],
          greaterThanOrEqualTo(2),
          reason:
              '$muscle is trained on back-to-back days (${days.join(", ")})',
        );
      }
    });
  });

  test('focusForToday stays inside the rotation', () {
    for (final split in TrainingSplit.values) {
      final focus = SplitService.focusForToday(split);
      expect(SplitService.rotation(split), contains(focus));
    }
  });

  test('every split has a label', () {
    for (final split in TrainingSplit.values) {
      expect(SplitService.label(split), isNotEmpty);
    }
  });
}
