import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/workout.dart';
import 'models/set_entry.dart';
import 'models/exercise.dart';
import 'models/workout_template.dart';
import 'models/readiness_entry.dart';
import 'models/cardio_entry.dart';
import 'models/cardio_template.dart';
import 'models/scheduled_workout.dart';

import 'pages/home_page.dart';
import 'pages/statistics_page.dart';
import 'services/app_capture_service.dart';
import 'services/app_logger.dart';
import 'services/cardio_notification_service.dart';
import 'services/workout_reminder_service.dart';

// lokalizacija
import 'l10n/l10n.dart';

const _charcoal = Color(0xFF1E1F23);
const _lime = Color(0xFFA6E65A);
const _limeDark = Color(0xFF7DAE3E);
const _surface = Color(0xFF141518);
const _card = Color(0xFF1C1E22);
const _text = Color(0xFFECEFF4);
const _muted = Color(0xFF9CA3AF);
const _divider = Color(0xFF2A2D33);
const _notificationInitTimeout = Duration(seconds: 8);

typedef AppBootstrap = Future<void> Function({void Function(String stage)? onStage});

Future<void>? _notificationInitFuture;

const List<({String name, String category})> _defaultExercises = [
  (name: 'Bench Press', category: 'Chest'),
  (name: 'Incline Bench Press', category: 'Chest'),
  (name: 'Dumbbell Bench Press', category: 'Chest'),
  (name: 'Dumbbell Fly', category: 'Chest'),
  (name: 'Dip', category: 'Chest'),
  (name: 'Push-Up', category: 'Chest'),
  (name: 'Squat', category: 'Legs'),
  (name: 'Bulgarian Split Squat', category: 'Legs'),
  (name: 'Walking Lunge', category: 'Legs'),
  (name: 'Leg Press', category: 'Legs'),
  (name: 'Leg Curl', category: 'Legs'),
  (name: 'Romanian Deadlift', category: 'Legs'),
  (name: 'Calf Raise', category: 'Calves'),
  (name: 'Deadlift', category: 'Back'),
  (name: 'Pull Up', category: 'Back'),
  (name: 'Chin Up', category: 'Back'),
  (name: 'Lat Pulldown', category: 'Back'),
  (name: 'Seated Cable Row', category: 'Back'),
  (name: 'Overhead Press', category: 'Shoulders'),
  (name: 'Lateral Raise', category: 'Shoulders'),
  (name: 'Face Pull', category: 'Shoulders'),
  (name: 'Barbell Row', category: 'Back'),
  (name: 'Biceps Curl', category: 'Arms'),
  (name: 'Hammer Curl', category: 'Arms'),
  (name: 'Triceps Pushdown', category: 'Arms'),
  (name: 'Skullcrusher', category: 'Arms'),
  (name: 'Hip Thrust', category: 'Glutes'),
  (name: 'Plank', category: 'Core'),
  (name: 'Hanging Leg Raise', category: 'Core'),
  (name: 'Russian Twist', category: 'Core'),
  (name: 'Kettlebell Swing', category: 'Full Body'),
  (name: "Farmer's Walk", category: 'Full Body'),
  (name: 'Rowing Machine', category: 'Cardio'),
  (name: 'Cycling', category: 'Cardio'),
  (name: 'Treadmill Run', category: 'Cardio'),
  (name: 'Jump Rope', category: 'Cardio'),
];

Future<void> _ensureDefaultExercises(Box<Exercise> ebox) async {
  final existing = ebox.values.map((e) => e.name.trim().toLowerCase()).toSet();
  final toAdd = _defaultExercises.where((e) => !existing.contains(e.name.toLowerCase())).toList();
  if (toAdd.isEmpty) return;
  await ebox.addAll(toAdd.map((e) => Exercise(name: e.name, category: e.category)));
}

int _segmentsTotalSeconds(List<CardioSegment> segments) {
  var total = 0;
  for (final segment in segments) {
    total += segment.durationSeconds;
  }
  return total;
}

CardioTemplate _cardioTemplate({
  required String name,
  required String activity,
  required List<CardioSegment> segments,
  String notes = '',
}) {
  return CardioTemplate(
    name: name,
    activity: activity,
    durationSeconds: _segmentsTotalSeconds(segments),
    segments: segments,
    notes: notes,
  );
}

List<CardioTemplate> _buildDefaultCardioTemplates() {
  return [
    _cardioTemplate(
      name: 'Easy Run 30 min',
      activity: 'Treadmill Run',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 5 * 60),
        CardioSegment(type: 'easy', durationSeconds: 20 * 60),
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Steady easy pace.',
    ),
    _cardioTemplate(
      name: 'Run Intervals 6x2 min',
      activity: 'Treadmill Run',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 8 * 60),
        for (var i = 0; i < 6; i++) ...[
          CardioSegment(type: 'work', durationSeconds: 2 * 60),
          CardioSegment(type: 'recovery', durationSeconds: 90),
        ],
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Hard effort on work segments.',
    ),
    _cardioTemplate(
      name: 'Cycling HIIT 10x30/60',
      activity: 'Cycling',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 5 * 60),
        for (var i = 0; i < 10; i++) ...[
          CardioSegment(type: 'work', durationSeconds: 30),
          CardioSegment(type: 'recovery', durationSeconds: 60),
        ],
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Strong cadence on work intervals.',
    ),
    _cardioTemplate(
      name: 'Jump Rope Tabata',
      activity: 'Jump Rope',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 3 * 60),
        for (var i = 0; i < 8; i++) ...[
          CardioSegment(type: 'work', durationSeconds: 20),
          CardioSegment(type: 'recovery', durationSeconds: 10),
        ],
        CardioSegment(type: 'cooldown', durationSeconds: 2 * 60),
      ],
      notes: 'Fast, controlled rhythm.',
    ),
    _cardioTemplate(
      name: 'Rowing Intervals 4x4 min',
      activity: 'Rowing Machine',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 5 * 60),
        for (var i = 0; i < 4; i++) ...[
          CardioSegment(type: 'work', durationSeconds: 4 * 60),
          CardioSegment(type: 'recovery', durationSeconds: 2 * 60),
        ],
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Sustainable hard effort.',
    ),
    _cardioTemplate(
      name: 'Cycling Endurance 45 min',
      activity: 'Cycling',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 5 * 60),
        CardioSegment(type: 'easy', durationSeconds: 35 * 60),
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Easy steady cadence.',
    ),
    _cardioTemplate(
      name: 'Treadmill Pyramid 1-2-3-2-1',
      activity: 'Treadmill Run',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 6 * 60),
        CardioSegment(type: 'work', durationSeconds: 60),
        CardioSegment(type: 'recovery', durationSeconds: 60),
        CardioSegment(type: 'work', durationSeconds: 2 * 60),
        CardioSegment(type: 'recovery', durationSeconds: 60),
        CardioSegment(type: 'work', durationSeconds: 3 * 60),
        CardioSegment(type: 'recovery', durationSeconds: 60),
        CardioSegment(type: 'work', durationSeconds: 2 * 60),
        CardioSegment(type: 'recovery', durationSeconds: 60),
        CardioSegment(type: 'work', durationSeconds: 60),
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Build and back down effort.',
    ),
    _cardioTemplate(
      name: 'Incline Walk 20 min',
      activity: 'Treadmill Run',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 3 * 60),
        CardioSegment(type: 'easy', durationSeconds: 14 * 60),
        CardioSegment(type: 'cooldown', durationSeconds: 3 * 60),
      ],
      notes: 'Set a steady incline.',
    ),
    _cardioTemplate(
      name: 'Recovery Spin 25 min',
      activity: 'Cycling',
      segments: [
        CardioSegment(type: 'easy', durationSeconds: 5 * 60),
        CardioSegment(type: 'easy', durationSeconds: 15 * 60),
        CardioSegment(type: 'cooldown', durationSeconds: 5 * 60),
      ],
      notes: 'Very easy effort.',
    ),
    _cardioTemplate(
      name: 'Jump Rope 10x40/20',
      activity: 'Jump Rope',
      segments: [
        CardioSegment(type: 'warmup', durationSeconds: 3 * 60),
        for (var i = 0; i < 10; i++) ...[
          CardioSegment(type: 'work', durationSeconds: 40),
          CardioSegment(type: 'recovery', durationSeconds: 20),
        ],
        CardioSegment(type: 'cooldown', durationSeconds: 2 * 60),
      ],
      notes: 'Light, quick jumps.',
    ),
  ];
}

Future<void> _ensureDefaultCardioTemplates(Box<CardioTemplate> tbox) async {
  final existing = tbox.values.map((t) => t.name.trim().toLowerCase()).toSet();
  final defaults = _buildDefaultCardioTemplates();
  final toAdd = defaults.where((t) => !existing.contains(t.name.trim().toLowerCase())).toList();
  if (toAdd.isEmpty) return;
  await tbox.addAll(toAdd);
}

Future<void> _syncCardioTemplateDurations(Box<CardioTemplate> tbox) async {
  for (final template in tbox.values) {
    final planned = _segmentsTotalSeconds(template.segments);
    if (template.durationSeconds != planned) {
      template.durationSeconds = planned;
      await template.save();
    }
  }
}

Future<void> _initNotifications() async {
  try {
    await CardioNotificationService.instance.init();
    await WorkoutReminderService.instance.init();
    AppLogger.info('Notification services initialized');
  } catch (error, stackTrace) {
    AppLogger.error('Notification init failed', error: error, stackTrace: stackTrace);
  }
}

void _startNotificationInit() {
  _notificationInitFuture ??= _initNotifications()
      .timeout(_notificationInitTimeout, onTimeout: () {
        AppLogger.warn(
          'Notification init timed out',
          context: <String, Object?>{'seconds': _notificationInitTimeout.inSeconds},
        );
      })
      .catchError((Object error, StackTrace stackTrace) {
        AppLogger.error('Notification init failed', error: error, stackTrace: stackTrace);
      });
}

Future<void> _runInitStep(
  String stage,
  Future<void> Function() step, {
  void Function(String stage)? onStage,
}) async {
  onStage?.call(stage);
  AppLogger.info('Startup stage started', context: <String, Object?>{'stage': stage});
  try {
    await step();
    AppLogger.info('Startup stage completed', context: <String, Object?>{'stage': stage});
  } catch (error, stackTrace) {
    AppLogger.error(
      'Startup stage failed',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{'stage': stage},
    );
    rethrow;
  }
}

void _configureGlobalErrorLogging() {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Unhandled Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
      context: <String, Object?>{'library': details.library ?? 'unknown'},
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    AppLogger.error(
      'Unhandled platform error',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  };
}

void _registerHiveAdapters() {
  void register<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  register(WorkoutAdapter());
  register(SetEntryAdapter());
  register(WorkoutTemplateAdapter());
  register(TemplateSetAdapter());
  register(ExerciseAdapter());
  register(ReadinessEntryAdapter());
  register(CardioEntryAdapter());
  register(CardioSegmentAdapter());
  register(CardioTemplateAdapter());
  register(ScheduledWorkoutAdapter());
}

Future<void> _openBoxes() async {
  await Hive.openBox<Workout>('workouts');
  await Hive.openBox<SetEntry>('sets');
  await Hive.openBox<WorkoutTemplate>('templates');
  await Hive.openBox<Exercise>('exercises');
  await Hive.openBox<ReadinessEntry>('readiness');
  await Hive.openBox('settings');
  await Hive.openBox<CardioEntry>('cardio_entries');
  await Hive.openBox<CardioTemplate>('cardio_templates');
  await Hive.openBox<ScheduledWorkout>('scheduled_workouts');
}

Future<void> _seedDefaults() async {
  // Seed default exercises (optional).
  final ebox = Hive.box<Exercise>('exercises');
  await _ensureDefaultExercises(ebox);
  final ctbox = Hive.box<CardioTemplate>('cardio_templates');
  await _ensureDefaultCardioTemplates(ctbox);
  await _syncCardioTemplateDurations(ctbox);
}

Future<void> _initApp({void Function(String stage)? onStage}) async {
  _startNotificationInit();
  await _runInitStep(
    'Initializing local storage',
    () async {
      await Hive.initFlutter();
      _registerHiveAdapters();
    },
    onStage: onStage,
  );
  await _runInitStep('Opening data boxes', _openBoxes, onStage: onStage);
  await _runInitStep('Preparing default data', _seedDefaults, onStage: onStage);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorLogging();
  AppLogger.info('App process started');
  runApp(WorkoutLoggerApp(bootstrap: _initApp));
}

class WorkoutLoggerApp extends StatelessWidget {
  const WorkoutLoggerApp({super.key, required this.bootstrap});

  final AppBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: _lime,
      onPrimary: _charcoal,
      primaryContainer: _limeDark,
      onPrimaryContainer: _charcoal,
      secondary: _charcoal,
      onSecondary: _text,
      secondaryContainer: Color(0xFF2A2C31),
      onSecondaryContainer: _text,
      tertiary: _limeDark,
      onTertiary: _charcoal,
      tertiaryContainer: Color(0xFF2A330F),
      onTertiaryContainer: _text,
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      errorContainer: Color(0xFF8C1D18),
      onErrorContainer: Color(0xFFF9DEDC),
      surface: _surface,
      onSurface: _text,
      surfaceVariant: Color(0xFF1B1D22),
      onSurfaceVariant: _text,
      outline: _divider,
      outlineVariant: Color(0xFF3A3D45),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE8EAED),
      onInverseSurface: Color(0xFF111318),
      inversePrimary: _lime,
    );

    return WithForegroundTask(
      child: RepaintBoundary(
        key: AppCaptureService.boundaryKey,
        child: MaterialApp(
          title: 'GymNotes',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: _surface,
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: _charcoal,
            contentTextStyle: TextStyle(color: _lime),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: _surface,
            foregroundColor: _text,
            elevation: 0,
            surfaceTintColor: _surface,
          ),
          cardTheme: const CardThemeData(
            color: _card,
            surfaceTintColor: _card,
            elevation: 0,
          ),
          dividerTheme: const DividerThemeData(color: _divider),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: _card,
            indicatorColor: _lime.withOpacity(0.2),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected) ? _lime : _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? _lime : _muted,
              ),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: _lime,
            foregroundColor: _charcoal,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled) ? _divider : _lime,
              ),
              foregroundColor: WidgetStateProperty.all(_charcoal),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(_lime),
              side: WidgetStateProperty.all(const BorderSide(color: _divider)),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(_lime),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: _card,
            selectedColor: _lime.withOpacity(0.2),
            labelStyle: const TextStyle(color: _text),
            secondaryLabelStyle: const TextStyle(color: _text),
            side: const BorderSide(color: _divider),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
          // l10n delegati
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBootstrapper(bootstrap: bootstrap),
        ),
      ),
    );
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key, required this.bootstrap});

  final AppBootstrap bootstrap;

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  late Future<void> _initFuture;
  String _stage = 'Starting...';

  @override
  void initState() {
    super.initState();
    _initFuture = widget.bootstrap(onStage: (stage) {
      if (!mounted || stage == _stage) return;
      setState(() => _stage = stage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return _StartupError(
              error: snapshot.error,
              onRetry: () => setState(() => _initFuture = widget.bootstrap()),
            );
          }
          return const RootNav();
        }
        return _StartupLoading(message: _stage);
      },
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Startup failed',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error?.toString() ?? 'Unknown error',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  final List<Widget> _pages = const [
    HomePage(),
    StatisticsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: s.home, // ili dodaj poseban key "home"
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: s.statisticsTitle,
          ),
        ],
      ),
    );
  }
}

