// lib/services/pdf_import_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/workout_template.dart';

// OSLONIMO SE NA export_service helper:
// - importPayloadFromPdfBytes(bytes) vraća (workout, sets) ili null
import 'export_service.dart' show importPayloadFromPdfBytes;

class PdfImportService {
  /// 1) Pokaže file picker (PDF), pročita bajtove i vrati parsirani payload
  ///    kao (workout, sets) ili null (ako nema našeg embeda).
  static Future<({Workout workout, List<SetEntry> sets})?> pickAndParse() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false, // path je dovoljan
    );
    if (res == null || res.files.isEmpty) return null;

    final path = res.files.single.path;
    if (path == null) return null;

    final bytes = await File(path).readAsBytes();
    return await importPayloadFromPdfBytes(Uint8List.fromList(bytes));
  }

  /// 2) Spremi u Hive kao Workout + SetEntry zapise.
  ///    Vraća ključ novog Workout-a.
  static Future<int> saveAsWorkout(Workout workout, List<SetEntry> sets) async {
    final wbox = Hive.box<Workout>('workouts');
    final sbox = Hive.box<SetEntry>('sets');

    // Kreiraj temeljni workout
    final wkKey = await wbox.add(Workout(
      date: workout.date,
      title: workout.title,
      notes: workout.notes,
      kind: workout.kind,
    ));

    // Upisi setove (uz novi workoutKey)
    int totalSets = 0;
    int totalReps = 0;
    double totalVolume = 0;

    final ordered = [...sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    for (final s in ordered) {
      final entry = SetEntry(
        workoutKey: wkKey,
        exercise: s.exercise,
        setNumber: s.setNumber,
        reps: s.reps,
        weightKg: s.weightKg,
        rpe: s.rpe,
        notes: s.notes,
        isTimeBased: s.isTimeBased,
        seconds: s.seconds,
        isCompleted: s.isCompleted,
      );
      await sbox.add(entry);

      totalSets += 1;
      if (!entry.isTimeBased) {
        totalReps += entry.reps;
        totalVolume += (entry.weightKg * entry.reps);
      }
    }

    // Update sumarni dio (ne moramo dirati ključ)
    final updated = Workout(
      date: workout.date,
      title: workout.title,
      notes: workout.notes,
      kind: workout.kind,
    )
      ..totalSets = totalSets
      ..totalReps = totalReps
      ..totalVolume = totalVolume;

    await wbox.put(wkKey, updated);
    return wkKey;
  }

  /// 3) Spremi u Hive kao WorkoutTemplate.
  ///    Vraća ključ novog template-a.
  static Future<int> saveAsTemplate(Workout workout, List<SetEntry> sets) async {
    final tbox = Hive.box<WorkoutTemplate>('templates');

    final templateSets = <TemplateSet>[];
    final ordered = [...sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    for (final s in ordered) {
      templateSets.add(
        TemplateSet(
          exercise: s.exercise,
          setNumber: s.setNumber,
          reps: s.reps,
          weightKg: s.weightKg,
          rpe: s.rpe,
          notes: s.notes,
          isTimeBased: s.isTimeBased,
          seconds: s.seconds,
          isSuperset: s.isSuperset,
        ),
      );
    }

    final name = _suggestTemplateName(workout.title, workout.date);
    final tmpl = WorkoutTemplate(
      name: name,
      notes: workout.notes,
      sets: templateSets,
    );

    final int key = await tbox.add(tmpl);
    return key;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _suggestTemplateName(String title, DateTime date) {
    final dateStr = '${_two(date.day)}.${_two(date.month)}.${date.year}.';
    return title.trim().isEmpty ? 'Workout $dateStr' : title.trim();
  }
}
