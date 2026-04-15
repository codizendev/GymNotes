// Rebuilt workout detail page without session feedback
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../models/scheduled_workout.dart';
import '../services/export_service.dart';
import '../services/workout_reminder_service.dart';
import '../l10n/l10n.dart';
import 'exercise_history_page.dart';
import 'cardio_workout_detail_page.dart';

enum _EntryMode { reps, time }

class WorkoutDetailPage extends StatefulWidget {
  final int workoutKey;
  const WorkoutDetailPage({super.key, required this.workoutKey});

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  static const double _fabHeight = 56;
  static const double _fabSpace = kFloatingActionButtonMargin + _fabHeight;
  static const bool _showProgressionSuggestionUi = false;

  late final Box<Workout> wbox;
  late final Box<SetEntry> sbox;
  late final Box<WorkoutTemplate> tbox;
  late final Box<ScheduledWorkout> swbox;
  late final Box settings;

  int _defaultRestSeconds = 120;
  bool _autoStartRest = false;
  final bool _restUiEnabled = false;
  Timer? _restTimer;
  int _restRemaining = 0;
  bool _restPaused = false;

  bool _isCompleted = false;

  int? _inlineEditSetKey;
  late TextEditingController _inlineExercise;
  late TextEditingController _inlineReps;
  late TextEditingController _inlineWeight;
  late TextEditingController _inlineMinutes;
  late TextEditingController _inlineSeconds;
  late TextEditingController _inlineRpe;
  late TextEditingController _inlineNotes;
  bool _inlineTimeBased = false;

  List<_SetGroup>? _cachedGroups;
  Map<int, _ProgressSuggestion> _lastProgressSuggestions = const {};
  bool _inlinePrefilledFromSuggestion = false;

  @override
  void initState() {
    super.initState();
    wbox = Hive.box<Workout>('workouts');
    sbox = Hive.box<SetEntry>('sets');
    tbox = Hive.box<WorkoutTemplate>('templates');
    swbox = Hive.box<ScheduledWorkout>('scheduled_workouts');
    settings = Hive.box('settings');
    _defaultRestSeconds =
        (settings.get('restSeconds') as int?)?.clamp(5, 1200) ?? 120;
    _autoStartRest = false;
    _isCompleted = workout.isCompleted;

    _inlineReps = TextEditingController();
    _inlineWeight = TextEditingController();
    _inlineMinutes = TextEditingController();
    _inlineSeconds = TextEditingController();
    _inlineRpe = TextEditingController();
    _inlineNotes = TextEditingController();
    _inlineExercise = TextEditingController();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _inlineExercise.dispose();
    _inlineReps.dispose();
    _inlineWeight.dispose();
    _inlineMinutes.dispose();
    _inlineSeconds.dispose();
    _inlineRpe.dispose();
    _inlineNotes.dispose();
    super.dispose();
  }

  Workout get workout => wbox.get(widget.workoutKey)!;

  List<SetEntry> _setsForWorkout() =>
      sbox.values.where((e) => e.workoutKey == widget.workoutKey).toList()
        ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

  SetEntry? _lastSet() {
    final list = _setsForWorkout();
    if (list.isEmpty) return null;
    return list.last;
  }

  Future<void> _shiftSetNumbers({
    required int startingFrom,
    required int delta,
    bool inclusive = false,
  }) async {
    final sets = _setsForWorkout();
    for (final e in sets) {
      final shouldShift = inclusive
          ? e.setNumber >= startingFrom
          : e.setNumber > startingFrom;
      if (shouldShift) {
        e.setNumber = e.setNumber + delta;
        await e.save();
      }
    }
  }

  Future<void> _maybeAddExerciseToLibrary(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final ebox = Hive.box<Exercise>('exercises');
    final exists = ebox.values.any(
      (e) => e.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (!exists) {
      await ebox.add(Exercise(name: trimmed, category: ''));
    }
  }

  void _startRestTimer({int? seconds, int? setKey}) {
    final duration = (seconds ?? _defaultRestSeconds).clamp(5, 1800);
    _restTimer?.cancel();
    setState(() {
      _restRemaining = duration;
      _restPaused = false;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restPaused) return;
      if (_restRemaining <= 1) {
        t.cancel();
        setState(() {
          _restRemaining = 0;
        });
      } else {
        setState(() {
          _restRemaining -= 1;
        });
      }
    });
  }

  void _maybeAutoStartRest({int? setKey}) {
    if (!_restUiEnabled) return;
    if (_autoStartRest) _startRestTimer(setKey: setKey);
  }

  Future<void> _recomputeTotals() async {
    _cachedGroups = null;
    final sets = _setsForWorkout();
    final w = workout
      ..totalSets = sets.length
      ..totalReps = sets
          .where((e) => !e.isTimeBased)
          .fold(0, (sum, e) => sum + e.reps)
      ..totalVolume = sets
          .where((e) => !e.isTimeBased)
          .fold(0.0, (sum, e) => sum + e.reps * e.weightKg);
    await w.save();
    if (!mounted) return;
    setState(() {});
  }

  void _openInlineEditor(SetEntry set) {
    final totalSecs = set.seconds ?? 0;
    _inlineEditSetKey = set.key;
    _inlineTimeBased = set.isTimeBased;
    _inlinePrefilledFromSuggestion = false;
    _inlineExercise.text = set.exercise;
    _inlineReps.text = set.reps.toString();
    _inlineWeight.text = set.weightKg.toString();
    _inlineMinutes.text = (totalSecs ~/ 60).toString();
    _inlineSeconds.text = (totalSecs % 60).toString();
    _inlineRpe.text = set.rpe?.toString() ?? '';
    _inlineNotes.text = set.notes;

    final setKey = set.key;
    if (!set.isTimeBased && setKey is int) {
      final suggestion = _lastProgressSuggestions[setKey];
      if (suggestion != null && suggestion.differsFrom(set)) {
        _inlineReps.text = suggestion.suggestedReps.toString();
        _inlineWeight.text = suggestion.suggestedWeightKg.toStringAsFixed(
          suggestion.suggestedWeightKg % 1 == 0 ? 0 : 2,
        );
        _inlinePrefilledFromSuggestion = true;
      }
    }
    setState(() {});
  }

  void _closeInlineEditor() {
    _inlineEditSetKey = null;
    _inlinePrefilledFromSuggestion = false;
    setState(() {});
  }

  bool _isInlineEditing(SetEntry set) => _inlineEditSetKey == set.key;

  Future<void> _applyInlineEdit(SetEntry set) async {
    final s = AppLocalizations.of(context);
    final exerciseName = _inlineExercise.text.trim();
    if (exerciseName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.enterExerciseName)));
      return;
    }
    final weight =
        double.tryParse(_inlineWeight.text.trim().replaceAll(',', '.')) ?? -1;
    if (weight < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.invalidWeight)));
      return;
    }
    final rpeVal = _inlineRpe.text.trim().isEmpty
        ? null
        : double.tryParse(_inlineRpe.text.trim().replaceAll(',', '.'));
    if (_inlineRpe.text.trim().isNotEmpty && rpeVal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.invalidRpe)));
      return;
    }
    if (_inlineTimeBased) {
      final m = int.tryParse(_inlineMinutes.text.trim()) ?? 0;
      final ss = int.tryParse(_inlineSeconds.text.trim()) ?? 0;
      final total = (m * 60) + ss;
      if (total <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.durationGreaterThanZero)));
        return;
      }
      set
        ..exercise = exerciseName
        ..seconds = total
        ..reps = 0
        ..weightKg = weight
        ..rpe = rpeVal
        ..notes = _inlineNotes.text.trim();
    } else {
      final reps = int.tryParse(_inlineReps.text.trim()) ?? 0;
      if (reps <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.enterRepsGreaterThanZero)));
        return;
      }
      set
        ..exercise = exerciseName
        ..reps = reps
        ..weightKg = weight
        ..rpe = rpeVal
        ..notes = _inlineNotes.text.trim();
    }
    await _maybeAddExerciseToLibrary(exerciseName);
    await set.save();
    await _recomputeTotals();
    HapticFeedback.mediumImpact();
    _maybeAutoStartRest(setKey: set.key);
    _closeInlineEditor();
  }

  Future<void> _applyNewOrder(List<SetEntry> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final s = ordered[i];
      if (s.setNumber != i + 1) {
        s.setNumber = i + 1;
        await s.save();
      }
    }
    await _recomputeTotals();
  }

  Future<int> _insertDuplicateAfter(
    SetEntry source, {
    bool showUndo = true,
  }) async {
    final all = _setsForWorkout();
    final pivot = source.setNumber + 1;
    for (final e in all.reversed) {
      if (e.setNumber >= pivot) {
        e.setNumber = e.setNumber + 1;
        await e.save();
      }
    }

    final dup = SetEntry(
      workoutKey: source.workoutKey,
      exercise: source.exercise,
      setNumber: source.setNumber + 1,
      reps: source.reps,
      weightKg: source.weightKg,
      rpe: source.rpe,
      notes: source.notes,
      isTimeBased: source.isTimeBased,
      seconds: source.seconds,
      isCompleted: false,
      isSuperset: source.isSuperset,
    );

    final int key = await sbox.add(dup);
    await _recomputeTotals();
    if (!mounted || !showUndo) return key;

    final s = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.setAdded),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await sbox.delete(key);
            final after = _setsForWorkout();
            for (final e in after) {
              if (e.setNumber > source.setNumber) {
                e.setNumber = e.setNumber - 1;
                await e.save();
              }
            }
            await _recomputeTotals();
          },
        ),
      ),
    );

    return key;
  }

  _SetGroup _groupForEntry(SetEntry entry) {
    final groups = _cachedGroups ?? _groupSets(_setsForWorkout());
    return groups.firstWhere(
      (g) => g.entries.any((e) => e.key == entry.key),
      orElse: () => _SetGroup([entry]),
    );
  }

  Future<List<int>> _duplicateGroup(
    _SetGroup group, {
    bool showUndo = true,
  }) async {
    if (group.entries.length <= 1) {
      final key = await _insertDuplicateAfter(
        group.entries.first,
        showUndo: showUndo,
      );
      return [key];
    }

    final shift = group.entries.length;
    final insertAt = group.entries.last.setNumber + 1;
    final all = _setsForWorkout();

    for (final e in all.reversed) {
      if (e.setNumber >= insertAt) {
        e.setNumber = e.setNumber + shift;
        await e.save();
      }
    }

    final newKeys = <int>[];
    for (var idx = 0; idx < group.entries.length; idx++) {
      final src = group.entries[idx];
      final dup = SetEntry(
        workoutKey: src.workoutKey,
        exercise: src.exercise,
        setNumber: insertAt + idx,
        reps: src.reps,
        weightKg: src.weightKg,
        rpe: src.rpe,
        notes: src.notes,
        isTimeBased: src.isTimeBased,
        seconds: src.seconds,
        isCompleted: false,
        isSuperset: src.isSuperset,
      );
      final key = await sbox.add(dup);
      newKeys.add(key);
    }

    await _recomputeTotals();
    if (!mounted || !showUndo) return newKeys;

    final s = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.setAdded),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            for (final k in newKeys) {
              await sbox.delete(k);
            }
            final after = _setsForWorkout();
            for (final e in after) {
              if (e.setNumber >= insertAt) {
                e.setNumber = e.setNumber - shift;
                await e.save();
              }
            }
            await _recomputeTotals();
          },
        ),
      ),
    );

    return newKeys;
  }

  Future<void> _syncSupersetPartner(
    SetEntry target, {
    bool wasSuperset = false,
  }) async {
    final sets = _setsForWorkout();
    final idx = sets.indexWhere((e) => e.key == target.key);
    if (idx < 0) return;

    final isNowSuperset = target.isSuperset;

    bool isSupersetAt(int i, {required bool useCurrentState}) {
      final set = sets[i];
      if (set.key == target.key) {
        return useCurrentState ? isNowSuperset : wasSuperset;
      }
      return set.isSuperset;
    }

    int runStart({required bool useCurrentState}) {
      var start = idx;
      while (start - 1 >= 0 &&
          isSupersetAt(start - 1, useCurrentState: useCurrentState)) {
        start--;
      }
      return start;
    }

    int runEnd({required bool useCurrentState}) {
      var end = idx;
      while (end + 1 < sets.length &&
          isSupersetAt(end + 1, useCurrentState: useCurrentState)) {
        end++;
      }
      return end;
    }

    if (wasSuperset && !isNowSuperset) {
      // Removing superset: drop only the partner from the same run so adjacent pairs stay intact.
      final start = runStart(useCurrentState: false);
      final end = runEnd(useCurrentState: false);
      final len = end - start + 1;
      if (len > 1) {
        final idxInRun = idx - start;
        final partnerOffset = idxInRun.isEven ? idxInRun + 1 : idxInRun - 1;
        if (partnerOffset >= 0 && partnerOffset < len) {
          final partner = sets[start + partnerOffset];
          if (partner.isSuperset) {
            partner.isSuperset = false;
            await partner.save();
          }
        }
      }
    } else if (!wasSuperset && isNowSuperset) {
      // Adding superset: find a safe partner without breaking neighboring pairs.
      SetEntry? partner;
      if (idx + 1 < sets.length && !sets[idx + 1].isSuperset) {
        partner = sets[idx + 1];
      } else if (idx > 0 && !sets[idx - 1].isSuperset) {
        partner = sets[idx - 1];
      } else {
        // Look for a lone superset neighbor (unpaired) to match with.
        if (idx + 1 < sets.length && sets[idx + 1].isSuperset) {
          final nnSuperset = (idx + 2 < sets.length)
              ? sets[idx + 2].isSuperset
              : false;
          if (!nnSuperset) partner = sets[idx + 1];
        }
        if (partner == null && idx > 0 && sets[idx - 1].isSuperset) {
          final ppSuperset = (idx - 2 >= 0) ? sets[idx - 2].isSuperset : false;
          if (!ppSuperset) partner = sets[idx - 1];
        }
      }

      if (partner == null) {
        // No valid partner; revert the change.
        target.isSuperset = false;
        await target.save();
      } else if (!partner.isSuperset) {
        partner.isSuperset = true;
        await partner.save();
      }
    }
    await _recomputeTotals();
    if (mounted) setState(() {});
  }

  Future<void> _toggleSuperset(SetEntry se) async {
    final wasSuperset = se.isSuperset;
    se.isSuperset = !se.isSuperset;
    await se.save();
    await _syncSupersetPartner(se, wasSuperset: wasSuperset);
  }

  Future<void> _saveHeader(DateTime date, String title, String notes) async {
    final w = workout
      ..date = date
      ..title = title
      ..notes = notes;
    await w.save();
    await _syncLinkedSchedulesFromWorkout(syncDate: true);
    if (!mounted) return;
    setState(() {});
  }

  String _formatScheduleDateTime(DateTime dateTime) {
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final yyyy = dateTime.year.toString();
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Future<void> _syncLinkedSchedulesFromWorkout({
    bool syncCompletion = false,
    bool syncDate = false,
  }) async {
    if (!syncCompletion && !syncDate) return;
    final w = workout;
    final s = AppLocalizations.of(context);
    final title = w.title.trim().isEmpty ? s.workout : w.title.trim();

    for (final schedule in swbox.values.where(
      (item) => item.linkedWorkoutKey == widget.workoutKey,
    )) {
      var changed = false;
      final scheduleKey = schedule.key as int;

      if (syncCompletion && schedule.isCompleted != w.isCompleted) {
        schedule.isCompleted = w.isCompleted;
        changed = true;
        if (w.isCompleted && schedule.reminderEnabled) {
          schedule.reminderEnabled = false;
          await WorkoutReminderService.instance.cancelReminder(scheduleKey);
        }
      }

      if (syncDate) {
        final nextDate = DateTime(
          w.date.year,
          w.date.month,
          w.date.day,
          schedule.scheduledAt.hour,
          schedule.scheduledAt.minute,
        );
        if (nextDate != schedule.scheduledAt) {
          schedule.scheduledAt = nextDate;
          changed = true;
          if (schedule.reminderEnabled && !schedule.isCompleted) {
            await WorkoutReminderService.instance.cancelReminder(scheduleKey);
            await WorkoutReminderService.instance.scheduleReminder(
              scheduleKey: scheduleKey,
              scheduledAt: nextDate,
              title: 'Workout reminder',
              body: '$title - ${_formatScheduleDateTime(nextDate)}',
            );
          }
        }
      }

      if (changed) {
        await schedule.save();
      }
    }
  }

  Future<void> _editHeader() async {
    final s = AppLocalizations.of(context);
    final date = workout.date;
    final titleCtrl = TextEditingController(text: workout.title);
    final notesCtrl = TextEditingController(text: workout.notes);

    final newDate =
        await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        ) ??
        date;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.editHeaderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: s.titleOptional),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: s.notesLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.close)),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(s.save)),
        ],
      ),
    );

    if (!mounted) return;
    await _saveHeader(newDate, titleCtrl.text.trim(), notesCtrl.text.trim());
  }

  Future<void> _addSet() async {
    final s = AppLocalizations.of(context);
    final last = _lastSet();
    final nextNo = (last?.setNumber ?? 0) + 1;

    final initial = SetEntry(
      workoutKey: widget.workoutKey,
      exercise: '',
      setNumber: nextNo,
      reps: 0,
      weightKg: 0,
      rpe: null,
      notes: '',
      isTimeBased: false,
      seconds: null,
      isCompleted: false,
    );

    final res = await showModalBottomSheet<SetEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SetForm(initial: initial, startBlank: true),
      ),
    );

    if (!mounted || res == null) return;

    if (res.isSuperset) {
      final partner = await showModalBottomSheet<SetEntry>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _SetForm(
            initial: SetEntry(
              workoutKey: widget.workoutKey,
              exercise: '',
              setNumber: res.setNumber + 1,
              reps: res.reps,
              weightKg: res.weightKg,
              rpe: res.rpe,
              notes: '',
              isTimeBased: res.isTimeBased,
              seconds: res.seconds,
              isCompleted: false,
              isSuperset: true,
            ),
            startBlank: true,
          ),
        ),
      );

      if (!mounted) return;

      if (partner != null) {
        final newKeys = <int>[];
        for (final se in [res..isSuperset = true, partner..isSuperset = true]) {
          await _maybeAddExerciseToLibrary(se.exercise);
          final key = await sbox.add(se);
          newKeys.add(key);
        }
        await _recomputeTotals();
        if (!mounted) return;
        _maybeAutoStartRest(setKey: newKeys.last);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.setAdded} (SS)'),
            action: SnackBarAction(
              label: s.undo,
              onPressed: () async {
                for (final k in newKeys) {
                  await sbox.delete(k);
                }
                await _recomputeTotals();
              },
            ),
          ),
        );
        return;
      } else {
        res.isSuperset = false;
      }
    }

    await _maybeAddExerciseToLibrary(res.exercise);
    final int newKey = await sbox.add(res);
    final newSet = sbox.get(newKey);
    if (newSet != null) await _syncSupersetPartner(newSet);
    await _recomputeTotals();
    if (!mounted) return;
    _maybeAutoStartRest(setKey: newKey);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.setAdded),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await sbox.delete(newKey);
            await _recomputeTotals();
          },
        ),
      ),
    );
  }

  Future<void> _duplicateLastSet() async {
    final last = _lastSet();
    if (last == null) {
      await _addSet();
      return;
    }
    if (last.isSuperset) {
      await _duplicateGroup(_groupForEntry(last));
    } else {
      await _insertDuplicateAfter(last);
    }
  }

  Future<void> _editSet(SetEntry set) async {
    final wasSuperset = set.isSuperset;
    final res = await showModalBottomSheet<SetEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SetForm(initial: set),
      ),
    );

    if (!mounted) return;

    if (res != null) {
      await _maybeAddExerciseToLibrary(res.exercise);
      set
        ..exercise = res.exercise
        ..setNumber = res.setNumber
        ..reps = res.reps
        ..weightKg = res.weightKg
        ..rpe = res.rpe
        ..notes = res.notes
        ..isTimeBased = res.isTimeBased
        ..seconds = res.seconds
        ..isSuperset = res.isSuperset;
      await set.save();
      await _syncSupersetPartner(set, wasSuperset: wasSuperset);
      await _recomputeTotals();
      HapticFeedback.mediumImpact();
      _maybeAutoStartRest(setKey: set.key);
    }
  }

  Future<void> _deleteSet(SetEntry sEntry) async {
    final group = _groupForEntry(sEntry);
    if (group.entries.length > 1) {
      await _deleteGroup(group);
      return;
    }
    final s = AppLocalizations.of(context);
    final removedNumber = sEntry.setNumber;
    await sEntry.delete();
    await _shiftSetNumbers(startingFrom: removedNumber, delta: -1);
    await _recomputeTotals();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.setDeleted),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await _shiftSetNumbers(
              startingFrom: removedNumber,
              delta: 1,
              inclusive: true,
            );
            final restored = SetEntry(
              workoutKey: sEntry.workoutKey,
              exercise: sEntry.exercise,
              setNumber: removedNumber,
              reps: sEntry.reps,
              weightKg: sEntry.weightKg,
              rpe: sEntry.rpe,
              notes: sEntry.notes,
              isTimeBased: sEntry.isTimeBased,
              seconds: sEntry.seconds,
              isCompleted: sEntry.isCompleted,
            );
            await sbox.add(restored);
            await _recomputeTotals();
          },
        ),
      ),
    );
  }

  Future<void> _deleteGroup(_SetGroup group) async {
    final s = AppLocalizations.of(context);
    final removedNumber = group.entries
        .map((e) => e.setNumber)
        .reduce((a, b) => a < b ? a : b);
    final count = group.entries.length;
    final backups = group.entries
        .map(
          (e) => SetEntry(
            workoutKey: e.workoutKey,
            exercise: e.exercise,
            setNumber: e.setNumber,
            reps: e.reps,
            weightKg: e.weightKg,
            rpe: e.rpe,
            notes: e.notes,
            isTimeBased: e.isTimeBased,
            seconds: e.seconds,
            isCompleted: e.isCompleted,
            isSuperset: e.isSuperset,
          ),
        )
        .toList();

    for (final e in group.entries) {
      await e.delete();
    }
    await _shiftSetNumbers(startingFrom: removedNumber, delta: -count);
    await _recomputeTotals();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.setDeleted),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await _shiftSetNumbers(
              startingFrom: removedNumber,
              delta: count,
              inclusive: true,
            );
            for (final e in backups) {
              await sbox.add(
                SetEntry(
                  workoutKey: e.workoutKey,
                  exercise: e.exercise,
                  setNumber: e.setNumber,
                  reps: e.reps,
                  weightKg: e.weightKg,
                  rpe: e.rpe,
                  notes: e.notes,
                  isTimeBased: e.isTimeBased,
                  seconds: e.seconds,
                  isCompleted: e.isCompleted,
                  isSuperset: e.isSuperset,
                ),
              );
            }
            await _recomputeTotals();
          },
        ),
      ),
    );
  }

  Future<String?> _pickPdfExportAction() async {
    final s = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                s.exportSharePdf,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(s.savePdfToDevice),
              onTap: () => Navigator.pop(ctx, 'download'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdfWithChoice() async {
    final s = AppLocalizations.of(context);
    final sets = _setsForWorkout();
    if (sets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.noSetsToExport)));
      return;
    }

    try {
      final action = await _pickPdfExportAction();
      if (action == null) return;
      if (action == 'share') {
        await shareWorkoutPdf(workout, sets);
      } else if (action == 'download') {
        final location = await saveWorkoutPdfToDevice(workout, sets);
        if (!mounted) return;
        final message = location.isEmpty
            ? s.savedToDevice
            : '${s.savedToDevice}: $location';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.exportError(e.toString()))));
    }
  }

  List<PopupMenuEntry<String>> _buildActionMenuItems(AppLocalizations s) {
    return [
      PopupMenuItem(
        value: 'export_pdf',
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf),
          title: Text(s.exportSharePdf),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'apply_template',
        child: ListTile(
          leading: const Icon(Icons.file_open),
          title: Text(s.applyTemplate),
        ),
      ),
      PopupMenuItem(
        value: 'save_template',
        child: ListTile(
          leading: const Icon(Icons.bookmark_add),
          title: Text(s.saveAsTemplate),
        ),
      ),
    ];
  }

  Future<void> _handleActionMenu(String value) async {
    switch (value) {
      case 'export_pdf':
        await _exportPdfWithChoice();
        break;
      case 'apply_template':
        await _applyTemplate();
        break;
      case 'save_template':
        await _saveAsTemplate();
        break;
    }
  }

  Future<void> _applyTemplate() async {
    final s = AppLocalizations.of(context);
    final templates = tbox.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (templates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.noTemplatesYet)));
      return;
    }

    final picked = await showModalBottomSheet<WorkoutTemplate>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.applyTemplate,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final t = templates[i];
                    final subtitle =
                        '${s.setsCount}: ${t.sets.length}'
                        '${t.notes.trim().isEmpty ? '' : ' - ${t.notes.trim()}'}';
                    return ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(t.name),
                      subtitle: Text(subtitle),
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;

    final existing = _setsForWorkout();
    for (final set in existing) {
      await set.delete();
    }

    for (var i = 0; i < picked.sets.length; i++) {
      final ts = picked.sets[i];
      await _maybeAddExerciseToLibrary(ts.exercise);
      await sbox.add(
        SetEntry(
          workoutKey: widget.workoutKey,
          exercise: ts.exercise,
          setNumber: i + 1,
          reps: ts.reps,
          weightKg: ts.weightKg,
          rpe: ts.rpe,
          notes: ts.notes,
          isTimeBased: ts.isTimeBased,
          seconds: ts.seconds,
          isCompleted: false,
          isSuperset: ts.isSuperset,
        ),
      );
    }

    await _recomputeTotals();
  }

  Future<void> _saveAsTemplate() async {
    final s = AppLocalizations.of(context);
    final sets = _setsForWorkout();
    if (sets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.workoutHasNoSetsForTemplate)));
      return;
    }
    if (!mounted) return;

    final d = workout.date;
    final defaultName = workout.title.isNotEmpty
        ? workout.title
        : 'Template ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';

    final nameCtrl = TextEditingController(text: defaultName);
    final notesCtrl = TextEditingController(text: workout.notes);
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.saveAsTemplate),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: s.templateName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: s.notesOptional),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(s.save),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final name = nameCtrl.text.trim().isEmpty
        ? defaultName
        : nameCtrl.text.trim();
    final tpl = WorkoutTemplate(
      name: name,
      notes: notesCtrl.text.trim(),
      sets: [
        for (final set in sets)
          TemplateSet(
            exercise: set.exercise,
            setNumber: set.setNumber,
            reps: set.reps,
            weightKg: set.weightKg,
            rpe: set.rpe,
            notes: set.notes,
            isTimeBased: set.isTimeBased,
            seconds: set.seconds,
            isSuperset: set.isSuperset,
          ),
      ],
    );

    await tbox.add(tpl);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.templateCreated)));
  }

  Future<void> _completeWorkout() async {
    final sets = _setsForWorkout();
    if (sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one set before completing.'),
        ),
      );
      return;
    }
    final w = workout..isCompleted = true;
    await w.save();
    await _syncLinkedSchedulesFromWorkout(syncCompletion: true);
    if (!mounted) return;
    setState(() => _isCompleted = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Workout marked complete.')));
  }

  Future<void> _reopenWorkout() async {
    final w = workout..isCompleted = false;
    await w.save();
    await _syncLinkedSchedulesFromWorkout(syncCompletion: true);
    if (!mounted) return;
    setState(() => _isCompleted = false);
  }

  bool _autoProgressionEnabled() {
    return (settings.get('autoProgressionEnabled') as bool?) ?? false;
  }

  double _plateIncrement() {
    final inc = (settings.get('plateIncrement') as num?)?.toDouble() ?? 2.5;
    return inc > 0 ? inc : 2.5;
  }

  double _customWeightIncrease() {
    final inc =
        (settings.get('weightIncreaseKg') as num?)?.toDouble() ??
        _plateIncrement();
    return inc > 0 ? inc : _plateIncrement();
  }

  bool _useCustomIncrease() {
    return (settings.get('useCustomIncrease') as bool?) ?? false;
  }

  Map<String, double> _parseCategoryIncrements(dynamic raw) {
    if (raw is! Map) return {};
    final parsed = <String, double>{};
    raw.forEach((key, value) {
      if (key is! String || value is! num) return;
      parsed[key] = value.toDouble();
    });
    return parsed;
  }

  Map<String, String> _exerciseCategoryMap() {
    final map = <String, String>{};
    final ebox = Hive.box<Exercise>('exercises');
    for (final exercise in ebox.values) {
      final name = exercise.name.trim().toLowerCase();
      final category = exercise.category.trim();
      if (name.isEmpty || category.isEmpty) continue;
      map[name] = category;
    }
    return map;
  }

  double _roundToIncrement(double value) {
    final step = _plateIncrement();
    if (step <= 0) return double.parse(value.toStringAsFixed(2));
    final steps = (value / step).round();
    final rounded = steps * step;
    final clamped = rounded < 0 ? 0.0 : rounded;
    return double.parse(clamped.toStringAsFixed(2));
  }

  double _incrementForExercise(
    String exercise,
    Map<String, double> categoryIncrements,
    Map<String, String> categoryByExercise,
  ) {
    final exerciseKey = exercise.trim().toLowerCase();
    final category = categoryByExercise[exerciseKey];
    if (category != null && categoryIncrements.containsKey(category)) {
      final value = categoryIncrements[category]!;
      if (value > 0) return value;
    }

    if (_useCustomIncrease()) {
      return _customWeightIncrease();
    }
    return _plateIncrement();
  }

  Map<int, _ProgressSuggestion> _buildProgressSuggestions(List<SetEntry> sets) {
    if (!_autoProgressionEnabled()) return const {};

    final categoryIncrements = _parseCategoryIncrements(
      settings.get('categoryIncrements'),
    );
    final categoryByExercise = _exerciseCategoryMap();
    final workoutDateByKey = <int, DateTime>{};
    for (final w in wbox.values) {
      final key = w.key;
      if (key is int) {
        workoutDateByKey[key] = w.date;
      }
    }

    final historicalByExercise = <String, List<SetEntry>>{};
    for (final entry in sbox.values) {
      if (entry.workoutKey == widget.workoutKey) continue;
      if (entry.isTimeBased) continue;
      final exerciseKey = entry.exercise.trim().toLowerCase();
      if (exerciseKey.isEmpty) continue;
      final bucket = historicalByExercise.putIfAbsent(exerciseKey, () => []);
      bucket.add(entry);
    }

    for (final list in historicalByExercise.values) {
      list.sort((a, b) {
        final dateA =
            workoutDateByKey[a.workoutKey] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            workoutDateByKey[b.workoutKey] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final byDate = dateB.compareTo(dateA);
        if (byDate != 0) return byDate;
        return b.setNumber.compareTo(a.setNumber);
      });
    }

    final suggestions = <int, _ProgressSuggestion>{};
    for (final set in sets) {
      if (set.isTimeBased) continue;
      if (set.isCompleted) continue;
      final setKey = set.key;
      if (setKey is! int) continue;
      final exerciseKey = set.exercise.trim().toLowerCase();
      if (exerciseKey.isEmpty) continue;

      final recent = (historicalByExercise[exerciseKey] ?? const <SetEntry>[])
          .take(3)
          .toList();
      if (recent.isEmpty) continue;

      final last = recent.first;
      final increment = _incrementForExercise(
        set.exercise,
        categoryIncrements,
        categoryByExercise,
      );
      final targetReps = set.reps <= 0 ? 1 : set.reps;
      var suggestedReps = targetReps;
      var suggestedWeight = set.weightKg;
      var rationale = 'Keep current target.';
      var label = 'keep';

      final missesOrHighRpe = recent
          .where(
            (h) => h.reps < targetReps || (h.rpe != null && h.rpe! >= 9.5),
          )
          .length;
      final lastComfortable =
          last.reps >= targetReps && (last.rpe == null || last.rpe! <= 8.5);
      final anchorWeight = _roundToIncrement(last.weightKg);

      if (missesOrHighRpe >= 2) {
        var targetWeight = _roundToIncrement(anchorWeight * 0.95);
        if ((anchorWeight - targetWeight).abs() < 0.001 &&
            anchorWeight > 0) {
          targetWeight = _roundToIncrement(anchorWeight - increment);
        }
        // In deload mode, never suggest adding load back.
        suggestedWeight = set.weightKg <= targetWeight
            ? _roundToIncrement(set.weightKg)
            : targetWeight;
        rationale = 'Recent sessions show misses/high RPE. Suggest deload.';
        label = 'deload';
      } else if (lastComfortable) {
        final targetWeight = _roundToIncrement(anchorWeight + increment);
        // Do not stack increases if current set is already at/above target.
        suggestedWeight = set.weightKg >= targetWeight
            ? _roundToIncrement(set.weightKg)
            : targetWeight;
        rationale = 'Last session hit target comfortably. Suggest increase.';
        label = 'increase';
      } else if (last.rpe != null && last.rpe! >= 9.0) {
        final targetWeight = _roundToIncrement(anchorWeight - increment);
        // In reduce mode, never suggest increasing load.
        suggestedWeight = set.weightKg <= targetWeight
            ? _roundToIncrement(set.weightKg)
            : targetWeight;
        rationale = 'Last session effort was high. Suggest lighter load.';
        label = 'reduce';
      } else if (last.reps < targetReps) {
        final targetWeight = _roundToIncrement(anchorWeight);
        // Repeat mode should not suggest going heavier than last comparable load.
        suggestedWeight = set.weightKg <= targetWeight
            ? _roundToIncrement(set.weightKg)
            : targetWeight;
        rationale = 'Repeat the target before increasing load.';
        label = 'repeat';
      }

      if (suggestedWeight < 0) suggestedWeight = 0;
      suggestions[setKey] = _ProgressSuggestion(
        suggestedReps: suggestedReps,
        suggestedWeightKg: suggestedWeight,
        rationale: rationale,
        label: label,
      );
    }

    return suggestions;
  }

  Future<void> _applyAllSuggestions(
    List<SetEntry> sets,
    Map<int, _ProgressSuggestion> suggestions,
  ) async {
    var applied = 0;
    for (final set in sets) {
      if (set.isTimeBased) continue;
      if (set.isCompleted) continue;
      final setKey = set.key;
      if (setKey is! int) continue;
      final suggestion = suggestions[setKey];
      if (suggestion == null || !suggestion.differsFrom(set)) continue;
      set
        ..reps = suggestion.suggestedReps
        ..weightKg = suggestion.suggestedWeightKg;
      await set.save();
      applied++;
    }
    await _recomputeTotals();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied == 0
              ? 'No suggestion changes to apply.'
              : 'Applied suggestions to $applied set${applied == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final w = workout;
    if (w.kind == 'cardio') {
      return CardioWorkoutDetailPage(workoutKey: widget.workoutKey);
    }
    final sets = _setsForWorkout();
    final progressSuggestions = _buildProgressSuggestions(sets);
    _lastProgressSuggestions = progressSuggestions;
    final setByKey = <int, SetEntry>{
      for (final set in sets)
        if (set.key is int) set.key as int: set,
    };
    final suggestionChangeCount = progressSuggestions.entries
        .where((entry) {
          final current = setByKey[entry.key];
          return current != null && entry.value.differsFrom(current);
        })
        .length;
    final prFlags = _computeSetPrFlags(sets);
    final totalPrs = prFlags.values.where((f) => f.any).length;
    final completed = _isCompleted;
    final listBottomPadding = completed ? 16.0 : (_fabSpace * 2);
    final groups = _cachedGroups ?? _groupSets(sets);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(s.workout),
        actions: [
          IconButton(
            tooltip: s.editTitleNotes,
            onPressed: _editHeader,
            icon: const Icon(Icons.edit_note),
          ),
          IconButton(
            tooltip: s.repeatLastSet,
            onPressed: _duplicateLastSet,
            icon: const Icon(Icons.copy_all),
          ),
          PopupMenuButton<String>(
            onSelected: _handleActionMenu,
            itemBuilder: (_) => _buildActionMenuItems(s),
          ),
        ],
      ),
      floatingActionButton: completed
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_addset',
              onPressed: _addSet,
              icon: const Icon(Icons.add),
              label: Text(s.addSet),
            ),
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _WorkoutSummary(
                    date: workout.date,
                    title: workout.title,
                    totalSets: workout.totalSets,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      if (completed)
                        Chip(
                          avatar: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: const Text('Completed'),
                        ),
                      const Spacer(),
                      if (!completed)
                        FilledButton.icon(
                          onPressed: () async {
                            await _completeWorkout();
                            await _recomputeTotals();
                          },
                          icon: const Icon(Icons.flag),
                          label: const Text('Complete workout'),
                        )
                      else
                        TextButton.icon(
                          onPressed: _reopenWorkout,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reopen'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (totalPrs > 0)
                        Chip(
                          avatar: const Icon(
                            Icons.emoji_events_outlined,
                            size: 18,
                          ),
                          label: Text(
                            '$totalPrs PR${totalPrs == 1 ? '' : 's'}',
                          ),
                        ),
                    ],
                  ),
                ),
                if (_showProgressionSuggestionUi &&
                    !completed &&
                    suggestionChangeCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Progression suggestions',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    suggestionChangeCount == 0
                                        ? 'No load/rep changes needed right now.'
                                        : '$suggestionChangeCount set${suggestionChangeCount == 1 ? '' : 's'} can be updated based on recent performance.',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (suggestionChangeCount > 0)
                              FilledButton(
                                onPressed: () => _applyAllSuggestions(
                                  sets,
                                  progressSuggestions,
                                ),
                                child: const Text('Apply all'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 0),
                Expanded(
                  child: groups.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(bottom: listBottomPadding),
                          children: [
                            const SizedBox(height: 24),
                            Center(child: Text(s.noSetsYet)),
                          ],
                        )
                      : ReorderableListView.builder(
                          padding: EdgeInsets.only(bottom: listBottomPadding),
                          buildDefaultDragHandles: false,
                          itemCount: groups.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final newGroups = List<_SetGroup>.from(groups);
                            final moved = newGroups.removeAt(oldIndex);
                            newGroups.insert(newIndex, moved);
                            final flattened = newGroups
                                .expand((g) => g.entries)
                                .toList();
                            setState(() {
                              _cachedGroups = newGroups;
                            });
                            await _applyNewOrder(flattened);
                            if (!mounted) return;
                            setState(() {
                              _cachedGroups = null;
                            });
                          },
                          itemBuilder: (_, i) {
                            final group = groups[i];
                            final entries = group.entries;
                            final completedGroup = entries.every(
                              (e) => e.isCompleted,
                            );
                            return Dismissible(
                              key: ValueKey(
                                'group-${entries.map((e) => e.key).join('-')}',
                              ),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (_) async {
                                final target = !completedGroup;
                                for (final e in entries) {
                                  e.isCompleted = target;
                                  await e.save();
                                }
                                await _recomputeTotals();
                                if (!mounted) return false;
                                setState(() {});
                                if (target && entries.isNotEmpty) {
                                  _maybeAutoStartRest(setKey: entries.last.key);
                                }
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                color: Colors.green.withValues(alpha: 0.12),
                                child: Row(
                                  children: [
                                    Icon(
                                      completedGroup
                                          ? Icons.refresh
                                          : Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      completedGroup
                                          ? 'Mark active'
                                          : 'Complete',
                                    ),
                                  ],
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: group.isSuperset
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.25),
                                        ),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.03),
                                      )
                                    : null,
                                child: Column(
                                  children: [
                                    if (group.isSuperset)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          4,
                                        ),
                                        child: Row(
                                          children: const [
                                            Chip(
                                              label: Text('Superset'),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ...entries.map((se) {
                                      final isFirst = identical(
                                        se,
                                        entries.first,
                                      );
                                      final isLast = identical(
                                        se,
                                        entries.last,
                                      );
                                      final isEditing = _isInlineEditing(se);
                                      final completedSet = se.isCompleted;
                                      final pr = prFlags[se.key] ?? _PrFlags();
                                      final suggestion = se.key is int
                                          ? progressSuggestions[se.key as int]
                                          : null;
                                      String details;
                                      if (se.isTimeBased) {
                                        final secs = se.seconds ?? 0;
                                        final mm = (secs ~/ 60)
                                            .toString()
                                            .padLeft(2, '0');
                                        final ss = (secs % 60)
                                            .toString()
                                            .padLeft(2, '0');
                                        final add = (se.weightKg > 0)
                                            ? '  +${se.weightKg.toStringAsFixed(1)} kg'
                                            : '';
                                        details = '$mm:$ss$add';
                                      } else {
                                        details =
                                            '${se.reps} reps @ ${se.weightKg.toStringAsFixed(1)} kg';
                                      }
                                      final extras =
                                          '${se.rpe != null ? '  RPE ${se.rpe}' : ''}'
                                          '${se.notes.isNotEmpty ? '\n${se.notes}' : ''}';
                                      final titleStyle = completedSet
                                          ? Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.copyWith(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                            )
                                          : null;
                                      final subtitleStyle = completedSet
                                          ? TextStyle(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.7),
                                            )
                                          : null;
                                      return Column(
                                        children: [
                                          ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 6,
                                                ),
                                            leading: Icon(
                                              completedSet
                                                  ? Icons.check_circle
                                                  : Icons.check_circle_outline,
                                              color: completedSet
                                                  ? Colors.green
                                                  : null,
                                              size: 20,
                                            ),
                                            title: Text(
                                              '${se.exercise}  -  ${s.setNumberShort} ${se.setNumber}',
                                              style: titleStyle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$details$extras',
                                                  style: subtitleStyle,
                                                  softWrap: true,
                                                ),
                                                if (_showProgressionSuggestionUi &&
                                                    suggestion != null &&
                                                    suggestion.differsFrom(se))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      suggestion
                                                          .summaryForSet(se),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.primary,
                                                          ),
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                if (pr.any)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      children: [
                                                        if (pr.weight)
                                                          _prChip(
                                                            label: 'Weight PR',
                                                          ),
                                                        if (pr.reps)
                                                          _prChip(
                                                            label: 'Reps PR',
                                                          ),
                                                        if (pr.volume)
                                                          _prChip(
                                                            label: 'Volume PR',
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: isEditing
                                                      ? s.close
                                                      : 'Quick edit',
                                                  icon: Icon(
                                                    isEditing
                                                        ? Icons.close
                                                        : Icons.edit,
                                                    size: 20,
                                                  ),
                                                  onPressed: () => isEditing
                                                      ? _closeInlineEditor()
                                                      : _openInlineEditor(se),
                                                ),
                                                PopupMenuButton<String>(
                                                  tooltip: 'More',
                                                  icon: const Icon(
                                                    Icons.more_vert,
                                                    size: 20,
                                                  ),
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'history',
                                                      child: ListTile(
                                                        leading: const Icon(
                                                          Icons.history,
                                                        ),
                                                        title: Text(s.history),
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'dup',
                                                      child: ListTile(
                                                        leading: const Icon(
                                                          Icons.copy,
                                                        ),
                                                        title: Text(
                                                          s.duplicateThisSet,
                                                        ),
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'superset',
                                                      child: ListTile(
                                                        leading: const Icon(
                                                          Icons.all_inclusive,
                                                        ),
                                                        title: Text(
                                                          se.isSuperset
                                                              ? 'Remove superset'
                                                              : 'Make superset',
                                                        ),
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'del',
                                                      child: ListTile(
                                                        leading: const Icon(
                                                          Icons.delete_outline,
                                                        ),
                                                        title: Text(s.delete),
                                                      ),
                                                    ),
                                                  ],
                                                  onSelected: (v) async {
                                                    if (v == 'history') {
                                                      final name = se.exercise
                                                          .trim();
                                                      if (name.isEmpty) return;
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              ExerciseHistoryPage(
                                                                exerciseName:
                                                                    name,
                                                              ),
                                                        ),
                                                      );
                                                    } else if (v == 'dup') {
                                                      await _duplicateGroup(
                                                        group,
                                                      );
                                                    } else if (v ==
                                                        'superset') {
                                                      await _toggleSuperset(se);
                                                    } else if (v == 'del') {
                                                      await _deleteSet(se);
                                                    }
                                                  },
                                                ),
                                                if (isFirst)
                                                  ReorderableDragStartListener(
                                                    index: i,
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                          ),
                                                      child: Icon(
                                                        Icons.drag_indicator,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const SizedBox(width: 24),
                                              ],
                                            ),
                                            onTap: () => _openInlineEditor(se),
                                            onLongPress: () => _editSet(se),
                                          ),
                                          if (isEditing) _inlineEditor(se),
                                          if (!isLast) const Divider(height: 0),
                                        ],
                                      );
                                    }),
                                    const Divider(height: 0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<int, _PrFlags> _computeSetPrFlags(List<SetEntry> sets) {
    final map = <int, _PrFlags>{};
    for (final s in sets) {
      map[s.key as int] = const _PrFlags();
    }
    return map;
  }

  // Groups consecutive superset sets so they render as a single block.
  // Keeps non-superset sets as single-entry groups.
  List<_SetGroup> _groupSets(List<SetEntry> sets) {
    final groups = <_SetGroup>[];
    var i = 0;
    while (i < sets.length) {
      final current = sets[i];
      if (current.isSuperset) {
        final cluster = <SetEntry>[current];
        var j = i + 1;
        while (j < sets.length && sets[j].isSuperset) {
          cluster.add(sets[j]);
          if (cluster.length >= 2) break; // keep pairs together
          j++;
        }
        groups.add(_SetGroup(cluster));
        i += cluster.length;
      } else {
        groups.add(_SetGroup([current]));
        i++;
      }
    }
    return groups;
  }

  Widget _prChip({required String label, Color? color}) {
    return Chip(
      label: Text(label),
      backgroundColor: color?.withValues(alpha: 0.12),
      avatar: Icon(
        Icons.emoji_events_outlined,
        size: 18,
        color: color ?? Colors.orange,
      ),
    );
  }

  Widget _inlineEditor(SetEntry se) {
    final s = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _inlineExercise,
            decoration: InputDecoration(labelText: s.exercise),
          ),
          if (_inlinePrefilledFromSuggestion) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Auto-suggested values prefilled',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_inlineTimeBased) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inlineMinutes,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.minutes),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _inlineSeconds,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.seconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inlineWeight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: s.weightKg),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inlineReps,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.reps),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _inlineWeight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: s.weightKg),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _inlineRpe,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: s.rpeOptional),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _inlineNotes,
            maxLines: 2,
            decoration: InputDecoration(labelText: s.notes),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _closeInlineEditor, child: Text(s.close)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _applyInlineEdit(se),
                icon: const Icon(Icons.check),
                label: Text(s.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutSummary extends StatelessWidget {
  const _WorkoutSummary({
    required this.date,
    required this.title,
    required this.totalSets,
  });

  final DateTime date;
  final String title;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.isEmpty ? s.workout : title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${s.date}: $dateStr  •  ${s.setsCount}: $totalSets',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PrFlags {
  final bool weight;
  final bool reps;
  final bool volume;
  const _PrFlags() : weight = false, reps = false, volume = false;
  bool get any => weight || reps || volume;
}

class _ProgressSuggestion {
  final int suggestedReps;
  final double suggestedWeightKg;
  final String rationale;
  final String label;

  const _ProgressSuggestion({
    required this.suggestedReps,
    required this.suggestedWeightKg,
    required this.rationale,
    required this.label,
  });

  bool differsFrom(SetEntry set) {
    if (set.isTimeBased) return false;
    return set.reps != suggestedReps ||
        (set.weightKg - suggestedWeightKg).abs() > 0.001;
  }

  String summaryForSet(SetEntry set) {
    final target = '$suggestedReps reps @ ${suggestedWeightKg.toStringAsFixed(1)} kg';
    if (!differsFrom(set)) {
      return 'Suggestion ($label): keep $target. $rationale';
    }
    return 'Suggestion ($label): $target. $rationale';
  }
}

class _SetGroup {
  final List<SetEntry> entries;
  _SetGroup(this.entries);
  bool get isSuperset => entries.any((e) => e.isSuperset);
}

class _SetForm extends StatefulWidget {
  final SetEntry initial;
  final bool startBlank;
  const _SetForm({required this.initial, this.startBlank = false});

  @override
  State<_SetForm> createState() => _SetFormState();
}

class _SetFormState extends State<_SetForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _exercise = TextEditingController();
  final TextEditingController _setNo = TextEditingController();
  final TextEditingController _reps = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _seconds = TextEditingController();
  final TextEditingController _rpe = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  _EntryMode mode = _EntryMode.reps;
  bool _isSuperset = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _exercise.text = init.exercise;
    _setNo.text = init.setNumber.toString();
    _reps.text = init.reps.toString();
    _weight.text = init.weightKg.toString();
    _minutes.text = ((init.seconds ?? 0) ~/ 60).toString();
    _seconds.text = ((init.seconds ?? 0) % 60).toString();
    _rpe.text = init.rpe?.toString() ?? '';
    _notes.text = init.notes;
    mode = init.isTimeBased ? _EntryMode.time : _EntryMode.reps;
    _isSuperset = init.isSuperset;
    if (widget.startBlank) {
      _exercise.clear();
      _notes.clear();
      _rpe.clear();
      _isSuperset = init.isSuperset;
    }
  }

  @override
  void dispose() {
    _exercise.dispose();
    _setNo.dispose();
    _reps.dispose();
    _weight.dispose();
    _minutes.dispose();
    _seconds.dispose();
    _rpe.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final ebox = Hive.box<Exercise>('exercises');
    final allNames = ebox.values.map((e) => e.name).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final bottomPad = mq.viewPadding.bottom;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + bottomInset + bottomPad,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue te) {
                    final q = te.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<String>.empty();
                    return allNames.where((n) => n.toLowerCase().contains(q));
                  },
                  fieldViewBuilder:
                      (context, textCtrl, focusNode, onFieldSubmitted) {
                        textCtrl.text = _exercise.text;
                        textCtrl.selection = TextSelection.collapsed(
                          offset: textCtrl.text.length,
                        );
                        textCtrl.addListener(() {
                          if (textCtrl.text != _exercise.text) {
                            _exercise.text = textCtrl.text;
                            _exercise.selection = textCtrl.selection;
                          }
                        });
                        return TextFormField(
                          controller: textCtrl,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: s.exercise,
                            prefixIcon: const Icon(Icons.fitness_center),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? s.enterExerciseName
                              : null,
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 240,
                            minWidth: 280,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final opt = options.elementAt(index);
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
                    );
                  },
                  onSelected: (val) {
                    _exercise.text = val;
                  },
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _setNo,
                        decoration: InputDecoration(
                          labelText: s.setNumberShort,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return s.invalidSetNumber;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        decoration: InputDecoration(labelText: s.weightKg),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final d = double.tryParse(
                            (v ?? '').replaceAll(',', '.'),
                          );
                          if (d == null || d < 0) return s.invalidWeight;
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ToggleButtons(
                  isSelected: [
                    mode == _EntryMode.reps,
                    mode == _EntryMode.time,
                  ],
                  onPressed: (index) => setState(() {
                    mode = index == 0 ? _EntryMode.reps : _EntryMode.time;
                  }),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(s.reps),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(s.time),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (mode == _EntryMode.reps) ...[
                  TextFormField(
                    controller: _reps,
                    decoration: InputDecoration(labelText: s.reps),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return s.enterReps;
                      return null;
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minutes,
                          decoration: InputDecoration(labelText: s.minutes),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '0') ?? 0;
                            if (n < 0) return s.invalidMinutes;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _seconds,
                          decoration: InputDecoration(labelText: s.seconds),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '0') ?? 0;
                            if (n < 0 || n > 59) return s.invalidSecondsRange;
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                TextFormField(
                  controller: _rpe,
                  decoration: InputDecoration(labelText: s.rpeOptional),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final d = double.tryParse(v.replaceAll(',', '.'));
                    if (d == null || d < 0) return s.invalidRpe;
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: s.notes),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                CheckboxListTile(
                  value: _isSuperset,
                  onChanged: (v) => setState(() => _isSuperset = v ?? false),
                  title: const Text('Part of a superset'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(s.close),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final setNo = int.tryParse(_setNo.text.trim()) ?? 1;
                          final reps = int.tryParse(_reps.text.trim()) ?? 0;
                          final weight =
                              double.tryParse(
                                _weight.text.trim().replaceAll(',', '.'),
                              ) ??
                              0;
                          final rpe = _rpe.text.trim().isEmpty
                              ? null
                              : double.tryParse(
                                  _rpe.text.trim().replaceAll(',', '.'),
                                );
                          final notes = _notes.text.trim();
                          final isTimeBased = mode == _EntryMode.time;
                          final minutes =
                              int.tryParse(_minutes.text.trim()) ?? 0;
                          final seconds =
                              int.tryParse(_seconds.text.trim()) ?? 0;
                          final totalSeconds = (minutes * 60) + seconds;

                          Navigator.of(context).pop(
                            SetEntry(
                              workoutKey: widget.initial.workoutKey,
                              exercise: _exercise.text.trim(),
                              setNumber: setNo,
                              reps: isTimeBased ? 0 : reps,
                              weightKg: weight,
                              rpe: rpe,
                              notes: notes,
                              isTimeBased: isTimeBased,
                              seconds: isTimeBased ? totalSeconds : null,
                              isCompleted: false,
                              isSuperset: _isSuperset,
                            ),
                          );
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
