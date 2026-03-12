import 'dart:typed_data';
import 'dart:io' show File, Platform;

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFile;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/workout_template.dart';
import '../models/cardio_entry.dart';
import '../models/cardio_template.dart';
import '../services/export_service.dart';
import '../services/pro_service.dart';
import 'workout_detail_page.dart';

import '../l10n/l10n.dart';

class WorkoutsListPage extends StatefulWidget {
  const WorkoutsListPage({super.key});

  @override
  State<WorkoutsListPage> createState() => _WorkoutsListPageState();
}

class _WorkoutsListPageState extends State<WorkoutsListPage> {
  late final Box<Workout> wbox;
  late final Box<SetEntry> sbox;
  late final Box<WorkoutTemplate> tbox;
  late final Box<CardioEntry> cbox;
  late final Box<CardioTemplate> ctbox;
  late final Box settings;

  final _searchCtrl = TextEditingController();
  String _kindFilter = 'all'; // all | strength | cardio
  String _statusFilter = 'all'; // all | completed | active
  int _rangeDays = 0; // 0 = all time
  String? _exerciseFilter;

  @override
  void initState() {
    super.initState();
    wbox = Hive.box<Workout>('workouts');
    sbox = Hive.box<SetEntry>('sets');
    tbox = Hive.box<WorkoutTemplate>('templates');
    cbox = Hive.box<CardioEntry>('cardio_entries');
    ctbox = Hive.box<CardioTemplate>('cardio_templates');
    settings = Hive.box('settings');
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  CardioEntry? _cardioEntryForWorkout(int workoutKey) {
    for (final e in cbox.values) {
      if (e.workoutKey == workoutKey) return e;
    }
    return null;
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

  Map<int, Set<String>> _exerciseIndexByWorkout() {
    final map = <int, Set<String>>{};
    for (final set in sbox.values) {
      final name = set.exercise.trim().toLowerCase();
      if (name.isEmpty) continue;
      map.putIfAbsent(set.workoutKey, () => <String>{}).add(name);
    }
    return map;
  }

  List<String> _allExercisesFromIndex(Map<int, Set<String>> exerciseIndex) {
    final unique = <String>{};
    for (final values in exerciseIndex.values) {
      unique.addAll(values);
    }
    final list = unique.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  List<Workout> _applyFilters(
    List<Workout> workouts,
    Map<int, Set<String>> exerciseIndex, {
    String? exerciseFilterValue,
  }) {
    final now = DateTime.now();
    final rangeStart = _rangeDays <= 0
        ? null
        : _startOfDay(now).subtract(Duration(days: _rangeDays - 1));
    final query = _searchCtrl.text.trim().toLowerCase();
    final exerciseFilter = exerciseFilterValue?.trim().toLowerCase();

    return workouts.where((workout) {
      if (_kindFilter != 'all' && workout.kind != _kindFilter) return false;

      if (_statusFilter == 'completed' && !workout.isCompleted) return false;
      if (_statusFilter == 'active' && workout.isCompleted) return false;

      if (rangeStart != null && workout.date.isBefore(rangeStart)) return false;

      final workoutKey = workout.key as int;
      final exercises = exerciseIndex[workoutKey] ?? const <String>{};
      if (exerciseFilter != null &&
          exerciseFilter.isNotEmpty &&
          !exercises.contains(exerciseFilter)) {
        return false;
      }

      if (query.isEmpty) return true;
      final inTitle = workout.title.trim().toLowerCase().contains(query);
      final inNotes = workout.notes.trim().toLowerCase().contains(query);
      final inDate = _d(workout.date).toLowerCase().contains(query);
      final inExercises = exercises.any((name) => name.contains(query));
      return inTitle || inNotes || inDate || inExercises;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _kindFilter = 'all';
      _statusFilter = 'all';
      _rangeDays = 0;
      _exerciseFilter = null;
      _searchCtrl.clear();
    });
  }

  Future<String?> _pickWorkoutKind(BuildContext context) async {
    final s = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.workoutTypeTitle,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.fitness_center_outlined),
                title: Text(s.workoutTypeStrength),
                onTap: () => Navigator.pop(ctx, 'strength'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.directions_run_outlined),
                title: Text(s.workoutTypeCardio),
                onTap: () => Navigator.pop(ctx, 'cardio'),
              ),
              const SizedBox(height: 12),
              Text(s.workoutTypeHint, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Future<_CardioTemplatePickResult?> _pickCardioTemplateBottomSheet(
    BuildContext context,
  ) async {
    final s = AppLocalizations.of(context);
    final templates = ctbox.values.toList();
    return showModalBottomSheet<_CardioTemplatePickResult?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.cardioTemplatePickTitle,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: (templates.isEmpty ? 1 : templates.length + 1),
                    separatorBuilder: (context, index) =>
                        const Divider(height: 0),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.note_add_outlined),
                          title: Text(s.emptyWorkout),
                          subtitle: Text(s.startWithoutTemplate),
                          onTap: () => Navigator.pop(
                            ctx,
                            const _CardioTemplatePickResult.empty(),
                          ),
                        );
                      }
                      final t = templates[i - 1];
                      final duration = _formatDurationShort(t.durationSeconds);
                      final distance = t.distanceKm != null
                          ? '${t.distanceKm!.toStringAsFixed(2)} km'
                          : s.noDistance;
                      return ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(t.name),
                        subtitle: Text('${t.activity} - $duration - $distance'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(
                          ctx,
                          _CardioTemplatePickResult.withTemplate(t),
                        ),
                      );
                    },
                  ),
                ),
                if (templates.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(ctx).dividerColor),
                    ),
                    child: Text(s.emptyTemplateListHint),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(s.cancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyCardioTemplateToWorkout(
    int workoutKey,
    CardioTemplate tpl,
  ) async {
    final entry = CardioEntry(
      workoutKey: workoutKey,
      activity: tpl.activity,
      durationSeconds: tpl.durationSeconds,
      distanceKm: tpl.distanceKm,
      elevationGainM: tpl.elevationGainM,
      inclinePercent: tpl.inclinePercent,
      avgHeartRate: tpl.avgHeartRate,
      maxHeartRate: tpl.maxHeartRate,
      rpe: tpl.rpe,
      calories: tpl.calories,
      zoneSeconds: List<int>.from(tpl.zoneSeconds),
      segments: tpl.segments.map((s) => s.copy()).toList(),
      environment: tpl.environment,
      terrain: tpl.terrain,
      weather: tpl.weather,
      equipment: tpl.equipment,
      mood: tpl.mood,
      energy: tpl.energy,
      notes: tpl.notes,
    );

    await cbox.add(entry);
    final w = wbox.get(workoutKey);
    if (w != null) {
      w.totalSets = entry.segments.length;
      await w.save();
    }
  }

  Future<void> _newWorkout() async {
    final kind = await _pickWorkoutKind(context);
    if (kind == null) return;
    if (!mounted) return;

    _CardioTemplatePickResult? cardioPicked;
    if (kind == 'cardio') {
      cardioPicked = await _pickCardioTemplateBottomSheet(context);
      if (cardioPicked == null) return;
      if (!mounted) return;
    }

    final now = DateTime.now();
    final workout = Workout(
      date: DateTime(now.year, now.month, now.day),
      kind: kind,
    );
    final key = await wbox.add(workout);
    if (cardioPicked?.template != null) {
      await _applyCardioTemplateToWorkout(key, cardioPicked!.template!);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: key)),
    );
  }

  Future<({Uint8List bytes, String name})?> _pickPdfBytes() async {
    if (kIsWeb) {
      final XFile? f = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'pdf', extensions: ['pdf']),
        ],
      );
      if (f == null) return null;
      final bytes = await f.readAsBytes();
      return (bytes: bytes, name: f.name);
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final res = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return null;
      final picked = res.files.single;
      final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
      final name = picked.name;
      return (bytes: bytes, name: name);
    }

    final XFile? f = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'pdf', extensions: ['pdf']),
      ],
    );
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    return (bytes: bytes, name: f.name);
  }

  Future<void> _deleteWorkoutCascade(BuildContext context, Workout w) async {
    final s = AppLocalizations.of(context);
    final wKey = w.key as int;

    final backupWorkout =
        Workout(date: w.date, title: w.title, notes: w.notes, kind: w.kind)
          ..totalSets = w.totalSets
          ..totalReps = w.totalReps
          ..totalVolume = w.totalVolume;

    final backupSets = sbox.values
        .where((e) => e.workoutKey == wKey)
        .map(
          (e) => SetEntry(
            workoutKey: -1,
            exercise: e.exercise,
            setNumber: e.setNumber,
            reps: e.reps,
            weightKg: e.weightKg,
            rpe: e.rpe,
            notes: e.notes,
            isTimeBased: e.isTimeBased,
            seconds: e.seconds,
            isCompleted: e.isCompleted,
          ),
        )
        .toList();

    final backupCardio = cbox.values
        .where((c) => c.workoutKey == wKey)
        .map((c) => c.copyWith(workoutKey: -1))
        .toList();

    for (final e in sbox.values.where((e) => e.workoutKey == wKey).toList()) {
      await e.delete();
    }
    for (final c in cbox.values.where((c) => c.workoutKey == wKey).toList()) {
      await c.delete();
    }
    await w.delete();

    if (!context.mounted) return;
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
            for (final e in backupSets) {
              await sbox.add(
                SetEntry(
                  workoutKey: newWKey,
                  exercise: e.exercise,
                  setNumber: e.setNumber,
                  reps: e.reps,
                  weightKg: e.weightKg,
                  rpe: e.rpe,
                  notes: e.notes,
                  isTimeBased: e.isTimeBased,
                  seconds: e.seconds,
                  isCompleted: e.isCompleted,
                ),
              );
            }
            for (final c in backupCardio) {
              await cbox.add(c.copyWith(workoutKey: newWKey));
            }
          },
        ),
      ),
    );
  }

  Future<void> _importFromPdf() async {
    final s = AppLocalizations.of(context);

    try {
      final picked = await _pickPdfBytes();
      if (picked == null) return;
      if (!mounted) return;

      final bytes = picked.bytes;
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.importFailed('no-bytes'))));
        return;
      }

      final parsed = await importPayloadFromPdfBytes(bytes);
      if (!mounted) return;
      if (parsed == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.pdfNoEmbeddedData)));
        return;
      }

      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(s.importFromPdfTitle),
          content: Text(s.newWorkoutPickTemplate),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 'cancel'),
              child: Text(s.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(c, 'template'),
              child: Text(s.importAsTemplate),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'workout'),
              child: Text(s.importAsWorkout),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;
      if (!mounted) return;

      if (choice == 'workout') {
        final w = parsed.workout;
        final newWKey = await wbox.add(
          Workout(date: w.date, title: w.title, notes: w.notes, kind: w.kind)
            ..totalSets = parsed.sets.length
            ..totalReps = parsed.sets
                .where((e) => !e.isTimeBased)
                .fold(0, (sum, e) => sum + e.reps)
            ..totalVolume = parsed.sets
                .where((e) => !e.isTimeBased)
                .fold(0.0, (sum, e) => sum + e.reps * e.weightKg),
        );

        for (final se in parsed.sets) {
          await sbox.add(
            SetEntry(
              workoutKey: newWKey,
              exercise: se.exercise,
              setNumber: se.setNumber,
              reps: se.reps,
              weightKg: se.weightKg,
              rpe: se.rpe,
              notes: se.notes,
              isTimeBased: se.isTimeBased,
              seconds: se.seconds,
              isCompleted: se.isCompleted,
            ),
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.importSuccessWorkout)));
      } else if (choice == 'template') {
        if (!await ProService.ensureTemplateCapacity(
          context,
          settings,
          tbox.length,
        )) {
          return;
        }
        if (!mounted) return;
        final w = parsed.workout;
        final tmplName = (w.title.isNotEmpty)
            ? w.title
            : 'Workout ${_d(w.date)}';

        final sets = [
          for (final se in parsed.sets)
            TemplateSet(
              exercise: se.exercise,
              setNumber: se.setNumber,
              reps: se.reps,
              weightKg: se.weightKg,
              rpe: se.rpe,
              notes: se.notes,
              isTimeBased: se.isTimeBased,
              seconds: se.seconds,
            ),
        ];

        await tbox.add(
          WorkoutTemplate(name: tmplName, notes: w.notes, sets: sets),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.importSuccessTemplate)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.importFailed(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final extraBottom = 56.0 + 16.0 + bottomInset;
    final merged = Listenable.merge([
      wbox.listenable(),
      sbox.listenable(),
      cbox.listenable(),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.allWorkouts),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'import_pdf') _importFromPdf();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import_pdf',
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(s.importFromPdfMenu),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newWorkout,
        icon: const Icon(Icons.add),
        label: Text(s.newWorkout),
      ),
      body: SafeArea(
        bottom: true,
        child: AnimatedBuilder(
          animation: merged,
          builder: (context, _) {
            final all = wbox.values.toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final exerciseIndex = _exerciseIndexByWorkout();
            final exerciseOptions = _allExercisesFromIndex(exerciseIndex);
            final dropdownExerciseFilter =
                (_exerciseFilter != null &&
                    exerciseOptions.contains(_exerciseFilter))
                ? _exerciseFilter
                : null;
            if (_exerciseFilter != null && dropdownExerciseFilter == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _exerciseFilter = null);
              });
            }
            final filtered = _applyFilters(
              all,
              exerciseIndex,
              exerciseFilterValue: dropdownExerciseFilter,
            );

            return ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, extraBottom),
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: s.workoutSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchCtrl.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: s.filterAll,
                      selected: _kindFilter == 'all',
                      onTap: () => setState(() => _kindFilter = 'all'),
                    ),
                    _FilterChip(
                      label: s.workoutTypeStrength,
                      selected: _kindFilter == 'strength',
                      onTap: () => setState(() => _kindFilter = 'strength'),
                    ),
                    _FilterChip(
                      label: s.workoutTypeCardio,
                      selected: _kindFilter == 'cardio',
                      onTap: () => setState(() => _kindFilter = 'cardio'),
                    ),
                    _FilterChip(
                      label: s.filterStatusAll,
                      selected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    _FilterChip(
                      label: s.filterStatusCompleted,
                      selected: _statusFilter == 'completed',
                      onTap: () => setState(() => _statusFilter = 'completed'),
                    ),
                    _FilterChip(
                      label: s.filterStatusActive,
                      selected: _statusFilter == 'active',
                      onTap: () => setState(() => _statusFilter = 'active'),
                    ),
                    _FilterChip(
                      label: s.filterRangeAll,
                      selected: _rangeDays == 0,
                      onTap: () => setState(() => _rangeDays = 0),
                    ),
                    _FilterChip(
                      label: s.period7days,
                      selected: _rangeDays == 7,
                      onTap: () => setState(() => _rangeDays = 7),
                    ),
                    _FilterChip(
                      label: s.period30days,
                      selected: _rangeDays == 30,
                      onTap: () => setState(() => _rangeDays = 30),
                    ),
                    _FilterChip(
                      label: s.filterRange90days,
                      selected: _rangeDays == 90,
                      onTap: () => setState(() => _rangeDays = 90),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: dropdownExerciseFilter,
                  decoration: InputDecoration(
                    labelText: s.filterExerciseLabel,
                    prefixIcon: const Icon(Icons.fitness_center),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(s.filterExerciseAny),
                    ),
                    ...exerciseOptions.map(
                      (name) => DropdownMenuItem<String?>(
                        value: name,
                        child: Text(name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _exerciseFilter = value),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off),
                    label: Text(s.clearFilters),
                  ),
                ),
                const SizedBox(height: 8),
                if (all.isEmpty)
                  Center(child: Text(s.noWorkoutsYet))
                else if (filtered.isEmpty)
                  Center(child: Text(s.noWorkoutsMatchFilters))
                else
                  ..._buildWorkoutTiles(filtered, s),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildWorkoutTiles(List<Workout> items, AppLocalizations s) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final w = items[i];
      final dateStr = _d(w.date);
      final hasTitle = w.title.isNotEmpty;
      final cardioEntry = w.kind == 'cardio'
          ? _cardioEntryForWorkout(w.key as int)
          : null;
      final cardioDuration = cardioEntry != null
          ? _formatDurationShort(cardioEntry.durationSeconds)
          : s.noDuration;
      final cardioDistance = cardioEntry?.distanceKm != null
          ? '${cardioEntry!.distanceKm!.toStringAsFixed(2)} km'
          : s.noDistance;
      final subtitle = w.kind == 'cardio'
          ? '${s.date}: $dateStr - ${s.durationLabel}: $cardioDuration - ${s.distanceTotalLabel}: $cardioDistance'
          : '${s.date}: $dateStr - ${s.setsCount}: ${w.totalSets}';

      widgets.add(
        Dismissible(
          key: ValueKey(w.key),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red.withValues(alpha: 0.15),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete, color: Colors.red),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(s.deleteWorkoutTitle),
                    content: Text(
                      s.deleteWorkoutBody(
                        dateStr,
                        hasTitle ? 'yes' : 'other',
                        w.title,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(s.cancel),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(s.delete),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) async {
            await _deleteWorkoutCascade(context, w);
          },
          child: ListTile(
            title: Text(
              hasTitle ? w.title : s.workout,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle),
            leading: Icon(
              w.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: w.isCompleted ? Colors.green : null,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutDetailPage(workoutKey: w.key as int),
              ),
            ),
          ),
        ),
      );
      if (i < items.length - 1) {
        widgets.add(const Divider(height: 0));
      }
    }
    return widgets;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _CardioTemplatePickResult {
  final CardioTemplate? template;
  final bool startEmpty;

  const _CardioTemplatePickResult._({this.template, required this.startEmpty});
  const _CardioTemplatePickResult.empty()
    : this._(template: null, startEmpty: true);
  const _CardioTemplatePickResult.withTemplate(this.template)
    : startEmpty = false;
}
