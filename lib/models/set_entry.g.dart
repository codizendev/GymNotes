// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SetEntryAdapter extends TypeAdapter<SetEntry> {
  @override
  final int typeId = 8;

  @override
  SetEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetEntry(
      workoutKey: fields[0] as int,
      exercise: fields[1] as String,
      setNumber: fields[2] as int,
      reps: fields[3] as int,
      weightKg: fields[4] as double,
      rpe: fields[5] as double?,
      notes: fields[6] as String,
      isTimeBased: fields[7] == null ? false : fields[7] as bool,
      seconds: fields[8] as int?,
      isCompleted: fields[9] == null ? false : fields[9] as bool,
      isSuperset: fields[10] == null ? false : fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SetEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.workoutKey)
      ..writeByte(1)
      ..write(obj.exercise)
      ..writeByte(2)
      ..write(obj.setNumber)
      ..writeByte(3)
      ..write(obj.reps)
      ..writeByte(4)
      ..write(obj.weightKg)
      ..writeByte(5)
      ..write(obj.rpe)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.isTimeBased)
      ..writeByte(8)
      ..write(obj.seconds)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.isSuperset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
