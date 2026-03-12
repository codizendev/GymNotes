import 'package:hive/hive.dart';

class CardioEntry extends HiveObject {
  int workoutKey;
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

  CardioEntry({
    required this.workoutKey,
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

  CardioEntry copyWith({int? workoutKey}) {
    return CardioEntry(
      workoutKey: workoutKey ?? this.workoutKey,
      activity: activity,
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      elevationGainM: elevationGainM,
      inclinePercent: inclinePercent,
      avgHeartRate: avgHeartRate,
      maxHeartRate: maxHeartRate,
      rpe: rpe,
      calories: calories,
      zoneSeconds: List<int>.from(zoneSeconds),
      segments: segments.map((s) => s.copy()).toList(),
      environment: environment,
      terrain: terrain,
      weather: weather,
      equipment: equipment,
      mood: mood,
      energy: energy,
      notes: notes,
    );
  }
}

class CardioSegment {
  String label;
  String type;
  int durationSeconds;
  double? distanceKm;
  double? targetSpeedKph;
  double? inclinePercent;
  double? rpe;
  String notes;

  CardioSegment({
    this.label = '',
    this.type = 'work',
    this.durationSeconds = 0,
    this.distanceKm,
    this.targetSpeedKph,
    this.inclinePercent,
    this.rpe,
    this.notes = '',
  });

  CardioSegment copy() {
    return CardioSegment(
      label: label,
      type: type,
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      targetSpeedKph: targetSpeedKph,
      inclinePercent: inclinePercent,
      rpe: rpe,
      notes: notes,
    );
  }
}

class CardioEntryAdapter extends TypeAdapter<CardioEntry> {
  @override
  final int typeId = 12;

  @override
  CardioEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CardioEntry(
      workoutKey: (fields[0] as int?) ?? -1,
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
  void write(BinaryWriter writer, CardioEntry obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.workoutKey)
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

class CardioSegmentAdapter extends TypeAdapter<CardioSegment> {
  @override
  final int typeId = 13;

  @override
  CardioSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CardioSegment(
      label: (fields[0] as String?) ?? '',
      type: (fields[1] as String?) ?? 'work',
      durationSeconds: (fields[2] as int?) ?? 0,
      distanceKm: (fields[3] as num?)?.toDouble(),
      targetSpeedKph: (fields[4] as num?)?.toDouble(),
      rpe: (fields[5] as num?)?.toDouble(),
      notes: (fields[6] as String?) ?? '',
      inclinePercent: (fields[7] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, CardioSegment obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.durationSeconds)
      ..writeByte(3)
      ..write(obj.distanceKm)
      ..writeByte(4)
      ..write(obj.targetSpeedKph)
      ..writeByte(5)
      ..write(obj.rpe)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.inclinePercent);
  }
}
