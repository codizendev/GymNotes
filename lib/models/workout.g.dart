// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 2;

  @override
  Workout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Workout(
      date: fields[0] as DateTime,
      title: fields[1] as String,
      notes: fields[2] as String,
      totalSets: fields[3] as int,
      totalReps: fields[4] as int,
      totalVolume: fields[5] as double,
      restAdherence: (fields[6] as double?) ?? 1.0,
      feelingScore: (fields[7] as int?) ?? 7,
      isCompleted: (fields[8] as bool?) ?? false,
      kind: (fields[9] as String?) ?? 'strength',
    );
  }

  @override
  void write(BinaryWriter writer, Workout obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.totalSets)
      ..writeByte(4)
      ..write(obj.totalReps)
      ..writeByte(5)
      ..write(obj.totalVolume)
      ..writeByte(6)
      ..write(obj.restAdherence)
      ..writeByte(7)
      ..write(obj.feelingScore)
      ..writeByte(8)
      ..write(obj.isCompleted)
      ..writeByte(9)
      ..write(obj.kind);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
