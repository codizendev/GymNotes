import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Dashboard'**
  String get appTitle;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @allWorkouts.
  ///
  /// In en, this message translates to:
  /// **'All workouts'**
  String get allWorkouts;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get importBackup;

  /// No description provided for @readinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Adaptive readiness'**
  String get readinessTitle;

  /// No description provided for @autoPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-tuned plan'**
  String get autoPlanTitle;

  /// No description provided for @autoProgressionToggle.
  ///
  /// In en, this message translates to:
  /// **'Auto progression'**
  String get autoProgressionToggle;

  /// No description provided for @readinessNoData.
  ///
  /// In en, this message translates to:
  /// **'Log a few workouts to see readiness.'**
  String get readinessNoData;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @sessionFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Session feedback'**
  String get sessionFeedbackTitle;

  /// No description provided for @feelingLabel.
  ///
  /// In en, this message translates to:
  /// **'How did you feel? {score}/10'**
  String feelingLabel(int score);

  /// No description provided for @weightStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight step'**
  String get weightStepLabel;

  /// No description provided for @weightIncreaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight increase'**
  String get weightIncreaseLabel;

  /// No description provided for @tuningSettings.
  ///
  /// In en, this message translates to:
  /// **'Tuning settings'**
  String get tuningSettings;

  /// No description provided for @tuningHint.
  ///
  /// In en, this message translates to:
  /// **'Weights increase by your chosen step only when prior sets matched reps.'**
  String get tuningHint;

  /// No description provided for @volumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volumeLabel;

  /// No description provided for @volumeModeFixed.
  ///
  /// In en, this message translates to:
  /// **'Keep template volume'**
  String get volumeModeFixed;

  /// No description provided for @volumeModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-adjust volume'**
  String get volumeModeAuto;

  /// No description provided for @readinessHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Readiness history'**
  String get readinessHistoryTitle;

  /// No description provided for @readinessHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Need a few readiness entries to show history.'**
  String get readinessHistoryEmpty;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days avg'**
  String get last7Days;

  /// No description provided for @last21Days.
  ///
  /// In en, this message translates to:
  /// **'Last 21 days avg'**
  String get last21Days;

  /// No description provided for @previewAutoPlan.
  ///
  /// In en, this message translates to:
  /// **'Preview next workout'**
  String get previewAutoPlan;

  /// No description provided for @autoPlanPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview: {template}'**
  String autoPlanPreviewTitle(String template);

  /// No description provided for @autoPlanPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-tuned targets with today\'s modifiers.'**
  String get autoPlanPreviewSubtitle;

  /// No description provided for @startWorkoutWithTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start with this template'**
  String get startWorkoutWithTemplate;

  /// No description provided for @weeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly goal'**
  String get weeklyGoal;

  /// No description provided for @setWeeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Set weekly goal'**
  String get setWeeklyGoal;

  /// No description provided for @workoutsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Workouts per week'**
  String get workoutsPerWeek;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterNumberGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than 0.'**
  String get enterNumberGreaterThanZero;

  /// No description provided for @recentWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Recent workouts'**
  String get recentWorkouts;

  /// No description provided for @noWorkoutsYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts yet. Tap “New workout”.'**
  String get noWorkoutsYet;

  /// No description provided for @newWorkout.
  ///
  /// In en, this message translates to:
  /// **'New workout'**
  String get newWorkout;

  /// No description provided for @workoutTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose workout type'**
  String get workoutTypeTitle;

  /// No description provided for @workoutTypeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get workoutTypeStrength;

  /// No description provided for @workoutTypeCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get workoutTypeCardio;

  /// No description provided for @workoutTypeHint.
  ///
  /// In en, this message translates to:
  /// **'You can add the other type later from the workout screen.'**
  String get workoutTypeHint;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @workoutDeleted.
  ///
  /// In en, this message translates to:
  /// **'Workout deleted'**
  String get workoutDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @emptyTemplateListHint.
  ///
  /// In en, this message translates to:
  /// **'No templates. You can start with an empty workout.'**
  String get emptyTemplateListHint;

  /// No description provided for @newWorkoutPickTemplate.
  ///
  /// In en, this message translates to:
  /// **'New workout — pick a template'**
  String get newWorkoutPickTemplate;

  /// No description provided for @emptyWorkout.
  ///
  /// In en, this message translates to:
  /// **'Empty workout'**
  String get emptyWorkout;

  /// No description provided for @startWithoutTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start without a template'**
  String get startWithoutTemplate;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @setsCount.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get setsCount;

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached!'**
  String get goalReached;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @editTitleNotes.
  ///
  /// In en, this message translates to:
  /// **'Edit title/notes'**
  String get editTitleNotes;

  /// No description provided for @repeatLastSet.
  ///
  /// In en, this message translates to:
  /// **'Repeat last set'**
  String get repeatLastSet;

  /// No description provided for @exportSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Export / share as PDF'**
  String get exportSharePdf;

  /// No description provided for @exportShareImage.
  ///
  /// In en, this message translates to:
  /// **'Export / share as image (PNG)'**
  String get exportShareImage;

  /// No description provided for @noSetsYet.
  ///
  /// In en, this message translates to:
  /// **'No sets yet. Add the first set.'**
  String get noSetsYet;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get addSet;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @setNumberShort.
  ///
  /// In en, this message translates to:
  /// **'Set #'**
  String get setNumberShort;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get seconds;

  /// No description provided for @rpeOptional.
  ///
  /// In en, this message translates to:
  /// **'RPE (optional)'**
  String get rpeOptional;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @enterExerciseName.
  ///
  /// In en, this message translates to:
  /// **'Enter exercise name'**
  String get enterExerciseName;

  /// No description provided for @invalidSetNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid set number'**
  String get invalidSetNumber;

  /// No description provided for @invalidWeight.
  ///
  /// In en, this message translates to:
  /// **'Invalid weight'**
  String get invalidWeight;

  /// No description provided for @enterReps.
  ///
  /// In en, this message translates to:
  /// **'Enter reps'**
  String get enterReps;

  /// No description provided for @invalidMinutes.
  ///
  /// In en, this message translates to:
  /// **'Invalid minutes'**
  String get invalidMinutes;

  /// No description provided for @invalidSecondsRange.
  ///
  /// In en, this message translates to:
  /// **'Seconds 0–59'**
  String get invalidSecondsRange;

  /// No description provided for @invalidRpe.
  ///
  /// In en, this message translates to:
  /// **'Invalid RPE'**
  String get invalidRpe;

  /// No description provided for @durationGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Duration must be > 0 seconds'**
  String get durationGreaterThanZero;

  /// No description provided for @enterRepsGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Enter reps greater than 0'**
  String get enterRepsGreaterThanZero;

  /// No description provided for @setAdded.
  ///
  /// In en, this message translates to:
  /// **'Set added'**
  String get setAdded;

  /// No description provided for @setDeleted.
  ///
  /// In en, this message translates to:
  /// **'Set deleted'**
  String get setDeleted;

  /// No description provided for @editHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Title and notes'**
  String get editHeaderTitle;

  /// No description provided for @titleOptional.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get titleOptional;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @workoutDate.
  ///
  /// In en, this message translates to:
  /// **'Workout date'**
  String get workoutDate;

  /// No description provided for @newExercise.
  ///
  /// In en, this message translates to:
  /// **'New exercise'**
  String get newExercise;

  /// No description provided for @editExercise.
  ///
  /// In en, this message translates to:
  /// **'Edit exercise'**
  String get editExercise;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @categoryOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get categoryOptionalLabel;

  /// No description provided for @favoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favoriteLabel;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get nameIsRequired;

  /// No description provided for @exerciseAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An exercise with that name already exists.'**
  String get exerciseAlreadyExists;

  /// No description provided for @deleteExerciseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete exercise?'**
  String get deleteExerciseQuestion;

  /// No description provided for @deleteExerciseWarning.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from the exercise library.\nNote: existing workouts keep the text already saved.'**
  String deleteExerciseWarning(String name);

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercise;

  /// No description provided for @searchExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercisesHint;

  /// No description provided for @noExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'No exercises. Add one with “Add exercise”.'**
  String get noExercisesHint;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @createTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create template'**
  String get createTemplate;

  /// No description provided for @saveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get saveAsTemplate;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @templateCreated.
  ///
  /// In en, this message translates to:
  /// **'Template created.'**
  String get templateCreated;

  /// No description provided for @workoutHasNoSetsForTemplate.
  ///
  /// In en, this message translates to:
  /// **'This workout has no sets — nothing to turn into a template.'**
  String get workoutHasNoSetsForTemplate;

  /// No description provided for @importDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importDataTitle;

  /// No description provided for @importDataBody.
  ///
  /// In en, this message translates to:
  /// **'Import (restore) may replace existing data. Continue?'**
  String get importDataBody;

  /// No description provided for @yesImport.
  ///
  /// In en, this message translates to:
  /// **'Yes, import'**
  String get yesImport;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @importCompleted.
  ///
  /// In en, this message translates to:
  /// **'Import completed.'**
  String get importCompleted;

  /// No description provided for @deleteWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete workout?'**
  String get deleteWorkoutTitle;

  /// No description provided for @deleteWorkoutBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete workout \"{date}\"{hasTitle, select, yes{ – {title}} other{}} and all its sets.'**
  String deleteWorkoutBody(String date, String hasTitle, String title);

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @period7days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get period7days;

  /// No description provided for @period30days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get period30days;

  /// No description provided for @workoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workoutsTitle;

  /// No description provided for @totalInPeriod.
  ///
  /// In en, this message translates to:
  /// **'total in period'**
  String get totalInPeriod;

  /// No description provided for @workoutsInPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts in period'**
  String get workoutsInPeriodTitle;

  /// No description provided for @noWorkoutsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No workouts in the selected period.'**
  String get noWorkoutsInPeriod;

  /// No description provided for @templateTitle.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get templateTitle;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'(untitled)'**
  String get untitled;

  /// No description provided for @noSetsInTemplate.
  ///
  /// In en, this message translates to:
  /// **'No sets in the template yet. Add the first set.'**
  String get noSetsInTemplate;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @templateSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Template set'**
  String get templateSetTitle;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @newTemplate.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get newTemplate;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Create the first one.'**
  String get noTemplatesYet;

  /// No description provided for @templateDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Template duplicated.'**
  String get templateDuplicated;

  /// No description provided for @deleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplateTitle;

  /// No description provided for @deleteTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be permanently deleted.'**
  String deleteTemplateBody(String name);

  /// No description provided for @templateDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" deleted.'**
  String templateDeleted(String name);

  /// No description provided for @gtZero.
  ///
  /// In en, this message translates to:
  /// **'> 0'**
  String get gtZero;

  /// No description provided for @geZero.
  ///
  /// In en, this message translates to:
  /// **'≥ 0'**
  String get geZero;

  /// No description provided for @duplicateThisSet.
  ///
  /// In en, this message translates to:
  /// **'Duplicate this set'**
  String get duplicateThisSet;

  /// No description provided for @noSetsToExport.
  ///
  /// In en, this message translates to:
  /// **'No sets to export'**
  String get noSetsToExport;

  /// No description provided for @exportError.
  ///
  /// In en, this message translates to:
  /// **'Export error: {error}'**
  String exportError(String error);

  /// No description provided for @backupShareText.
  ///
  /// In en, this message translates to:
  /// **'Workout backup'**
  String get backupShareText;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @exerciseHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History — {exercise}'**
  String exerciseHistoryTitle(String exercise);

  /// No description provided for @heaviestSet.
  ///
  /// In en, this message translates to:
  /// **'Heaviest'**
  String get heaviestSet;

  /// No description provided for @bestReps.
  ///
  /// In en, this message translates to:
  /// **'Best reps'**
  String get bestReps;

  /// No description provided for @bestVolume.
  ///
  /// In en, this message translates to:
  /// **'Best volume'**
  String get bestVolume;

  /// No description provided for @estimated1RM.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1RM'**
  String get estimated1RM;

  /// No description provided for @noHistoryForExercise.
  ///
  /// In en, this message translates to:
  /// **'No history for this exercise yet.'**
  String get noHistoryForExercise;

  /// No description provided for @workoutsPerDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts per day'**
  String get workoutsPerDayTitle;

  /// No description provided for @topExercisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top exercises'**
  String get topExercisesTitle;

  /// No description provided for @exerciseProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise progress'**
  String get exerciseProgressTitle;

  /// No description provided for @exerciseLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exerciseLabel;

  /// No description provided for @metricLabel.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metricLabel;

  /// No description provided for @periodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodLabel;

  /// No description provided for @smoothingLabel.
  ///
  /// In en, this message translates to:
  /// **'Smoothing'**
  String get smoothingLabel;

  /// No description provided for @pickExerciseHint.
  ///
  /// In en, this message translates to:
  /// **'Pick an exercise to see progress.'**
  String get pickExerciseHint;

  /// No description provided for @noDataForSelectedPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for the selected period.'**
  String get noDataForSelectedPeriod;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'latest'**
  String get latest;

  /// No description provided for @metricMaxWeight.
  ///
  /// In en, this message translates to:
  /// **'Max weight (kg)'**
  String get metricMaxWeight;

  /// No description provided for @metricEst1RM.
  ///
  /// In en, this message translates to:
  /// **'Est. 1RM (kg)'**
  String get metricEst1RM;

  /// No description provided for @metricTotalReps.
  ///
  /// In en, this message translates to:
  /// **'Total reps'**
  String get metricTotalReps;

  /// No description provided for @metricTotalTimeSec.
  ///
  /// In en, this message translates to:
  /// **'Total time (s)'**
  String get metricTotalTimeSec;

  /// No description provided for @epPeriod30days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get epPeriod30days;

  /// No description provided for @epPeriod180days.
  ///
  /// In en, this message translates to:
  /// **'180 days'**
  String get epPeriod180days;

  /// No description provided for @epPeriod1year.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get epPeriod1year;

  /// No description provided for @epPeriodAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get epPeriodAllTime;

  /// No description provided for @importFromPdfMenu.
  ///
  /// In en, this message translates to:
  /// **'Import from PDF (this app)'**
  String get importFromPdfMenu;

  /// No description provided for @importFromPdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open and preview before saving'**
  String get importFromPdfSubtitle;

  /// No description provided for @importFromPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from PDF'**
  String get importFromPdfTitle;

  /// No description provided for @choosePdf.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF'**
  String get choosePdf;

  /// No description provided for @importAsWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save as workout'**
  String get importAsWorkout;

  /// No description provided for @importAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get importAsTemplate;

  /// No description provided for @importSuccessWorkout.
  ///
  /// In en, this message translates to:
  /// **'Imported workout.'**
  String get importSuccessWorkout;

  /// No description provided for @importSuccessTemplate.
  ///
  /// In en, this message translates to:
  /// **'Imported as template.'**
  String get importSuccessTemplate;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @pdfNoEmbeddedData.
  ///
  /// In en, this message translates to:
  /// **'This PDF doesn\'t contain workout data from this app.'**
  String get pdfNoEmbeddedData;

  /// No description provided for @pdfParseError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read embedded data.'**
  String get pdfParseError;

  /// No description provided for @savePdfToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save PDF to device'**
  String get savePdfToDevice;

  /// No description provided for @savedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved to device'**
  String get savedToDevice;

  /// No description provided for @cardioWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio workout'**
  String get cardioWorkoutTitle;

  /// No description provided for @cardioTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio template'**
  String get cardioTemplateTitle;

  /// No description provided for @newCardioTemplate.
  ///
  /// In en, this message translates to:
  /// **'New cardio template'**
  String get newCardioTemplate;

  /// No description provided for @cardioPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout plan'**
  String get cardioPlanTitle;

  /// No description provided for @plannedDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned duration'**
  String get plannedDurationLabel;

  /// No description provided for @segmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get segmentsLabel;

  /// No description provided for @timerAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer alerts'**
  String get timerAlertsTitle;

  /// No description provided for @soundLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundLabel;

  /// No description provided for @vibrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibrationLabel;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// No description provided for @logManually.
  ///
  /// In en, this message translates to:
  /// **'Log manually'**
  String get logManually;

  /// No description provided for @addWorkRestPair.
  ///
  /// In en, this message translates to:
  /// **'Add work/rest pair'**
  String get addWorkRestPair;

  /// No description provided for @currentSegmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current segment'**
  String get currentSegmentLabel;

  /// No description provided for @nextSegmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Next segment'**
  String get nextSegmentLabel;

  /// No description provided for @elapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get elapsedLabel;

  /// No description provided for @segmentCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get segmentCountLabel;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @skipSegment.
  ///
  /// In en, this message translates to:
  /// **'Skip segment'**
  String get skipSegment;

  /// No description provided for @endWorkout.
  ///
  /// In en, this message translates to:
  /// **'End workout'**
  String get endWorkout;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTitle;

  /// No description provided for @summaryDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary details'**
  String get summaryDetailsTitle;

  /// No description provided for @advancedDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced details'**
  String get advancedDetailsTitle;

  /// No description provided for @editPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get editPlan;

  /// No description provided for @cardioNeedSegments.
  ///
  /// In en, this message translates to:
  /// **'Add at least one segment to start.'**
  String get cardioNeedSegments;

  /// No description provided for @cardioInvalidSegmentDuration.
  ///
  /// In en, this message translates to:
  /// **'Each segment needs a duration.'**
  String get cardioInvalidSegmentDuration;

  /// No description provided for @cardioDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio details'**
  String get cardioDetailsTitle;

  /// No description provided for @activityLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityLabel;

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'Distance (km)'**
  String get distanceKm;

  /// No description provided for @elevationGainM.
  ///
  /// In en, this message translates to:
  /// **'Elevation gain (m)'**
  String get elevationGainM;

  /// No description provided for @inclinePercent.
  ///
  /// In en, this message translates to:
  /// **'Incline (%)'**
  String get inclinePercent;

  /// No description provided for @avgHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Avg HR'**
  String get avgHeartRate;

  /// No description provided for @maxHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Max HR'**
  String get maxHeartRate;

  /// No description provided for @caloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get caloriesLabel;

  /// No description provided for @heartRateZones.
  ///
  /// In en, this message translates to:
  /// **'Heart rate zones'**
  String get heartRateZones;

  /// No description provided for @zoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get zoneLabel;

  /// No description provided for @intervalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get intervalsTitle;

  /// No description provided for @addInterval.
  ///
  /// In en, this message translates to:
  /// **'Add interval'**
  String get addInterval;

  /// No description provided for @editInterval.
  ///
  /// In en, this message translates to:
  /// **'Edit interval'**
  String get editInterval;

  /// No description provided for @noIntervalsYet.
  ///
  /// In en, this message translates to:
  /// **'No intervals yet.'**
  String get noIntervalsYet;

  /// No description provided for @segmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Segment label'**
  String get segmentLabel;

  /// No description provided for @segmentType.
  ///
  /// In en, this message translates to:
  /// **'Segment type'**
  String get segmentType;

  /// No description provided for @segmentWarmup.
  ///
  /// In en, this message translates to:
  /// **'Warmup'**
  String get segmentWarmup;

  /// No description provided for @segmentWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get segmentWork;

  /// No description provided for @segmentRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get segmentRecovery;

  /// No description provided for @segmentCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cooldown'**
  String get segmentCooldown;

  /// No description provided for @segmentEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get segmentEasy;

  /// No description provided for @segmentOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get segmentOther;

  /// No description provided for @targetSpeedKph.
  ///
  /// In en, this message translates to:
  /// **'Target speed (km/h)'**
  String get targetSpeedKph;

  /// No description provided for @contextTitle.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get contextTitle;

  /// No description provided for @environmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environmentLabel;

  /// No description provided for @terrainLabel.
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get terrainLabel;

  /// No description provided for @weatherLabel.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weatherLabel;

  /// No description provided for @equipmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipmentLabel;

  /// No description provided for @moodLabel.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get moodLabel;

  /// No description provided for @energyLabel.
  ///
  /// In en, this message translates to:
  /// **'Energy (1-10)'**
  String get energyLabel;

  /// No description provided for @derivedMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Derived metrics'**
  String get derivedMetricsTitle;

  /// No description provided for @avgSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get avgSpeedLabel;

  /// No description provided for @paceLabel.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get paceLabel;

  /// No description provided for @caloriesEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated calories'**
  String get caloriesEstimateLabel;

  /// No description provided for @efficiencyScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Efficiency score'**
  String get efficiencyScoreLabel;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get notAvailable;

  /// No description provided for @noDuration.
  ///
  /// In en, this message translates to:
  /// **'No duration'**
  String get noDuration;

  /// No description provided for @noDistance.
  ///
  /// In en, this message translates to:
  /// **'No distance'**
  String get noDistance;

  /// No description provided for @noPace.
  ///
  /// In en, this message translates to:
  /// **'No pace'**
  String get noPace;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @distanceTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceTotalLabel;

  /// No description provided for @cardioSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio summary'**
  String get cardioSummaryTitle;

  /// No description provided for @cardioSessionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cardio sessions'**
  String get cardioSessionsLabel;

  /// No description provided for @longestSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Longest session'**
  String get longestSessionLabel;

  /// No description provided for @bestPaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Best pace'**
  String get bestPaceLabel;

  /// No description provided for @noCardioInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No cardio sessions in the selected period.'**
  String get noCardioInPeriod;

  /// No description provided for @cardioTemplatePickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a cardio template'**
  String get cardioTemplatePickTitle;

  /// No description provided for @applyTemplate.
  ///
  /// In en, this message translates to:
  /// **'Apply template'**
  String get applyTemplate;

  /// No description provided for @noCardioTemplates.
  ///
  /// In en, this message translates to:
  /// **'No cardio templates yet.'**
  String get noCardioTemplates;

  /// No description provided for @cardioSaved.
  ///
  /// In en, this message translates to:
  /// **'Cardio saved.'**
  String get cardioSaved;

  /// No description provided for @workoutCompleted.
  ///
  /// In en, this message translates to:
  /// **'Workout completed'**
  String get workoutCompleted;

  /// No description provided for @workoutCompletedHint.
  ///
  /// In en, this message translates to:
  /// **'Mark complete after saving your cardio details.'**
  String get workoutCompletedHint;

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerTitle;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @useTimer.
  ///
  /// In en, this message translates to:
  /// **'Use timer'**
  String get useTimer;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minutesShort;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @aboutMenu.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutMenu;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About GymNotes'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'GymNotes is an offline workout log. Your data stays on your device unless you export or share it.'**
  String get aboutBody;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'We do not collect or share personal data. Backups and PDFs are saved only to locations you choose.'**
  String get privacyPolicyBody;

  /// No description provided for @proMenuUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get proMenuUpgrade;

  /// No description provided for @proMenuActive.
  ///
  /// In en, this message translates to:
  /// **'Pro unlocked'**
  String get proMenuActive;

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get proTitle;

  /// No description provided for @proActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro unlocked'**
  String get proActiveTitle;

  /// No description provided for @proBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock unlimited templates, custom auto progression controls, and advanced stats.'**
  String get proBody;

  /// No description provided for @proActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Pro features are enabled on this device.'**
  String get proActiveBody;

  /// No description provided for @proFeatureLocked.
  ///
  /// In en, this message translates to:
  /// **'This feature requires Pro:'**
  String get proFeatureLocked;

  /// No description provided for @proFeatureTemplates.
  ///
  /// In en, this message translates to:
  /// **'Unlimited templates'**
  String get proFeatureTemplates;

  /// No description provided for @proFeatureAutoProgression.
  ///
  /// In en, this message translates to:
  /// **'Custom auto progression controls'**
  String get proFeatureAutoProgression;

  /// No description provided for @proFeatureAdvancedStats.
  ///
  /// In en, this message translates to:
  /// **'Advanced stats'**
  String get proFeatureAdvancedStats;

  /// No description provided for @proEnableTest.
  ///
  /// In en, this message translates to:
  /// **'Enable Pro (test)'**
  String get proEnableTest;

  /// No description provided for @proDisableTest.
  ///
  /// In en, this message translates to:
  /// **'Disable Pro (test)'**
  String get proDisableTest;

  /// No description provided for @proNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get proNotNow;

  /// No description provided for @proUnlockedSnack.
  ///
  /// In en, this message translates to:
  /// **'Pro unlocked for this device.'**
  String get proUnlockedSnack;

  /// No description provided for @proLockedSnack.
  ///
  /// In en, this message translates to:
  /// **'Pro locked on this device.'**
  String get proLockedSnack;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleTitle;

  /// No description provided for @scheduleWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule workout'**
  String get scheduleWorkoutTitle;

  /// No description provided for @editScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit schedule'**
  String get editScheduleTitle;

  /// No description provided for @scheduleWorkoutAction.
  ///
  /// In en, this message translates to:
  /// **'Schedule workout'**
  String get scheduleWorkoutAction;

  /// No description provided for @scheduleStartWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get scheduleStartWorkout;

  /// No description provided for @scheduleMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get scheduleMarkCompleted;

  /// No description provided for @scheduleSkipWorkout.
  ///
  /// In en, this message translates to:
  /// **'Skip workout'**
  String get scheduleSkipWorkout;

  /// No description provided for @scheduleReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen schedule'**
  String get scheduleReopen;

  /// No description provided for @scheduleRescheduleTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Reschedule to tomorrow'**
  String get scheduleRescheduleTomorrow;

  /// No description provided for @scheduleRescheduleNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Reschedule to next week'**
  String get scheduleRescheduleNextWeek;

  /// No description provided for @scheduleStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get scheduleStatusPending;

  /// No description provided for @scheduleStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get scheduleStatusCompleted;

  /// No description provided for @scheduleLinkedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Linked workout'**
  String get scheduleLinkedWorkout;

  /// No description provided for @scheduleOpenLinkedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Open linked workout'**
  String get scheduleOpenLinkedWorkout;

  /// No description provided for @scheduleMissingCardioTemplate.
  ///
  /// In en, this message translates to:
  /// **'Missing cardio template.'**
  String get scheduleMissingCardioTemplate;

  /// No description provided for @scheduleMissingStrengthTemplate.
  ///
  /// In en, this message translates to:
  /// **'Missing strength template.'**
  String get scheduleMissingStrengthTemplate;

  /// No description provided for @noScheduledWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No scheduled workouts yet.'**
  String get noScheduledWorkouts;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderLabel;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout reminder'**
  String get reminderTitle;

  /// No description provided for @pickTemplate.
  ///
  /// In en, this message translates to:
  /// **'Pick a template'**
  String get pickTemplate;

  /// No description provided for @templateLabel.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get templateLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @workoutSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search workouts, notes, dates, exercises...'**
  String get workoutSearchHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All status'**
  String get filterStatusAll;

  /// No description provided for @filterStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterStatusCompleted;

  /// No description provided for @filterStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterStatusActive;

  /// No description provided for @filterRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get filterRangeAll;

  /// No description provided for @filterRange90days.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get filterRange90days;

  /// No description provided for @filterExerciseLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercise filter'**
  String get filterExerciseLabel;

  /// No description provided for @filterExerciseAny.
  ///
  /// In en, this message translates to:
  /// **'Any exercise'**
  String get filterExerciseAny;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noWorkoutsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No workouts match current filters.'**
  String get noWorkoutsMatchFilters;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
