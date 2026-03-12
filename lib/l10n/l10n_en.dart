// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Workout Dashboard';

  @override
  String get templates => 'Templates';

  @override
  String get allWorkouts => 'All workouts';

  @override
  String get exercises => 'Exercises';

  @override
  String get exportBackup => 'Export backup';

  @override
  String get importBackup => 'Import backup';

  @override
  String get readinessTitle => 'Adaptive readiness';

  @override
  String get autoPlanTitle => 'Auto-tuned plan';

  @override
  String get autoProgressionToggle => 'Auto progression';

  @override
  String get readinessNoData => 'Log a few workouts to see readiness.';

  @override
  String get refresh => 'Refresh';

  @override
  String get sessionFeedbackTitle => 'Session feedback';

  @override
  String feelingLabel(int score) {
    return 'How did you feel? $score/10';
  }

  @override
  String get weightStepLabel => 'Weight step';

  @override
  String get weightIncreaseLabel => 'Weight increase';

  @override
  String get tuningSettings => 'Tuning settings';

  @override
  String get tuningHint =>
      'Weights increase by your chosen step only when prior sets matched reps.';

  @override
  String get volumeLabel => 'Volume';

  @override
  String get volumeModeFixed => 'Keep template volume';

  @override
  String get volumeModeAuto => 'Auto-adjust volume';

  @override
  String get readinessHistoryTitle => 'Readiness history';

  @override
  String get readinessHistoryEmpty =>
      'Need a few readiness entries to show history.';

  @override
  String get last7Days => 'Last 7 days avg';

  @override
  String get last21Days => 'Last 21 days avg';

  @override
  String get previewAutoPlan => 'Preview next workout';

  @override
  String autoPlanPreviewTitle(String template) {
    return 'Preview: $template';
  }

  @override
  String get autoPlanPreviewSubtitle =>
      'Auto-tuned targets with today\'s modifiers.';

  @override
  String get startWorkoutWithTemplate => 'Start with this template';

  @override
  String get weeklyGoal => 'Weekly goal';

  @override
  String get setWeeklyGoal => 'Set weekly goal';

  @override
  String get workoutsPerWeek => 'Workouts per week';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get enterNumberGreaterThanZero => 'Enter a number greater than 0.';

  @override
  String get recentWorkouts => 'Recent workouts';

  @override
  String get noWorkoutsYet => 'No workouts yet. Tap “New workout”.';

  @override
  String get newWorkout => 'New workout';

  @override
  String get workoutTypeTitle => 'Choose workout type';

  @override
  String get workoutTypeStrength => 'Strength';

  @override
  String get workoutTypeCardio => 'Cardio';

  @override
  String get workoutTypeHint =>
      'You can add the other type later from the workout screen.';

  @override
  String get open => 'Open';

  @override
  String get delete => 'Delete';

  @override
  String get workoutDeleted => 'Workout deleted';

  @override
  String get undo => 'Undo';

  @override
  String get emptyTemplateListHint =>
      'No templates. You can start with an empty workout.';

  @override
  String get newWorkoutPickTemplate => 'New workout — pick a template';

  @override
  String get emptyWorkout => 'Empty workout';

  @override
  String get startWithoutTemplate => 'Start without a template';

  @override
  String get workout => 'Workout';

  @override
  String get setsCount => 'Sets';

  @override
  String get goalReached => 'Goal reached!';

  @override
  String get date => 'Date';

  @override
  String get editTitleNotes => 'Edit title/notes';

  @override
  String get repeatLastSet => 'Repeat last set';

  @override
  String get exportSharePdf => 'Export / share as PDF';

  @override
  String get exportShareImage => 'Export / share as image (PNG)';

  @override
  String get noSetsYet => 'No sets yet. Add the first set.';

  @override
  String get addSet => 'Add set';

  @override
  String get exercise => 'Exercise';

  @override
  String get setNumberShort => 'Set #';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get reps => 'Reps';

  @override
  String get time => 'Time';

  @override
  String get minutes => 'Minutes';

  @override
  String get seconds => 'Seconds';

  @override
  String get rpeOptional => 'RPE (optional)';

  @override
  String get notes => 'Notes';

  @override
  String get close => 'Close';

  @override
  String get enterExerciseName => 'Enter exercise name';

  @override
  String get invalidSetNumber => 'Invalid set number';

  @override
  String get invalidWeight => 'Invalid weight';

  @override
  String get enterReps => 'Enter reps';

  @override
  String get invalidMinutes => 'Invalid minutes';

  @override
  String get invalidSecondsRange => 'Seconds 0–59';

  @override
  String get invalidRpe => 'Invalid RPE';

  @override
  String get durationGreaterThanZero => 'Duration must be > 0 seconds';

  @override
  String get enterRepsGreaterThanZero => 'Enter reps greater than 0';

  @override
  String get setAdded => 'Set added';

  @override
  String get setDeleted => 'Set deleted';

  @override
  String get editHeaderTitle => 'Title and notes';

  @override
  String get titleOptional => 'Title (optional)';

  @override
  String get notesLabel => 'Notes';

  @override
  String get workoutDate => 'Workout date';

  @override
  String get newExercise => 'New exercise';

  @override
  String get editExercise => 'Edit exercise';

  @override
  String get nameLabel => 'Name';

  @override
  String get categoryOptionalLabel => 'Category (optional)';

  @override
  String get favoriteLabel => 'Favorite';

  @override
  String get nameIsRequired => 'Name is required.';

  @override
  String get exerciseAlreadyExists =>
      'An exercise with that name already exists.';

  @override
  String get deleteExerciseQuestion => 'Delete exercise?';

  @override
  String deleteExerciseWarning(String name) {
    return '\"$name\" will be removed from the exercise library.\nNote: existing workouts keep the text already saved.';
  }

  @override
  String get addExercise => 'Add exercise';

  @override
  String get searchExercisesHint => 'Search exercises...';

  @override
  String get noExercisesHint => 'No exercises. Add one with “Add exercise”.';

  @override
  String get edit => 'Edit';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get createTemplate => 'Create template';

  @override
  String get saveAsTemplate => 'Save as template';

  @override
  String get templateName => 'Template name';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get templateCreated => 'Template created.';

  @override
  String get workoutHasNoSetsForTemplate =>
      'This workout has no sets — nothing to turn into a template.';

  @override
  String get importDataTitle => 'Import data';

  @override
  String get importDataBody =>
      'Import (restore) may replace existing data. Continue?';

  @override
  String get yesImport => 'Yes, import';

  @override
  String get no => 'No';

  @override
  String get importCompleted => 'Import completed.';

  @override
  String get deleteWorkoutTitle => 'Delete workout?';

  @override
  String deleteWorkoutBody(String date, String hasTitle, String title) {
    String _temp0 = intl.Intl.selectLogic(hasTitle, {
      'yes': ' – $title',
      'other': '',
    });
    return 'This will delete workout \"$date\"$_temp0 and all its sets.';
  }

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get period7days => '7 days';

  @override
  String get period30days => '30 days';

  @override
  String get workoutsTitle => 'Workouts';

  @override
  String get totalInPeriod => 'total in period';

  @override
  String get workoutsInPeriodTitle => 'Workouts in period';

  @override
  String get noWorkoutsInPeriod => 'No workouts in the selected period.';

  @override
  String get templateTitle => 'Template';

  @override
  String get untitled => '(untitled)';

  @override
  String get noSetsInTemplate =>
      'No sets in the template yet. Add the first set.';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get templateSetTitle => 'Template set';

  @override
  String get requiredField => 'Required';

  @override
  String get newTemplate => 'New template';

  @override
  String get create => 'Create';

  @override
  String get noTemplatesYet => 'No templates yet. Create the first one.';

  @override
  String get templateDuplicated => 'Template duplicated.';

  @override
  String get deleteTemplateTitle => 'Delete template?';

  @override
  String deleteTemplateBody(String name) {
    return '\"$name\" will be permanently deleted.';
  }

  @override
  String templateDeleted(String name) {
    return '\"$name\" deleted.';
  }

  @override
  String get gtZero => '> 0';

  @override
  String get geZero => '≥ 0';

  @override
  String get duplicateThisSet => 'Duplicate this set';

  @override
  String get noSetsToExport => 'No sets to export';

  @override
  String exportError(String error) {
    return 'Export error: $error';
  }

  @override
  String get backupShareText => 'Workout backup';

  @override
  String get history => 'History';

  @override
  String exerciseHistoryTitle(String exercise) {
    return 'History — $exercise';
  }

  @override
  String get heaviestSet => 'Heaviest';

  @override
  String get bestReps => 'Best reps';

  @override
  String get bestVolume => 'Best volume';

  @override
  String get estimated1RM => 'Estimated 1RM';

  @override
  String get noHistoryForExercise => 'No history for this exercise yet.';

  @override
  String get workoutsPerDayTitle => 'Workouts per day';

  @override
  String get topExercisesTitle => 'Top exercises';

  @override
  String get exerciseProgressTitle => 'Exercise progress';

  @override
  String get exerciseLabel => 'Exercise';

  @override
  String get metricLabel => 'Metric';

  @override
  String get periodLabel => 'Period';

  @override
  String get smoothingLabel => 'Smoothing';

  @override
  String get pickExerciseHint => 'Pick an exercise to see progress.';

  @override
  String get noDataForSelectedPeriod => 'No data for the selected period.';

  @override
  String get latest => 'latest';

  @override
  String get metricMaxWeight => 'Max weight (kg)';

  @override
  String get metricEst1RM => 'Est. 1RM (kg)';

  @override
  String get metricTotalReps => 'Total reps';

  @override
  String get metricTotalTimeSec => 'Total time (s)';

  @override
  String get epPeriod30days => '30 days';

  @override
  String get epPeriod180days => '180 days';

  @override
  String get epPeriod1year => '1 year';

  @override
  String get epPeriodAllTime => 'All time';

  @override
  String get importFromPdfMenu => 'Import from PDF (this app)';

  @override
  String get importFromPdfSubtitle => 'Open and preview before saving';

  @override
  String get importFromPdfTitle => 'Import from PDF';

  @override
  String get choosePdf => 'Choose PDF';

  @override
  String get importAsWorkout => 'Save as workout';

  @override
  String get importAsTemplate => 'Save as template';

  @override
  String get importSuccessWorkout => 'Imported workout.';

  @override
  String get importSuccessTemplate => 'Imported as template.';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get pdfNoEmbeddedData =>
      'This PDF doesn\'t contain workout data from this app.';

  @override
  String get pdfParseError => 'Couldn\'t read embedded data.';

  @override
  String get savePdfToDevice => 'Save PDF to device';

  @override
  String get savedToDevice => 'Saved to device';

  @override
  String get cardioWorkoutTitle => 'Cardio workout';

  @override
  String get cardioTemplateTitle => 'Cardio template';

  @override
  String get newCardioTemplate => 'New cardio template';

  @override
  String get cardioPlanTitle => 'Workout plan';

  @override
  String get plannedDurationLabel => 'Planned duration';

  @override
  String get segmentsLabel => 'Segments';

  @override
  String get timerAlertsTitle => 'Timer alerts';

  @override
  String get soundLabel => 'Sound';

  @override
  String get vibrationLabel => 'Vibration';

  @override
  String get startWorkout => 'Start workout';

  @override
  String get logManually => 'Log manually';

  @override
  String get addWorkRestPair => 'Add work/rest pair';

  @override
  String get currentSegmentLabel => 'Current segment';

  @override
  String get nextSegmentLabel => 'Next segment';

  @override
  String get elapsedLabel => 'Elapsed';

  @override
  String get segmentCountLabel => 'Segment';

  @override
  String get resume => 'Resume';

  @override
  String get skipSegment => 'Skip segment';

  @override
  String get endWorkout => 'End workout';

  @override
  String get summaryTitle => 'Summary';

  @override
  String get summaryDetailsTitle => 'Summary details';

  @override
  String get advancedDetailsTitle => 'Advanced details';

  @override
  String get editPlan => 'Edit plan';

  @override
  String get cardioNeedSegments => 'Add at least one segment to start.';

  @override
  String get cardioInvalidSegmentDuration => 'Each segment needs a duration.';

  @override
  String get cardioDetailsTitle => 'Cardio details';

  @override
  String get activityLabel => 'Activity';

  @override
  String get distanceKm => 'Distance (km)';

  @override
  String get elevationGainM => 'Elevation gain (m)';

  @override
  String get inclinePercent => 'Incline (%)';

  @override
  String get avgHeartRate => 'Avg HR';

  @override
  String get maxHeartRate => 'Max HR';

  @override
  String get caloriesLabel => 'Calories';

  @override
  String get heartRateZones => 'Heart rate zones';

  @override
  String get zoneLabel => 'Zone';

  @override
  String get intervalsTitle => 'Intervals';

  @override
  String get addInterval => 'Add interval';

  @override
  String get editInterval => 'Edit interval';

  @override
  String get noIntervalsYet => 'No intervals yet.';

  @override
  String get segmentLabel => 'Segment label';

  @override
  String get segmentType => 'Segment type';

  @override
  String get segmentWarmup => 'Warmup';

  @override
  String get segmentWork => 'Work';

  @override
  String get segmentRecovery => 'Recovery';

  @override
  String get segmentCooldown => 'Cooldown';

  @override
  String get segmentEasy => 'Easy';

  @override
  String get segmentOther => 'Other';

  @override
  String get targetSpeedKph => 'Target speed (km/h)';

  @override
  String get contextTitle => 'Context';

  @override
  String get environmentLabel => 'Environment';

  @override
  String get terrainLabel => 'Terrain';

  @override
  String get weatherLabel => 'Weather';

  @override
  String get equipmentLabel => 'Equipment';

  @override
  String get moodLabel => 'Mood';

  @override
  String get energyLabel => 'Energy (1-10)';

  @override
  String get derivedMetricsTitle => 'Derived metrics';

  @override
  String get avgSpeedLabel => 'Average speed';

  @override
  String get paceLabel => 'Pace';

  @override
  String get caloriesEstimateLabel => 'Estimated calories';

  @override
  String get efficiencyScoreLabel => 'Efficiency score';

  @override
  String get notAvailable => 'n/a';

  @override
  String get noDuration => 'No duration';

  @override
  String get noDistance => 'No distance';

  @override
  String get noPace => 'No pace';

  @override
  String get durationLabel => 'Duration';

  @override
  String get distanceTotalLabel => 'Distance';

  @override
  String get cardioSummaryTitle => 'Cardio summary';

  @override
  String get cardioSessionsLabel => 'Cardio sessions';

  @override
  String get longestSessionLabel => 'Longest session';

  @override
  String get bestPaceLabel => 'Best pace';

  @override
  String get noCardioInPeriod => 'No cardio sessions in the selected period.';

  @override
  String get cardioTemplatePickTitle => 'Pick a cardio template';

  @override
  String get applyTemplate => 'Apply template';

  @override
  String get noCardioTemplates => 'No cardio templates yet.';

  @override
  String get cardioSaved => 'Cardio saved.';

  @override
  String get workoutCompleted => 'Workout completed';

  @override
  String get workoutCompletedHint =>
      'Mark complete after saving your cardio details.';

  @override
  String get timerTitle => 'Timer';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get useTimer => 'Use timer';

  @override
  String get reset => 'Reset';

  @override
  String get minutesShort => 'm';

  @override
  String get home => 'Home';

  @override
  String get aboutMenu => 'About';

  @override
  String get aboutTitle => 'About GymNotes';

  @override
  String get aboutBody =>
      'GymNotes is an offline workout log. Your data stays on your device unless you export or share it.';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get privacyPolicyBody =>
      'We do not collect or share personal data. Backups and PDFs are saved only to locations you choose.';

  @override
  String get proMenuUpgrade => 'Upgrade to Pro';

  @override
  String get proMenuActive => 'Pro unlocked';

  @override
  String get proTitle => 'Upgrade to Pro';

  @override
  String get proActiveTitle => 'Pro unlocked';

  @override
  String get proBody =>
      'Unlock unlimited templates, custom auto progression controls, and advanced stats.';

  @override
  String get proActiveBody => 'Pro features are enabled on this device.';

  @override
  String get proFeatureLocked => 'This feature requires Pro:';

  @override
  String get proFeatureTemplates => 'Unlimited templates';

  @override
  String get proFeatureAutoProgression => 'Custom auto progression controls';

  @override
  String get proFeatureAdvancedStats => 'Advanced stats';

  @override
  String get proEnableTest => 'Enable Pro (test)';

  @override
  String get proDisableTest => 'Disable Pro (test)';

  @override
  String get proNotNow => 'Not now';

  @override
  String get proUnlockedSnack => 'Pro unlocked for this device.';

  @override
  String get proLockedSnack => 'Pro locked on this device.';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get scheduleWorkoutTitle => 'Schedule workout';

  @override
  String get editScheduleTitle => 'Edit schedule';

  @override
  String get scheduleWorkoutAction => 'Schedule workout';

  @override
  String get scheduleStartWorkout => 'Start workout';

  @override
  String get scheduleMarkCompleted => 'Mark completed';

  @override
  String get scheduleSkipWorkout => 'Skip workout';

  @override
  String get scheduleReopen => 'Reopen schedule';

  @override
  String get scheduleRescheduleTomorrow => 'Reschedule to tomorrow';

  @override
  String get scheduleRescheduleNextWeek => 'Reschedule to next week';

  @override
  String get scheduleStatusPending => 'Pending';

  @override
  String get scheduleStatusCompleted => 'Completed';

  @override
  String get scheduleLinkedWorkout => 'Linked workout';

  @override
  String get scheduleOpenLinkedWorkout => 'Open linked workout';

  @override
  String get scheduleMissingCardioTemplate => 'Missing cardio template.';

  @override
  String get scheduleMissingStrengthTemplate => 'Missing strength template.';

  @override
  String get noScheduledWorkouts => 'No scheduled workouts yet.';

  @override
  String get reminderLabel => 'Reminder';

  @override
  String get reminderTitle => 'Workout reminder';

  @override
  String get pickTemplate => 'Pick a template';

  @override
  String get templateLabel => 'Template';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get workoutSearchHint => 'Search workouts, notes, dates, exercises...';

  @override
  String get filterAll => 'All';

  @override
  String get filterStatusAll => 'All status';

  @override
  String get filterStatusCompleted => 'Completed';

  @override
  String get filterStatusActive => 'Active';

  @override
  String get filterRangeAll => 'All time';

  @override
  String get filterRange90days => '90 days';

  @override
  String get filterExerciseLabel => 'Exercise filter';

  @override
  String get filterExerciseAny => 'Any exercise';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noWorkoutsMatchFilters => 'No workouts match current filters.';
}
