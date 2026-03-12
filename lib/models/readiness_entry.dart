import 'package:hive/hive.dart';

part 'readiness_entry.g.dart';

/// Snapshot of the daily readiness calculation.
@HiveType(typeId: 11)
class ReadinessEntry extends HiveObject {
  @HiveField(0)
  DateTime date;

  /// 0–1 scale representing how prepared the user is to push.
  @HiveField(1)
  double score;

  /// 'green' | 'amber' | 'red' banding for quick UI display.
  @HiveField(2)
  String band;

  /// Suggested load multiplier (e.g. 1.05 means +5% weight).
  @HiveField(3)
  double loadModifier;

  /// Suggested volume multiplier (e.g. 0.92 means -8% sets/reps).
  @HiveField(4)
  double volumeModifier;

  /// Average volume of the latest block (kg) used to score readiness.
  @HiveField(5)
  double recentVolumeAvg;

  /// Baseline volume (kg) from the comparison window.
  @HiveField(6)
  double baselineVolumeAvg;

  /// Average RPE for the comparison window (0 if no data).
  @HiveField(7)
  double avgRpe;

  /// How many workouts were considered when computing readiness.
  @HiveField(8)
  int workoutsConsidered;

  /// Optional free-form notes that explain the current state.
  @HiveField(9)
  String note;

  ReadinessEntry({
    required this.date,
    required this.score,
    required this.band,
    required this.loadModifier,
    required this.volumeModifier,
    required this.recentVolumeAvg,
    required this.baselineVolumeAvg,
    required this.avgRpe,
    required this.workoutsConsidered,
    this.note = '',
  });
}
