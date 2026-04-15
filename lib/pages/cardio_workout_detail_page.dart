import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/cardio_entry.dart';
import '../models/cardio_template.dart';
import '../models/scheduled_workout.dart';
import '../services/export_service.dart';
import '../services/cardio_notification_service.dart';
import '../services/workout_reminder_service.dart';
import '../l10n/l10n.dart';

class CardioWorkoutDetailPage extends StatefulWidget {
  final int workoutKey;
  const CardioWorkoutDetailPage({super.key, required this.workoutKey});

  @override
  State<CardioWorkoutDetailPage> createState() =>
      _CardioWorkoutDetailPageState();
}

enum _CardioFlow { plan, running, summary }

class _CardioWorkoutDetailPageState extends State<CardioWorkoutDetailPage>
    with WidgetsBindingObserver {
  static const String _shortBeepAsset = 'sounds/beep.wav';
  static const String _longBeepAsset = 'sounds/beep_long.wav';

  late final Box<Workout> wbox;
  late final Box<CardioEntry> cbox;
  late final Box<CardioTemplate> tbox;
  late final Box<ScheduledWorkout> swbox;
  late final Box<Exercise> ebox;
  CardioEntry? _entry;

  _CardioFlow _flow = _CardioFlow.plan;
  int _currentSegmentIndex = 0;
  int _segmentRemaining = 0;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _isInBackground = false;
  int _lastPreAlertSegmentIndex = -1;
  int _lastPostAlertSegmentIndex = -1;

  bool _isCompleted = false;

  final _activity = TextEditingController();
  final _durationMin = TextEditingController();
  final _durationSec = TextEditingController();
  final _distance = TextEditingController();
  final _elevation = TextEditingController();
  final _incline = TextEditingController();
  final _avgHr = TextEditingController();
  final _maxHr = TextEditingController();
  final _rpe = TextEditingController();
  final _calories = TextEditingController();
  final _environment = TextEditingController();
  final _terrain = TextEditingController();
  final _weather = TextEditingController();
  final _equipment = TextEditingController();
  final _mood = TextEditingController();
  final _energy = TextEditingController();
  final _notes = TextEditingController();
  late final List<TextEditingController> _zoneMinutes;
  late final AudioPlayer _beepPlayer;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isInBackground =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    wbox = Hive.box<Workout>('workouts');
    cbox = Hive.box<CardioEntry>('cardio_entries');
    tbox = Hive.box<CardioTemplate>('cardio_templates');
    swbox = Hive.box<ScheduledWorkout>('scheduled_workouts');
    ebox = Hive.box<Exercise>('exercises');
    _zoneMinutes = List.generate(5, (_) => TextEditingController());
    _beepPlayer = AudioPlayer();
    unawaited(_beepPlayer.setPlayerMode(PlayerMode.lowLatency));
    unawaited(_beepPlayer.setReleaseMode(ReleaseMode.stop));
    unawaited(
      _beepPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      ),
    );
    _isCompleted = workout.isCompleted;
    Future.microtask(_loadEntry);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(CardioNotificationService.instance.clear());
    WidgetsBinding.instance.removeObserver(this);
    _activity.dispose();
    _durationMin.dispose();
    _durationSec.dispose();
    _distance.dispose();
    _elevation.dispose();
    _incline.dispose();
    _avgHr.dispose();
    _maxHr.dispose();
    _rpe.dispose();
    _calories.dispose();
    _environment.dispose();
    _terrain.dispose();
    _weather.dispose();
    _equipment.dispose();
    _mood.dispose();
    _energy.dispose();
    _notes.dispose();
    for (final ctrl in _zoneMinutes) {
      ctrl.dispose();
    }
    unawaited(_beepPlayer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInBackground = state != AppLifecycleState.resumed;
  }

  Workout get workout => wbox.get(widget.workoutKey)!;

  CardioEntry? _entryForWorkout() {
    if (_entry != null) return _entry;
    for (final e in cbox.values) {
      if (e.workoutKey == widget.workoutKey) {
        _entry = e;
        return e;
      }
    }
    return null;
  }

  Future<void> _loadEntry() async {
    var entry = _entryForWorkout();
    if (entry == null) {
      entry = CardioEntry(workoutKey: widget.workoutKey);
      await cbox.add(entry);
    }
    _entry = entry;
    _applyEntryToControllers(entry);
    if (mounted) setState(() {});
  }

  void _applyEntryToControllers(CardioEntry entry) {
    _activity.text = entry.activity;
    final duration = entry.durationSeconds;
    _durationMin.text = (duration ~/ 60).toString();
    _durationSec.text = (duration % 60).toString().padLeft(2, '0');
    _distance.text = entry.distanceKm?.toString() ?? '';
    _elevation.text = entry.elevationGainM?.toString() ?? '';
    _incline.text = entry.inclinePercent?.toString() ?? '';
    _avgHr.text = entry.avgHeartRate?.toString() ?? '';
    _maxHr.text = entry.maxHeartRate?.toString() ?? '';
    _rpe.text = entry.rpe?.toString() ?? '';
    _calories.text = entry.calories?.toString() ?? '';
    _environment.text = entry.environment;
    _terrain.text = entry.terrain;
    _weather.text = entry.weather;
    _equipment.text = entry.equipment;
    _mood.text = entry.mood;
    _energy.text = entry.energy?.toString() ?? '';
    _notes.text = entry.notes;
    for (var i = 0; i < 5; i++) {
      final minutes =
          (entry.zoneSeconds.length > i ? entry.zoneSeconds[i] : 0) ~/ 60;
      _zoneMinutes[i].text = minutes == 0 ? '' : minutes.toString();
    }
  }

  Future<void> _saveEntry({bool showSnack = true}) async {
    final s = AppLocalizations.of(context);
    final entry =
        _entryForWorkout() ?? CardioEntry(workoutKey: widget.workoutKey);

    final durationSeconds = _parseDurationSeconds();
    if (durationSeconds <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.durationGreaterThanZero)));
      return;
    }

    entry
      ..activity = _activity.text.trim()
      ..durationSeconds = durationSeconds
      ..distanceKm = _tryParseDouble(_distance.text)
      ..elevationGainM = _tryParseDouble(_elevation.text)
      ..inclinePercent = _tryParseDouble(_incline.text)
      ..avgHeartRate = _tryParseInt(_avgHr.text)
      ..maxHeartRate = _tryParseInt(_maxHr.text)
      ..rpe = _tryParseDouble(_rpe.text)
      ..calories = _tryParseDouble(_calories.text)
      ..environment = _environment.text.trim()
      ..terrain = _terrain.text.trim()
      ..weather = _weather.text.trim()
      ..equipment = _equipment.text.trim()
      ..mood = _mood.text.trim()
      ..energy = _tryParseInt(_energy.text)
      ..notes = _notes.text.trim()
      ..zoneSeconds = _parseZoneSeconds()
      ..segments = entry.segments;

    if (entry.isInBox) {
      await entry.save();
    } else {
      await cbox.add(entry);
    }

    final w = workout
      ..totalSets = entry.segments.length
      ..totalReps = 0
      ..totalVolume = 0.0
      ..isCompleted = _isCompleted;
    await w.save();
    await _syncLinkedSchedulesFromWorkout(syncCompletion: true);
    if (!mounted) return;

    if (showSnack) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.cardioSaved)));
    }
    if (mounted) setState(() {});
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

  int _parseDurationSeconds() {
    final m = int.tryParse(_durationMin.text.trim()) ?? 0;
    final s = int.tryParse(_durationSec.text.trim()) ?? 0;
    final seconds = (m * 60) + s;
    return seconds;
  }

  List<int> _parseZoneSeconds() {
    return List<int>.generate(5, (i) {
      final m = int.tryParse(_zoneMinutes[i].text.trim()) ?? 0;
      return m * 60;
    });
  }

  double? _tryParseDouble(String input) {
    final v = input.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  int? _tryParseInt(String input) {
    final v = input.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  int _plannedTotalSeconds(CardioEntry entry) {
    return entry.segments.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  CardioSegment? _segmentAt(int index) {
    final entry = _entryForWorkout();
    if (entry == null) return null;
    if (index < 0 || index >= entry.segments.length) return null;
    return entry.segments[index];
  }

  void _startSession() {
    final s = AppLocalizations.of(context);
    final entry = _entryForWorkout();
    if (entry == null || entry.segments.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.cardioNeedSegments)));
      return;
    }

    _elapsedSeconds = 0;
    _currentSegmentIndex = 0;
    final firstDuration = entry.segments.first.durationSeconds;
    _segmentRemaining = firstDuration < 0 ? 0 : firstDuration;
    _isPaused = false;
    _lastPreAlertSegmentIndex = -1;
    _lastPostAlertSegmentIndex = -1;
    _flow = _CardioFlow.running;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickSession());
    _playSegmentChangeCue();
    setState(() {});
    unawaited(_updateNotification());
  }

  void _tickSession() {
    if (!mounted || _flow != _CardioFlow.running) return;
    if (_isPaused) return;
    if (_segmentRemaining <= 0) {
      final current = _segmentAt(_currentSegmentIndex);
      if ((current?.durationSeconds ?? 0) <= 0) {
        // Empty-duration intervals require manual progression.
        setState(() {
          _elapsedSeconds += 1;
        });
        unawaited(_updateNotification());
        return;
      }
      _advanceSegment();
      return;
    }
    setState(() {
      _segmentRemaining -= 1;
      _elapsedSeconds += 1;
    });
    if (_segmentRemaining > 0 && _segmentRemaining <= 3) {
      _playCountdownCue();
    }
    if (_segmentRemaining == 5) {
      _maybeShowPreSegmentAlert();
    }
    unawaited(_updateNotification());
    if (_segmentRemaining == 0) {
      final current = _segmentAt(_currentSegmentIndex);
      if ((current?.durationSeconds ?? 0) > 0) {
        _advanceSegment();
      }
    }
  }

  void _advanceSegment() {
    final entry = _entryForWorkout();
    if (entry == null) return;
    if (_currentSegmentIndex + 1 >= entry.segments.length) {
      _finishSession(fromSegmentEnd: true);
      return;
    }
    _currentSegmentIndex += 1;
    final segmentDuration = entry.segments[_currentSegmentIndex].durationSeconds;
    _segmentRemaining = segmentDuration < 0 ? 0 : segmentDuration;
    _playSegmentChangeCue();
    _maybeShowPostSegmentAlert();
    if (mounted) setState(() {});
    unawaited(_updateNotification());
  }

  void _finishSession({bool fromSegmentEnd = false}) {
    _timer?.cancel();
    _flow = _CardioFlow.summary;
    _isPaused = false;
    _isCompleted = true;
    _durationMin.text = (_elapsedSeconds ~/ 60).toString();
    _durationSec.text = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    if (fromSegmentEnd) {
      _playSegmentChangeCue();
    }
    if (mounted) setState(() {});
    unawaited(CardioNotificationService.instance.clear());
  }

  void _pauseSession() {
    if (_flow != _CardioFlow.running) return;
    setState(() => _isPaused = true);
    unawaited(_updateNotification());
  }

  void _resumeSession() {
    if (_flow != _CardioFlow.running) return;
    setState(() => _isPaused = false);
    unawaited(_updateNotification());
  }

  void _nextSegment() {
    if (_flow != _CardioFlow.running) return;
    _advanceSegment();
  }

  void _backToPlan() {
    _timer?.cancel();
    _flow = _CardioFlow.plan;
    _isPaused = false;
    setState(() {});
    unawaited(CardioNotificationService.instance.clear());
  }

  void _playCountdownCue() {
    if (_soundEnabled) {
      unawaited(
        _beepPlayer.stop().then(
          (_) => _beepPlayer.play(AssetSource(_shortBeepAsset)),
        ),
      );
    }
  }

  void _playSegmentChangeCue() {
    if (_soundEnabled) {
      unawaited(
        _beepPlayer.stop().then(
          (_) => _beepPlayer.play(AssetSource(_longBeepAsset)),
        ),
      );
    }
    if (_vibrateEnabled) {
      HapticFeedback.vibrate();
    }
  }

  String _formatDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  double? _currentSegmentIncline(CardioEntry? entry, CardioSegment? current) {
    return current?.inclinePercent ??
        _tryParseDouble(_incline.text) ??
        entry?.inclinePercent;
  }

  List<String> _segmentDetailsList(
    CardioSegment? segment, {
    double? fallbackIncline,
  }) {
    if (segment == null) return [];
    final details = <String>[];
    if (segment.distanceKm != null) {
      details.add('${segment.distanceKm!.toStringAsFixed(2)} km');
    }
    if (segment.targetSpeedKph != null) {
      details.add('${segment.targetSpeedKph!.toStringAsFixed(1)} km/h');
    }
    final incline = segment.inclinePercent ?? fallbackIncline;
    if (incline != null) {
      details.add('${incline.toStringAsFixed(1)} %');
    }
    return details;
  }

  String _segmentInfoText(
    CardioSegment? segment,
    AppLocalizations s, {
    double? fallbackIncline,
  }) {
    if (segment == null) return '-';
    final label = _segmentLabel(segment, s);
    final details = _segmentDetailsList(
      segment,
      fallbackIncline: fallbackIncline,
    );
    if (details.isEmpty) return label;
    return '$label ${details.join(' | ')}';
  }

  void _maybeShowPreSegmentAlert() {
    if (!mounted || !_isInBackground) return;
    if (_lastPreAlertSegmentIndex == _currentSegmentIndex) return;
    final next = _segmentAt(_currentSegmentIndex + 1);
    if (next == null) return;
    _lastPreAlertSegmentIndex = _currentSegmentIndex;
    final s = AppLocalizations.of(context);
    final entry = _entryForWorkout();
    final current = _segmentAt(_currentSegmentIndex);
    final currentInfo = _segmentInfoText(
      current,
      s,
      fallbackIncline: _currentSegmentIncline(entry, current),
    );
    final nextInfo = _segmentInfoText(next, s);
    final lines = <String>[
      '${s.currentSegmentLabel}: $currentInfo',
      '${s.nextSegmentLabel}: $nextInfo',
      'in 5s',
    ];
    unawaited(
      CardioNotificationService.instance.showSegmentAlert(
        title: '${s.nextSegmentLabel}: ${_segmentLabel(next, s)}',
        body: lines.join('\n'),
      ),
    );
    unawaited(
      CardioNotificationService.instance.showSegmentOverlay(
        title: '${s.nextSegmentLabel}: ${_segmentLabel(next, s)}',
        body: lines.join('\n'),
      ),
    );
  }

  void _maybeShowPostSegmentAlert() {
    if (!mounted || !_isInBackground) return;
    if (_lastPostAlertSegmentIndex == _currentSegmentIndex) return;
    final current = _segmentAt(_currentSegmentIndex);
    if (current == null) return;
    _lastPostAlertSegmentIndex = _currentSegmentIndex;
    final s = AppLocalizations.of(context);
    final entry = _entryForWorkout();
    final next = _segmentAt(_currentSegmentIndex + 1);
    final currentInfo = _segmentInfoText(
      current,
      s,
      fallbackIncline: _currentSegmentIncline(entry, current),
    );
    final lines = <String>[
      '${s.currentSegmentLabel}: $currentInfo',
      if (next != null) '${s.nextSegmentLabel}: ${_segmentInfoText(next, s)}',
      'started',
    ];
    unawaited(
      CardioNotificationService.instance.showSegmentAlert(
        title: '${s.currentSegmentLabel}: ${_segmentLabel(current, s)}',
        body: lines.join('\n'),
      ),
    );
    unawaited(
      CardioNotificationService.instance.showSegmentOverlay(
        title: '${s.currentSegmentLabel}: ${_segmentLabel(current, s)}',
        body: lines.join('\n'),
      ),
    );
  }

  Future<void> _updateNotification() async {
    if (!mounted || _flow != _CardioFlow.running) return;
    final s = AppLocalizations.of(context);
    final activity = _activity.text.trim();
    final workoutTitle = workout.title.trim();
    final baseTitle = activity.isNotEmpty
        ? activity
        : (workoutTitle.isNotEmpty ? workoutTitle : s.cardioWorkoutTitle);

    final entry = _entryForWorkout();
    final current = _segmentAt(_currentSegmentIndex);
    final next = _segmentAt(_currentSegmentIndex + 1);
    final segmentLabel = current == null
        ? s.noIntervalsYet
        : _segmentLabel(current, s);
    final elapsed = _formatDuration(_elapsedSeconds);
    final timeLeft = _formatDuration(_segmentRemaining);

    final currentIncline = _currentSegmentIncline(entry, current);
    final currentDetails = _segmentDetailsList(
      current,
      fallbackIncline: currentIncline,
    );
    final nextDetails = _segmentDetailsList(next);

    final bodyParts = <String>[];
    if (currentDetails.isNotEmpty) {
      bodyParts.add(currentDetails.join(' '));
    }
    if (next != null) {
      final nextLabel = _segmentLabel(next, s);
      final nextInfo = nextDetails.isEmpty
          ? nextLabel
          : '$nextLabel ${nextDetails.join(' | ')}';
      bodyParts.add('${s.nextSegmentLabel}: $nextInfo');
    }
    if (_isPaused || bodyParts.isEmpty) {
      bodyParts.add('${s.elapsedLabel}: $elapsed');
    }

    final title = current == null
        ? baseTitle
        : _isPaused
        ? '${s.pause}: $segmentLabel'
        : '$segmentLabel $timeLeft';
    final body = bodyParts.join(' | ');

    await CardioNotificationService.instance.showStatus(
      title: title,
      body: body,
    );
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
    final w = workout
      ..date = newDate
      ..title = titleCtrl.text.trim()
      ..notes = notesCtrl.text.trim();
    await w.save();
    await _syncLinkedSchedulesFromWorkout(syncDate: true);
    if (!mounted) return;
    setState(() {});
  }

  String _segmentLabel(CardioSegment seg, AppLocalizations s) {
    if (seg.label.trim().isNotEmpty) return seg.label.trim();
    return _segmentTypeLabel(seg.type, s);
  }

  String _segmentTypeLabel(String type, AppLocalizations s) {
    switch (type) {
      case 'warmup':
        return s.segmentWarmup;
      case 'work':
        return s.segmentWork;
      case 'recovery':
        return s.segmentRecovery;
      case 'cooldown':
        return s.segmentCooldown;
      case 'easy':
        return s.segmentEasy;
      default:
        return s.segmentOther;
    }
  }

  Future<void> _editSegment({CardioSegment? existing, int? index}) async {
    final s = AppLocalizations.of(context);
    final seg = existing ?? CardioSegment();
    final labelCtrl = TextEditingController(text: seg.label);
    final minutesCtrl = TextEditingController(
      text: (seg.durationSeconds ~/ 60).toString(),
    );
    final secondsCtrl = TextEditingController(
      text: (seg.durationSeconds % 60).toString().padLeft(2, '0'),
    );
    final distanceCtrl = TextEditingController(
      text: seg.distanceKm?.toString() ?? '',
    );
    final targetSpeedCtrl = TextEditingController(
      text: seg.targetSpeedKph?.toString() ?? '',
    );
    final inclineCtrl = TextEditingController(
      text: seg.inclinePercent?.toString() ?? '',
    );
    final rpeCtrl = TextEditingController(text: seg.rpe?.toString() ?? '');
    final notesCtrl = TextEditingController(text: seg.notes);
    var selectedType = seg.type;

    final result = await showModalBottomSheet<CardioSegment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final bottomInset = media.viewInsets.bottom;
        final safeBottom = media.viewPadding.bottom;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + safeBottom,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? s.addInterval : s.editInterval,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(labelText: s.segmentLabel),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(labelText: s.segmentType),
                    items: [
                      DropdownMenuItem(
                        value: 'warmup',
                        child: Text(s.segmentWarmup),
                      ),
                      DropdownMenuItem(
                        value: 'work',
                        child: Text(s.segmentWork),
                      ),
                      DropdownMenuItem(
                        value: 'recovery',
                        child: Text(s.segmentRecovery),
                      ),
                      DropdownMenuItem(
                        value: 'cooldown',
                        child: Text(s.segmentCooldown),
                      ),
                      DropdownMenuItem(
                        value: 'easy',
                        child: Text(s.segmentEasy),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(s.segmentOther),
                      ),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => selectedType = v ?? 'work'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minutesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: s.minutes),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: secondsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: s.seconds),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: distanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: s.distanceKm),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetSpeedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: s.targetSpeedKph),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: inclineCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: s.inclinePercent),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rpeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: s.rpeOptional),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: s.notes),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(s.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final minutes =
                              int.tryParse(minutesCtrl.text.trim()) ?? 0;
                          final seconds =
                              int.tryParse(secondsCtrl.text.trim()) ?? 0;
                          final total = (minutes * 60) + seconds;
                          final normalizedTotal = total < 0 ? 0 : total;
                          Navigator.pop(
                            ctx,
                            CardioSegment(
                              label: labelCtrl.text.trim(),
                              type: selectedType,
                              durationSeconds: normalizedTotal,
                              distanceKm: _tryParseDouble(distanceCtrl.text),
                              targetSpeedKph: _tryParseDouble(
                                targetSpeedCtrl.text,
                              ),
                              inclinePercent: _tryParseDouble(inclineCtrl.text),
                              rpe: _tryParseDouble(rpeCtrl.text),
                              notes: notesCtrl.text.trim(),
                            ),
                          );
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    final entry = _entryForWorkout();
    if (entry == null) return;
    if (index == null) {
      entry.segments.add(result);
    } else {
      entry.segments[index] = result;
    }
    await entry.save();
    final w = workout..totalSets = entry.segments.length;
    await w.save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteSegment(int index) async {
    final entry = _entryForWorkout();
    if (entry == null) return;
    if (index < 0 || index >= entry.segments.length) return;
    entry.segments.removeAt(index);
    await entry.save();
    final w = workout..totalSets = entry.segments.length;
    await w.save();
    if (mounted) setState(() {});
  }

  Future<void> _duplicateSegment(int index) async {
    final entry = _entryForWorkout();
    if (entry == null) return;
    if (index < 0 || index >= entry.segments.length) return;
    final duplicate = entry.segments[index].copy();
    entry.segments.insert(index + 1, duplicate);
    await entry.save();
    final w = workout..totalSets = entry.segments.length;
    await w.save();
    if (mounted) setState(() {});
  }

  void _reorderSegments(CardioEntry entry, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= entry.segments.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= entry.segments.length) return;
    final moved = entry.segments.removeAt(oldIndex);
    entry.segments.insert(newIndex, moved);
    if (mounted) setState(() {});
    unawaited(entry.save());
  }

  Future<void> _applyTemplate() async {
    final s = AppLocalizations.of(context);
    final templates = tbox.values.toList();
    if (templates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.noCardioTemplates)));
      return;
    }

    final picked = await showModalBottomSheet<CardioTemplate>(
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
                s.cardioTemplatePickTitle,
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
                    final duration = _formatDuration(t.durationSeconds);
                    final distance = t.distanceKm != null
                        ? ' - ${t.distanceKm} km'
                        : '';
                    return ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(t.name),
                      subtitle: Text(
                        '${t.activity} - $duration$distance'.trim(),
                      ),
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
    _activity.text = picked.activity;
    _durationMin.text = (picked.durationSeconds ~/ 60).toString();
    _durationSec.text = (picked.durationSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    _distance.text = picked.distanceKm?.toString() ?? '';
    _elevation.text = picked.elevationGainM?.toString() ?? '';
    _incline.text = picked.inclinePercent?.toString() ?? '';
    _avgHr.text = picked.avgHeartRate?.toString() ?? '';
    _maxHr.text = picked.maxHeartRate?.toString() ?? '';
    _rpe.text = picked.rpe?.toString() ?? '';
    _calories.text = picked.calories?.toString() ?? '';
    _environment.text = picked.environment;
    _terrain.text = picked.terrain;
    _weather.text = picked.weather;
    _equipment.text = picked.equipment;
    _mood.text = picked.mood;
    _energy.text = picked.energy?.toString() ?? '';
    _notes.text = picked.notes;
    for (var i = 0; i < 5; i++) {
      final minutes =
          (picked.zoneSeconds.length > i ? picked.zoneSeconds[i] : 0) ~/ 60;
      _zoneMinutes[i].text = minutes == 0 ? '' : minutes.toString();
    }

    final entry = _entryForWorkout();
    if (entry != null) {
      entry
        ..segments = picked.segments.map((s) => s.copy()).toList()
        ..activity = picked.activity;
      await entry.save();
      final w = workout..totalSets = entry.segments.length;
      await w.save();
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveAsTemplate() async {
    final s = AppLocalizations.of(context);
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.saveAsTemplate),
            content: TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: s.templateName),
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
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final entry = _entryForWorkout();
    if (entry == null) return;

    final tmpl = CardioTemplate(
      name: name,
      activity: _activity.text.trim(),
      durationSeconds: _parseDurationSeconds(),
      distanceKm: _tryParseDouble(_distance.text),
      elevationGainM: _tryParseDouble(_elevation.text),
      inclinePercent: _tryParseDouble(_incline.text),
      avgHeartRate: _tryParseInt(_avgHr.text),
      maxHeartRate: _tryParseInt(_maxHr.text),
      rpe: _tryParseDouble(_rpe.text),
      calories: _tryParseDouble(_calories.text),
      zoneSeconds: _parseZoneSeconds(),
      segments: entry.segments.map((s) => s.copy()).toList(),
      environment: _environment.text.trim(),
      terrain: _terrain.text.trim(),
      weather: _weather.text.trim(),
      equipment: _equipment.text.trim(),
      mood: _mood.text.trim(),
      energy: _tryParseInt(_energy.text),
      notes: _notes.text.trim(),
    );

    await tbox.add(tmpl);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.templateCreated)));
  }

  CardioEntry _buildExportEntry(CardioEntry base) {
    final plannedSeconds = _plannedTotalSeconds(base);
    final durationSeconds = _parseDurationSeconds();
    final effectiveDuration = durationSeconds > 0
        ? durationSeconds
        : (base.durationSeconds > 0 ? base.durationSeconds : plannedSeconds);

    return CardioEntry(
      workoutKey: base.workoutKey,
      activity: _activity.text.trim(),
      durationSeconds: effectiveDuration,
      distanceKm: _tryParseDouble(_distance.text),
      elevationGainM: _tryParseDouble(_elevation.text),
      inclinePercent: _tryParseDouble(_incline.text),
      avgHeartRate: _tryParseInt(_avgHr.text),
      maxHeartRate: _tryParseInt(_maxHr.text),
      rpe: _tryParseDouble(_rpe.text),
      calories: _tryParseDouble(_calories.text),
      zoneSeconds: _parseZoneSeconds(),
      segments: base.segments.map((s) => s.copy()).toList(),
      environment: _environment.text.trim(),
      terrain: _terrain.text.trim(),
      weather: _weather.text.trim(),
      equipment: _equipment.text.trim(),
      mood: _mood.text.trim(),
      energy: _tryParseInt(_energy.text),
      notes: _notes.text.trim(),
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
    try {
      final baseEntry =
          _entryForWorkout() ?? CardioEntry(workoutKey: widget.workoutKey);
      final snapshot = _buildExportEntry(baseEntry);

      final action = await _pickPdfExportAction();
      if (action == null) return;
      if (action == 'share') {
        await shareCardioWorkoutPdf(workout, snapshot);
      } else if (action == 'download') {
        final location = await saveCardioWorkoutPdfToDevice(workout, snapshot);
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
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'export_pdf',
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf),
          title: Text(s.exportSharePdf),
        ),
      ),
    ];

    if (_flow == _CardioFlow.plan) {
      items.add(const PopupMenuDivider());
      items.add(
        PopupMenuItem(
          value: 'apply_template',
          child: ListTile(
            leading: const Icon(Icons.file_open),
            title: Text(s.applyTemplate),
          ),
        ),
      );
      items.add(
        PopupMenuItem(
          value: 'save_template',
          child: ListTile(
            leading: const Icon(Icons.bookmark_add),
            title: Text(s.saveAsTemplate),
          ),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final actions = <Widget>[];

    if (_flow != _CardioFlow.running) {
      actions.add(
        IconButton(
          tooltip: s.editTitleNotes,
          onPressed: _editHeader,
          icon: const Icon(Icons.edit_note),
        ),
      );
    }

    if (_flow != _CardioFlow.running) {
      actions.add(
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'export_pdf':
                await _exportPdfWithChoice();
                break;
              case 'apply_template':
                _applyTemplate();
                break;
              case 'save_template':
                _saveAsTemplate();
                break;
            }
          },
          itemBuilder: (_) => _buildActionMenuItems(s),
        ),
      );
    }

    Widget body;
    switch (_flow) {
      case _CardioFlow.plan:
        body = _buildPlan(s);
        break;
      case _CardioFlow.running:
        body = _buildRunning(s);
        break;
      case _CardioFlow.summary:
        body = _buildSummary(s);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.cardioWorkoutTitle),
        centerTitle: true,
        actions: actions,
      ),
      body: SafeArea(bottom: true, child: body),
    );
  }

  Widget _buildPlan(AppLocalizations s) {
    final entry = _entryForWorkout();
    final plannedSeconds = entry == null ? 0 : _plannedTotalSeconds(entry);
    final plannedLabel = plannedSeconds > 0
        ? _formatDuration(plannedSeconds)
        : s.noDuration;
    final cardioExercises = _cardioExerciseNames();
    final distanceKm = _tryParseDouble(_distance.text);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _CardioSummary(
          date: workout.date,
          title: workout.title,
          durationSeconds: plannedSeconds,
          distanceKm: distanceKm,
        ),
        const SizedBox(height: 12),
        Text(
          s.cardioPlanTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text('${s.plannedDurationLabel}: $plannedLabel'),
        if (entry != null) Text('${s.segmentsLabel}: ${entry.segments.length}'),
        const SizedBox(height: 12),
        _SectionCard(
          title: s.cardioDetailsTitle,
          child: Column(
            children: [
              Autocomplete<String>(
                optionsBuilder: (te) {
                  final q = te.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<String>.empty();
                  return cardioExercises.where(
                    (n) => n.toLowerCase().contains(q),
                  );
                },
                fieldViewBuilder: (context, textCtrl, focusNode, submit) {
                  textCtrl.text = _activity.text;
                  textCtrl.selection = TextSelection.collapsed(
                    offset: textCtrl.text.length,
                  );
                  textCtrl.addListener(() {
                    if (textCtrl.text != _activity.text) {
                      _activity.text = textCtrl.text;
                      _activity.selection = textCtrl.selection;
                    }
                  });
                  return TextField(
                    controller: textCtrl,
                    focusNode: focusNode,
                    decoration: InputDecoration(labelText: s.activityLabel),
                    onSubmitted: (_) => submit(),
                  );
                },
                onSelected: (val) => _activity.text = val,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: s.intervalsTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entry == null || entry.segments.isEmpty)
                Text(s.noIntervalsYet),
              if (entry != null && entry.segments.isNotEmpty)
                _buildSegmentsList(entry, s, editable: true),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => _editSegment(),
                icon: const Icon(Icons.add),
                label: Text(s.addInterval),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addWorkRestPair,
                icon: const Icon(Icons.swap_horiz),
                label: Text(s.addWorkRestPair),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: s.timerAlertsTitle,
          child: Column(
            children: [
              SwitchListTile(
                value: _soundEnabled,
                onChanged: (v) => setState(() => _soundEnabled = v),
                title: Text(s.soundLabel),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _vibrateEnabled,
                onChanged: (v) => setState(() => _vibrateEnabled = v),
                title: Text(s.vibrationLabel),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _startSession,
          icon: const Icon(Icons.play_arrow),
          label: Text(s.startWorkout),
        ),
        TextButton(onPressed: _openSummary, child: Text(s.logManually)),
      ],
    );
  }

  Widget _buildRunning(AppLocalizations s) {
    final entry = _entryForWorkout();
    final totalSegments = entry?.segments.length ?? 0;
    final current = _segmentAt(_currentSegmentIndex);
    final next = _segmentAt(_currentSegmentIndex + 1);
    final currentLabel = current == null
        ? s.noIntervalsYet
        : _segmentLabel(current, s);
    final totalSeconds = current?.durationSeconds ?? 0;
    final progress = totalSeconds <= 0
        ? 0.0
        : 1 - (_segmentRemaining / totalSeconds);
    final speedKph = current?.targetSpeedKph;
    final inclinePercent =
        current?.inclinePercent ??
        _tryParseDouble(_incline.text) ??
        entry?.inclinePercent;
    final nextSpeedKph = next?.targetSpeedKph;
    final nextInclinePercent = next?.inclinePercent;
    final nextDetails = <String>[
      if (next?.distanceKm != null)
        '${next!.distanceKm!.toStringAsFixed(2)} km',
      if (nextSpeedKph != null) '${nextSpeedKph.toStringAsFixed(1)} km/h',
      if (nextInclinePercent != null)
        '${nextInclinePercent.toStringAsFixed(1)} %',
    ];
    final infoItems = <Widget>[
      if (current?.distanceKm != null)
        _RunningInfoItem(
          icon: Icons.straighten,
          label: s.distanceKm,
          value: '${current!.distanceKm!.toStringAsFixed(2)} km',
        ),
      if (speedKph != null)
        _RunningInfoItem(
          icon: Icons.speed,
          label: s.targetSpeedKph,
          value: '${speedKph.toStringAsFixed(1)} km/h',
        ),
      if (inclinePercent != null)
        _RunningInfoItem(
          icon: Icons.trending_up,
          label: s.inclinePercent,
          value: '${inclinePercent.toStringAsFixed(1)} %',
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _CardioSummary(
          date: workout.date,
          title: workout.title,
          durationSeconds: _elapsedSeconds,
          distanceKm: _tryParseDouble(_distance.text),
        ),
        const SizedBox(height: 16),
        Text(
          s.currentSegmentLabel,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Text(
          currentLabel,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _formatDuration(_segmentRemaining),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
        const SizedBox(height: 12),
        Text(
          '${s.elapsedLabel}: ${_formatDuration(_elapsedSeconds)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (infoItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: infoItems,
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 6),
          Text(
            '${s.nextSegmentLabel}: ${_segmentLabel(next, s)}',
            textAlign: TextAlign.center,
          ),
          if (nextDetails.isNotEmpty)
            Text(
              nextDetails.join(' | '),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (totalSegments > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${s.segmentCountLabel}: ${_currentSegmentIndex + 1}/$totalSegments',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _isPaused ? _resumeSession : _pauseSession,
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(_isPaused ? s.resume : s.pause),
            ),
            OutlinedButton.icon(
              onPressed: _nextSegment,
              icon: const Icon(Icons.skip_next),
              label: Text(s.nextSegmentLabel),
            ),
            TextButton.icon(
              onPressed: _finishSession,
              icon: const Icon(Icons.stop),
              label: Text(s.endWorkout),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(AppLocalizations s) {
    final entry = _entryForWorkout();
    final durationSeconds = _parseDurationSeconds();
    final distanceKm = _tryParseDouble(_distance.text);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          s.summaryTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _CardioSummary(
          date: workout.date,
          title: workout.title,
          durationSeconds: durationSeconds,
          distanceKm: distanceKm,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: s.summaryDetailsTitle,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationMin,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: s.minutes),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _durationSec,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: s.seconds),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: s.distanceKm),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rpe,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: s.rpeOptional),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(labelText: s.notes),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _isCompleted,
          onChanged: (v) async {
            setState(() => _isCompleted = v);
            final w = workout..isCompleted = v;
            await w.save();
            await _syncLinkedSchedulesFromWorkout(syncCompletion: true);
          },
          title: Text(s.workoutCompleted),
          subtitle: Text(s.workoutCompletedHint),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        if (entry != null)
          _SectionCard(
            title: s.intervalsTitle,
            child: _buildSegmentsList(entry, s, editable: false),
          ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: Text(s.advancedDetailsTitle),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildAdvancedDetails(s),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _backToPlan,
                child: Text(s.editPlan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _saveEntry, child: Text(s.save)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentsList(
    CardioEntry entry,
    AppLocalizations s, {
    required bool editable,
  }) {
    if (entry.segments.isEmpty) {
      return Text(s.noIntervalsYet);
    }

    final items = entry.segments.asMap().entries.map((entryMap) {
      final idx = entryMap.key;
      final seg = entryMap.value;
      final duration = seg.durationSeconds > 0
          ? _formatDuration(seg.durationSeconds)
          : s.noDuration;
      final details = <String>[
        duration,
        if (seg.distanceKm != null) '${seg.distanceKm} km',
        if (seg.targetSpeedKph != null) '${seg.targetSpeedKph} km/h',
        if (seg.inclinePercent != null)
          '${seg.inclinePercent!.toStringAsFixed(1)} %',
      ];
      return Card(
        key: ObjectKey(seg),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          title: Text(_segmentLabel(seg, s)),
          subtitle: DefaultTextStyle.merge(
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            child: Text(details.join(' - ')),
          ),
          trailing: editable
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            await _editSegment(existing: seg, index: idx);
                            break;
                          case 'duplicate':
                            await _duplicateSegment(idx);
                            break;
                          case 'delete':
                            await _deleteSegment(idx);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: const Icon(Icons.edit),
                            title: Text(s.edit),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: ListTile(
                            leading: const Icon(Icons.copy),
                            title: Text(s.duplicate),
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
                    const SizedBox(width: 4),
                    ReorderableDragStartListener(
                      index: idx,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.drag_indicator),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      );
    }).toList();

    if (!editable) {
      return Column(children: items);
    }

    return ReorderableListView(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) =>
          _reorderSegments(entry, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return Material(color: Colors.transparent, child: child);
      },
      children: items,
    );
  }

  Widget _buildAdvancedDetails(AppLocalizations s) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _elevation,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: s.elevationGainM),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _incline,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: s.inclinePercent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _avgHr,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.avgHeartRate),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxHr,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.maxHeartRate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _calories,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s.caloriesLabel),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            s.heartRateZones,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < 5; i++) ...[
          TextField(
            controller: _zoneMinutes[i],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${s.zoneLabel} ${i + 1} (${s.minutes})',
            ),
          ),
          if (i < 4) const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _environment,
          decoration: InputDecoration(labelText: s.environmentLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _terrain,
          decoration: InputDecoration(labelText: s.terrainLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _weather,
          decoration: InputDecoration(labelText: s.weatherLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _equipment,
          decoration: InputDecoration(labelText: s.equipmentLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _mood,
          decoration: InputDecoration(labelText: s.moodLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _energy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: s.energyLabel),
        ),
      ],
    );
  }

  List<String> _cardioExerciseNames() {
    final names =
        ebox.values
            .where((e) => e.category.trim().toLowerCase() == 'cardio')
            .map((e) => e.name)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  void _openSummary() {
    _timer?.cancel();
    _flow = _CardioFlow.summary;
    _isPaused = false;
    setState(() {});
    unawaited(CardioNotificationService.instance.clear());
  }

  Future<void> _addWorkRestPair() async {
    final entry = _entryForWorkout();
    if (entry == null) return;
    entry.segments.addAll([
      CardioSegment(type: 'work', durationSeconds: 60),
      CardioSegment(type: 'recovery', durationSeconds: 60),
    ]);
    await entry.save();
    final w = workout..totalSets = entry.segments.length;
    await w.save();
    if (mounted) setState(() {});
  }
}

class _CardioSummary extends StatelessWidget {
  const _CardioSummary({
    required this.date,
    required this.title,
    required this.durationSeconds,
    required this.distanceKm,
  });

  final DateTime date;
  final String title;
  final int durationSeconds;
  final double? distanceKm;

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dateStr = '${_two(date.day)}.${_two(date.month)}.${date.year}.';
    final duration = durationSeconds > 0
        ? '${(durationSeconds ~/ 60)}${s.minutesShort}'
        : s.noDuration;
    final distance = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(2)} km'
        : s.noDistance;
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
          '${s.date}: $dateStr - $duration - $distance',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _RunningInfoItem extends StatelessWidget {
  const _RunningInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
