import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static const int _maxEntries = 250;
  static final List<Map<String, Object?>> _entries = <Map<String, Object?>>[];

  static void info(String message, {Map<String, Object?>? context}) {
    _append(level: 'INFO', message: message, context: context);
  }

  static void warn(String message, {Map<String, Object?>? context}) {
    _append(level: 'WARN', message: message, context: context);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _append(
      level: 'ERROR',
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static List<Map<String, Object?>> snapshot() {
    return List<Map<String, Object?>>.from(_entries);
  }

  static String asText() {
    return const JsonEncoder.withIndent('  ').convert(_entries);
  }

  static void _append({
    required String level,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final entry = <String, Object?>{
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'message': message,
      if (context != null && context.isNotEmpty) 'context': _normalizeMap(context),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }

    debugPrint('[${entry['timestampUtc']}] $level $message');
    if (error != null) {
      debugPrint('  error: $error');
    }
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Map<String, Object?> _normalizeMap(Map<String, Object?> source) {
    return source.map((key, value) => MapEntry(key, _normalizeValue(value)));
  }

  static Object? _normalizeValue(Object? value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String ||
        value is Map<String, Object?> ||
        value is List<Object?>) {
      return value;
    }
    return value.toString();
  }
}
