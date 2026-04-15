import 'package:flutter_test/flutter_test.dart';
import 'package:gymnotes/models/workout.dart';
import 'package:gymnotes/models/set_entry.dart';
import 'package:gymnotes/services/export_service.dart';

void main() {
  test('PDF embed/extract/import round-trip', () async {
    final workout = Workout(date: DateTime.utc(2025, 10, 28), title: 'Test', notes: 'notes');
    final sets = [
      SetEntry(workoutKey: -1, exercise: 'Bench Press', setNumber: 1, reps: 5, weightKg: 100.0),
      SetEntry(workoutKey: -1, exercise: 'Squat', setNumber: 2, reps: 5, weightKg: 150.0),
    ];

    final bytes = await buildWorkoutPdfBytesForTest(workout, sets);
    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));

    final extracted = await extractEmbeddedFromPdf(bytes);
    expect(extracted, isNotNull);
    expect(extracted!['workout'], isA<Map>());
    expect(extracted['sets'], isA<List>());

    final imported = await importPayloadFromPdfBytes(bytes);
    expect(imported, isNotNull);
    expect(imported!.workout.title, equals(workout.title));
    expect(imported.sets.length, equals(2));
    expect(imported.sets[0].exercise, equals('Bench Press'));
  });
}
