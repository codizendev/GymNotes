import 'package:hive/hive.dart';

import 'cardio_entry.dart';

class CardioTemplate extends HiveObject {
  String name;
  String activity;
  int durationSeconds;
  double? distanceKm;
  double? elevationGainM;
  double? inclinePercent;
  int? avgHeartRate;
  int? maxHeartRate;
  double? rpe;
  double? calories;
  List<int> zoneSeconds;
  List<CardioSegment> segments;
  String environment;
  String terrain;
  String weather;
  String equipment;
  String mood;
  int? energy;
  String notes;

  CardioTemplate({
    required this.name,
    this.activity = '',
    this.durationSeconds = 0,
    this.distanceKm,
    this.elevationGainM,
    this.inclinePercent,
    this.avgHeartRate,
    this.maxHeartRate,
    this.rpe,
    this.calories,
    List<int>? zoneSeconds,
    List<CardioSegment>? segments,
    this.environment = '',
    this.terrain = '',
    this.weather = '',
    this.equipment = '',
    this.mood = '',
    this.energy,
    this.notes = '',
  })  : zoneSeconds = _normalizeZones(zoneSeconds),
        segments = List<CardioSegment>.from(segments ?? const []);

  static List<int> _normalizeZones(List<int>? input) {
    final raw = List<int>.from(input ?? const []);
    while (raw.length < 5) {
      raw.add(0);
    }
    return raw.take(5).toList();
  }
}

class CardioTemplateAdapter extends TypeAdapter<CardioTemplate> {
  @override
  final int typeId = 14;

  @override
  CardioTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CardioTemplate(
      name: (fields[0] as String?) ?? '',
      activity: (fields[1] as String?) ?? '',
      durationSeconds: (fields[2] as int?) ?? 0,
      distanceKm: (fields[3] as num?)?.toDouble(),
      elevationGainM: (fields[4] as num?)?.toDouble(),
      inclinePercent: (fields[5] as num?)?.toDouble(),
      avgHeartRate: fields[6] as int?,
      maxHeartRate: fields[7] as int?,
      rpe: (fields[8] as num?)?.toDouble(),
      calories: (fields[9] as num?)?.toDouble(),
      zoneSeconds: (fields[10] as List?)?.cast<int>(),
      segments: (fields[11] as List?)?.cast<CardioSegment>(),
      environment: (fields[12] as String?) ?? '',
      terrain: (fields[13] as String?) ?? '',
      weather: (fields[14] as String?) ?? '',
      equipment: (fields[15] as String?) ?? '',
      mood: (fields[16] as String?) ?? '',
      energy: fields[17] as int?,
      notes: (fields[18] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, CardioTemplate obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.activity)
      ..writeByte(2)
      ..write(obj.durationSeconds)
      ..writeByte(3)
      ..write(obj.distanceKm)
      ..writeByte(4)
      ..write(obj.elevationGainM)
      ..writeByte(5)
      ..write(obj.inclinePercent)
      ..writeByte(6)
      ..write(obj.avgHeartRate)
      ..writeByte(7)
      ..write(obj.maxHeartRate)
      ..writeByte(8)
      ..write(obj.rpe)
      ..writeByte(9)
      ..write(obj.calories)
      ..writeByte(10)
      ..write(obj.zoneSeconds)
      ..writeByte(11)
      ..write(obj.segments)
      ..writeByte(12)
      ..write(obj.environment)
      ..writeByte(13)
      ..write(obj.terrain)
      ..writeByte(14)
      ..write(obj.weather)
      ..writeByte(15)
      ..write(obj.equipment)
      ..writeByte(16)
      ..write(obj.mood)
      ..writeByte(17)
      ..write(obj.energy)
      ..writeByte(18)
      ..write(obj.notes);
  }
}
