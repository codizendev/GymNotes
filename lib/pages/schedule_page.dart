import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/cardio_entry.dart';
import '../models/scheduled_workout.dart';
import '../models/workout_template.dart';
import '../models/cardio_template.dart';
import 'workout_detail_page.dart';
import 'cardio_workout_detail_page.dart';
import '../services/program_service.dart';
import '../services/workout_reminder_service.dart';
import '../l10n/l10n.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late final Box<Workout> wbox;
  late final Box<SetEntry> sbox;
  late final Box<CardioEntry> cbox;
  late final Box<ScheduledWorkout> swbox;
  late final Box<WorkoutTemplate> tbox;
  late final Box<CardioTemplate> ctbox;
  late final ValueListenable<Box<Workout>> _workoutsListenable;

  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    wbox = Hive.box<Workout>('workouts');
    sbox = Hive.box<SetEntry>('sets');
    cbox = Hive.box<CardioEntry>('cardio_entries');
    swbox = Hive.box<ScheduledWorkout>('scheduled_workouts');
    tbox = Hive.box<WorkoutTemplate>('templates');
    ctbox = Hive.box<CardioTemplate>('cardio_templates');
    _workoutsListenable = wbox.listenable();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _workoutsListenable.addListener(_onWorkoutBoxChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLinkedCompletionFromWorkouts();
    });
  }

  @override
  void dispose() {
    _workoutsListenable.removeListener(_onWorkoutBoxChanged);
    super.dispose();
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  List<ScheduledWorkout> _schedulesForDay(DateTime day) {
    final target = _dayKey(day);
    final items = swbox.values
        .where((s) => _dayKey(s.scheduledAt) == target)
        .toList();
    items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return items;
  }

  Map<DateTime, int> _countsForMonth(DateTime month) {
    final map = <DateTime, int>{};
    for (final s in swbox.values) {
      if (s.scheduledAt.year != month.year ||
          s.scheduledAt.month != month.month) {
        continue;
      }
      final key = _dayKey(s.scheduledAt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  void _goToMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  String _templateName(String kind, int templateKey) {
    if (kind == 'cardio') {
      return ctbox.get(templateKey)?.name ?? 'Missing template';
    }
    return tbox.get(templateKey)?.name ?? 'Missing template';
  }

  Workout? _linkedWorkout(ScheduledWorkout schedule) {
    final linkedKey = schedule.linkedWorkoutKey;
    if (linkedKey == null) return null;
    return wbox.get(linkedKey);
  }

  String _scheduleDisplayTitle(ScheduledWorkout schedule) {
    final linkedTitle = _linkedWorkout(schedule)?.title.trim() ?? '';
    if (linkedTitle.isNotEmpty) return linkedTitle;
    final base = _templateName(schedule.kind, schedule.templateKey);
    final week = schedule.programWeek;
    if (week == null) return base;
    return 'W$week - $base';
  }

  String? _scheduleDisplayNotes(ScheduledWorkout schedule) {
    final notes = _linkedWorkout(schedule)?.notes.trim() ?? '';
    if (notes.isEmpty) return null;
    return notes;
  }

  IconData _kindIcon(String kind) {
    return kind == 'cardio' ? Icons.directions_run : Icons.fitness_center;
  }

  void _onWorkoutBoxChanged() {
    _syncLinkedCompletionFromWorkouts(forceRebuild: true);
  }

  Future<void> _syncLinkedCompletionFromWorkouts({
    bool forceRebuild = false,
  }) async {
    var changed = false;
    for (final schedule in swbox.values) {
      final linked = schedule.linkedWorkoutKey;
      if (linked == null || schedule.isCompleted) continue;
      final workout = wbox.get(linked);
      if (workout == null) continue;
      if (workout.isCompleted) {
        schedule
          ..isCompleted = true
          ..reminderEnabled = false;
        await schedule.save();
        await WorkoutReminderService.instance.cancelReminder(
          schedule.key as int,
        );
        changed = true;
      }
    }
    if ((changed || forceRebuild) && mounted) {
      setState(() {});
    }
  }

  Future<void> _syncLinkedWorkoutFromSchedule(
    ScheduledWorkout schedule, {
    bool syncCompletion = true,
    bool syncDate = true,
  }) async {
    final linkedKey = schedule.linkedWorkoutKey;
    if (linkedKey == null) return;
    final workout = wbox.get(linkedKey);
    if (workout == null) return;

    var changed = false;
    if (syncCompletion && workout.isCompleted != schedule.isCompleted) {
      workout.isCompleted = schedule.isCompleted;
      changed = true;
    }
    if (syncDate) {
      final targetDate = _dayKey(schedule.scheduledAt);
      final currentDate = _dayKey(workout.date);
      if (currentDate != targetDate) {
        workout.date = targetDate;
        changed = true;
      }
    }
    if (changed) {
      await workout.save();
    }
  }

  Future<int?> _createWorkoutFromSchedule(ScheduledWorkout schedule) async {
    final scheduleDate = DateTime(
      schedule.scheduledAt.year,
      schedule.scheduledAt.month,
      schedule.scheduledAt.day,
    );

    if (schedule.kind == 'cardio') {
      final template = ctbox.get(schedule.templateKey);
      if (template == null) {
        if (mounted) {
          final s = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.scheduleMissingCardioTemplate)),
          );
        }
        return null;
      }
      final tunedTemplate = ProgramService.tuneCardioTemplate(
        schedule: schedule,
        baseTemplate: template,
      );
      final workoutKey = await wbox.add(
        Workout(
          date: scheduleDate,
          title: tunedTemplate.name,
          notes: tunedTemplate.notes,
          kind: 'cardio',
        )..totalSets = tunedTemplate.segments.length,
      );
      await cbox.add(
        CardioEntry(
          workoutKey: workoutKey,
          activity: tunedTemplate.activity,
          durationSeconds: tunedTemplate.durationSeconds,
          distanceKm: tunedTemplate.distanceKm,
          elevationGainM: tunedTemplate.elevationGainM,
          inclinePercent: tunedTemplate.inclinePercent,
          avgHeartRate: tunedTemplate.avgHeartRate,
          maxHeartRate: tunedTemplate.maxHeartRate,
          rpe: tunedTemplate.rpe,
          calories: tunedTemplate.calories,
          zoneSeconds: List<int>.from(tunedTemplate.zoneSeconds),
          segments: tunedTemplate.segments.map((segment) => segment.copy()).toList(),
          environment: tunedTemplate.environment,
          terrain: tunedTemplate.terrain,
          weather: tunedTemplate.weather,
          equipment: tunedTemplate.equipment,
          mood: tunedTemplate.mood,
          energy: tunedTemplate.energy,
          notes: tunedTemplate.notes,
        ),
      );
      return workoutKey;
    }

    final template = tbox.get(schedule.templateKey);
    if (template == null) {
      if (mounted) {
        final s = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.scheduleMissingStrengthTemplate)),
        );
      }
      return null;
    }

    final workoutKey = await wbox.add(
      Workout(
        date: scheduleDate,
        title: template.name,
        notes: template.notes,
        kind: 'strength',
      ),
    );

    var totalSets = 0;
    var totalReps = 0;
    var totalVolume = 0.0;
    for (final templateSet in template.sets) {
      final tuned = ProgramService.tuneStrengthSet(
        schedule: schedule,
        baseSet: templateSet,
      );
      final entry = SetEntry(
        workoutKey: workoutKey,
        exercise: templateSet.exercise,
        setNumber: templateSet.setNumber,
        reps: tuned.reps,
        weightKg: tuned.weightKg,
        rpe: templateSet.rpe,
        notes: templateSet.notes,
        isTimeBased: templateSet.isTimeBased,
        seconds: tuned.seconds,
      );
      await sbox.add(entry);
      totalSets += 1;
      if (!entry.isTimeBased) {
        totalReps += entry.reps;
        totalVolume += entry.reps * entry.weightKg;
      }
    }

    final workout = wbox.get(workoutKey);
    if (workout != null) {
      workout
        ..totalSets = totalSets
        ..totalReps = totalReps
        ..totalVolume = totalVolume;
      await workout.save();
    }
    return workoutKey;
  }

  Future<void> _openOrStartScheduledWorkout(ScheduledWorkout schedule) async {
    var workoutKey = schedule.linkedWorkoutKey;
    if (workoutKey != null && wbox.get(workoutKey) == null) {
      workoutKey = null;
    }

    if (workoutKey == null) {
      workoutKey = await _createWorkoutFromSchedule(schedule);
      if (workoutKey == null) return;
      schedule
        ..linkedWorkoutKey = workoutKey
        ..isCompleted = false;
      await schedule.save();
    }

    final targetWorkoutKey = workoutKey;

    final scheduleKey = schedule.key as int;
    if (schedule.reminderEnabled) {
      await WorkoutReminderService.instance.cancelReminder(scheduleKey);
      schedule.reminderEnabled = false;
      await schedule.save();
    }

    if (!mounted) return;
    if (schedule.kind == 'cardio') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardioWorkoutDetailPage(workoutKey: targetWorkoutKey),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutDetailPage(workoutKey: targetWorkoutKey),
        ),
      );
    }

    if (!mounted) return;
    await _syncLinkedCompletionFromWorkouts();
  }

  Future<void> _markScheduleCompleted(
    ScheduledWorkout schedule, {
    bool clearLink = false,
  }) async {
    final key = schedule.key as int;
    schedule
      ..isCompleted = true
      ..reminderEnabled = false;
    if (clearLink) {
      schedule.linkedWorkoutKey = null;
    }
    await schedule.save();
    if (!clearLink) {
      await _syncLinkedWorkoutFromSchedule(schedule);
    }
    await WorkoutReminderService.instance.cancelReminder(key);
    if (mounted) setState(() {});
  }

  Future<void> _reopenSchedule(ScheduledWorkout schedule) async {
    schedule.isCompleted = false;
    await schedule.save();
    await _syncLinkedWorkoutFromSchedule(schedule);
    if (mounted) setState(() {});
  }

  Future<void> _rescheduleBy(ScheduledWorkout schedule, Duration delta) async {
    final reminderTitle = AppLocalizations.of(context).reminderTitle;
    final key = schedule.key as int;
    final wasReminderEnabled = schedule.reminderEnabled;
    if (wasReminderEnabled) {
      await WorkoutReminderService.instance.cancelReminder(key);
    }

    final next = schedule.scheduledAt.add(delta);
    schedule
      ..scheduledAt = next
      ..isCompleted = false;
    await schedule.save();
    await _syncLinkedWorkoutFromSchedule(schedule);

    if (wasReminderEnabled) {
      await WorkoutReminderService.instance.scheduleReminder(
        scheduleKey: key,
        scheduledAt: next,
        title: reminderTitle,
        body: '${_scheduleDisplayTitle(schedule)} - ${_formatDateTime(next)}',
      );
    }

    if (mounted) {
      setState(() {
        _focusedMonth = DateTime(next.year, next.month);
        _selectedDay = DateTime(next.year, next.month, next.day);
      });
    }
  }

  Future<int?> _pickTemplateKey(String kind) async {
    final s = AppLocalizations.of(context);
    final options = kind == 'cardio'
        ? ctbox.values.map((t) => (key: t.key as int, name: t.name)).toList()
        : tbox.values.map((t) => (key: t.key as int, name: t.name)).toList();
    return showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (options.isEmpty) {
          return SizedBox(
            height: 160,
            child: Center(child: Text(s.noTemplatesYet)),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: options.length,
          separatorBuilder: (context, index) => const Divider(height: 0),
          itemBuilder: (ctx, i) {
            final option = options[i];
            return ListTile(
              title: Text(option.name),
              onTap: () => Navigator.pop(ctx, option.key),
            );
          },
        );
      },
    );
  }

  Future<void> _openScheduleForm({
    ScheduledWorkout? existing,
    DateTime? date,
  }) async {
    final s = AppLocalizations.of(context);
    var kind = existing?.kind ?? 'strength';
    int? templateKey = existing?.templateKey;
    var scheduledAt =
        existing?.scheduledAt ??
        DateTime(
          date?.year ?? _selectedDay.year,
          date?.month ?? _selectedDay.month,
          date?.day ?? _selectedDay.day,
          9,
          0,
        );
    var reminderEnabled = existing?.reminderEnabled ?? true;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
            final templateName = templateKey == null
                ? s.pickTemplate
                : _templateName(kind, templateKey!);
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null
                          ? s.scheduleWorkoutTitle
                          : s.editScheduleTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'strength',
                          label: Text(s.workoutTypeStrength),
                        ),
                        ButtonSegment(
                          value: 'cardio',
                          label: Text(s.workoutTypeCardio),
                        ),
                      ],
                      selected: {kind},
                      onSelectionChanged: (selection) {
                        setSheetState(() {
                          kind = selection.first;
                          templateKey = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.templateLabel),
                      subtitle: Text(templateName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await _pickTemplateKey(kind);
                        if (picked == null) return;
                        setSheetState(() => templateKey = picked);
                      },
                    ),
                    const Divider(height: 0),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.dateLabel),
                      subtitle: Text(_formatDate(scheduledAt)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: scheduledAt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setSheetState(() {
                          scheduledAt = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            scheduledAt.hour,
                            scheduledAt.minute,
                          );
                        });
                      },
                    ),
                    const Divider(height: 0),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.timeLabel),
                      subtitle: Text(_formatTime(scheduledAt)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: TimeOfDay.fromDateTime(scheduledAt),
                        );
                        if (picked == null) return;
                        setSheetState(() {
                          scheduledAt = DateTime(
                            scheduledAt.year,
                            scheduledAt.month,
                            scheduledAt.day,
                            picked.hour,
                            picked.minute,
                          );
                        });
                      },
                    ),
                    const Divider(height: 0),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reminderEnabled,
                      onChanged: (v) =>
                          setSheetState(() => reminderEnabled = v),
                      title: Text(s.reminderLabel),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(s.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            if (templateKey == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s.pickTemplate)),
                              );
                              return;
                            }
                            if (existing == null) {
                              final key = await swbox.add(
                                ScheduledWorkout(
                                  kind: kind,
                                  templateKey: templateKey!,
                                  scheduledAt: scheduledAt,
                                  reminderEnabled: reminderEnabled,
                                ),
                              );
                              if (reminderEnabled) {
                                await WorkoutReminderService.instance
                                    .scheduleReminder(
                                      scheduleKey: key,
                                      scheduledAt: scheduledAt,
                                      title: s.reminderTitle,
                                      body:
                                          '${_templateName(kind, templateKey!)} - ${_formatDateTime(scheduledAt)}',
                                    );
                              }
                            } else {
                              final ScheduledWorkout current = existing;
                              final key = current.key as int;
                              final wasEnabled = current.reminderEnabled;
                              final planChanged =
                                  current.kind != kind ||
                                  current.templateKey != templateKey!;
                              current
                                ..kind = kind
                                ..templateKey = templateKey!
                                ..scheduledAt = scheduledAt
                                ..reminderEnabled = reminderEnabled;
                              if (planChanged) {
                                current
                                  ..isCompleted = false
                                  ..linkedWorkoutKey = null;
                              }
                              await current.save();
                              if (!planChanged) {
                                await _syncLinkedWorkoutFromSchedule(current);
                              }
                              if (wasEnabled) {
                                await WorkoutReminderService.instance
                                    .cancelReminder(key);
                              }
                              if (reminderEnabled) {
                                await WorkoutReminderService.instance
                                    .scheduleReminder(
                                      scheduleKey: key,
                                      scheduledAt: scheduledAt,
                                      title: s.reminderTitle,
                                      body:
                                          '${_scheduleDisplayTitle(current)} - ${_formatDateTime(scheduledAt)}',
                                    );
                              }
                            }
                            if (mounted) setState(() {});
                            if (context.mounted) Navigator.pop(sheetContext);
                          },
                          child: Text(s.save),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSchedule(ScheduledWorkout schedule) async {
    final key = schedule.key as int;
    await WorkoutReminderService.instance.cancelReminder(key);
    await swbox.delete(key);
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} ${_formatTime(date)}';

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.scheduleTitle)),
      body: ValueListenableBuilder(
        valueListenable: swbox.listenable(),
        builder: (context, box, child) {
          final counts = _countsForMonth(_focusedMonth);
          final daysInMonth = _daysInMonth(_focusedMonth);
          final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
          final offset = firstDay.weekday - 1; // Monday start
          final totalCells = offset + daysInMonth;
          final rows = (totalCells / 7).ceil();
          final dayItems = List<DateTime?>.generate(rows * 7, (index) {
            if (index < offset) return null;
            final day = index - offset + 1;
            if (day > daysInMonth) return null;
            return DateTime(_focusedMonth.year, _focusedMonth.month, day);
          });
          final selectedSchedules = _schedulesForDay(_selectedDay);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _goToMonth(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_focusedMonth),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _goToMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in [
                    s.weekdayMon,
                    s.weekdayTue,
                    s.weekdayWed,
                    s.weekdayThu,
                    s.weekdayFri,
                    s.weekdaySat,
                    s.weekdaySun,
                  ])
                    Text(label),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent: 58,
                ),
                itemCount: dayItems.length,
                itemBuilder: (context, i) {
                  final day = dayItems[i];
                  if (day == null) return const SizedBox.shrink();
                  final key = _dayKey(day);
                  final isSelected = _dayKey(day) == _dayKey(_selectedDay);
                  final isToday = _dayKey(day) == _dayKey(DateTime.now());
                  final count = counts[key] ?? 0;
                  return InkWell(
                    onTap: () => setState(() => _selectedDay = day),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12)
                            : null,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (count > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.scheduleTitle} - ${_formatDate(_selectedDay)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openScheduleForm(date: _selectedDay),
                    icon: const Icon(Icons.add),
                    label: Text(s.scheduleWorkoutAction),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (selectedSchedules.isEmpty)
                Text(s.noScheduledWorkouts)
              else
                Column(
                  children: selectedSchedules.map((item) {
                    final linkedWorkoutExists =
                        item.linkedWorkoutKey != null &&
                        wbox.get(item.linkedWorkoutKey) != null;
                    final scheduleTitle = _scheduleDisplayTitle(item);
                    final scheduleNotes = _scheduleDisplayNotes(item);
                    final statusLabel = item.isCompleted
                        ? s.scheduleStatusCompleted
                        : s.scheduleStatusPending;
                    final subtitleTop = linkedWorkoutExists
                        ? '${_formatDateTime(item.scheduledAt)} - $statusLabel - ${s.scheduleLinkedWorkout}'
                        : '${_formatDateTime(item.scheduledAt)} - $statusLabel';
                    final subtitle = scheduleNotes == null
                        ? subtitleTop
                        : '$subtitleTop\n$scheduleNotes';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.isCompleted
                              ? Icons.check_circle
                              : _kindIcon(item.kind),
                          color: item.isCompleted ? Colors.green : null,
                        ),
                        title: Text(
                          scheduleTitle,
                          style: item.isCompleted
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: Text(subtitle, maxLines: 3),
                        isThreeLine: scheduleNotes != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (linkedWorkoutExists)
                              IconButton(
                                tooltip: s.scheduleOpenLinkedWorkout,
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () async {
                                  await _openOrStartScheduledWorkout(item);
                                },
                              ),
                            if (item.reminderEnabled && !item.isCompleted)
                              const Icon(Icons.notifications_active),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'open_workout') {
                                  await _openOrStartScheduledWorkout(item);
                                } else if (value == 'mark_completed') {
                                  await _markScheduleCompleted(item);
                                } else if (value == 'skip') {
                                  await _markScheduleCompleted(
                                    item,
                                    clearLink: true,
                                  );
                                } else if (value == 'reopen') {
                                  await _reopenSchedule(item);
                                } else if (value == 'reschedule_tomorrow') {
                                  await _rescheduleBy(
                                    item,
                                    const Duration(days: 1),
                                  );
                                } else if (value == 'reschedule_week') {
                                  await _rescheduleBy(
                                    item,
                                    const Duration(days: 7),
                                  );
                                } else if (value == 'edit') {
                                  await _openScheduleForm(existing: item);
                                } else if (value == 'delete') {
                                  await _deleteSchedule(item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'open_workout',
                                  child: ListTile(
                                    leading: Icon(
                                      linkedWorkoutExists
                                          ? Icons.open_in_new
                                          : Icons.play_arrow,
                                    ),
                                    title: Text(
                                      linkedWorkoutExists
                                          ? s.open
                                          : s.scheduleStartWorkout,
                                    ),
                                  ),
                                ),
                                if (!item.isCompleted)
                                  PopupMenuItem(
                                    value: 'mark_completed',
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      title: Text(s.scheduleMarkCompleted),
                                    ),
                                  ),
                                if (!item.isCompleted)
                                  PopupMenuItem(
                                    value: 'skip',
                                    child: ListTile(
                                      leading: const Icon(Icons.skip_next),
                                      title: Text(s.scheduleSkipWorkout),
                                    ),
                                  ),
                                if (item.isCompleted)
                                  PopupMenuItem(
                                    value: 'reopen',
                                    child: ListTile(
                                      leading: const Icon(Icons.replay),
                                      title: Text(s.scheduleReopen),
                                    ),
                                  ),
                                if (!item.isCompleted)
                                  PopupMenuItem(
                                    value: 'reschedule_tomorrow',
                                    child: ListTile(
                                      leading: const Icon(Icons.calendar_today),
                                      title: Text(s.scheduleRescheduleTomorrow),
                                    ),
                                  ),
                                if (!item.isCompleted)
                                  PopupMenuItem(
                                    value: 'reschedule_week',
                                    child: ListTile(
                                      leading: const Icon(Icons.event_repeat),
                                      title: Text(s.scheduleRescheduleNextWeek),
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: Text(s.edit),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: Text(s.delete),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () async {
                          await _openOrStartScheduledWorkout(item);
                        },
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}
