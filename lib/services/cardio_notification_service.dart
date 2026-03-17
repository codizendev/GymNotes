import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
void cardioForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_CardioForegroundTaskHandler());
}

class _CardioForegroundTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {}

  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
  }

  void onReceiveData(dynamic data) {}
}

class CardioNotificationService {
  CardioNotificationService._internal();

  static final CardioNotificationService instance = CardioNotificationService._internal();

  static const int _notificationId = 12001;
  static const String _channelId = 'cardio_workout';
  static const String _channelName = 'Cardio workout';
  static const String _channelDescription = 'Cardio workout status updates';
  static const int _alertNotificationId = 12002;
  static const String _alertChannelId = 'cardio_segment_alerts';
  static const String _alertChannelName = 'Cardio segment alerts';
  static const String _alertChannelDescription = 'Segment change alerts for cardio workouts';
  static const MethodChannel _overlayChannel = MethodChannel('com.gymnotes.app/segment_overlay');

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionChecked = false;
  bool _permissionGranted = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: _channelId,
          channelName: _channelName,
          channelDescription: _channelDescription,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          iconData: NotificationIconData(
            resType: ResourceType.mipmap,
            resPrefix: ResourcePrefix.ic,
            name: 'launcher',
          ),
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 5000,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );
    }
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

  Future<void> showStatus({required String title, required String body}) async {
    await init();
    if (!await _ensurePermission()) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final running = await FlutterForegroundTask.isRunningService;
      if (running) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: body,
        );
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: title,
          notificationText: body,
          callback: cardioForegroundTaskCallback,
        );
      }
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.status,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(_notificationId, title, body, details);
  }

  Future<void> showSegmentAlert({
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 5),
  }) async {
    await init();
    if (!await _ensurePermission()) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: _alertChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      showWhen: false,
      timeoutAfter: duration.inMilliseconds,
      category: AndroidNotificationCategory.status,
      styleInformation: BigTextStyleInformation(body),
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(_alertNotificationId, title, body, details);
  }

  Future<void> openOverlaySettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await FlutterForegroundTask.openSystemAlertWindowSettings();
  }

  Future<bool> canDrawOverlay() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return FlutterForegroundTask.canDrawOverlays;
  }

  Future<bool> showSegmentOverlay({
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 5),
  }) async {
    if (!await canDrawOverlay()) return false;
    try {
      final ok = await _overlayChannel.invokeMethod<bool>('show', {
        'title': title,
        'body': body,
        'durationMs': duration.inMilliseconds,
      });
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> clearSegmentOverlay() async {
    try {
      await _overlayChannel.invokeMethod('dismiss');
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> clear() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    }
    await init();
    await _plugin.cancel(_notificationId);
    await _plugin.cancel(_alertNotificationId);
    await clearSegmentOverlay();
  }
}
