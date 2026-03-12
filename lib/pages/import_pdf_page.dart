import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/workout.dart';
import '../models/set_entry.dart';
import '../models/workout_template.dart';
import '../services/export_service.dart' show importPayloadFromPdfBytes;
import '../services/pro_service.dart';
import '../l10n/l10n.dart';

class ImportPdfScreen extends StatefulWidget {
  const ImportPdfScreen({super.key});

  @override
  State<ImportPdfScreen> createState() => _ImportPdfScreenState();
}

class _ImportPdfScreenState extends State<ImportPdfScreen> {
  ({Workout workout, List<SetEntry> sets})? _preview;
  bool _loading = false;
  String? _error;

  Future<void> _pickAndParse() async {
    final s = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      Uint8List bytes;
      final picked = res.files.single;
      if (picked.bytes != null) {
        bytes = picked.bytes!;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        throw Exception(s.pdfParseError);
      }

      final parsed = await importPayloadFromPdfBytes(bytes);
      if (parsed == null) {
        setState(() {
          _loading = false;
          _error = s.pdfNoEmbeddedData;
        });
        return;
      }

      setState(() {
        _preview = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = s.importFailed(e.toString());
      });
    }
  }

  Future<void> _saveAsWorkout() async {
    if (_preview == null) return;
    final wbox = Hive.box<Workout>('workouts');
    final sbox = Hive.box<SetEntry>('sets');

    final w = _preview!.workout;
    final sets = _preview!.sets;

    final newKey = await wbox.add(Workout(
      date: w.date,
      title: w.title,
      notes: w.notes,
      kind: w.kind,
    )
      ..totalSets = w.totalSets
      ..totalReps = w.totalReps
      ..totalVolume = w.totalVolume);

    for (final entry in sets) {
      await sbox.add(SetEntry(
        workoutKey: newKey,
        exercise: entry.exercise,
        setNumber: entry.setNumber,
        reps: entry.reps,
        weightKg: entry.weightKg,
        rpe: entry.rpe,
        notes: entry.notes,
        isTimeBased: entry.isTimeBased,
        seconds: entry.seconds,
        isCompleted: entry.isCompleted,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).importSuccessWorkout)),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_preview == null) return;
    final tbox = Hive.box<WorkoutTemplate>('templates');
    final settings = Hive.box('settings');
    if (!await ProService.ensureTemplateCapacity(context, settings, tbox.length)) return;

    final w = _preview!.workout;
    final sets = _preview!.sets;

    final name = (w.title.trim().isEmpty)
        ? 'Workout ${_two(w.date.day)}.${_two(w.date.month)}.${w.date.year}.'
        : w.title.trim();

    final tmpl = WorkoutTemplate(
      name: name,
      notes: w.notes,
      sets: [
        for (final entry in sets)
          TemplateSet(
            exercise: entry.exercise,
            setNumber: entry.setNumber,
            reps: entry.reps,
            weightKg: entry.weightKg,
            rpe: entry.rpe,
            notes: entry.notes,
            isTimeBased: entry.isTimeBased,
            seconds: entry.seconds,
          )
      ],
    );

    await tbox.add(tmpl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).importSuccessTemplate)),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.importFromPdfTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _pickAndParse,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(s.choosePdf),
            ),
            const SizedBox(height: 16),

            if (_loading) const LinearProgressIndicator(),

            if (_error != null) ...[
              Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
            ],

            if (_preview != null)
              Expanded(
                child: _ImportedPreviewCard(
                  preview: _preview!,
                  onSaveWorkout: _saveAsWorkout,
                  onSaveTemplate: _saveAsTemplate,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportedPreviewCard extends StatelessWidget {
  final ({Workout workout, List<SetEntry> sets}) preview;
  final VoidCallback onSaveWorkout;
  final VoidCallback onSaveTemplate;

  const _ImportedPreviewCard({
    required this.preview,
    required this.onSaveWorkout,
    required this.onSaveTemplate,
  });

  String _fmtDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}.';

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final w = preview.workout;
    final sets = [...preview.sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                w.title.isEmpty ? s.workout : w.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_fmtDate(w.date)),
              trailing: Text('${s.setsCount}: ${sets.length}'),
            ),
            if (w.notes.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(w.notes),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: sets.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final entry = sets[i];
                  final detail = entry.isTimeBased
                      ? _fmtTimeDetail(entry.seconds ?? 0, entry.weightKg)
                      : '${entry.reps} ${s.reps.toLowerCase()} @ ${entry.weightKg.toStringAsFixed(1)} kg';
                  final extras = <String>[];
                  if (entry.rpe != null) extras.add('RPE ${entry.rpe}');
                  if (entry.notes.isNotEmpty) extras.add(entry.notes);
                  final extraText = extras.join(' - ');
                  return ListTile(
                    dense: true,
                    title: Text('${entry.exercise} - ${s.setNumberShort} ${entry.setNumber}'),
                    subtitle: Text(extraText.isEmpty ? detail : '$detail\n$extraText'),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSaveTemplate,
                    icon: const Icon(Icons.save_alt),
                    label: Text(s.importAsTemplate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSaveWorkout,
                    icon: const Icon(Icons.check_circle),
                    label: Text(s.importAsWorkout),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTimeDetail(int totalSeconds, double weightKg) {
    final mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    final add = (weightKg > 0) ? '  +${weightKg.toStringAsFixed(1)} kg' : '';
    return '$mm:$ss$add';
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
