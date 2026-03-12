import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
class WorkoutReminderService {
  WorkoutReminderService._internal();

  static final WorkoutReminderService instance = WorkoutReminderService._internal();

  static const String _channelId = 'scheduled_workouts';
  static const String _channelName = 'Workout reminders';
  static const String _channelDescription = 'Scheduled workout reminders';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionChecked = false;
  bool _permissionGranted = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> _ensurePermission() async {
    if (_permissionChecked) return _permissionGranted;
    if (kIsWeb) {
      _permissionChecked = true;
      _permissionGranted = true;
      return true;
    }

    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      _permissionChecked = true;
      _permissionGranted = true;
      return true;
    }

    final status = await Permission.notification.status;
    if (status.isGranted) {
      _permissionChecked = true;
      _permissionGranted = true;
      return true;
    }

    final result = await Permission.notification.request();
    _permissionChecked = true;
    _permissionGranted = result.isGranted;
    return _permissionGranted;
  }

  int notificationIdForSchedule(int scheduleKey) => 22000 + scheduleKey;

  Future<void> scheduleReminder({
    required int scheduleKey,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    await init();
    if (!await _ensurePermission()) return;
    if (scheduledAt.isBefore(DateTime.now())) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    final when = tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(
        notificationIdForSchedule(scheduleKey),
        title,
        body,
        when,
        details,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') rethrow;
      await _plugin.zonedSchedule(
        notificationIdForSchedule(scheduleKey),
        title,
        body,
        when,
        details,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelReminder(int scheduleKey) async {
    await init();
    await _plugin.cancel(notificationIdForSchedule(scheduleKey));
  }

  Future<void> requestExactAlarmsPermission() async {
    await init();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } on PlatformException {
      // Best effort.
    }
  }
}
