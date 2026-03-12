import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/workout_template.dart';
import '../models/readiness_entry.dart';
import '../models/cardio_entry.dart';
import '../models/cardio_template.dart';
import '../models/exercise.dart';
import '../models/scheduled_workout.dart';
import 'workout_detail_page.dart';
import 'workouts_list_page.dart';
import 'templates_page.dart';
import 'exercises_page.dart';
import 'template_detail_page.dart';
import 'import_pdf_page.dart';
import 'schedule_page.dart';

import '../services/backup_service.dart';
import '../services/app_capture_service.dart';
import '../services/app_logger.dart';
import '../services/cardio_notification_service.dart';
import '../services/feedback_service.dart';
import '../services/readiness_service.dart';
import '../services/workout_reminder_service.dart';
import '../services/pro_service.dart';

// localization
import '../l10n/l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _fabHeight = 56;
  static const double _fabSpace = kFloatingActionButtonMargin + _fabHeight;

  late final Box<Workout> wbox;
  late final Box<SetEntry> sbox;
  late final Box settings;
  late final Box<WorkoutTemplate> tbox;
  late final Box<ReadinessEntry> rbox;
  late final Box<CardioEntry> cbox;
  late final Box<CardioTemplate> ctbox;
  Box<Exercise>? _ebox;
  Box<ScheduledWorkout>? _swbox;
  late final ReadinessService readinessService;
  late final Listenable _homeListenable;

  int _weeklyGoal = 4;
  bool _autoProgressionEnabled = true;
  double _plateIncrement = 2.5;
  double _weightIncreaseKg = 2.5;
  bool _useCustomIncrease = false;
  String _volumeMode = 'auto'; // 'auto' or 'fixed'
  Map<String, double> _categoryIncrements = {};

  ReadinessEntry? _readiness;

  @override
  void initState() {
    super.initState();
    wbox = Hive.box<Workout>('workouts');
    sbox = Hive.box<SetEntry>('sets');
    settings = Hive.box('settings');
    tbox = Hive.box<WorkoutTemplate>('templates');
    rbox = Hive.box<ReadinessEntry>('readiness');
    cbox = Hive.box<CardioEntry>('cardio_entries');
    ctbox = Hive.box<CardioTemplate>('cardio_templates');
    _ebox = Hive.box<Exercise>('exercises');
    _swbox = Hive.box<ScheduledWorkout>('scheduled_workouts');
    readinessService = ReadinessService(
      workoutsBox: wbox,
      setsBox: sbox,
      readinessBox: rbox,
      settingsBox: settings,
    );

    _weeklyGoal = (settings.get('weeklyGoal') as int?)?.clamp(1, 14) ?? 4;
    _autoProgressionEnabled = (settings.get('autoProgressionEnabled') as bool?) ?? true;
    _plateIncrement = (settings.get('plateIncrement') as num?)?.toDouble() ?? 2.5;
    _useCustomIncrease = (settings.get('useCustomIncrease') as bool?) ?? false;
    final storedIncrease = (settings.get('weightIncreaseKg') as num?)?.toDouble();
    _weightIncreaseKg = storedIncrease ?? _plateIncrement;
    if (!_useCustomIncrease && storedIncrease != null && (_plateIncrement - storedIncrease).abs() > 0.001) {
      _useCustomIncrease = true;
    }
    if (!_useCustomIncrease) {
      _weightIncreaseKg = _plateIncrement;
    }
    _volumeMode = (settings.get('volumeMode') as String?) ?? 'auto';
    _categoryIncrements = _parseCategoryIncrements(settings.get('categoryIncrements'));
    _homeListenable = Listenable.merge([
      wbox.listenable(),
      sbox.listenable(),
      rbox.listenable(),
      cbox.listenable(),
      _scheduleBox().listenable(),
      ProService.listenable(settings),
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshReadiness();
      _maybeRequestPermissionsOnFirstOpen();
    });
  }

  Future<void> _maybeRequestPermissionsOnFirstOpen() async {
    final prompted = (settings.get('permissionsPromptedV1') as bool?) ?? false;
    if (prompted) return;
    await settings.put('permissionsPromptedV1', true);
    if (!mounted) return;

    final s = AppLocalizations.of(context);
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.permissionsPromptTitle),
        content: Text(s.permissionsPromptBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.permissionsNotNow)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.permissionsAllow)),
        ],
      ),
    );
    if (allow != true) return;

    if (!kIsWeb) {
      await Permission.notification.request();
    }
    await WorkoutReminderService.instance.requestExactAlarmsPermission();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final canOverlay = await CardioNotificationService.instance.canDrawOverlay();
      if (!canOverlay && mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.overlayPromptTitle),
            content: Text(s.overlayPromptBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.permissionsNotNow)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.overlayOpenSettings)),
            ],
          ),
        );
        if (openSettings == true) {
          await CardioNotificationService.instance.openOverlaySettings();
        }
      }
    }
  }

  Future<void> _showAboutDialog() async {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String versionText = 'Unknown';
    String packageName = 'Unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      versionText = '${info.version} (${info.buildNumber})';
      packageName = info.packageName;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to read package info for about dialog',
        context: <String, Object?>{'error': error.toString(), 'stack': stackTrace.toString()},
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.aboutTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.aboutBody),
              const SizedBox(height: 12),
              Text(
                s.privacyPolicyTitle,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(s.privacyPolicyBody),
              const SizedBox(height: 12),
              Text(
                'Build info',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText('Version: $versionText'),
              SelectableText('Package: $packageName'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        ],
      ),
    );
  }

  Future<void> _sendFeedbackPackage() async {
    final feedbackInput = await _collectFeedbackInput();
    if (feedbackInput == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing feedback package...')));

    try {
      AppLogger.info('Preparing feedback package from home menu');
      await WidgetsBinding.instance.endOfFrame;
      final screenshotBytes = await AppCaptureService.captureScreenshotPng(pixelRatio: 2.0);
      await FeedbackService.shareFeedbackPackage(
        subject: 'GymNotes tester feedback',
        shareText: 'GymNotes tester feedback: ${feedbackInput['summary']}',
        testerFeedback: feedbackInput,
        screenshotBytes: screenshotBytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            screenshotBytes == null
                ? 'Feedback package opened (without screenshot).'
                : 'Feedback package opened in share sheet.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to share feedback package', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Feedback failed: $error')));
    }
  }

  Future<Map<String, Object?>?> _collectFeedbackInput() async {
    final summaryController = TextEditingController();
    final stepsController = TextEditingController();
    final expectedController = TextEditingController();
    final actualController = TextEditingController();

    String severity = 'medium';
    String? errorText;

    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Session feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    hintText: 'Short title of the issue',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => severity = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stepsController,
                  decoration: const InputDecoration(
                    labelText: 'Steps to reproduce',
                    hintText: '1) ... 2) ... 3) ...',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expectedController,
                  decoration: const InputDecoration(
                    labelText: 'Expected result',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: actualController,
                  decoration: const InputDecoration(
                    labelText: 'Actual result',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final summary = summaryController.text.trim();
                final steps = stepsController.text.trim();
                final expected = expectedController.text.trim();
                final actual = actualController.text.trim();

                if (summary.isEmpty || steps.isEmpty || expected.isEmpty || actual.isEmpty) {
                  setDialogState(() {
                    errorText = 'Please fill all fields before continuing.';
                  });
                  return;
                }

                Navigator.pop(ctx, <String, Object?>{
                  'summary': summary,
                  'severity': severity,
                  'stepsToReproduce': steps,
                  'expectedResult': expected,
                  'actualResult': actual,
                  'capturedAtLocal': DateTime.now().toIso8601String(),
                });
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    summaryController.dispose();
    stepsController.dispose();
    expectedController.dispose();
    actualController.dispose();
    return result;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final sd = _startOfDay(d);
    return sd.subtract(Duration(days: sd.weekday - 1));
  }

  DateTime _endOfWeekExclusive(DateTime d) => _startOfWeek(d).add(const Duration(days: 7));

  Map<int, CardioEntry> _cardioEntriesByWorkout() {
    final map = <int, CardioEntry>{};
    for (final entry in cbox.values) {
      map[entry.workoutKey] = entry;
    }
    return map;
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

  Box<Exercise> _exerciseBox() {
    return _ebox ??= Hive.box<Exercise>('exercises');
  }

  Box<ScheduledWorkout> _scheduleBox() {
    return _swbox ??= Hive.box<ScheduledWorkout>('scheduled_workouts');
  }

  List<String> _exerciseCategories() {
    final categories = <String>{};
    for (final e in _exerciseBox().values) {
      final cat = e.category.trim();
      if (cat.isNotEmpty) categories.add(cat);
    }
    final list = categories.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String? _categoryForExercise(String exercise) {
    final target = exercise.trim().toLowerCase();
    for (final e in _exerciseBox().values) {
      if (e.name.trim().toLowerCase() == target) {
        final cat = e.category.trim();
        return cat.isEmpty ? null : cat;
      }
    }
    return null;
  }

  double _incrementForExercise(String exercise) {
    final category = _categoryForExercise(exercise);
    final override = category == null ? null : _categoryIncrements[category];
    if (override != null && override > 0) return override;
    return _weightIncreaseKg;
  }

  List<ScheduledWorkout> _pendingSchedulesSorted() {
    final items = _scheduleBox().values.where((s) => !s.isCompleted).toList();
    items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return items;
  }

  List<ScheduledWorkout> _upcomingSchedulesFrom(
    List<ScheduledWorkout> sorted,
    DateTime now, {
    int limit = 3,
  }) {
    final cutoff = now.subtract(const Duration(minutes: 1));
    final upcoming = sorted.where((s) => s.scheduledAt.isAfter(cutoff)).toList();
    if (upcoming.length <= limit) return upcoming;
    return upcoming.sublist(0, limit);
  }

  ScheduledWorkout? _nextDueScheduleFrom(List<ScheduledWorkout> sorted, DateTime now) {
    for (final s in sorted) {
      final delta = s.scheduledAt.difference(now);
      if (delta.inMinutes <= 120 && delta.inMinutes >= -15) {
        return s;
      }
    }
    return null;
  }

  String _scheduledTitle(ScheduledWorkout s) {
    if (s.kind == 'cardio') {
      final t = ctbox.get(s.templateKey);
      return t?.name ?? 'Missing template';
    }
    final t = tbox.get(s.templateKey);
    return t?.name ?? 'Missing template';
  }

  String _formatScheduleDateTime(DateTime dateTime) {
    return DateFormat('EEE, d MMM HH:mm').format(dateTime);
  }

  double? _tryParseDouble(String input) {
    final v = input.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
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

  int _workoutsThisWeek(Iterable<Workout> workouts, DateTime now) {
    final from = _startOfWeek(now);
    final to = _endOfWeekExclusive(now);
    return workouts.where((w) {
      final inRange = !w.date.isBefore(from) && w.date.isBefore(to);
      return inRange && (w.isCompleted);
    }).length;
  }

  Future<void> _openTuningSheet() async {
    final s = AppLocalizations.of(context);
    final isPro = ProService.isPro(settings);
    final categoryControllers = <String, TextEditingController>{};
    TextEditingController controllerForCategory(String category) {
      return categoryControllers.putIfAbsent(category, () {
        final value = _categoryIncrements[category];
        final text = value == null ? '' : value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
        return TextEditingController(text: text);
      });
    }

    try {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (sheetContext, setModalState) {
              final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
              final categories = _exerciseCategories();
              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.tuningSettings,
                            style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch.adaptive(
                          value: _autoProgressionEnabled,
                          onChanged: (v) {
                            _toggleAutoProgression(v).then((_) => setModalState(() {}));
                          },
                        ),
                      ],
                    ),
                    Text(
                      s.autoProgressionToggle,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(s.weightStepLabel, style: Theme.of(sheetContext).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final inc in const [1.0, 1.25, 2.5, 5.0])
                          ChoiceChip(
                            label: Text('${inc.toStringAsFixed(inc % 1 == 0 ? 0 : 2)} kg'),
                            selected: (_plateIncrement - inc).abs() < 0.001,
                            onSelected: (_) {
                              _setPlateIncrement(inc).then((_) => setModalState(() {}));
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text(s.weightIncreaseLabel, style: Theme.of(sheetContext).textTheme.bodySmall)),
                        Switch.adaptive(
                          value: _useCustomIncrease,
                          onChanged: (v) {
                            if (!isPro) {
                              ProService.showUpsell(
                                context,
                                settings,
                                feature: s.proFeatureAutoProgression,
                              );
                              return;
                            }
                            _toggleCustomIncrease(v).then((_) => setModalState(() {}));
                          },
                        ),
                      ],
                    ),
                    Text(
                      _useCustomIncrease
                          ? 'Pick a custom jump; otherwise we match your plate size.'
                          : 'Auto-matches your plate size. Turn on to pick a different jump.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final inc in const [1.0, 1.25, 2.5, 5.0])
                          ChoiceChip(
                            label: Text('+${inc.toStringAsFixed(inc % 1 == 0 ? 0 : 2)} kg'),
                            selected: (_weightIncreaseKg - inc).abs() < 0.001,
                            onSelected: (_useCustomIncrease && isPro)
                                ? (_) {
                                    _setWeightIncrease(inc).then((_) => setModalState(() {}));
                                  }
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Category increments (override default)',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    if (!isPro) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${s.proFeatureLocked} ${s.proFeatureAutoProgression}',
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (categories.isEmpty)
                      Text(
                        'No exercise categories yet.',
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      )
                    else
                      Column(
                        children: [
                          for (final category in categories) ...[
                            Row(
                              children: [
                                Expanded(child: Text(category)),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: controllerForCategory(category),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      suffixText: 'kg',
                                    ),
                                    enabled: isPro,
                                    onChanged: (value) {
                                      if (!isPro) return;
                                      final parsed = _tryParseDouble(value);
                                      if (value.trim().isEmpty) {
                                        _setCategoryIncrement(category, null).then((_) => setModalState(() {}));
                                      } else if (parsed != null) {
                                        _setCategoryIncrement(category, parsed).then((_) => setModalState(() {}));
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    const SizedBox(height: 12),
                    Text(
                      s.tuningHint,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      for (final controller in categoryControllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _refreshReadiness() async {
    final entry = await readinessService.recompute(weeklyGoal: _weeklyGoal);
    if (!mounted) return;
    setState(() {
      _readiness = entry;
    });
  }

  Future<void> _toggleAutoProgression(bool value) async {
    setState(() => _autoProgressionEnabled = value);
    await settings.put('autoProgressionEnabled', value);
  }

  double _tunedWeightForSet(String exercise, double baseWeight, double loadMult) {
    if (!_autoProgressionEnabled) return _roundToIncrement(baseWeight);

    final canIncrease = loadMult > 1.0 && _exerciseHasUniformReps(exercise);
    if (canIncrease) {
      return _roundToIncrement(baseWeight + _incrementForExercise(exercise));
    }
    if (loadMult < 1.0) {
      return _roundToIncrement(baseWeight * loadMult);
    }
    return _roundToIncrement(baseWeight);
  }

  bool _exerciseHasUniformReps(String exercise) {
    final workouts = wbox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final w in workouts) {
      final wKey = w.key;
      if (wKey == null) continue;
      final sets = sbox.values
          .where((s) => s.workoutKey == wKey && s.exercise == exercise)
          .toList();
      if (sets.isEmpty) continue;
      final relevant = sets.where((s) => s.isCompleted).toList();
      final source = relevant.isNotEmpty ? relevant : sets;
      final reps = source.map((s) => s.reps).toSet();
      return reps.length == 1;
    }
    return false;
  }

  double _roundToIncrement(double value) {
    if (_plateIncrement <= 0) return double.parse(value.toStringAsFixed(1));
    final steps = (value / _plateIncrement).round();
    return double.parse((steps * _plateIncrement).toStringAsFixed(2));
  }

  Future<void> _setPlateIncrement(double value) async {
    setState(() {
      _plateIncrement = value;
      if (!_useCustomIncrease) {
        _weightIncreaseKg = value;
      }
    });
    await settings.put('plateIncrement', value);
    if (!_useCustomIncrease) {
      await settings.put('weightIncreaseKg', value);
    }
  }

  Future<void> _toggleCustomIncrease(bool value) async {
    setState(() {
      _useCustomIncrease = value;
      if (!value) {
        _weightIncreaseKg = _plateIncrement;
      }
    });
    await settings.put('useCustomIncrease', value);
    await settings.put('weightIncreaseKg', _weightIncreaseKg);
  }

  Future<void> _setWeightIncrease(double value) async {
    setState(() {
      _useCustomIncrease = true;
      _weightIncreaseKg = value;
    });
    await settings.put('useCustomIncrease', true);
    await settings.put('weightIncreaseKg', value);
  }

  Future<void> _setCategoryIncrement(String category, double? value) async {
    setState(() {
      if (value == null || value <= 0) {
        _categoryIncrements.remove(category);
      } else {
        _categoryIncrements[category] = value;
      }
    });
    await settings.put('categoryIncrements', Map<String, double>.from(_categoryIncrements));
  }

  Future<void> _setVolumeMode(String mode) async {
    setState(() => _volumeMode = mode);
    await settings.put('volumeMode', mode);
  }

  List<Workout> _latestWorkoutsFrom(List<Workout> workouts, {int limit = 10}) {
    if (workouts.isEmpty) return const <Workout>[];
    final list = List<Workout>.from(workouts)..sort((a, b) => b.date.compareTo(a.date));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  // ---------- Template apply ----------
  Future<void> _applyTemplateToWorkout(int workoutKey, WorkoutTemplate tpl) async {
    final readiness = _autoProgressionEnabled ? (_readiness ?? readinessService.latest()) : null;
    final loadMultBase = readiness?.loadModifier ?? 1.0;
    final volumeMult = (_autoProgressionEnabled && _volumeMode == 'auto') ? (readiness?.volumeModifier ?? 1.0) : 1.0;

    for (var i = 0; i < tpl.sets.length; i++) {
      final ts = tpl.sets[i];
      final adjustedReps = (ts.reps * volumeMult).round();
      final adjustedSeconds = ts.seconds != null ? (ts.seconds! * volumeMult).round() : null;
      final adjustedWeight = _tunedWeightForSet(ts.exercise, ts.weightKg, loadMultBase);

      await sbox.add(SetEntry(
        workoutKey: workoutKey,
        exercise: ts.exercise,
        setNumber: i + 1,
        reps: adjustedReps <= 0 ? 1 : adjustedReps,
        weightKg: adjustedWeight,
        rpe: ts.rpe,
        notes: ts.notes,
        isTimeBased: ts.isTimeBased,
        seconds: adjustedSeconds == null || adjustedSeconds <= 0 ? ts.seconds : adjustedSeconds,
        isCompleted: false,
      ));
    }
    final sets = sbox.values.where((e) => e.workoutKey == workoutKey).toList();
    final w = wbox.get(workoutKey)!;
    w
      ..totalSets = sets.length
      ..totalReps = sets.fold(0, (sum, e) => sum + e.reps)
      ..totalVolume = sets.fold(0.0, (sum, e) => sum + e.reps * e.weightKg);
    await w.save();
  }

  Future<_TemplatePickResult?> _pickTemplateBottomSheet() async {
    final s = AppLocalizations.of(context);
    final templates = tbox.values.toList();
    return showModalBottomSheet<_TemplatePickResult?>(
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
                  s.newWorkoutPickTemplate,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    // uvijek imamo +1 za "Prazan trening"
                    itemCount: (templates.isEmpty ? 1 : templates.length + 1),
                    separatorBuilder: (context, index) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.note_add_outlined),
                          title: Text(s.emptyWorkout),
                          subtitle: Text(s.startWithoutTemplate),
                          onTap: () => Navigator.pop(ctx, const _TemplatePickResult.empty()),
                        );
                      }
                      final t = templates[i - 1];
                      return ListTile(
                        leading: const Icon(Icons.content_paste),
                        title: Text(t.name),
                        subtitle: Text(
                          t.sets.isEmpty
                              ? s.setsCount
                              : '${t.sets.length} ${s.setsCount.toLowerCase()} \u2022 e.g. ${t.sets.first.exercise}',
                          maxLines: 2,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(ctx, _TemplatePickResult.withTemplate(t)),
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

  Future<_CardioTemplatePickResult?> _pickCardioTemplateBottomSheet() async {
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
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: (templates.isEmpty ? 1 : templates.length + 1),
                    separatorBuilder: (context, index) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.note_add_outlined),
                          title: Text(s.emptyWorkout),
                          subtitle: Text(s.startWithoutTemplate),
                          onTap: () => Navigator.pop(ctx, const _CardioTemplatePickResult.empty()),
                        );
                      }
                      final t = templates[i - 1];
                      final duration = _formatDurationShort(t.durationSeconds);
                      final distance =
                          t.distanceKm != null ? '${t.distanceKm!.toStringAsFixed(2)} km' : s.noDistance;
                      return ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(t.name),
                        subtitle: Text('${t.activity} - $duration - $distance'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(ctx, _CardioTemplatePickResult.withTemplate(t)),
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
  Future<void> _applyCardioTemplateToWorkout(int workoutKey, CardioTemplate tpl) async {
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
      segments: tpl.segments
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

  Future<String?> _pickWorkoutKind() async {
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
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
              Text(
                s.workoutTypeHint,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newWorkout() async {
    final kind = await _pickWorkoutKind();
    if (kind == null) return; // user cancelled

    _TemplatePickResult? picked;
    _CardioTemplatePickResult? cardioPicked;
    if (kind == 'strength') {
      picked = await _pickTemplateBottomSheet();
      if (picked == null) return; // user cancelled
    } else if (kind == 'cardio') {
      cardioPicked = await _pickCardioTemplateBottomSheet();
      if (cardioPicked == null) return; // user cancelled
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workout = Workout(date: today, kind: kind);
    final key = await wbox.add(workout);

    if (picked?.template != null) {
      await _applyTemplateToWorkout(key, picked!.template!);
    }
    if (cardioPicked?.template != null) {
      await _applyCardioTemplateToWorkout(key, cardioPicked!.template!);
    }

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: key)));
    if (!mounted) return;
    setState(() {});
    _refreshReadiness();
  }

  // ---------- Create template from an existing workout ----------
  Future<void> _createTemplateFromWorkout(Workout w) async {
    final s = AppLocalizations.of(context);
    final wKey = w.key as int;
    final sets = sbox.values
        .where((s) => s.workoutKey == wKey)
        .toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    if (sets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.workoutHasNoSetsForTemplate)),
      );
      return;
    }
    if (!await ProService.ensureTemplateCapacity(context, settings, tbox.length)) return;

    final d = w.date;
    final defaultName = (w.title.isNotEmpty)
        ? w.title
        : 'Template ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';

    final nameCtrl = TextEditingController(text: defaultName);
    final notesCtrl = TextEditingController(text: w.notes);

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.saveAsTemplate),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.templateName)),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: InputDecoration(labelText: s.notesOptional)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.save)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final tpl = WorkoutTemplate(
      name: nameCtrl.text.trim().isEmpty ? defaultName : nameCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      sets: [
        for (final s in sets)
          TemplateSet(
            exercise: s.exercise,
            setNumber: s.setNumber,
            reps: s.reps,
            weightKg: s.weightKg,
            rpe: s.rpe,
            notes: s.notes,
            isTimeBased: s.isTimeBased,
            seconds: s.seconds,
          ),
      ],
    );

    final int key = await tbox.add(tpl);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.templateCreated)),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TemplateDetailPage(templateKey: key)),
    );
  }

  // ---------- Delete (confirm + undo) ----------
  Future<void> _confirmDeleteWorkout(Workout w) async {
    final s = AppLocalizations.of(context);
    final dateStr =
        '${w.date.day.toString().padLeft(2, '0')}.${w.date.month.toString().padLeft(2, '0')}.${w.date.year}.';

    // Pass all 3 arguments: date, flag ('yes' / 'other'), title.
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
      ..totalVolume = w.totalVolume
      ..restAdherence = w.restAdherence
      ..feelingScore = w.feelingScore;

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
                ..totalVolume = backupWorkout.totalVolume
                ..restAdherence = backupWorkout.restAdherence
                ..feelingScore = backupWorkout.feelingScore,
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
            _refreshReadiness();
          },
        ),
      ),
    );

    setState(() {});
    _refreshReadiness();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _homeListenable,
      builder: (context, _) {
        final now = DateTime.now();
        final workouts = wbox.values.toList();
        final latest = _latestWorkoutsFrom(workouts);
        final cardioByWorkout = _cardioEntriesByWorkout();
        final done = _workoutsThisWeek(workouts, now);
        final isPro = ProService.isPro(settings);
        final goal = _weeklyGoal.clamp(1, 14);
        final progress = (goal == 0) ? 0.0 : (done / goal).clamp(0.0, 1.0);
        final weekStart = _startOfWeek(now);
        final weekEnd = _endOfWeekExclusive(now).subtract(const Duration(days: 1));
        final rangeLabel =
            '${weekStart.day.toString().padLeft(2, '0')}.${weekStart.month.toString().padLeft(2, '0')} - '
            '${weekEnd.day.toString().padLeft(2, '0')}.${weekEnd.month.toString().padLeft(2, '0')}';
        final schedules = _pendingSchedulesSorted();
        final upcomingSchedules = _upcomingSchedulesFrom(schedules, now);
        final nextDueSchedule = _nextDueScheduleFrom(schedules, now);

        return Scaffold(
          appBar: AppBar(
            title: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  s.appTitle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: s.scheduleTitle,
                icon: const Icon(Icons.calendar_month),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulePage()));
                },
              ),
              IconButton(
                tooltip: s.templates,
                icon: const Icon(Icons.content_paste_search),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesPage()));
                },
              ),
              IconButton(
                tooltip: s.allWorkouts,
                icon: const Icon(Icons.view_list),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutsListPage()));
                },
              ),
              IconButton(
                tooltip: s.exercises,
                icon: const Icon(Icons.fitness_center),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExercisesPage()));
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'export') {
                    AppLogger.info('User triggered backup export');
                    await BackupService.exportAll();
                  } else if (v == 'import') {
                    AppLogger.info('User opened backup import confirmation');
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(s.importDataTitle),
                            content: Text(s.importDataBody),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.no)),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.yesImport)),
                            ],
                          ),
                        ) ??
                        false;
                    if (!context.mounted) return;
                    if (confirmed) {
                      AppLogger.info('User confirmed backup import');
                      await BackupService.importAll(replace: true);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.importCompleted)));
                      setState(() {});
                    }
                  } else if (v == 'import_pdf') {
                    AppLogger.info('User opened PDF import screen');
                    if (!context.mounted) return;
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const ImportPdfScreen()),
                    );
                    if (changed == true && mounted) {
                      setState(() {});
                    }
                  } else if (v == 'about') {
                    AppLogger.info('User opened about dialog');
                    await _showAboutDialog();
                  } else if (v == 'feedback') {
                    await _sendFeedbackPackage();
                  } else if (v == 'pro') {
                    AppLogger.info('User opened Pro upsell');
                    await ProService.showUpsell(context, settings);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(leading: const Icon(Icons.file_upload_outlined), title: Text(s.exportBackup)),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: ListTile(leading: const Icon(Icons.file_download_outlined), title: Text(s.importBackup)),
                  ),
                  PopupMenuItem(
                    value: 'import_pdf',
                    child: ListTile(
                      leading: const Icon(Icons.file_open),
                      title: Text(s.importFromPdfMenu),
                      subtitle: Text(s.importFromPdfSubtitle),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pro',
                    child: ListTile(
                      leading: Icon(isPro ? Icons.verified : Icons.workspace_premium),
                      title: Text(isPro ? s.proMenuActive : s.proMenuUpgrade),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'about',
                    child: ListTile(leading: const Icon(Icons.info_outline), title: Text(s.aboutMenu)),
                  ),
                  PopupMenuItem(
                    value: 'feedback',
                    child: ListTile(
                      leading: const Icon(Icons.feedback_outlined),
                      title: Text(s.sessionFeedbackTitle),
                      subtitle: const Text('Include screenshot + logs + app version'),
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + _fabSpace),
              children: [
                _TuningCard(
                  plateIncrement: _plateIncrement,
                  weightIncreaseKg: _weightIncreaseKg,
                  useCustomIncrease: _useCustomIncrease,
                  onOpenTuning: _openTuningSheet,
                ),
                const SizedBox(height: 16),
                _ScheduleCard(
                  upcoming: upcomingSchedules,
                  nextDue: nextDueSchedule,
                  titleFor: _scheduledTitle,
                  timeFor: (s) => _formatScheduleDateTime(s.scheduledAt),
                  onOpenCalendar: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulePage()));
                  },
                ),
                const SizedBox(height: 16),
                _WeeklyGoalCard(
                  done: done,
                  goal: goal,
                  progress: progress,
                  rangeLabel: rangeLabel,
                  onChangeGoal: () async {
                    final ctrl = TextEditingController(text: '$_weeklyGoal');
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(s.setWeeklyGoal),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: s.workoutsPerWeek,
                                prefixIcon: const Icon(Icons.flag_outlined),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.save)),
                            ],
                          ),
                        ) ??
                        false;
                    if (!context.mounted) return;
                    if (ok) {
                      final v = int.tryParse(ctrl.text.trim());
                      if (v != null && v > 0) {
                        final newGoal = v.clamp(1, 14);
                        setState(() => _weeklyGoal = newGoal);
                        await settings.put('weeklyGoal', newGoal);
                        await _refreshReadiness();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.enterNumberGreaterThanZero)),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),

                Text(
                  s.recentWorkouts,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (latest.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(s.noWorkoutsYet),
                  )
                else
                  ...latest.map((w) {
                    final key = w.key as int;
                    final completed = w.isCompleted;
                    final d = w.date;
                    final dateStr =
                        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';
                    final cardioEntry = w.kind == 'cardio' ? cardioByWorkout[key] : null;
                    final cardioDuration =
                        cardioEntry != null ? _formatDurationShort(cardioEntry.durationSeconds) : s.noDuration;
                    final cardioDistance = cardioEntry?.distanceKm != null
                        ? '${cardioEntry!.distanceKm!.toStringAsFixed(2)} km'
                        : s.noDistance;
                    final subtitle = w.kind == 'cardio'
                        ? '${s.durationLabel}: $cardioDuration\n${s.distanceTotalLabel}: $cardioDistance'
                        : '${s.date}: $dateStr\n${s.setsCount}: ${w.totalSets}';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          completed ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: completed ? Colors.green : null,
                        ),
                        title: Text(w.title.isNotEmpty ? w.title : '${s.workout} $dateStr'),
                        subtitle: Text(subtitle, maxLines: 2),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'open') {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: key)),
                              );
                            } else if (v == 'delete') {
                              await _confirmDeleteWorkout(w);
                            } else if (v == 'tpl') {
                              await _createTemplateFromWorkout(w);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'open',
                              child: ListTile(leading: const Icon(Icons.open_in_new), title: Text(s.open)),
                            ),
                            PopupMenuItem(
                              value: 'tpl',
                              child: ListTile(leading: const Icon(Icons.copy_all), title: Text(s.createTemplate)),
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
                            MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutKey: key)),
                          );
                        },
                      ),
                    );
                  }),

                const SizedBox(height: _fabSpace),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension _HomeL10nFallback on AppLocalizations {
  String get cardioTemplatePickTitle => 'Pick a cardio template';
  String get noDistance => 'No distance';
  String get importFromPdfSubtitle => 'Restore a workout or a template from a PDF.';
  String get noDuration => 'No duration';
  String get durationLabel => 'Duration';
  String get distanceTotalLabel => 'Distance';
  String get scheduleTitle => 'Schedule';
  String get scheduledWorkoutsTitle => 'Scheduled workouts';
  String get scheduleWorkoutAction => 'Schedule workout';
  String get noScheduledWorkouts => 'No scheduled workouts yet.';
  String get upcomingReminderTitle => 'Upcoming workout';
  String get permissionsPromptTitle => 'Permissions';
  String get permissionsPromptBody =>
      'Allow notifications, exact alarms, and overlay banners so reminders and interval alerts work in the background.';
  String get permissionsAllow => 'Allow';
  String get permissionsNotNow => 'Not now';
  String get overlayPromptTitle => 'Overlay banner';
  String get overlayPromptBody =>
      'Enable draw over other apps to show 5-second interval banners while other apps are open.';
  String get overlayOpenSettings => 'Open settings';
}

/// Result from picking a template or choosing an empty workout.
class _TemplatePickResult {
  final WorkoutTemplate? template;
  final bool startEmpty;

  const _TemplatePickResult._({this.template, required this.startEmpty});
  const _TemplatePickResult.empty() : this._(template: null, startEmpty: true);
  const _TemplatePickResult.withTemplate(this.template) : startEmpty = false;
}

class _CardioTemplatePickResult {
  final CardioTemplate? template;
  final bool startEmpty;

  const _CardioTemplatePickResult._({this.template, required this.startEmpty});
  const _CardioTemplatePickResult.empty() : this._(template: null, startEmpty: true);
  const _CardioTemplatePickResult.withTemplate(this.template) : startEmpty = false;
}

class _TuningCard extends StatelessWidget {
  const _TuningCard({
    required this.plateIncrement,
    required this.weightIncreaseKg,
    required this.useCustomIncrease,
    required this.onOpenTuning,
  });

  final double plateIncrement;
  final double weightIncreaseKg;
  final bool useCustomIncrease;
  final VoidCallback onOpenTuning;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final plateText = '${plateIncrement.toStringAsFixed(plateIncrement % 1 == 0 ? 0 : 2)} kg';
    final increaseText = '+${weightIncreaseKg.toStringAsFixed(weightIncreaseKg % 1 == 0 ? 0 : 2)} kg';
    final increaseLabel = useCustomIncrease ? increaseText : '$increaseText (matches plates)';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tuningSettings,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: s.tuningSettings,
                  icon: const Icon(Icons.tune),
                  onPressed: onOpenTuning,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${s.weightStepLabel}: $plateText', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('${s.weightIncreaseLabel}: $increaseLabel', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.settings_suggest_outlined),
                label: Text(s.tuningSettings),
                onPressed: onOpenTuning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.upcoming,
    required this.nextDue,
    required this.titleFor,
    required this.timeFor,
    required this.onOpenCalendar,
  });

  final List<ScheduledWorkout> upcoming;
  final ScheduledWorkout? nextDue;
  final String Function(ScheduledWorkout) titleFor;
  final String Function(ScheduledWorkout) timeFor;
  final VoidCallback onOpenCalendar;

  IconData _kindIcon(String kind) {
    return kind == 'cardio' ? Icons.directions_run : Icons.fitness_center;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.scheduledWorkoutsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: onOpenCalendar,
                  child: Text(s.scheduleWorkoutAction),
                ),
              ],
            ),
            if (nextDue != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.upcomingReminderTitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${titleFor(nextDue!)} • ${timeFor(nextDue!)}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              Text(
                s.noScheduledWorkouts,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                children: upcoming.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_kindIcon(item.kind)),
                    title: Text(titleFor(item)),
                    subtitle: Text(timeFor(item)),
                    trailing: item.reminderEnabled ? const Icon(Icons.notifications_active) : null,
                    onTap: onOpenCalendar,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  final int done;
  final int goal;
  final double progress;
  final String rangeLabel;
  final VoidCallback onChangeGoal;

  const _WeeklyGoalCard({
    required this.done,
    required this.goal,
    required this.progress,
    required this.rangeLabel,
    required this.onChangeGoal,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final reached = done >= goal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.weeklyGoal,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: s.setWeeklyGoal,
                onPressed: onChangeGoal,
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$done / $goal ${s.workoutsPerWeek.toLowerCase()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (reached)
                Row(
                  children: [
                    const Icon(Icons.celebration_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(s.goalReached),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}







