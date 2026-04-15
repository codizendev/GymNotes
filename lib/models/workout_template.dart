import 'package:hive/hive.dart';

part 'workout_template.g.dart';

@HiveType(typeId: 4) // promijeni ako se sudara s nečim postojećim
class WorkoutTemplate extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<TemplateSet> sets;

  @HiveField(2)
  String notes;

  WorkoutTemplate({
    required this.name,
    required this.sets,
    this.notes = '',
  });
}

@HiveType(typeId: 5)
class TemplateSet {
  @HiveField(0)
  String exercise;

  @HiveField(1)
  int setNumber;

  @HiveField(2)
  int reps;

  @HiveField(3)
  double weightKg;

  @HiveField(4)
  double? rpe;

  @HiveField(5)
  String notes;

  @HiveField(6, defaultValue: false)
  bool isTimeBased;

  /// Duration in seconds for time-based sets (e.g. plank 45 s).
  @HiveField(7)
  int? seconds;

  @HiveField(8, defaultValue: false)
  bool isSuperset;

  TemplateSet({
    required this.exercise,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    this.rpe,
    this.notes = '',
    this.isTimeBased = false,
    this.seconds,
    this.isSuperset = false,
  });
}
