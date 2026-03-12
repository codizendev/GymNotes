import 'package:hive/hive.dart';

part 'workout.g.dart';

@HiveType(typeId: 2)
class Workout extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String title; // npr. Push / Legs / Full body (opcionalno, može biti prazan)

  @HiveField(2)
  String notes;

  // denormalizirani sažeci radi brzine listanja
  @HiveField(3)
  int totalSets;

  @HiveField(4)
  int totalReps;

  @HiveField(5)
  double totalVolume;

  /// User-reported rest adherence for the session (0–1 range).
  @HiveField(6, defaultValue: 1.0)
  double restAdherence;

  /// User-reported feeling / energy for the session (1–10).
  @HiveField(7, defaultValue: 7)
  int feelingScore;

  /// Whether the workout was marked complete by the user.
  @HiveField(8, defaultValue: false)
  bool isCompleted;

  /// Workout type: 'strength' (default) or 'cardio'.
  @HiveField(9, defaultValue: 'strength')
  String kind;

  Workout({
    required this.date,
    this.title = '',
    this.notes = '',
    this.totalSets = 0,
    this.totalReps = 0,
    this.totalVolume = 0.0,
    this.restAdherence = 1.0,
    this.feelingScore = 7,
    this.isCompleted = false,
    this.kind = 'strength',
  });
}
