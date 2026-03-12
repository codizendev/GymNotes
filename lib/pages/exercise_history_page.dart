import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import 'workout_detail_page.dart';
import '../l10n/l10n.dart';

class ExerciseHistoryPage extends StatefulWidget {
  final String exerciseName;
  const ExerciseHistoryPage({super.key, required this.exerciseName});

  @override
  State<ExerciseHistoryPage> createState() => _ExerciseHistoryPageState();
}

class _ExerciseHistoryPageState extends State<ExerciseHistoryPage> {
  late final Box<Workout> wbox;
  late final Box<SetEntry> sbox;

  @override
  void initState() {
    super.initState();
    wbox = Hive.box<Workout>('workouts');
    sbox = Hive.box<SetEntry>('sets');
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';

  DateTime _workoutDate(int workoutKey) => wbox.get(workoutKey)?.date ?? DateTime(2000);

  List<SetEntry> _setsForExercise() {
    final target = widget.exerciseName.trim().toLowerCase();
    final list = sbox.values
        .where((s) => s.exercise.trim().toLowerCase() == target)
        .toList();
    // sort by workout date desc, then setNumber asc
    list.sort((a, b) {
      final wa = wbox.get(a.workoutKey);
      final wb = wbox.get(b.workoutKey);
      final cmp = (wb?.date ?? DateTime(2000)).compareTo(wa?.date ?? DateTime(2000));
      if (cmp != 0) return cmp;
      return a.setNumber.compareTo(b.setNumber);
    });
    return list;
  }

  ({double? heaviest, int? bestReps, double? bestVolume, double? best1rm}) _prs(List<SetEntry> sets) {
    double? heaviest;
    int? bestReps;
    double? bestVolume;
    double? best1rm;

    for (final s in sets) {
      if (s.isTimeBased) continue;
      if (s.weightKg > (heaviest ?? double.negativeInfinity)) heaviest = s.weightKg;
      if (s.reps > (bestReps ?? -1)) bestReps = s.reps;
      final vol = s.reps * s.weightKg;
      if (vol > (bestVolume ?? double.negativeInfinity)) bestVolume = vol;
      final est = s.weightKg * (1 + (s.reps / 30.0));
      if (est > (best1rm ?? double.negativeInfinity)) best1rm = est;
    }

    return (heaviest: heaviest, bestReps: bestReps, bestVolume: bestVolume, best1rm: best1rm);
  }

  ({List<_PrEvent> heaviest, List<_PrEvent> reps, List<_PrEvent> volume, List<_PrEvent> est1rm})
      _prHistory(List<SetEntry> sets) {
    double bestHeaviest = -1e9;
    double bestReps = -1e9;
    double bestVolume = -1e9;
    double best1rm = -1e9;

    final eventsHeaviest = <_PrEvent>[];
    final eventsReps = <_PrEvent>[];
    final eventsVolume = <_PrEvent>[];
    final events1rm = <_PrEvent>[];

    final chronological = [...sets]
      ..sort((a, b) {
        final cmp = _workoutDate(a.workoutKey).compareTo(_workoutDate(b.workoutKey));
        if (cmp != 0) return cmp;
        return a.setNumber.compareTo(b.setNumber);
      });

    for (final s in chronological) {
      if (s.isTimeBased) continue;
      final date = _workoutDate(s.workoutKey);
      if (s.weightKg > bestHeaviest) {
        bestHeaviest = s.weightKg;
        eventsHeaviest.add(_PrEvent(date: date, value: '${s.weightKg.toStringAsFixed(1)} kg', workoutKey: s.workoutKey));
      }
      if (s.reps.toDouble() > bestReps) {
        bestReps = s.reps.toDouble();
        eventsReps.add(_PrEvent(date: date, value: s.reps.toString(), workoutKey: s.workoutKey));
      }
      final vol = s.reps * s.weightKg;
      if (vol > bestVolume) {
        bestVolume = vol;
        eventsVolume.add(_PrEvent(date: date, value: vol.toStringAsFixed(0), workoutKey: s.workoutKey));
      }
      final est = s.weightKg * (1 + (s.reps / 30.0));
      if (est > best1rm) {
        best1rm = est;
        events1rm.add(_PrEvent(date: date, value: '${est.toStringAsFixed(1)} kg', workoutKey: s.workoutKey));
      }
    }

    // show latest first
    int desc(DateTime a, DateTime b) => b.compareTo(a);
    eventsHeaviest.sort((a, b) => desc(a.date, b.date));
    eventsReps.sort((a, b) => desc(a.date, b.date));
    eventsVolume.sort((a, b) => desc(a.date, b.date));
    events1rm.sort((a, b) => desc(a.date, b.date));

    return (heaviest: eventsHeaviest, reps: eventsReps, volume: eventsVolume, est1rm: events1rm);
  }

  String _fmtSetLine(SetEntry s, AppLocalizations t) {
    if (s.isTimeBased) {
      final total = s.seconds ?? 0;
      final mm = (total ~/ 60).toString().padLeft(2, '0');
      final ss = (total % 60).toString().padLeft(2, '0');
      final add = (s.weightKg > 0) ? '  •  +${s.weightKg.toStringAsFixed(1)} kg' : '';
      return '$mm:$ss$add';
    } else {
      return '${s.reps} ${t.reps.toLowerCase()} @ ${s.weightKg.toStringAsFixed(1)} kg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);

    // listen to boxes; rebuild on change
    final merged = Listenable.merge([wbox.listenable(), sbox.listenable()]);

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        final sets = _setsForExercise();
        final prs = _prs(sets);
        final prHistory = _prHistory(sets);
        final hasPrHistory = prHistory.heaviest.isNotEmpty ||
            prHistory.reps.isNotEmpty ||
            prHistory.volume.isNotEmpty ||
            prHistory.est1rm.isNotEmpty;

        // group by workoutKey -> list<SetEntry>
        final Map<int, List<SetEntry>> byWorkout = {};
        for (final se in sets) {
          byWorkout.putIfAbsent(se.workoutKey, () => []).add(se);
        }
        // sort workout keys by workout date desc
        final sortedKeys = byWorkout.keys.toList()
          ..sort((a, b) {
            final wa = wbox.get(a);
            final wb = wbox.get(b);
            return (wb?.date ?? DateTime(2000)).compareTo(wa?.date ?? DateTime(2000));
          });

        return Scaffold(
          appBar: AppBar(
            title: Text(s.exerciseHistoryTitle(widget.exerciseName)),
          ),
          body: SafeArea(
            bottom: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                // PR cards
                _PRGrid(
                  heaviestLabel: s.heaviestSet,
                  heaviestValue: prs.heaviest != null ? '${prs.heaviest!.toStringAsFixed(1)} kg' : '—',
                  bestRepsLabel: s.bestReps,
                  bestRepsValue: prs.bestReps?.toString() ?? '—',
                  bestVolumeLabel: s.bestVolume,
                  bestVolumeValue: prs.bestVolume != null ? prs.bestVolume!.toStringAsFixed(0) : '—',
                  est1rmLabel: s.estimated1RM,
                  est1rmValue: prs.best1rm != null ? '${prs.best1rm!.toStringAsFixed(1)} kg' : '-',
                ),
                const SizedBox(height: 16),

                Text(
                  'PR history',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (!hasPrHistory)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.noHistoryForExercise),
                  )
                else ...[
                  _PrHistoryList(
                    title: s.heaviestSet,
                    events: prHistory.heaviest,
                    dateFormatter: _d,
                    onOpenWorkout: (wk) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: wk)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrHistoryList(
                    title: s.bestReps,
                    events: prHistory.reps,
                    dateFormatter: _d,
                    onOpenWorkout: (wk) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: wk)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrHistoryList(
                    title: s.bestVolume,
                    events: prHistory.volume,
                    dateFormatter: _d,
                    onOpenWorkout: (wk) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: wk)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrHistoryList(
                    title: s.estimated1RM,
                    events: prHistory.est1rm,
                    dateFormatter: _d,
                    onOpenWorkout: (wk) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: wk)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                if (sortedKeys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(child: Text(s.noHistoryForExercise)),
                  )
                else
                  ...sortedKeys.map((wk) {
                    final w = wbox.get(wk);
                    final list = byWorkout[wk]!..sort((a, b) => a.setNumber.compareTo(b.setNumber));
                    final dateLabel = w != null ? _d(w.date) : '';
                    final title = w != null && w.title.isNotEmpty ? ' • ${w.title}' : '';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text('$dateLabel$title'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final se in list) ...[
                                Text('• ${s.setNumberShort} ${se.setNumber}: ${_fmtSetLine(se, s)}'
                                    '${se.rpe != null ? '  •  RPE ${se.rpe}' : ''}'
                                    '${se.notes.isNotEmpty ? '\n   ${se.notes}' : ''}'),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                        onTap: () {
                          if (w == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: w.key as int)),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrEvent {
  final DateTime date;
  final String value;
  final int workoutKey;
  const _PrEvent({required this.date, required this.value, required this.workoutKey});
}

class _PrHistoryList extends StatelessWidget {
  final String title;
  final List<_PrEvent> events;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<int> onOpenWorkout;

  const _PrHistoryList({
    required this.title,
    required this.events,
    required this.dateFormatter,
    required this.onOpenWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (events.isEmpty)
            Text('-', style: Theme.of(context).textTheme.bodySmall)
          else
            ...events.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(dateFormatter(e.date)),
                trailing: Text(e.value, style: Theme.of(context).textTheme.titleMedium),
                onTap: () => onOpenWorkout(e.workoutKey),
              ),
            ),
        ],
      ),
    );
  }
}

class _PRGrid extends StatelessWidget {
  final String heaviestLabel;
  final String heaviestValue;
  final String bestRepsLabel;
  final String bestRepsValue;
  final String bestVolumeLabel;
  final String bestVolumeValue;
  final String est1rmLabel;
  final String est1rmValue;

  const _PRGrid({
    required this.heaviestLabel,
    required this.heaviestValue,
    required this.bestRepsLabel,
    required this.bestRepsValue,
    required this.bestVolumeLabel,
    required this.bestVolumeValue,
    required this.est1rmLabel,
    required this.est1rmValue,
  });

  @override
  Widget build(BuildContext context) {
    Widget card(String label, String value, IconData icon) {
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
                  Text(label, style: const TextStyle(fontSize: 12)),
                  Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: card(heaviestLabel, heaviestValue, Icons.fitness_center)),
            const SizedBox(width: 10),
            Expanded(child: card(bestRepsLabel, bestRepsValue, Icons.repeat)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: card(bestVolumeLabel, bestVolumeValue, Icons.scale)),
            const SizedBox(width: 10),
            Expanded(child: card(est1rmLabel, est1rmValue, Icons.trending_up)),
          ],
        ),
      ],
    );
  }
}
