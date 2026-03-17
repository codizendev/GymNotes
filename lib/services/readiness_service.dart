import 'dart:math';

import 'package:hive/hive.dart';

import '../models/readiness_entry.dart';
import '../models/set_entry.dart';
import '../models/workout.dart';
import '../models/workout_template.dart';

class ReadinessService {
  ReadinessService({
    required this.workoutsBox,
    required this.setsBox,
    required this.readinessBox,
    required this.settingsBox,
  });

  final Box<Workout> workoutsBox;
  final Box<SetEntry> setsBox;
  final Box<ReadinessEntry> readinessBox;
  final Box settingsBox;

  ReadinessEntry? latest() {
    if (readinessBox.isEmpty) return null;
    final list = readinessBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.first;
  }

  /// Recalculate readiness based on recent training history and store it.
  Future<ReadinessEntry> recompute({int? weeklyGoal}) async {
    final goal = weeklyGoal ?? (settingsBox.get('weeklyGoal') as int? ?? 4);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final workouts = workoutsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final last21Days = workouts.where((w) => !_isBeforeDays(w.date, 21)).toList();
    if (last21Days.isEmpty) {
      final entry = ReadinessEntry(
        date: today,
        score: 0.0,
        band: 'amber',
        loadModifier: 1.0,
        volumeModifier: 1.0,
        recentVolumeAvg: 0,
        baselineVolumeAvg: 0,
        avgRpe: 0,
        workoutsConsidered: 0,
        note: 'Log a few workouts to enable readiness.',
      );
      final existingToday = readinessBox.values.where((e) => _isSameDay(e.date, today)).toList();
      for (final e in existingToday) {
        await e.delete();
      }
      await readinessBox.add(entry);
      return entry;
    }
    final recent = last21Days.take(3).toList();
    final baseline = last21Days.skip(3).toList();

    final recentAvgVolume = _avgVolume(recent);
    final baselineAvgVolume = baseline.isEmpty ? recentAvgVolume : _avgVolume(baseline);
    final rpeAvg = _avgRpe(last21Days);
    final feelingAvg = _avgFeeling(last21Days);
    final feelingScore = _clamp01(feelingAvg / 10);

    final workoutsThisWeek = last21Days.where((w) => !_isBeforeDays(w.date, 7)).length;
    final consistencyScore = goal <= 0 ? 0.0 : min(1.0, workoutsThisWeek / goal);

    final volumeLoad = baselineAvgVolume == 0 ? 1.0 : recentAvgVolume / baselineAvgVolume;
    final volumePenalty = _clamp01((volumeLoad - 1.15) / 0.6); // penalize only if +15% vs baseline

    final rpePenalty = _clamp01((rpeAvg - 7) / 3); // above RPE7 reduces readiness

    final readinessScore = _clamp01(
      (0.35 * consistencyScore) +
          (0.3 * (1 - volumePenalty)) +
          (0.2 * (1 - rpePenalty)) +
          (0.15 * feelingScore),
    );

    final band = (readinessScore >= 0.67)
        ? 'green'
        : (readinessScore >= 0.45)
            ? 'amber'
            : 'red';

    final loadModifier = 0.9 + (0.2 * readinessScore); // 0.9–1.1
    final volumeModifier = 0.88 + (0.24 * readinessScore); // 0.88–1.12

    final noteParts = <String>[];
    noteParts.add('Consistency: ${(consistencyScore * 100).round()}% of weekly goal.');
    if (baselineAvgVolume > 0) {
      final delta = ((volumeLoad - 1) * 100).round();
      noteParts.add('Volume trend: ${delta >= 0 ? '+' : ''}$delta%.');
    }
    if (rpeAvg > 0) {
      noteParts.add('Avg RPE: ${rpeAvg.toStringAsFixed(1)}.');
    }
    noteParts.add('Feeling: ${feelingAvg.toStringAsFixed(1)}/10.');

    final entry = ReadinessEntry(
      date: today,
      score: readinessScore,
      band: band,
      loadModifier: double.parse(loadModifier.toStringAsFixed(3)),
      volumeModifier: double.parse(volumeModifier.toStringAsFixed(3)),
      recentVolumeAvg: recentAvgVolume,
      baselineVolumeAvg: baselineAvgVolume,
      avgRpe: rpeAvg,
      workoutsConsidered: last21Days.length,
      note: noteParts.join(' '),
    );

    final existingToday = readinessBox.values.where((e) => _isSameDay(e.date, today)).toList();
    for (final e in existingToday) {
      await e.delete();
    }
    await readinessBox.add(entry);
    return entry;
  }

  AutoPlanSummary buildAutoPlanSummary({ReadinessEntry? snapshot}) {
    final snap = snapshot ?? latest();
    if (snap == null) return AutoPlanSummary.empty();

    final headline = switch (snap.band) {
      'green' => 'Ready to push',
      'amber' => 'Maintain and monitor',
      _ => 'Pull back and focus on quality',
    };

    final loadPct = ((snap.loadModifier - 1) * 100).round();
    final volumePct = ((snap.volumeModifier - 1) * 100).round();

    final rationale = [
      'Load ${loadPct >= 0 ? '+' : ''}$loadPct%',
      'Volume ${volumePct >= 0 ? '+' : ''}$volumePct%',
      if (snap.note.isNotEmpty) snap.note,
    ].join(' • ');

    return AutoPlanSummary(
      band: snap.band,
      score: snap.score,
      loadModifier: snap.loadModifier,
      volumeModifier: snap.volumeModifier,
      headline: headline,
      rationale: rationale,
    );
  }

  TunedTemplate previewTemplate(
    WorkoutTemplate template, {
    ReadinessEntry? snapshot,
    double? weightIncrement,
    double? additiveIncrease,
  }) {
    final snap = snapshot ?? latest();
    final loadMult = snap?.loadModifier ?? 1.0;
    final volumeMult = snap?.volumeModifier ?? 1.0;

    double roundWeight(double value) {
      if (weightIncrement == null || weightIncrement <= 0) {
        return double.parse(value.toStringAsFixed(1));
      }
      final steps = (value / weightIncrement).round();
      return double.parse((steps * weightIncrement).toStringAsFixed(2));
    }

    final tunedSets = template.sets.map((s) {
      double tunedWeight;
      if (additiveIncrease != null && additiveIncrease > 0 && loadMult > 1.0) {
        tunedWeight = roundWeight(s.weightKg + additiveIncrease);
      } else if (loadMult < 1.0) {
        tunedWeight = roundWeight(s.weightKg * loadMult);
      } else {
        tunedWeight = roundWeight(s.weightKg);
      }
      final tunedReps = max(1, (s.reps * volumeMult).round());
      final tunedSeconds = s.seconds != null ? max(1, (s.seconds! * volumeMult).round()) : null;
      return TunedSet(
        exercise: s.exercise,
        setNumber: s.setNumber,
        targetReps: tunedReps,
        targetWeight: tunedWeight,
        targetSeconds: tunedSeconds,
        isTimeBased: s.isTimeBased,
      );
    }).toList();

    return TunedTemplate(
      name: template.name,
      loadModifier: loadMult,
      volumeModifier: volumeMult,
      tunedSets: tunedSets,
    );
  }

  double _avgVolume(List<Workout> list) {
    if (list.isEmpty) return 0.0;
    final total = list.fold<double>(0.0, (sum, w) => sum + w.totalVolume);
    return total / list.length;
  }

  double _avgRpe(List<Workout> workouts) {
    if (workouts.isEmpty) return 0.0;
    final workoutKeys = workouts.map((w) => w.key).whereType<int>().toSet();
    final rpeValues = setsBox.values
        .where((s) => workoutKeys.contains(s.workoutKey) && s.rpe != null)
        .map((s) => s.rpe!)
        .toList();
    if (rpeValues.isEmpty) return 0.0;
    final sum = rpeValues.fold<double>(0.0, (a, b) => a + b);
    return sum / rpeValues.length;
  }

  double _avgFeeling(List<Workout> workouts) {
    if (workouts.isEmpty) return 7.0;
    final values = workouts.map((w) => w.feelingScore.toDouble()).toList();
    final sum = values.fold<double>(0.0, (a, b) => a + b);
    return sum / values.length;
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isBeforeDays(DateTime date, int days) {
    final now = DateTime.now();
    final cut = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    return date.isBefore(cut);
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0);
}

class AutoPlanSummary {
  final String band;
  final double score;
  final double loadModifier;
  final double volumeModifier;
  final String headline;
  final String rationale;

  const AutoPlanSummary({
    required this.band,
    required this.score,
    required this.loadModifier,
    required this.volumeModifier,
    required this.headline,
    required this.rationale,
  });

  factory AutoPlanSummary.empty() => const AutoPlanSummary(
        band: 'amber',
        score: 0.0,
        loadModifier: 1.0,
        volumeModifier: 1.0,
        headline: 'No readiness data yet',
        rationale: 'Log a few workouts to start getting smart suggestions.',
      );
}

class TunedTemplate {
  final String name;
  final double loadModifier;
  final double volumeModifier;
  final List<TunedSet> tunedSets;

  TunedTemplate({
    required this.name,
    required this.loadModifier,
    required this.volumeModifier,
    required this.tunedSets,
  });
}

class TunedSet {
  final String exercise;
  final int setNumber;
  final int targetReps;
  final double targetWeight;
  final int? targetSeconds;
  final bool isTimeBased;

  TunedSet({
    required this.exercise,
    required this.setNumber,
    required this.targetReps,
    required this.targetWeight,
    required this.targetSeconds,
    required this.isTimeBased,
  });
}
