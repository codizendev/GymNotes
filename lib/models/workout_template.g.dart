// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutTemplateAdapter extends TypeAdapter<WorkoutTemplate> {
  @override
  final int typeId = 4;

  @override
  WorkoutTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutTemplate(
      name: fields[0] as String,
      sets: (fields[1] as List).cast<TemplateSet>(),
      notes: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutTemplate obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.sets)
      ..writeByte(2)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TemplateSetAdapter extends TypeAdapter<TemplateSet> {
  @override
  final int typeId = 5;

  @override
  TemplateSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateSet(
      exercise: fields[0] as String,
      setNumber: fields[1] as int,
      reps: fields[2] as int,
      weightKg: fields[3] as double,
      rpe: fields[4] as double?,
      notes: fields[5] as String,
      isTimeBased: fields[6] == null ? false : fields[6] as bool,
      seconds: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TemplateSet obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.exercise)
      ..writeByte(1)
      ..write(obj.setNumber)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.weightKg)
      ..writeByte(4)
      ..write(obj.rpe)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.isTimeBased)
      ..writeByte(7)
      ..write(obj.seconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
