import 'package:hive/hive.dart';

class ScheduledWorkout extends HiveObject {
  String kind; // 'strength' or 'cardio'
  int templateKey;
  DateTime scheduledAt;
  bool reminderEnabled;
  bool isCompleted;
  int? linkedWorkoutKey;

  ScheduledWorkout({
    required this.kind,
    required this.templateKey,
    required this.scheduledAt,
    this.reminderEnabled = true,
    this.isCompleted = false,
    this.linkedWorkoutKey,
  });
}

class ScheduledWorkoutAdapter extends TypeAdapter<ScheduledWorkout> {
  @override
  final int typeId = 15;

  @override
  ScheduledWorkout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ScheduledWorkout(
      kind: (fields[0] as String?) ?? 'strength',
      templateKey: (fields[1] as int?) ?? -1,
      scheduledAt: (fields[2] as DateTime?) ?? DateTime.now(),
      reminderEnabled: (fields[3] as bool?) ?? true,
      isCompleted: (fields[4] as bool?) ?? false,
      linkedWorkoutKey: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledWorkout obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.kind)
      ..writeByte(1)
      ..write(obj.templateKey)
      ..writeByte(2)
      ..write(obj.scheduledAt)
      ..writeByte(3)
      ..write(obj.reminderEnabled)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.linkedWorkoutKey);
  }
}
