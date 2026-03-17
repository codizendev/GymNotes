import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/workout_template.dart';
import '../models/exercise.dart';
import '../models/cardio_entry.dart';
import '../models/cardio_template.dart';
import '../models/readiness_entry.dart';
import '../models/scheduled_workout.dart';
import '../models/program_block.dart';

class BackupService {
  /// Export svih podataka u JSON i share.
  /// [shareText] i [subject] dolaze iz UI-a (lokalizirano).
  static Future<void> exportAll({String? shareText, String? subject}) async {
    final wbox = Hive.box<Workout>('workouts');
    final sbox = Hive.box<SetEntry>('sets');
    final tbox = Hive.box<WorkoutTemplate>('templates');
    final ebox = Hive.box<Exercise>('exercises');
    final cbox = Hive.box<CardioEntry>('cardio_entries');
    final ctbox = Hive.box<CardioTemplate>('cardio_templates');
    final rbox = Hive.box<ReadinessEntry>('readiness');
    final swbox = Hive.box<ScheduledWorkout>('scheduled_workouts');
    final pbox = Hive.box<ProgramBlock>('program_blocks');
    final settings = Hive.box('settings');

    // 1) Workouts -> list + map (key -> index)
    final workouts = <Map<String, dynamic>>[];
    final workoutKeyToIndex = <int, int>{};
    final wValues = wbox.values.toList();
    for (var i = 0; i < wValues.length; i++) {
      final w = wValues[i];
      final key = w.key as int;
      workoutKeyToIndex[key] = i;
      workouts.add({
        'date': w.date.toIso8601String(),
        'title': w.title,
        'notes': w.notes,
        'totalSets': w.totalSets,
        'totalReps': w.totalReps,
        'totalVolume': w.totalVolume,
        'feelingScore': w.feelingScore,
        'kind': w.kind,
      });
    }

    // 2) Sets – vežemo na workoutIndex (ne ključ)
    final sets = sbox.values.map((s) {
      final wk = s.workoutKey;
      final wi = workoutKeyToIndex[wk] ?? -1;
      return {
        'workoutIndex': wi,
        'exercise': s.exercise,
        'setNumber': s.setNumber,
        'reps': s.reps,
        'weightKg': s.weightKg,
        'rpe': s.rpe,
        'notes': s.notes,
        'isTimeBased': s.isTimeBased,
        'seconds': s.seconds,
        'isCompleted': s.isCompleted,
      };
    }).toList();

    final cardioEntries = cbox.values.map((c) {
      final wk = c.workoutKey;
      final wi = workoutKeyToIndex[wk] ?? -1;
      return {
        'workoutIndex': wi,
        'activity': c.activity,
        'durationSeconds': c.durationSeconds,
        'distanceKm': c.distanceKm,
        'elevationGainM': c.elevationGainM,
        'inclinePercent': c.inclinePercent,
        'avgHeartRate': c.avgHeartRate,
        'maxHeartRate': c.maxHeartRate,
        'rpe': c.rpe,
        'calories': c.calories,
        'zoneSeconds': c.zoneSeconds,
        'segments': c.segments
            .map((seg) => {
                  'label': seg.label,
                  'type': seg.type,
                  'durationSeconds': seg.durationSeconds,
                  'distanceKm': seg.distanceKm,
                  'targetSpeedKph': seg.targetSpeedKph,
                  'inclinePercent': seg.inclinePercent,
                  'rpe': seg.rpe,
                  'notes': seg.notes,
                })
            .toList(),
        'environment': c.environment,
        'terrain': c.terrain,
        'weather': c.weather,
        'equipment': c.equipment,
        'mood': c.mood,
        'energy': c.energy,
        'notes': c.notes,
      };
    }).toList();

    // 3) Templates + index maps (for stable cross-box references)
    final templates = <Map<String, dynamic>>[];
    final strengthTemplateKeyToIndex = <int, int>{};
    final strengthTemplates = tbox.values.toList();
    for (var i = 0; i < strengthTemplates.length; i++) {
      final t = strengthTemplates[i];
      final key = t.key as int;
      strengthTemplateKeyToIndex[key] = i;
      templates.add({
        'name': t.name,
        'notes': t.notes,
        'sets': t.sets
            .map((ts) => {
                  'exercise': ts.exercise,
                  'setNumber': ts.setNumber,
                  'reps': ts.reps,
                  'weightKg': ts.weightKg,
                  'rpe': ts.rpe,
                  'notes': ts.notes,
                  'isTimeBased': ts.isTimeBased,
                  'seconds': ts.seconds,
                })
            .toList(),
      });
    }

    final cardioTemplates = <Map<String, dynamic>>[];
    final cardioTemplateKeyToIndex = <int, int>{};
    final cardioTemplateValues = ctbox.values.toList();
    for (var i = 0; i < cardioTemplateValues.length; i++) {
      final t = cardioTemplateValues[i];
      final key = t.key as int;
      cardioTemplateKeyToIndex[key] = i;
      cardioTemplates.add({
        'name': t.name,
        'activity': t.activity,
        'durationSeconds': t.durationSeconds,
        'distanceKm': t.distanceKm,
        'elevationGainM': t.elevationGainM,
        'inclinePercent': t.inclinePercent,
        'avgHeartRate': t.avgHeartRate,
        'maxHeartRate': t.maxHeartRate,
        'rpe': t.rpe,
        'calories': t.calories,
        'zoneSeconds': t.zoneSeconds,
        'segments': t.segments
            .map((seg) => {
                  'label': seg.label,
                  'type': seg.type,
                  'durationSeconds': seg.durationSeconds,
                  'distanceKm': seg.distanceKm,
                  'targetSpeedKph': seg.targetSpeedKph,
                  'inclinePercent': seg.inclinePercent,
                  'rpe': seg.rpe,
                  'notes': seg.notes,
                })
            .toList(),
        'environment': t.environment,
        'terrain': t.terrain,
        'weather': t.weather,
        'equipment': t.equipment,
        'mood': t.mood,
        'energy': t.energy,
        'notes': t.notes,
      });
    }

    // 4) Exercises
    final exercises = ebox.values
        .map((e) => {
              'name': e.name,
              'category': e.category,
              'isFavorite': e.isFavorite,
            })
        .toList();

    final readinessEntries = rbox.values
        .map((r) => {
              'date': r.date.toIso8601String(),
              'score': r.score,
              'band': r.band,
              'loadModifier': r.loadModifier,
              'volumeModifier': r.volumeModifier,
              'recentVolumeAvg': r.recentVolumeAvg,
              'baselineVolumeAvg': r.baselineVolumeAvg,
              'avgRpe': r.avgRpe,
              'workoutsConsidered': r.workoutsConsidered,
              'note': r.note,
            })
        .toList();

    final programBlocks = <Map<String, dynamic>>[];
    final programKeyToIndex = <int, int>{};
    final programs = pbox.values.toList();
    for (var i = 0; i < programs.length; i++) {
      final p = programs[i];
      final programKey = p.key as int;
      programKeyToIndex[programKey] = i;
      programBlocks.add({
        'name': p.name,
        'startDate': p.startDate.toIso8601String(),
        'durationWeeks': p.durationWeeks,
        'isActive': p.isActive,
        'generatedUntilWeek': p.generatedUntilWeek,
        'createdAt': p.createdAt.toIso8601String(),
        'progression': {
          'strengthMode': p.progression.strengthMode,
          'strengthStepValueKg': p.progression.strengthStepValueKg,
          'strengthStepPercent': p.progression.strengthStepPercent,
          'strengthStepEveryWeeks': p.progression.strengthStepEveryWeeks,
          'strengthRoundingKg': p.progression.strengthRoundingKg,
          'cardioMode': p.progression.cardioMode,
          'cardioStepValueSeconds': p.progression.cardioStepValueSeconds,
          'cardioStepPercent': p.progression.cardioStepPercent,
          'cardioWorkIntervalStepSeconds': p.progression.cardioWorkIntervalStepSeconds,
          'cardioStepEveryWeeks': p.progression.cardioStepEveryWeeks,
          'deloadEnabled': p.progression.deloadEnabled,
          'deloadEveryWeeks': p.progression.deloadEveryWeeks,
          'deloadLoadPercent': p.progression.deloadLoadPercent,
          'deloadVolumePercent': p.progression.deloadVolumePercent,
          'applyReadinessModifiers': p.progression.applyReadinessModifiers,
        },
        'sessions': p.sessions
            .map((session) {
              final templateIndex = session.kind == 'cardio'
                  ? cardioTemplateKeyToIndex[session.templateKey]
                  : strengthTemplateKeyToIndex[session.templateKey];
              return {
                'id': session.id,
                'weekDay': session.weekDay,
                'kind': session.kind,
                'templateKey': session.templateKey,
                'templateIndex': templateIndex,
                'hour': session.hour,
                'minute': session.minute,
                'reminderEnabled': session.reminderEnabled,
                'note': session.note,
              };
            })
            .toList(),
      });
    }

    final scheduledWorkouts = swbox.values
        .map((s) {
          final linkedWorkoutIndex = s.linkedWorkoutKey == null
              ? null
              : workoutKeyToIndex[s.linkedWorkoutKey!];
          final templateIndex = s.kind == 'cardio'
              ? cardioTemplateKeyToIndex[s.templateKey]
              : strengthTemplateKeyToIndex[s.templateKey];
          final programIndex = s.programKey == null
              ? null
              : programKeyToIndex[s.programKey!];
          return {
            'kind': s.kind,
            'templateKey': s.templateKey,
            'templateIndex': templateIndex,
            'scheduledAt': s.scheduledAt.toIso8601String(),
            'reminderEnabled': s.reminderEnabled,
            'isCompleted': s.isCompleted,
            'linkedWorkoutKey': s.linkedWorkoutKey,
            'linkedWorkoutIndex': linkedWorkoutIndex,
            'programKey': s.programKey,
            'programIndex': programIndex,
            'programWeek': s.programWeek,
            'programSessionId': s.programSessionId,
            'isAutoGenerated': s.isAutoGenerated,
          };
        })
        .toList();
    // 5) Settings – svi key/value parovi
    final settingsMap = <String, dynamic>{};
    for (final k in settings.keys) {
      settingsMap[k.toString()] = settings.get(k);
    }

    final payload = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'workouts': workouts,
      'sets': sets,
      'cardioEntries': cardioEntries,
      'templates': templates,
      'cardioTemplates': cardioTemplates,
      'exercises': exercises,
      'readiness': readinessEntries,
      'programBlocks': programBlocks,
      'scheduledWorkouts': scheduledWorkouts,
      'settings': settingsMap,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    // spremi temp datoteku i Share
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/workouts_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsString(jsonStr);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path)],
        text: shareText ?? 'Workout backup',
        subject: subject ?? 'Workout backup',
      ),
    );
  }

  /// Import iz JSON-a (opcionalno briše postojeće podatke).
  static Future<void> importAll({bool replace = true}) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (res == null || res.files.isEmpty) return;
    final picked = res.files.single;
    final filePath = picked.path;
    String jsonStr;
    if (filePath != null) {
      jsonStr = await File(filePath).readAsString();
    } else if (picked.bytes != null) {
      jsonStr = utf8.decode(picked.bytes!);
    } else {
      return;
    }
    final json = jsonDecode(jsonStr) as Map;

    // Otvori boxeve
    final wbox = Hive.box<Workout>('workouts');
    final sbox = Hive.box<SetEntry>('sets');
    final tbox = Hive.box<WorkoutTemplate>('templates');
    final ebox = Hive.box<Exercise>('exercises');
    final cbox = Hive.box<CardioEntry>('cardio_entries');
    final ctbox = Hive.box<CardioTemplate>('cardio_templates');
    final rbox = Hive.box<ReadinessEntry>('readiness');
    final swbox = Hive.box<ScheduledWorkout>('scheduled_workouts');
    final pbox = Hive.box<ProgramBlock>('program_blocks');
    final settings = Hive.box('settings');

    if (replace) {
      await sbox.clear();
      await wbox.clear();
      await tbox.clear();
      await ebox.clear();
      await cbox.clear();
      await ctbox.clear();
      await rbox.clear();
      await swbox.clear();
      await pbox.clear();
      await settings.clear();
    }

    // Workouts
    final List workouts = (json['workouts'] as List?) ?? [];
    final indexToNewWorkoutKey = <int, int>{};
    for (var i = 0; i < workouts.length; i++) {
      final w = workouts[i] as Map;
      final newKey = await wbox.add(Workout(
        date: DateTime.parse(w['date'] as String),
        title: (w['title'] ?? '') as String,
        notes: (w['notes'] ?? '') as String,
        kind: (w['kind'] ?? 'strength') as String,
      )
        ..totalSets = (w['totalSets'] ?? 0) as int
        ..totalReps = (w['totalReps'] ?? 0) as int
        ..totalVolume = ((w['totalVolume'] ?? 0.0) as num).toDouble()
        ..feelingScore = ((w['feelingScore'] ?? 7) as num).toInt());
      indexToNewWorkoutKey[i] = newKey;
    }

    // Sets
    final List sets = (json['sets'] as List?) ?? [];
    for (final s in sets) {
      final m = s as Map;
      final wi = (m['workoutIndex'] ?? -1) as int;
      if (!indexToNewWorkoutKey.containsKey(wi)) continue;
      await sbox.add(SetEntry(
        workoutKey: indexToNewWorkoutKey[wi]!,
        exercise: (m['exercise'] ?? '') as String,
        setNumber: (m['setNumber'] ?? 1) as int,
        reps: (m['reps'] ?? 0) as int,
        weightKg: ((m['weightKg'] ?? 0.0) as num).toDouble(),
        rpe: (m['rpe'] == null) ? null : ((m['rpe'] as num).toDouble()),
        notes: (m['notes'] ?? '') as String,
        isTimeBased: (m['isTimeBased'] ?? false) as bool,
        seconds: (m['seconds'] == null) ? null : (m['seconds'] as int),
        isCompleted: (m['isCompleted'] ?? false) as bool,
      ));
    }

    final List cardioEntries = (json['cardioEntries'] as List?) ?? [];
    for (final c in cardioEntries) {
      final m = c as Map;
      final wi = (m['workoutIndex'] ?? -1) as int;
      if (!indexToNewWorkoutKey.containsKey(wi)) continue;
      final segments = ((m['segments'] as List?) ?? [])
          .map((seg) => seg as Map)
          .map(
            (seg) => CardioSegment(
              label: (seg['label'] ?? '') as String,
              type: (seg['type'] ?? 'work') as String,
              durationSeconds: (seg['durationSeconds'] ?? 0) as int,
              distanceKm: (seg['distanceKm'] as num?)?.toDouble(),
              targetSpeedKph: (seg['targetSpeedKph'] as num?)?.toDouble(),
              inclinePercent: (seg['inclinePercent'] as num?)?.toDouble(),
              rpe: (seg['rpe'] as num?)?.toDouble(),
              notes: (seg['notes'] ?? '') as String,
            ),
          )
          .toList();

      await cbox.add(CardioEntry(
        workoutKey: indexToNewWorkoutKey[wi]!,
        activity: (m['activity'] ?? '') as String,
        durationSeconds: (m['durationSeconds'] ?? 0) as int,
        distanceKm: (m['distanceKm'] as num?)?.toDouble(),
        elevationGainM: (m['elevationGainM'] as num?)?.toDouble(),
        inclinePercent: (m['inclinePercent'] as num?)?.toDouble(),
        avgHeartRate: m['avgHeartRate'] as int?,
        maxHeartRate: m['maxHeartRate'] as int?,
        rpe: (m['rpe'] as num?)?.toDouble(),
        calories: (m['calories'] as num?)?.toDouble(),
        zoneSeconds: (m['zoneSeconds'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        segments: segments,
        environment: (m['environment'] ?? '') as String,
        terrain: (m['terrain'] ?? '') as String,
        weather: (m['weather'] ?? '') as String,
        equipment: (m['equipment'] ?? '') as String,
        mood: (m['mood'] ?? '') as String,
        energy: m['energy'] as int?,
        notes: (m['notes'] ?? '') as String,
      ));
    }

    // Templates
    final indexToStrengthTemplateKey = <int, int>{};
    final List templates = (json['templates'] as List?) ?? [];
    for (var i = 0; i < templates.length; i++) {
      final t = templates[i];
      final tm = t as Map;
      final List s = (tm['sets'] as List?) ?? [];
      final setsList = s.map((ts) {
        final m = ts as Map;
        return TemplateSet(
          exercise: (m['exercise'] ?? '') as String,
          setNumber: (m['setNumber'] ?? 1) as int,
          reps: (m['reps'] ?? 0) as int,
          weightKg: ((m['weightKg'] ?? 0.0) as num).toDouble(),
          rpe: (m['rpe'] == null) ? null : ((m['rpe'] as num).toDouble()),
          notes: (m['notes'] ?? '') as String,
          isTimeBased: (m['isTimeBased'] ?? false) as bool,
          seconds: (m['seconds'] == null) ? null : (m['seconds'] as int),
        );
      }).toList();
      final newTemplateKey = await tbox.add(WorkoutTemplate(
        name: (tm['name'] ?? '') as String,
        notes: (tm['notes'] ?? '') as String,
        sets: setsList,
      ));
      indexToStrengthTemplateKey[i] = newTemplateKey;
    }

    final indexToCardioTemplateKey = <int, int>{};
    final List cardioTemplates = (json['cardioTemplates'] as List?) ?? [];
    for (var i = 0; i < cardioTemplates.length; i++) {
      final t = cardioTemplates[i];
      final tm = t as Map;
      final segments = ((tm['segments'] as List?) ?? [])
          .map((seg) => seg as Map)
          .map(
            (seg) => CardioSegment(
              label: (seg['label'] ?? '') as String,
              type: (seg['type'] ?? 'work') as String,
              durationSeconds: (seg['durationSeconds'] ?? 0) as int,
              distanceKm: (seg['distanceKm'] as num?)?.toDouble(),
              targetSpeedKph: (seg['targetSpeedKph'] as num?)?.toDouble(),
              inclinePercent: (seg['inclinePercent'] as num?)?.toDouble(),
              rpe: (seg['rpe'] as num?)?.toDouble(),
              notes: (seg['notes'] ?? '') as String,
            ),
          )
          .toList();

      final newTemplateKey = await ctbox.add(CardioTemplate(
        name: (tm['name'] ?? '') as String,
        activity: (tm['activity'] ?? '') as String,
        durationSeconds: (tm['durationSeconds'] ?? 0) as int,
        distanceKm: (tm['distanceKm'] as num?)?.toDouble(),
        elevationGainM: (tm['elevationGainM'] as num?)?.toDouble(),
        inclinePercent: (tm['inclinePercent'] as num?)?.toDouble(),
        avgHeartRate: tm['avgHeartRate'] as int?,
        maxHeartRate: tm['maxHeartRate'] as int?,
        rpe: (tm['rpe'] as num?)?.toDouble(),
        calories: (tm['calories'] as num?)?.toDouble(),
        zoneSeconds: (tm['zoneSeconds'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        segments: segments,
        environment: (tm['environment'] ?? '') as String,
        terrain: (tm['terrain'] ?? '') as String,
        weather: (tm['weather'] ?? '') as String,
        equipment: (tm['equipment'] ?? '') as String,
        mood: (tm['mood'] ?? '') as String,
        energy: tm['energy'] as int?,
        notes: (tm['notes'] ?? '') as String,
      ));
      indexToCardioTemplateKey[i] = newTemplateKey;
    }

    // Exercises
    final List exercises = (json['exercises'] as List?) ?? [];
    for (final e in exercises) {
      final m = e as Map;
      await ebox.add(Exercise(
        name: (m['name'] ?? '') as String,
        category: (m['category'] ?? '') as String,
        isFavorite: (m['isFavorite'] ?? false) as bool,
      ));
    }


    // Readiness entries
    final List readinessEntries = (json['readiness'] as List?) ?? [];
    for (final r in readinessEntries) {
      final m = r as Map;
      await rbox.add(ReadinessEntry(
        date: DateTime.parse(m['date'] as String),
        score: ((m['score'] ?? 0.0) as num).toDouble(),
        band: (m['band'] ?? 'amber') as String,
        loadModifier: ((m['loadModifier'] ?? 1.0) as num).toDouble(),
        volumeModifier: ((m['volumeModifier'] ?? 1.0) as num).toDouble(),
        recentVolumeAvg: ((m['recentVolumeAvg'] ?? 0.0) as num).toDouble(),
        baselineVolumeAvg: ((m['baselineVolumeAvg'] ?? 0.0) as num).toDouble(),
        avgRpe: ((m['avgRpe'] ?? 0.0) as num).toDouble(),
        workoutsConsidered: (m['workoutsConsidered'] ?? 0) as int,
        note: (m['note'] ?? '') as String,
      ));
    }

    final indexToProgramKey = <int, int>{};
    final List programBlocks = (json['programBlocks'] as List?) ?? [];
    for (var i = 0; i < programBlocks.length; i++) {
      final p = programBlocks[i] as Map;
      final progressionMap = p['progression'] as Map?;
      final sessionsMap = (p['sessions'] as List?) ?? [];
      final sessions = sessionsMap
          .whereType<Map>()
          .map((m) {
            final kind = _readString(m['kind'], 'strength');
            final templateIndex = _readInt(m['templateIndex'], -1);
            var templateKey = _readInt(m['templateKey'], -1);
            if (templateIndex >= 0) {
              templateKey = kind == 'cardio'
                  ? (indexToCardioTemplateKey[templateIndex] ?? templateKey)
                  : (indexToStrengthTemplateKey[templateIndex] ?? templateKey);
            }
            if (templateKey < 0) return null;
            return ProgramSessionPlan(
              id: _readString(m['id'], DateTime.now().microsecondsSinceEpoch.toString()),
              weekDay: _clampInt(_readInt(m['weekDay'], 1), 1, 7),
              kind: kind == 'cardio' ? 'cardio' : 'strength',
              templateKey: templateKey,
              hour: _clampInt(_readInt(m['hour'], 9), 0, 23),
              minute: _clampInt(_readInt(m['minute'], 0), 0, 59),
              reminderEnabled: _readBool(m['reminderEnabled'], true),
              note: _readString(m['note'], ''),
            );
          })
          .whereType<ProgramSessionPlan>()
          .toList();
      final progression = ProgramProgressionConfig(
        strengthMode: _readString(progressionMap?['strengthMode'], 'fixed_kg'),
        strengthStepValueKg: _readDouble(progressionMap?['strengthStepValueKg'], 2.5),
        strengthStepPercent: _readDouble(progressionMap?['strengthStepPercent'], 2.5),
        strengthStepEveryWeeks: _readInt(progressionMap?['strengthStepEveryWeeks'], 1),
        strengthRoundingKg: _readDouble(progressionMap?['strengthRoundingKg'], 0.5),
        cardioMode: _readString(progressionMap?['cardioMode'], 'duration_percent'),
        cardioStepValueSeconds: _readInt(progressionMap?['cardioStepValueSeconds'], 60),
        cardioStepPercent: _readDouble(progressionMap?['cardioStepPercent'], 5),
        cardioWorkIntervalStepSeconds: _readInt(progressionMap?['cardioWorkIntervalStepSeconds'], 10),
        cardioStepEveryWeeks: _readInt(progressionMap?['cardioStepEveryWeeks'], 1),
        deloadEnabled: _readBool(progressionMap?['deloadEnabled'], false),
        deloadEveryWeeks: _readInt(progressionMap?['deloadEveryWeeks'], 4),
        deloadLoadPercent: _readDouble(progressionMap?['deloadLoadPercent'], -10),
        deloadVolumePercent: _readDouble(progressionMap?['deloadVolumePercent'], -15),
        applyReadinessModifiers: _readBool(progressionMap?['applyReadinessModifiers'], false),
      );
      final newProgramKey = await pbox.add(ProgramBlock(
        name: _readString(p['name'], 'Program'),
        startDate: DateTime.tryParse(_readString(p['startDate'], '')) ?? DateTime.now(),
        durationWeeks: _clampInt(_readInt(p['durationWeeks'], 8), 1, 52),
        sessions: sessions,
        progression: progression,
        isActive: _readBool(p['isActive'], true),
        generatedUntilWeek: _readInt(p['generatedUntilWeek'], 0),
        createdAt: DateTime.tryParse(_readString(p['createdAt'], '')) ?? DateTime.now(),
      ));
      indexToProgramKey[i] = newProgramKey;
    }

    final List scheduledWorkouts = (json['scheduledWorkouts'] as List?) ?? [];
    for (final s in scheduledWorkouts) {
      final m = s as Map;
      final kind = _readString(m['kind'], 'strength');
      final scheduledAt = DateTime.tryParse(_readString(m['scheduledAt'], ''));
      if (scheduledAt == null) continue;
      final templateIndex = _readInt(m['templateIndex'], -1);
      var templateKey = _readInt(m['templateKey'], -1);
      if (templateIndex >= 0) {
        templateKey = kind == 'cardio'
            ? (indexToCardioTemplateKey[templateIndex] ?? templateKey)
            : (indexToStrengthTemplateKey[templateIndex] ?? templateKey);
      }
      final linkedWorkoutIndex = _readInt(m['linkedWorkoutIndex'], -1);
      final linkedWorkoutKey = linkedWorkoutIndex >= 0
          ? indexToNewWorkoutKey[linkedWorkoutIndex]
          : (m['linkedWorkoutKey'] as int?);
      final programIndex = _readInt(m['programIndex'], -1);
      final programKey = programIndex >= 0
          ? indexToProgramKey[programIndex]
          : (m['programKey'] as int?);
      final programWeek = _readInt(m['programWeek'], -1);
      await swbox.add(ScheduledWorkout(
        kind: kind,
        templateKey: templateKey,
        scheduledAt: scheduledAt,
        reminderEnabled: _readBool(m['reminderEnabled'], true),
        isCompleted: _readBool(m['isCompleted'], false),
        linkedWorkoutKey: linkedWorkoutKey,
        programKey: programKey,
        programWeek: programWeek >= 0 ? programWeek : null,
        programSessionId: _readString(m['programSessionId'], '').trim().isEmpty
            ? null
            : _readString(m['programSessionId'], ''),
        isAutoGenerated: _readBool(m['isAutoGenerated'], false),
      ));
    }

    // Settings
    final Map? settingsMap = json['settings'] as Map?;
    if (settingsMap != null) {
      for (final entry in settingsMap.entries) {
        await settings.put(entry.key, entry.value);
      }
    }
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _readString(dynamic value, String fallback) {
    if (value is String) return value;
    return fallback;
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static bool _readBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }
}



