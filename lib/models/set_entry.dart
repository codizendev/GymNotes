import 'package:hive/hive.dart';

part 'set_entry.g.dart';

@HiveType(typeId: 8) // ← ostaje isti kao prije
class SetEntry extends HiveObject {
  @HiveField(0)
  int workoutKey;

  @HiveField(1)
  String exercise;

  @HiveField(2)
  int setNumber;

  @HiveField(3)
  int reps;

  @HiveField(4)
  double weightKg;

  @HiveField(5)
  double? rpe;

  @HiveField(6)
  String notes;

  // 👇 NOVO
  @HiveField(7, defaultValue: false)
  bool isTimeBased;

  /// Trajanje u sekundama ako je `isTimeBased == true` (npr. plank 45 s)
  @HiveField(8)
  int? seconds;

  /// Oznaka da je set završen (za swipe-to-complete i tajmer odmora)
  @HiveField(9, defaultValue: false)
  bool isCompleted;

  @HiveField(10, defaultValue: false)
  bool isSuperset;

  SetEntry({
    required this.workoutKey,
    required this.exercise,
    required this.setNumber,
    this.reps = 0,
    this.weightKg = 0,
    this.rpe,
    this.notes = '',
    this.isTimeBased = false,
    this.seconds,
    this.isCompleted = false,
    this.isSuperset = false,
  });
}
