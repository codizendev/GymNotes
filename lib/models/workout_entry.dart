import 'package:hive/hive.dart';

part 'workout_entry.g.dart';

@HiveType(typeId: 1)
class WorkoutEntry extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String exercise;

  @HiveField(2)
  int sets;

  @HiveField(3)
  int reps;

  @HiveField(4)
  double weightKg;

  @HiveField(5)
  String notes;

  WorkoutEntry({
    required this.date,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.notes = '',
  });

  double get volume => sets * reps * weightKg;
}
