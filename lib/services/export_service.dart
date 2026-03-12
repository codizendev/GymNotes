import 'package:file_selector/file_selector.dart' as fs;
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/cardio_entry.dart';

// Android platform channel for MediaStore save
const MethodChannel _androidSaveChannel = MethodChannel('com.example.flutter_application_1/media_save');

Future<bool> _savePdfToAndroidMediaStore(Uint8List bytes, String filename) async {
  try {
    final b64 = base64Encode(bytes);
    final res = await _androidSaveChannel.invokeMethod('savePdf', {'filename': filename, 'bytesBase64': b64});
    return res == true;
  } catch (e) {
    print('MediaStore save error: $e');
    return false;
  }
}

/// Public helper used by tests to build PDF bytes with embedded payload.
@visibleForTesting
Future<Uint8List> buildWorkoutPdfBytesForTest(Workout workout, List<SetEntry> sets) async {
  final bytes = await _buildWorkoutPdfBytes(workout, sets: sets);
  return Uint8List.fromList(bytes);
}

/// ===== Public API =====
/// shareWorkoutPdf / shareCardioWorkoutPdf
/// - extractEmbeddedFromPdf(Uint8List bytes)
/// - importPayloadFromPdfBytes(Uint8List bytes)

Future<void> shareWorkoutPdf(Workout workout, List<SetEntry> sets) async {
  final bytes = await _buildWorkoutPdfBytes(workout, sets: sets);
  final fname = _defaultFileName(workout, 'pdf');
  await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fname);
}

Future<void> shareCardioWorkoutPdf(Workout workout, CardioEntry entry) async {
  final bytes = await _buildWorkoutPdfBytes(workout, cardio: entry);
  final fname = _defaultFileName(workout, 'pdf');
  await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fname);
}

/// If PDF contains embedded payload, return decoded Map. Otherwise null.
Future<Map<String, dynamic>?> extractEmbeddedFromPdf(Uint8List bytes) async {
  final payload = _extractEmbedBlock(bytes);
  if (payload == null) return null;
  try {
    final jsonStr = utf8.decode(base64Decode(payload));
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return map;
  } catch (_) {
    return null;
  }
}

/// Attempt to build domain objects from PDF bytes.
/// Does not save to database - UI decides how to import.
/// Returns tuple with Workout and list of SetEntry (sorted by setNumber).
Future<({Workout workout, List<SetEntry> sets})?> importPayloadFromPdfBytes(
  Uint8List bytes,
) async {
  final map = await extractEmbeddedFromPdf(bytes);
  if (map == null) return null;

  final version = (map['version'] ?? 1) as int;
  if (version != 1) {
    // TODO: migrations as needed
  }

  final w = map['workout'] as Map<String, dynamic>;
  final sList = (map['sets'] as List).cast<Map>();

  final workout = Workout(
    date: DateTime.parse(w['date'] as String),
    title: (w['title'] ?? '') as String,
    notes: (w['notes'] ?? '') as String,
    kind: (w['kind'] as String?) ?? 'strength',
  )
    ..totalSets = (w['totalSets'] ?? 0) as int
    ..totalReps = (w['totalReps'] ?? 0) as int
    ..totalVolume = ((w['totalVolume'] ?? 0.0) as num).toDouble();

  final sets = <SetEntry>[];
  for (final m in sList) {
    sets.add(
      SetEntry(
        workoutKey: -1,
        exercise: (m['exercise'] ?? '') as String,
        setNumber: (m['setNumber'] ?? 1) as int,
        reps: (m['reps'] ?? 0) as int,
        weightKg: ((m['weightKg'] ?? 0.0) as num).toDouble(),
        rpe: (m['rpe'] == null) ? null : ((m['rpe'] as num).toDouble()),
        notes: (m['notes'] ?? '') as String,
        isTimeBased: (m['isTimeBased'] ?? false) as bool,
        seconds: (m['seconds'] == null) ? null : (m['seconds'] as int),
        isCompleted: (m['isCompleted'] ?? false) as bool,
      ),
    );
  }

  sets.sort((a, b) => a.setNumber.compareTo(b.setNumber));

  return (workout: workout, sets: sets);
}

/// ===== Helpers =====

String _defaultFileName(Workout w, String ext) {
  final df = DateFormat('yyyy-MM-dd');
  final d = df.format(w.date);
  final title = (w.title.isNotEmpty ? '-${_fileSafe(w.title)}' : '');
  return 'Workout-$d$title.$ext';
}

String _fileSafe(String s) => s.replaceAll(RegExp(r'[^\w\-]+'), '_').replaceAll('__', '_');

String _fmtDate(DateTime d) => DateFormat('dd.MM.yyyy.').format(d);

String _fmtDuration(int seconds) {
  final mm = (seconds ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

String _segmentLabel(CardioSegment seg) {
  if (seg.label.trim().isNotEmpty) return seg.label.trim();
  switch (seg.type) {
    case 'warmup':
      return 'Warmup';
    case 'work':
      return 'Work';
    case 'recovery':
      return 'Recovery';
    case 'cooldown':
      return 'Cooldown';
    case 'easy':
      return 'Easy';
    default:
      return 'Other';
  }
}

String _segmentDetails(CardioSegment seg) {
  final details = <String>[];
  if (seg.rpe != null) {
    details.add('RPE ${seg.rpe!.toStringAsFixed(1)}');
  }
  if (seg.notes.trim().isNotEmpty) {
    details.add(seg.notes.trim());
  }
  return details.isEmpty ? '-' : details.join(' | ');
}

String _segmentDistance(CardioSegment seg) {
  if (seg.distanceKm == null) return '-';
  return '${seg.distanceKm!.toStringAsFixed(2)} km';
}

String _segmentSpeed(CardioSegment seg) {
  if (seg.targetSpeedKph == null) return '-';
  return '${seg.targetSpeedKph!.toStringAsFixed(1)} km/h';
}

String _segmentIncline(CardioSegment seg) {
  if (seg.inclinePercent == null) return '-';
  return '${seg.inclinePercent!.toStringAsFixed(1)} %';
}

String _fmtSetLine(SetEntry s) {
  if (s.isTimeBased) {
    final total = s.seconds ?? 0;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    final add = (s.weightKg > 0) ? '  +${s.weightKg.toStringAsFixed(1)} kg' : '';
    return '$mm:$ss$add';
  } else {
    return '${s.reps} reps @ ${s.weightKg.toStringAsFixed(1)} kg';
  }
}

/// ===== PDF (with embedded payload) =====

const _kEmbedStart = '[[WL-EMBED:';
const _kEmbedEnd = ']]';

Map<String, dynamic> _payloadMap(Workout workout, List<SetEntry> sets, {CardioEntry? cardio}) {
  final sorted = [...sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
  final payload = {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'workout': {
      'date': workout.date.toIso8601String(),
      'title': workout.title,
      'notes': workout.notes,
      'kind': workout.kind,
      'totalSets': workout.totalSets,
      'totalReps': workout.totalReps,
      'totalVolume': workout.totalVolume,
    },
    'sets': [
      for (final s in sorted)
        {
          'exercise': s.exercise,
          'setNumber': s.setNumber,
          'reps': s.reps,
          'weightKg': s.weightKg,
          'rpe': s.rpe,
          'notes': s.notes,
          'isTimeBased': s.isTimeBased,
          'seconds': s.seconds,
          'isCompleted': s.isCompleted,
        }
    ],
  };
  if (cardio != null) {
    payload['cardio'] = {
      'activity': cardio.activity,
      'durationSeconds': cardio.durationSeconds,
      'distanceKm': cardio.distanceKm,
      'elevationGainM': cardio.elevationGainM,
      'inclinePercent': cardio.inclinePercent,
      'avgHeartRate': cardio.avgHeartRate,
      'maxHeartRate': cardio.maxHeartRate,
      'rpe': cardio.rpe,
      'calories': cardio.calories,
      'zoneSeconds': cardio.zoneSeconds,
      'environment': cardio.environment,
      'terrain': cardio.terrain,
      'weather': cardio.weather,
      'equipment': cardio.equipment,
      'mood': cardio.mood,
      'energy': cardio.energy,
      'notes': cardio.notes,
      'segments': [
        for (final seg in cardio.segments)
          {
            'label': seg.label,
            'type': seg.type,
            'durationSeconds': seg.durationSeconds,
            'distanceKm': seg.distanceKm,
            'targetSpeedKph': seg.targetSpeedKph,
            'inclinePercent': seg.inclinePercent,
            'rpe': seg.rpe,
            'notes': seg.notes,
          }
      ],
    };
  }
  return payload;
}

Future<List<int>> _buildWorkoutPdfBytes(
  Workout workout, {
  List<SetEntry> sets = const [],
  CardioEntry? cardio,
}) async {
  // compress: false keeps content stream uncompressed for easy extraction
  final doc = pw.Document(compress: false);

  final titleStyle = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  final h2 = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700);
  final body = pw.TextStyle(fontSize: 11);

  final dateStr = _fmtDate(workout.date);
  final isCardio = workout.kind == 'cardio' || cardio != null;
  final headerTitle = workout.title.isNotEmpty ? workout.title : (isCardio ? 'Cardio Workout' : 'Workout');
  final headerSubtitle =
      workout.title.isNotEmpty ? '$dateStr - ${isCardio ? 'Cardio Workout' : 'Strength Workout'}' : dateStr;
  final sectionStyle = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  final accent = PdfColor.fromInt(0xFF7DAE3E);
  final soft = PdfColor.fromInt(0xFFF2F4F6);
  const tableCellPadding = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4);
  const tableHeaderAlignment = pw.Alignment.centerLeft;

  pw.Widget sectionTitle(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: soft,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text, style: sectionStyle),
    );
  }

  pw.Widget keyValueTable(List<List<String>> rows, {List<String> headers = const ['Metric', 'Value']}) {
    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerAlignment: tableHeaderAlignment,
      headerPadding: tableCellPadding,
      cellStyle: body,
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: tableCellPadding,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(2.7),
      },
      border: null,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0x22000000), width: 0.5),
        ),
      ),
    );
  }

  final embedJson = jsonEncode(_payloadMap(workout, sets, cardio: cardio));
  final embedB64 = base64Encode(utf8.encode(embedJson));
  final embedLine = '$_kEmbedStart$embedB64$_kEmbedEnd';

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: pw.BoxDecoration(
              color: soft,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 4, height: 44, color: accent),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GymNotes', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(headerTitle, style: titleStyle),
                      pw.SizedBox(height: 2),
                      pw.Text(headerSubtitle, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

        if (workout.notes.isNotEmpty) {
          widgets.addAll([
            pw.SizedBox(height: 12),
            pw.Text('Notes', style: h2),
            pw.SizedBox(height: 4),
            pw.Text(workout.notes, style: body),
          ]);
        }

        if (isCardio) {
          final entry = cardio ?? CardioEntry(workoutKey: -1);
          final plannedSeconds = entry.segments.fold<int>(0, (sum, s) => sum + s.durationSeconds);
          final durationSeconds =
              entry.durationSeconds > 0 ? entry.durationSeconds : (plannedSeconds > 0 ? plannedSeconds : 0);
          final durationLabel = durationSeconds > 0 ? _fmtDuration(durationSeconds) : '-';

          final summary = <List<String>>[
            if (entry.activity.trim().isNotEmpty) ['Activity', entry.activity.trim()],
            ['Duration', durationLabel],
            if (plannedSeconds > 0 && plannedSeconds != durationSeconds) ['Planned', _fmtDuration(plannedSeconds)],
            if (entry.distanceKm != null) ['Distance', '${entry.distanceKm!.toStringAsFixed(2)} km'],
            if (entry.calories != null) ['Calories', '${entry.calories!.toStringAsFixed(0)} kcal'],
            if (entry.rpe != null) ['RPE', entry.rpe!.toStringAsFixed(1)],
            if (entry.avgHeartRate != null) ['Avg HR', '${entry.avgHeartRate} bpm'],
            if (entry.maxHeartRate != null) ['Max HR', '${entry.maxHeartRate} bpm'],
            if (entry.elevationGainM != null) ['Elevation gain', '${entry.elevationGainM!.toStringAsFixed(0)} m'],
            if (entry.inclinePercent != null) ['Incline', '${entry.inclinePercent!.toStringAsFixed(1)} %'],
            ['Segments', entry.segments.length.toString()],
          ];

          final context = <List<String>>[
            if (entry.environment.trim().isNotEmpty) ['Environment', entry.environment.trim()],
            if (entry.terrain.trim().isNotEmpty) ['Terrain', entry.terrain.trim()],
            if (entry.weather.trim().isNotEmpty) ['Weather', entry.weather.trim()],
            if (entry.equipment.trim().isNotEmpty) ['Equipment', entry.equipment.trim()],
            if (entry.mood.trim().isNotEmpty) ['Mood', entry.mood.trim()],
            if (entry.energy != null) ['Energy', entry.energy.toString()],
          ];

          final zones = <List<String>>[];
          for (var i = 0; i < entry.zoneSeconds.length; i++) {
            final seconds = entry.zoneSeconds[i];
            if (seconds > 0) {
              zones.add(['Zone ${i + 1}', _fmtDuration(seconds)]);
            }
          }

          widgets.addAll([
            sectionTitle('Summary'),
            if (summary.isEmpty) pw.Text('-', style: body) else keyValueTable(summary),
            if (context.isNotEmpty) ...[
              sectionTitle('Context'),
              keyValueTable(context),
            ],
            if (zones.isNotEmpty) ...[
              sectionTitle('Heart Rate Zones'),
              keyValueTable(zones, headers: const ['Zone', 'Time']),
            ],
            if (entry.notes.trim().isNotEmpty) ...[
              sectionTitle('Notes'),
              pw.Text(entry.notes.trim(), style: body),
            ],
            sectionTitle('Intervals (${entry.segments.length})'),
            if (entry.segments.isEmpty)
              pw.Text('No intervals', style: body)
            else
              pw.Table.fromTextArray(
                headers: ['Segment', 'Duration', 'Distance', 'Speed', 'Incline', 'Details'],
                data: [
                  for (final seg in entry.segments)
                    [
                      _segmentLabel(seg),
                      _fmtDuration(seg.durationSeconds),
                      _segmentDistance(seg),
                      _segmentSpeed(seg),
                      _segmentIncline(seg),
                      _segmentDetails(seg),
                    ]
                ],
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerAlignment: tableHeaderAlignment,
                headerPadding: tableCellPadding,
                cellStyle: body,
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: tableCellPadding,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.3),
                  1: const pw.FlexColumnWidth(0.8),
                  2: const pw.FlexColumnWidth(0.9),
                  3: const pw.FlexColumnWidth(0.9),
                  4: const pw.FlexColumnWidth(0.9),
                  5: const pw.FlexColumnWidth(1.8),
                },
                border: null,
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromInt(0x22000000), width: 0.5),
                  ),
                ),
              ),
          ]);
        } else {
          final ordered = [...sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
          final supersetGroups = <List<SetEntry>>[];
          final supersetLabels = <int, String>{};
          var ssIndex = 0;
          var i = 0;
          while (i < ordered.length) {
            final entry = ordered[i];
            if (!entry.isSuperset) {
              i += 1;
              continue;
            }
            final group = <SetEntry>[entry];
            i += 1;
            if (i < ordered.length && ordered[i].isSuperset) {
              group.add(ordered[i]);
              i += 1;
            }
            ssIndex += 1;
            supersetGroups.add(group);
            for (final member in group) {
              supersetLabels[member.setNumber] = 'SS$ssIndex';
            }
          }

          final summary = <List<String>>[
            ['Sets', workout.totalSets.toString()],
            ['Reps', workout.totalReps.toString()],
            ['Volume', '${workout.totalVolume.toStringAsFixed(0)} kg'],
            if (ordered.any((s) => s.isTimeBased)) ['Time sets', ordered.where((s) => s.isTimeBased).length.toString()],
            if (supersetGroups.isNotEmpty) ['Supersets', supersetGroups.length.toString()],
          ];

          widgets.addAll([
            sectionTitle('Summary'),
            if (summary.isEmpty) pw.Text('-', style: body) else keyValueTable(summary),
            sectionTitle('Sets (${ordered.length})'),
            pw.Table.fromTextArray(
              headers: ['Exercise', 'Set', 'Details', 'SS', 'Notes'],
              data: [
                for (final s in ordered)
                  [
                    s.exercise,
                    s.setNumber.toString(),
                    _fmtSetLine(s),
                    supersetLabels[s.setNumber] ?? '-',
                    [
                      if (s.rpe != null) 'RPE ${s.rpe}',
                      if (s.notes.isNotEmpty) s.notes,
                    ].join(' | '),
                  ],
              ],
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerAlignment: tableHeaderAlignment,
              headerPadding: tableCellPadding,
              cellStyle: body,
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: tableCellPadding,
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(0.6),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(0.6),
                4: const pw.FlexColumnWidth(2.1),
              },
              border: null,
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromInt(0x22000000), width: 0.5),
                ),
              ),
            ),
            if (supersetGroups.isNotEmpty) ...[
              sectionTitle('Supersets'),
              pw.Table.fromTextArray(
                headers: ['Group', 'Exercises'],
                data: [
                  for (var index = 0; index < supersetGroups.length; index++)
                    [
                      'SS${index + 1}',
                      supersetGroups[index]
                          .map((s) => s.exercise.trim())
                          .where((name) => name.isNotEmpty)
                          .join(' + '),
                    ],
                ],
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerAlignment: tableHeaderAlignment,
                headerPadding: tableCellPadding,
                cellStyle: body,
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: tableCellPadding,
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(3.8),
                },
                border: null,
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromInt(0x22000000), width: 0.5),
                  ),
                ),
              ),
            ],
          ]);
        }

        widgets.addAll([
          pw.SizedBox(height: 2),
          pw.Text(
            embedLine,
            style: pw.TextStyle(fontSize: 0.1, color: PdfColors.white),
          ),
        ]);

        return widgets;
      },
    ),
  );

  return await doc.save();
}

String? _extractEmbedBlock(Uint8List bytes) {
  final startBytes = ascii.encode(_kEmbedStart);
  final endBytes = ascii.encode(_kEmbedEnd);

  int indexOf(Uint8List data, List<int> pattern, [int start = 0]) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  final s = indexOf(bytes, startBytes, 0);
  if (s < 0) return null;
  final e = indexOf(bytes, endBytes, s + startBytes.length);
  if (e < 0) return null;

  final b64 = bytes.sublist(s + startBytes.length, e);
  try {
    return ascii.decode(b64);
  } catch (_) {
    return null;
  }
}

Future<String> saveWorkoutPdfToDevice(Workout workout, List<SetEntry> sets) async {
  final bytes = await _buildWorkoutPdfBytes(workout, sets: sets);
  final suggested = _defaultFileName(workout, 'pdf');

  if (kIsWeb) {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: suggested);
    print('PDF offered for download (web)');
    return '';
  }

  if (Platform.isAndroid) {
    final ok = await _savePdfToAndroidMediaStore(Uint8List.fromList(bytes), suggested);
    if (ok) {
      print('PDF saved to Downloads (Android via MediaStore)');
      return 'Downloads';
    }
    // Fallback to app Documents
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$suggested';
    await File(path).writeAsBytes(bytes, flush: true);
    print('MediaStore fallback saved to app dir: $path');
    return path;
  }

  if (Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$suggested';
    await File(path).writeAsBytes(bytes, flush: true);
    print('PDF saved to app Documents (iOS): $path');
    return path;
  }

  // Desktop
  final location = await fs.getSaveLocation(
    suggestedName: suggested,
    acceptedTypeGroups: const [
      fs.XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']),
    ],
  );
  if (location == null) return '';
  final xf = fs.XFile.fromData(Uint8List.fromList(bytes), name: suggested, mimeType: 'application/pdf');
  await xf.saveTo(location.path);
  print('PDF saved: ${location.path}');
  return location.path;
}

Future<String> saveCardioWorkoutPdfToDevice(Workout workout, CardioEntry entry) async {
  final bytes = await _buildWorkoutPdfBytes(workout, cardio: entry);
  final suggested = _defaultFileName(workout, 'pdf');

  if (kIsWeb) {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: suggested);
    print('PDF offered for download (web)');
    return '';
  }

  if (Platform.isAndroid) {
    final ok = await _savePdfToAndroidMediaStore(Uint8List.fromList(bytes), suggested);
    if (ok) {
      print('PDF saved to Downloads (Android via MediaStore)');
      return 'Downloads';
    }
    // Fallback to app Documents
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$suggested';
    await File(path).writeAsBytes(bytes, flush: true);
    print('MediaStore fallback saved to app dir: $path');
    return path;
  }

  if (Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$suggested';
    await File(path).writeAsBytes(bytes, flush: true);
    print('PDF saved to app Documents (iOS): $path');
    return path;
  }

  // Desktop
  final location = await fs.getSaveLocation(
    suggestedName: suggested,
    acceptedTypeGroups: const [
      fs.XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']),
    ],
  );
  if (location == null) return '';
  final xf = fs.XFile.fromData(Uint8List.fromList(bytes), name: suggested, mimeType: 'application/pdf');
  await xf.saveTo(location.path);
  print('PDF saved: ${location.path}');
  return location.path;
}
