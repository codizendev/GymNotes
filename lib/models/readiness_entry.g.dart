// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readiness_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadinessEntryAdapter extends TypeAdapter<ReadinessEntry> {
  @override
  final int typeId = 11;

  @override
  ReadinessEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadinessEntry(
      date: fields[0] as DateTime,
      score: fields[1] as double,
      band: fields[2] as String,
      loadModifier: fields[3] as double,
      volumeModifier: fields[4] as double,
      recentVolumeAvg: fields[5] as double,
      baselineVolumeAvg: fields[6] as double,
      avgRpe: fields[7] as double,
      workoutsConsidered: fields[8] as int,
      note: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ReadinessEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.band)
      ..writeByte(3)
      ..write(obj.loadModifier)
      ..writeByte(4)
      ..write(obj.volumeModifier)
      ..writeByte(5)
      ..write(obj.recentVolumeAvg)
      ..writeByte(6)
      ..write(obj.baselineVolumeAvg)
      ..writeByte(7)
      ..write(obj.avgRpe)
      ..writeByte(8)
      ..write(obj.workoutsConsidered)
      ..writeByte(9)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadinessEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
