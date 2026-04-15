import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/cardio_entry.dart';
import '../models/exercise.dart'; // For exercise autocomplete.
import 'workout_detail_page.dart';

// Localization.
import '../l10n/l10n.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

enum _Period { week, month }

// Exercise progress section.
enum _EPMetric { maxWeight, est1RM, totalReps, totalTimeSec }
enum _EPPeriod { days30, days180, year1, all }

class _StatisticsPageState extends State<StatisticsPage> {
  late final Box<Workout> wbox;
  late final Box<SetEntry> sbox;
  late final Box<Exercise> ebox;
  late final Box<CardioEntry> cbox;

  _Period period = _Period.week;

  // --- Exercise progress state ---
  String? _exerciseName;
  _EPMetric _metric = _EPMetric.est1RM;
  _EPPeriod _epPeriod = _EPPeriod.days180;
  bool _smooth = true; // moving average 3

  @override
  void initState() {
    super.initState();
    wbox = Hive.box<Workout>('workouts');
    sbox = Hive.box<SetEntry>('sets');
    // Box can be empty; keep for autocomplete.
    ebox = Hive.box<Exercise>('exercises');
    cbox = Hive.box<CardioEntry>('cardio_entries');
  }

  int get _days => period == _Period.week ? 7 : 30;
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  ({DateTime from, DateTime to}) _range() {
    final now = DateTime.now();
    final to = _startOfDay(now).add(const Duration(days: 1));
    final from = _startOfDay(now.subtract(Duration(days: _days - 1)));
    return (from: from, to: to);
  }

  ({int workouts, int sets, int reps, int seconds}) _periodStats(List<Workout> workouts, List<SetEntry> sets) {
    final totalSets = workouts.fold<int>(0, (sum, w) => sum + w.totalSets);
    final totalReps = sets.where((s) => !s.isTimeBased).fold<int>(0, (sum, s) => sum + s.reps);
    final totalSeconds = sets.where((s) => s.isTimeBased).fold<int>(0, (sum, s) => sum + (s.seconds ?? 0));
    return (workouts: workouts.length, sets: totalSets, reps: totalReps, seconds: totalSeconds);
  }

  List<Workout> _workoutsInRange() {
    final r = _range();
    final list = wbox.values
        .where((w) => !w.date.isBefore(r.from) && w.date.isBefore(r.to))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<SetEntry> _setsForWorkouts(List<Workout> workouts) {
    final keys = workouts.map((w) => w.key as int).toSet();
    return sbox.values.where((s) => keys.contains(s.workoutKey)).toList();
  }

  List<CardioEntry> _cardioForWorkouts(List<Workout> workouts) {
    final keys = workouts.where((w) => w.kind == 'cardio').map((w) => w.key as int).toSet();
    return cbox.values.where((c) => keys.contains(c.workoutKey)).toList();
  }

  CardioEntry? _cardioEntryForWorkout(int workoutKey) {
    for (final c in cbox.values) {
      if (c.workoutKey == workoutKey) return c;
    }
    return null;
  }

  CardioEntry _cloneCardioEntry(CardioEntry entry, {required int workoutKey}) {
    return CardioEntry(
      workoutKey: workoutKey,
      activity: entry.activity,
      durationSeconds: entry.durationSeconds,
      distanceKm: entry.distanceKm,
      elevationGainM: entry.elevationGainM,
      inclinePercent: entry.inclinePercent,
      avgHeartRate: entry.avgHeartRate,
      maxHeartRate: entry.maxHeartRate,
      rpe: entry.rpe,
      calories: entry.calories,
      zoneSeconds: List<int>.from(entry.zoneSeconds),
      segments: entry.segments
          .map(
            (s) => CardioSegment(
              label: s.label,
              type: s.type,
              durationSeconds: s.durationSeconds,
              distanceKm: s.distanceKm,
              targetSpeedKph: s.targetSpeedKph,
              inclinePercent: s.inclinePercent,
              rpe: s.rpe,
              notes: s.notes,
            ),
          )
          .toList(),
      environment: entry.environment,
      terrain: entry.terrain,
      weather: entry.weather,
      equipment: entry.equipment,
      mood: entry.mood,
      energy: entry.energy,
      notes: entry.notes,
    );
  }

  ({
    int sessions,
    int totalSeconds,
    double totalDistance,
    int longestSeconds,
    double? bestPaceSecPerKm,
  }) _cardioStats(List<CardioEntry> entries) {
    int sessions = entries.length;
    int totalSeconds = 0;
    double totalDistance = 0.0;
    int longestSeconds = 0;
    double? bestPace;

    for (final e in entries) {
      totalSeconds += e.durationSeconds;
      if (e.durationSeconds > longestSeconds) longestSeconds = e.durationSeconds;
      if (e.distanceKm != null) totalDistance += e.distanceKm!;
      if (e.distanceKm != null && e.distanceKm! > 0 && e.durationSeconds > 0) {
        final pace = e.durationSeconds / e.distanceKm!;
        if (bestPace == null || pace < bestPace) bestPace = pace;
      }
    }

    return (
      sessions: sessions,
      totalSeconds: totalSeconds,
      totalDistance: totalDistance,
      longestSeconds: longestSeconds,
      bestPaceSecPerKm: bestPace,
    );
  }

  String _formatDurationShort(int seconds) {
    if (seconds <= 0) return '0m';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    if (remMinutes == 0) return '${hours}h';
    return '${hours}h ${remMinutes}m';
  }

  String _formatPace(double paceSecondsPerKm) {
    final total = paceSecondsPerKm.round();
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss /km';
  }

  List<({DateTime day, int count})> _workoutsPerDay(List<Workout> workouts) {
    final start = _range().from;
    final map = <DateTime, int>{};
    for (var i = 0; i < _days; i++) {
      map[_startOfDay(start.add(Duration(days: i)))] = 0;
    }
    for (final w in workouts) {
      final d = _startOfDay(w.date);
      map[d] = (map[d] ?? 0) + 1;
    }
    final days = map.keys.toList()..sort();
    return days.map((d) => (day: d, count: map[d] ?? 0)).toList();
  }

  List<({String name, int sets, int reps, int seconds, double best1rm, double maxWeight})> _topExercises(
      List<SetEntry> sets) {
    final agg =
        <String, ({String name, int sets, int reps, int seconds, double best1rm, double maxWeight})>{};
    for (final s in sets) {
      final name = s.exercise.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final current = agg[key] ??
          (name: name, sets: 0, reps: 0, seconds: 0, best1rm: 0.0, maxWeight: 0.0); // stable record shape
      final est = (!s.isTimeBased && s.reps > 0) ? _est1RM(s.reps, s.weightKg) : 0.0;
      agg[key] = (
        name: current.name,
        sets: current.sets + 1,
        reps: current.reps + (s.isTimeBased ? 0 : s.reps),
        seconds: current.seconds + (s.isTimeBased ? (s.seconds ?? 0) : 0),
        best1rm: est > current.best1rm ? est : current.best1rm,
        maxWeight: s.weightKg > current.maxWeight ? s.weightKg : current.maxWeight,
      );
    }
    final list = agg.values.toList();
    list.sort((a, b) {
      final bySets = b.sets.compareTo(a.sets);
      if (bySets != 0) return bySets;
      final byReps = b.reps.compareTo(a.reps);
      if (byReps != 0) return byReps;
      return b.best1rm.compareTo(a.best1rm);
    });
    return list;
  }

  // ---------- Delete ----------
  Future<void> _confirmDeleteWorkout(Workout w) async {
    final s = AppLocalizations.of(context);
    final dateStr =
        '${w.date.day.toString().padLeft(2, '0')}.${w.date.month.toString().padLeft(2, '0')}.${w.date.year}.';

    final titleTrim = w.title.trim();
    final bodyText = s.deleteWorkoutBody(
      dateStr,
      titleTrim.isNotEmpty ? 'yes' : 'other',
      titleTrim,
    );

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.deleteWorkoutTitle),
            content: Text(bodyText),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: Text(s.delete)),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await _deleteWorkoutWithUndo(w);
    }
  }

  Future<void> _deleteWorkoutWithUndo(Workout w) async {
    final s = AppLocalizations.of(context);
    final wKey = w.key as int;

    final backupWorkout = Workout(date: w.date, title: w.title, notes: w.notes, kind: w.kind)
      ..totalSets = w.totalSets
      ..totalReps = w.totalReps
      ..totalVolume = w.totalVolume;

    final backupSets = sbox.values
        .where((s) => s.workoutKey == wKey)
        .map((s) => SetEntry(
              workoutKey: -1,
              exercise: s.exercise,
              setNumber: s.setNumber,
              reps: s.reps,
              weightKg: s.weightKg,
              rpe: s.rpe,
              notes: s.notes,
              isTimeBased: s.isTimeBased,
              seconds: s.seconds,
              isCompleted: s.isCompleted,
            ))
        .toList();

    final backupCardio = cbox.values
        .where((c) => c.workoutKey == wKey)
        .map((c) => _cloneCardioEntry(c, workoutKey: -1))
        .toList();

    for (final s in sbox.values.where((s) => s.workoutKey == wKey).toList()) {
      await s.delete();
    }
    for (final c in cbox.values.where((c) => c.workoutKey == wKey).toList()) {
      await c.delete();
    }
    await w.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.workoutDeleted),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            final newWKey = await wbox.add(
              Workout(
                date: backupWorkout.date,
                title: backupWorkout.title,
                notes: backupWorkout.notes,
                kind: backupWorkout.kind,
              )
                ..totalSets = backupWorkout.totalSets
                ..totalReps = backupWorkout.totalReps
                ..totalVolume = backupWorkout.totalVolume,
            );
            for (final s in backupSets) {
              await sbox.add(SetEntry(
                workoutKey: newWKey,
                exercise: s.exercise,
                setNumber: s.setNumber,
                reps: s.reps,
                weightKg: s.weightKg,
                rpe: s.rpe,
                notes: s.notes,
                isTimeBased: s.isTimeBased,
                seconds: s.seconds,
                isCompleted: s.isCompleted,
              ));
            }
            for (final c in backupCardio) {
              await cbox.add(_cloneCardioEntry(c, workoutKey: newWKey));
            }
            if (!mounted) return;
            setState(() {});
          },
        ),
      ),
    );
    setState(() {});
  }

  // ---------- Exercise progress helpers ----------
  DateTime _fromDateForEP(DateTime now) {
    switch (_epPeriod) {
      case _EPPeriod.days30:
        return _startOfDay(now).subtract(const Duration(days: 29));
      case _EPPeriod.days180:
        return _startOfDay(now).subtract(const Duration(days: 179));
      case _EPPeriod.year1:
        return _startOfDay(now).subtract(const Duration(days: 364));
      case _EPPeriod.all:
        return DateTime(2000, 1, 1);
    }
  }

  double _est1RM(int reps, double weight) => weight * (1 + (reps / 30.0));

  /// build series: date -> value for the chosen exercise/metric
  Map<DateTime, double> _exerciseSeries() {
    if (_exerciseName == null || _exerciseName!.trim().isEmpty) return {};
    final now = DateTime.now();
    final from = _fromDateForEP(now);
    final toExclusive = _startOfDay(now).add(const Duration(days: 1));

    final sets = sbox.values.where((s) {
      final w = wbox.get(s.workoutKey);
      if (w == null) return false;
      final d = w.date;
      final matchExercise = s.exercise.trim().toLowerCase() == _exerciseName!.trim().toLowerCase();
      final inRange = !d.isBefore(from) && d.isBefore(toExclusive);
      return matchExercise && inRange;
    }).toList();

    final byDay = <DateTime, List<SetEntry>>{};
    for (final s in sets) {
      final w = wbox.get(s.workoutKey)!;
      final day = _startOfDay(w.date);
      (byDay[day] ??= []).add(s);
    }

    final out = <DateTime, double>{};
    byDay.forEach((day, list) {
      switch (_metric) {
        case _EPMetric.maxWeight:
          final maxW = list
              .where((e) => !e.isTimeBased)
              .fold<double>(0.0, (m, e) => e.weightKg > m ? e.weightKg : m);
          final maxAddon = list
              .where((e) => e.isTimeBased && (e.weightKg > 0))
              .fold<double>(0.0, (m, e) => e.weightKg > m ? e.weightKg : m);
          out[day] = (maxW > 0) ? maxW : maxAddon;
          break;
        case _EPMetric.est1RM:
          double max1rm = 0.0;
          for (final e in list) {
            if (!e.isTimeBased && e.reps > 0) {
              final v = _est1RM(e.reps, e.weightKg);
              if (v > max1rm) max1rm = v;
            }
          }
          out[day] = max1rm;
          break;
        case _EPMetric.totalReps:
          final reps = list.where((e) => !e.isTimeBased).fold<int>(0, (sum, e) => sum + e.reps);
          out[day] = reps.toDouble();
          break;
        case _EPMetric.totalTimeSec:
          final secs = list.where((e) => e.isTimeBased).fold<int>(0, (sum, e) => sum + (e.seconds ?? 0));
          out[day] = secs.toDouble();
          break;
      }
    });

    final sorted = out.keys.toList()..sort();
    return {for (final k in sorted) k: out[k]!};
  }

  List<FlSpot> _spotsFromSeries(Map<DateTime, double> series, DateTime baseFrom) {
    final base = _startOfDay(baseFrom).millisecondsSinceEpoch.toDouble();
    return series.entries.map((e) {
      final x = (_startOfDay(e.key).millisecondsSinceEpoch.toDouble() - base) / (1000 * 60 * 60 * 24);
      return FlSpot(x, e.value);
    }).toList();
  }

  /// simple MA with window 3
  List<FlSpot> _movingAverage3(List<FlSpot> spots) {
    if (spots.length < 3) return spots;
    final out = <FlSpot>[];
    for (var i = 0; i < spots.length; i++) {
      final a = i > 0 ? spots[i - 1].y : spots[i].y;
      final b = spots[i].y;
      final c = i < spots.length - 1 ? spots[i + 1].y : spots[i].y;
      final avg = (a + b + c) / 3.0;
      out.add(FlSpot(spots[i].x, avg));
    }
    return out;
  }

  /// return set of x-values where a new PR happened (strictly greater than any previous)
  Set<double> _prXs(List<FlSpot> spots) {
    final out = <double>{};
    double best = -1e9;
    for (final s in spots) {
      if (s.y > best) {
        best = s.y;
        out.add(s.x);
      }
    }
    return out;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final merged = Listenable.merge([
      wbox.listenable(),
      sbox.listenable(),
      ebox.listenable(),
      cbox.listenable(),
    ]);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    final allExerciseNames = ebox.values.map((e) => e.name).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        final workouts = _workoutsInRange();
        final sets = _setsForWorkouts(workouts);
        final stats = _periodStats(workouts, sets);
        final cardioEntries = _cardioForWorkouts(workouts);
        final cardioStats = _cardioStats(cardioEntries);
        final workoutsPerDay = _workoutsPerDay(workouts);
        final topExercises = _topExercises(sets).take(3).toList();
        final hasPerDayActivity = workoutsPerDay.any((d) => d.count > 0);
        final maxPerDay = workoutsPerDay.fold<int>(0, (m, d) => d.count > m ? d.count : m);
        final perDayMaxY = (maxPerDay == 0 ? 1 : maxPerDay + 1).toDouble();

        // exercise progress data
        final now = DateTime.now();
        final epFrom = _fromDateForEP(now);
        final series = _exerciseSeries();
        var spots = _spotsFromSeries(series, epFrom);
        final prXs = _prXs(spots);
        if (_smooth) spots = _movingAverage3(spots);

        return Scaffold(
          appBar: AppBar(
            title: Text(s.statisticsTitle),
          ),
          body: SafeArea(
            bottom: true,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
              children: [
                // Existing filters.
                Row(
                  children: [
                    _PeriodChip(
                      label: s.period7days,
                      selected: period == _Period.week,
                      onTap: () => setState(() => period = _Period.week),
                    ),
                    const SizedBox(width: 8),
                    _PeriodChip(
                      label: s.period30days,
                      selected: period == _Period.month,
                      onTap: () => setState(() => period = _Period.month),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      title: s.workoutsTitle,
                      value: '${stats.workouts}',
                      subtitle: s.totalInPeriod,
                      icon: Icons.calendar_today,
                    ),
                    _StatCard(
                      title: s.setsCount,
                      value: '${stats.sets}',
                      subtitle: s.totalInPeriod,
                      icon: Icons.fitness_center,
                    ),
                    _StatCard(
                      title: s.metricTotalReps,
                      value: '${stats.reps}',
                      subtitle: s.totalInPeriod,
                      icon: Icons.repeat,
                    ),
                    if (stats.seconds > 0)
                      _StatCard(
                        title: s.metricTotalTimeSec,
                        value: _formatSecondsShort(stats.seconds),
                        subtitle: s.totalInPeriod,
                        icon: Icons.timer,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  s.cardioSummaryTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (cardioStats.sessions == 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.noCardioInPeriod),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: s.cardioSessionsLabel,
                        value: '${cardioStats.sessions}',
                        subtitle: s.totalInPeriod,
                        icon: Icons.directions_run,
                      ),
                      _StatCard(
                        title: s.durationLabel,
                        value: _formatSecondsShort(cardioStats.totalSeconds),
                        subtitle: s.totalInPeriod,
                        icon: Icons.timer_outlined,
                      ),
                      _StatCard(
                        title: s.distanceTotalLabel,
                        value: cardioStats.totalDistance == 0.0
                            ? s.noDistance
                            : '${cardioStats.totalDistance.toStringAsFixed(2)} km',
                        subtitle: s.totalInPeriod,
                        icon: Icons.straighten,
                      ),
                      _StatCard(
                        title: s.longestSessionLabel,
                        value: _formatSecondsShort(cardioStats.longestSeconds),
                        subtitle: s.totalInPeriod,
                        icon: Icons.emoji_events_outlined,
                      ),
                      if (cardioStats.bestPaceSecPerKm != null)
                        _StatCard(
                          title: s.bestPaceLabel,
                          value: _formatPace(cardioStats.bestPaceSecPerKm!),
                          subtitle: s.totalInPeriod,
                          icon: Icons.speed,
                        ),
                    ],
                  ),
                const SizedBox(height: 20),

                Text(
                  s.workoutsPerDayTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: SizedBox(
                    height: 190,
                    child: hasPerDayActivity
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final dayCount = workoutsPerDay.length;
                              final minLabelWidth = period == _Period.week ? 28.0 : 40.0;
                              final step = _labelStepForWidth(
                                itemCount: dayCount,
                                width: constraints.maxWidth,
                                minLabelWidth: minLabelWidth,
                              );

                              return BarChart(
                                BarChartData(
                                  maxY: perDayMaxY,
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        final day = workoutsPerDay[group.x.toInt()].day;
                                        return BarTooltipItem(
                                          '${_two(day.day)}.${_two(day.month)}.${day.year}\n${rod.toY.toInt()} ${s.workoutsTitle.toLowerCase()}',
                                          const TextStyle(fontWeight: FontWeight.w700),
                                        );
                                      },
                                    ),
                                  ),
                                  gridData: FlGridData(show: true, drawVerticalLine: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 34,
                                        getTitlesWidget: (value, _) => Text(
                                          value.toInt().toString(),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: step.toDouble(),
                                        getTitlesWidget: (value, _) {
                                          final idx = value.toInt();
                                          if (idx < 0 || idx >= workoutsPerDay.length) {
                                            return const SizedBox.shrink();
                                          }
                                          if (idx % step != 0) {
                                            return const SizedBox.shrink();
                                          }
                                          final d = workoutsPerDay[idx].day;
                                          final label = period == _Period.week ? _weekdayShort(d) : '${d.day}.${d.month}';
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
                                          );
                                        },
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                  ),
                                  barGroups: List.generate(
                                    workoutsPerDay.length,
                                    (i) => BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: workoutsPerDay[i].count.toDouble(),
                                          width: 12,
                                          borderRadius: BorderRadius.circular(8),
                                          gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                                              Theme.of(context).colorScheme.primary,
                                            ],
                                          ),
                                          backDrawRodData: BackgroundBarChartRodData(
                                            show: true,
                                            toY: perDayMaxY,
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(child: Text(s.noWorkoutsInPeriod)),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  s.topExercisesTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (topExercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.noWorkoutsInPeriod),
                  )
                else
                  ...topExercises.map((ex) {
                    final meta = <String>[
                      '${ex.sets} ${s.setsCount}',
                      if (ex.reps > 0) '${ex.reps} ${s.reps}',
                      if (ex.seconds > 0) _formatSecondsShort(ex.seconds),
                    ];
                    String? highlightLabel;
                    String? highlightValue;
                    if (ex.best1rm > 0) {
                      highlightLabel = s.metricEst1RM;
                      highlightValue = _formatY(ex.best1rm);
                    } else if (ex.maxWeight > 0) {
                      highlightLabel = s.metricMaxWeight;
                      highlightValue = _formatY(ex.maxWeight);
                    }
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                          child: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(ex.name),
                        subtitle: Text(meta.where((m) => m.isNotEmpty).join(' | ')),
                        trailing: (highlightLabel == null || highlightValue == null)
                            ? null
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    highlightValue,
                                    style:
                                        Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    highlightLabel,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                      ),
                    );
                  }),

                const SizedBox(height: 20),

                Text(
                  s.workoutsInPeriodTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (workouts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.noWorkoutsInPeriod),
                  )
                else
                  ...workouts.map((w) {
                    final d = w.date;
                    final dateStr =
                        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';
                    final cardioEntry = w.kind == 'cardio' ? _cardioEntryForWorkout(w.key as int) : null;
                    final cardioDuration =
                        cardioEntry != null ? _formatDurationShort(cardioEntry.durationSeconds) : s.noDuration;
                    final cardioDistance = cardioEntry?.distanceKm != null
                        ? '${cardioEntry!.distanceKm!.toStringAsFixed(2)} km'
                        : s.noDistance;
                    final subtitle = w.kind == 'cardio'
                        ? '${s.durationLabel}: $cardioDuration - ${s.distanceTotalLabel}: $cardioDistance'
                        : '${s.setsCount}: ${w.totalSets}';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(w.title.isNotEmpty ? w.title : '${s.workout} $dateStr'),
                        subtitle: Text(subtitle),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'open') {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: w.key as int)),
                              );
                            } else if (v == 'delete') {
                              await _confirmDeleteWorkout(w);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'open',
                              child: ListTile(leading: const Icon(Icons.open_in_new), title: Text(s.open)),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(s.delete)),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: w.key as int)),
                          );
                        },
                      ),
                    );
                  }),

                const SizedBox(height: 28),
                // ===============================
                //  EXERCISE PROGRESS (NOVO)
                // ===============================
                Text(
                  s.exerciseProgressTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                  // ===============================
                  // Exercise picker + Metric + Period + Smoothing
                  // ===============================
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final exerciseField = Autocomplete<String>(
                      optionsBuilder: (te) {
                        final q = te.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return allExerciseNames.where((n) => n.toLowerCase().contains(q));
                      },
                      fieldViewBuilder: (_, ctrl, focus, submit) {
                        ctrl.text = _exerciseName ?? '';
                        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
                        return TextField(
                          controller: ctrl,
                          focusNode: focus,
                          decoration: InputDecoration(
                            labelText: s.exerciseLabel,
                            prefixIcon: const Icon(Icons.fitness_center),
                          ),
                          onSubmitted: (_) => submit(),
                        );
                      },
                      onSelected: (val) => setState(() => _exerciseName = val),
                      optionsViewBuilder: (context, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (_, i) {
                                final opt = options.elementAt(i);
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.fitness_center),
                                  title: Text(opt),
                                  onTap: () => onSelected(opt),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                    final metricDropdown = DropdownButtonFormField<_EPMetric>(
                      initialValue: _metric,
                      decoration: InputDecoration(
                        labelText: s.metricLabel,
                        prefixIcon: const Icon(Icons.stacked_line_chart),
                      ),
                      items: _EPMetric.values
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(_metricLabel(m, s)),
                              ))
                          .toList(),
                      onChanged: (m) => setState(() => _metric = m!),
                    );
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          exerciseField,
                          const SizedBox(height: 12),
                          metricDropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 12, child: exerciseField),
                        const SizedBox(width: 12),
                        Expanded(flex: 10, child: metricDropdown),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final periodDropdown = DropdownButtonFormField<_EPPeriod>(
                      initialValue: _epPeriod,
                      decoration: InputDecoration(
                        labelText: s.periodLabel,
                        prefixIcon: const Icon(Icons.calendar_month),
                      ),
                      items: _EPPeriod.values
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(_periodLabel(p, s)),
                              ))
                          .toList(),
                      onChanged: (p) => setState(() => _epPeriod = p!),
                    );
                    final smoothingToggle = SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.smoothingLabel),
                      value: _smooth,
                      onChanged: (v) => setState(() => _smooth = v),
                    );
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          periodDropdown,
                          const SizedBox(height: 12),
                          smoothingToggle,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: periodDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: smoothingToggle),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (_exerciseName == null || _exerciseName!.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.pickExerciseHint),
                  )
                else if (spots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.noDataForSelectedPeriod),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalDays = now.difference(epFrom).inDays;
                      final step = _labelStepForWidth(
                        itemCount: totalDays + 1,
                        width: constraints.maxWidth,
                        minLabelWidth: 48,
                      );
                      final useMonthYear = totalDays > 365;

                      return AspectRatio(
                        aspectRatio: 1.6,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((ts) {
                                    final dayOffset = ts.x.toInt();
                                    final d = _startOfDay(epFrom).add(Duration(days: dayOffset));
                                    return LineTooltipItem(
                                      '${_two(d.day)}.${_two(d.month)}.${d.year}\n${_formatY(ts.y)}',
                                      const TextStyle(fontWeight: FontWeight.w700),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, _) =>
                                      Text(_leftTick(value), style: Theme.of(context).textTheme.bodySmall),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: step.toDouble(),
                                  getTitlesWidget: (value, _) {
                                    final dayOffset = value.toInt();
                                    if (dayOffset < 0 || dayOffset > totalDays) {
                                      return const SizedBox.shrink();
                                    }
                                    if (dayOffset % step != 0) {
                                      return const SizedBox.shrink();
                                    }
                                    final d = _startOfDay(epFrom).add(Duration(days: dayOffset));
                                    final label = useMonthYear
                                        ? '${_two(d.month)}.${d.year.toString().substring(2)}'
                                        : '${_two(d.day)}.${_two(d.month)}';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            lineBarsData: [
                              // glavna linija
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                dotData: FlDotData(
                                  show: true,
                                  checkToShowDot: (spot, _) => prXs.contains(spot.x), // PR marker
                                  getDotPainter: (spot, percent, bar, index) {
                                    // Slightly larger dot for PR.
                                    return FlDotCirclePainter(
                                      radius: 3.5,
                                      strokeWidth: 1.5,
                                      color: Colors.transparent,
                                      strokeColor: Theme.of(context).colorScheme.primary,
                                    );
                                  },
                                ),
                                barWidth: 3,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                if (_exerciseName != null && _exerciseName!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StatCard(
                    title: _metricLabel(_metric, s),
                    value: (series.isEmpty) ? '-' : _formatY(series.values.last),
                    subtitle: s.latest,
                    icon: Icons.trending_up,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  int _labelStepForWidth({
    required int itemCount,
    required double width,
    double minLabelWidth = 40,
  }) {
    if (itemCount <= 0) return 1;
    final maxLabels = (width / minLabelWidth).floor();
    if (maxLabels <= 1) return itemCount;
    final step = (itemCount / maxLabels).ceil();
    return step < 1 ? 1 : step;
  }

  String _metricLabel(_EPMetric m, AppLocalizations s) {
    switch (m) {
      case _EPMetric.maxWeight:
        return s.metricMaxWeight;
      case _EPMetric.est1RM:
        return s.metricEst1RM;
      case _EPMetric.totalReps:
        return s.metricTotalReps;
      case _EPMetric.totalTimeSec:
        return s.metricTotalTimeSec;
    }
  }

  String _periodLabel(_EPPeriod p, AppLocalizations s) {
    switch (p) {
      case _EPPeriod.days30:
        return s.epPeriod30days;
      case _EPPeriod.days180:
        return s.epPeriod180days;
      case _EPPeriod.year1:
        return s.epPeriod1year;
      case _EPPeriod.all:
        return s.epPeriodAllTime;
    }
  }

  String _weekdayShort(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(d.weekday - 1) % 7];
  }

  String _formatSecondsShort(int seconds) {
    if (seconds <= 0) return '0s';
    final minutes = seconds ~/ 60;
    final remSeconds = seconds % 60;
    if (minutes == 0) return '${seconds}s';
    if (minutes < 60) return remSeconds == 0 ? '${minutes}m' : '${minutes}m ${remSeconds}s';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    if (remMinutes == 0 && remSeconds == 0) return '${hours}h';
    if (remSeconds == 0) return '${hours}h ${remMinutes}m';
    return '${hours}h ${remMinutes}m';
  }

  String _formatY(double y) {
    // No total volume; show number with 1 decimal.
    return y % 1 == 0 ? y.toStringAsFixed(0) : y.toStringAsFixed(1);
  }

  String _leftTick(double v) => _formatY(v);

  String _two(int n) => n.toString().padLeft(2, '0');
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.icon = Icons.calendar_today,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black12.withValues(alpha: 0.04),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12)),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}















