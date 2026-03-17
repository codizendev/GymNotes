import 'package:hive/hive.dart';

class ProgramBlock extends HiveObject {
  String name;
  DateTime startDate;
  int durationWeeks;
  bool isActive;
  List<ProgramSessionPlan> sessions;
  ProgramProgressionConfig progression;
  int generatedUntilWeek;
  DateTime createdAt;

  ProgramBlock({
    required this.name,
    required this.startDate,
    required this.durationWeeks,
    required this.sessions,
    ProgramProgressionConfig? progression,
    this.isActive = true,
    this.generatedUntilWeek = 0,
    DateTime? createdAt,
  }) : progression = progression ?? ProgramProgressionConfig(),
       createdAt = createdAt ?? DateTime.now();
}

class ProgramSessionPlan {
  String id;
  int weekDay; // 1 = Monday ... 7 = Sunday
  String kind; // 'strength' | 'cardio'
  int templateKey;
  int hour;
  int minute;
  bool reminderEnabled;
  String note;

  ProgramSessionPlan({
    required this.id,
    required this.weekDay,
    required this.kind,
    required this.templateKey,
    this.hour = 9,
    this.minute = 0,
    this.reminderEnabled = true,
    this.note = '',
  });

  ProgramSessionPlan copyWith({
    String? id,
    int? weekDay,
    String? kind,
    int? templateKey,
    int? hour,
    int? minute,
    bool? reminderEnabled,
    String? note,
  }) {
    return ProgramSessionPlan(
      id: id ?? this.id,
      weekDay: weekDay ?? this.weekDay,
      kind: kind ?? this.kind,
      templateKey: templateKey ?? this.templateKey,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      note: note ?? this.note,
    );
  }
}

class ProgramProgressionConfig {
  // strength
  String strengthMode; // 'none' | 'fixed_kg' | 'percent'
  double strengthStepValueKg;
  double strengthStepPercent;
  int strengthStepEveryWeeks;
  double strengthRoundingKg;

  // cardio
  String cardioMode; // 'none' | 'duration_percent' | 'duration_seconds' | 'work_interval_seconds'
  int cardioStepValueSeconds;
  double cardioStepPercent;
  int cardioWorkIntervalStepSeconds;
  int cardioStepEveryWeeks;

  // deload + readiness
  bool deloadEnabled;
  int deloadEveryWeeks;
  double deloadLoadPercent;
  double deloadVolumePercent;
  bool applyReadinessModifiers;

  ProgramProgressionConfig({
    this.strengthMode = 'fixed_kg',
    this.strengthStepValueKg = 2.5,
    this.strengthStepPercent = 2.5,
    this.strengthStepEveryWeeks = 1,
    this.strengthRoundingKg = 0.5,
    this.cardioMode = 'duration_percent',
    this.cardioStepValueSeconds = 60,
    this.cardioStepPercent = 5,
    this.cardioWorkIntervalStepSeconds = 10,
    this.cardioStepEveryWeeks = 1,
    this.deloadEnabled = false,
    this.deloadEveryWeeks = 4,
    this.deloadLoadPercent = -10,
    this.deloadVolumePercent = -15,
    this.applyReadinessModifiers = false,
  });
}

class ProgramBlockAdapter extends TypeAdapter<ProgramBlock> {
  @override
  final int typeId = 16;

  @override
  ProgramBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ProgramBlock(
      name: (fields[0] as String?) ?? '',
      startDate: (fields[1] as DateTime?) ?? DateTime.now(),
      durationWeeks: (fields[2] as int?) ?? 8,
      isActive: (fields[3] as bool?) ?? true,
      sessions: (fields[4] as List?)?.cast<ProgramSessionPlan>() ?? <ProgramSessionPlan>[],
      progression: (fields[5] as ProgramProgressionConfig?) ?? ProgramProgressionConfig(),
      generatedUntilWeek: (fields[6] as int?) ?? 0,
      createdAt: (fields[7] as DateTime?) ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, ProgramBlock obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.durationWeeks)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.sessions)
      ..writeByte(5)
      ..write(obj.progression)
      ..writeByte(6)
      ..write(obj.generatedUntilWeek)
      ..writeByte(7)
      ..write(obj.createdAt);
  }
}

class ProgramSessionPlanAdapter extends TypeAdapter<ProgramSessionPlan> {
  @override
  final int typeId = 17;

  @override
  ProgramSessionPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ProgramSessionPlan(
      id: (fields[0] as String?) ?? '',
      weekDay: (fields[1] as int?) ?? 1,
      kind: (fields[2] as String?) ?? 'strength',
      templateKey: (fields[3] as int?) ?? -1,
      hour: (fields[4] as int?) ?? 9,
      minute: (fields[5] as int?) ?? 0,
      reminderEnabled: (fields[6] as bool?) ?? true,
      note: (fields[7] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ProgramSessionPlan obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weekDay)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.templateKey)
      ..writeByte(4)
      ..write(obj.hour)
      ..writeByte(5)
      ..write(obj.minute)
      ..writeByte(6)
      ..write(obj.reminderEnabled)
      ..writeByte(7)
      ..write(obj.note);
  }
}

class ProgramProgressionConfigAdapter extends TypeAdapter<ProgramProgressionConfig> {
  @override
  final int typeId = 18;

  @override
  ProgramProgressionConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ProgramProgressionConfig(
      strengthMode: (fields[0] as String?) ?? 'fixed_kg',
      strengthStepValueKg: (fields[1] as num?)?.toDouble() ?? 2.5,
      strengthStepPercent: (fields[2] as num?)?.toDouble() ?? 2.5,
      strengthStepEveryWeeks: (fields[3] as int?) ?? 1,
      strengthRoundingKg: (fields[4] as num?)?.toDouble() ?? 0.5,
      cardioMode: (fields[5] as String?) ?? 'duration_percent',
      cardioStepValueSeconds: (fields[6] as int?) ?? 60,
      cardioStepPercent: (fields[7] as num?)?.toDouble() ?? 5,
      cardioWorkIntervalStepSeconds: (fields[8] as int?) ?? 10,
      cardioStepEveryWeeks: (fields[9] as int?) ?? 1,
      deloadEnabled: (fields[10] as bool?) ?? false,
      deloadEveryWeeks: (fields[11] as int?) ?? 4,
      deloadLoadPercent: (fields[12] as num?)?.toDouble() ?? -10,
      deloadVolumePercent: (fields[13] as num?)?.toDouble() ?? -15,
      applyReadinessModifiers: (fields[14] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramProgressionConfig obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.strengthMode)
      ..writeByte(1)
      ..write(obj.strengthStepValueKg)
      ..writeByte(2)
      ..write(obj.strengthStepPercent)
      ..writeByte(3)
      ..write(obj.strengthStepEveryWeeks)
      ..writeByte(4)
      ..write(obj.strengthRoundingKg)
      ..writeByte(5)
      ..write(obj.cardioMode)
      ..writeByte(6)
      ..write(obj.cardioStepValueSeconds)
      ..writeByte(7)
      ..write(obj.cardioStepPercent)
      ..writeByte(8)
      ..write(obj.cardioWorkIntervalStepSeconds)
      ..writeByte(9)
      ..write(obj.cardioStepEveryWeeks)
      ..writeByte(10)
      ..write(obj.deloadEnabled)
      ..writeByte(11)
      ..write(obj.deloadEveryWeeks)
      ..writeByte(12)
      ..write(obj.deloadLoadPercent)
      ..writeByte(13)
      ..write(obj.deloadVolumePercent)
      ..writeByte(14)
      ..write(obj.applyReadinessModifiers);
  }
}
