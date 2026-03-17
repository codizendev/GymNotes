import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_logger.dart';

class FeedbackService {
  FeedbackService._();

  static Future<void> shareFeedbackPackage({
    required String subject,
    required String shareText,
    required Map<String, Object?> testerFeedback,
    Uint8List? screenshotBytes,
  }) async {
    var appName = 'GymNotes';
    var packageName = 'unknown';
    var version = 'unknown';
    var buildNumber = 'unknown';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appName = packageInfo.appName;
      packageName = packageInfo.packageName;
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Package info lookup failed',
        context: <String, Object?>{
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
    final nowUtc = DateTime.now().toUtc();

    final report = <String, Object?>{
      'generatedAtUtc': nowUtc.toIso8601String(),
      'app': <String, Object?>{
        'name': appName,
        'packageName': packageName,
        'version': version,
        'buildNumber': buildNumber,
      },
      'runtime': <String, Object?>{
        'mode': _buildMode(),
        'platform': defaultTargetPlatform.name,
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'dartVersion': Platform.version,
      },
      'storage': _collectStorageSummary(),
      'testerFeedback': testerFeedback,
      'logs': AppLogger.snapshot(),
    };

    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final reportFile = File('${tempDir.path}/gymnotes_feedback_$ts.json');
    await reportFile.writeAsString(const JsonEncoder.withIndent('  ').convert(report));

    final files = <XFile>[XFile(reportFile.path)];
    var screenshotIncluded = false;
    if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
      final screenshotFile = File('${tempDir.path}/gymnotes_feedback_$ts.png');
      await screenshotFile.writeAsBytes(screenshotBytes, flush: true);
      files.add(XFile(screenshotFile.path));
      screenshotIncluded = true;
    }

    AppLogger.info(
      'Feedback package prepared',
      context: <String, Object?>{
        'reportFile': reportFile.path,
        'screenshotIncluded': screenshotIncluded,
      },
    );

    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: subject,
        text: shareText,
      ),
    );
  }

  static String _buildMode() {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  static Map<String, Object?> _collectStorageSummary() {
    return <String, Object?>{
      'workouts': _safeBoxLength('workouts'),
      'sets': _safeBoxLength('sets'),
      'templates': _safeBoxLength('templates'),
      'exercises': _safeBoxLength('exercises'),
      'readiness': _safeBoxLength('readiness'),
      'cardioEntries': _safeBoxLength('cardio_entries'),
      'cardioTemplates': _safeBoxLength('cardio_templates'),
      'scheduledWorkouts': _safeBoxLength('scheduled_workouts'),
      'settingsKeys': _safeSettingsKeys(),
    };
  }

  static int? _safeBoxLength(String name) {
    try {
      return Hive.box(name).length;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?>? _safeSettingsKeys() {
    try {
      final settings = Hive.box('settings');
      final keys = settings.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        'count': keys.length,
        'keys': keys,
      };
    } catch (_) {
      return null;
    }
  }
}
