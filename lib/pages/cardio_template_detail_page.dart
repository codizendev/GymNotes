import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cardio_entry.dart';
import '../models/cardio_template.dart';
import '../l10n/l10n.dart';

class CardioTemplateDetailPage extends StatefulWidget {
  final int templateKey;
  const CardioTemplateDetailPage({super.key, required this.templateKey});

  @override
  State<CardioTemplateDetailPage> createState() => _CardioTemplateDetailPageState();
}

class _CardioTemplateDetailPageState extends State<CardioTemplateDetailPage> {
  late final Box<CardioTemplate> tbox;
  final _activity = TextEditingController();
  final _distance = TextEditingController();
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    tbox = Hive.box<CardioTemplate>('cardio_templates');
    final template = tbox.get(widget.templateKey);
    if (template != null) {
      _activity.text = template.activity;
      _distance.text = template.distanceKm?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _activity.dispose();
    _distance.dispose();
    super.dispose();
  }

  CardioTemplate get tmpl => tbox.get(widget.templateKey)!;

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      _saveDetails();
    });
  }

  Future<void> _saveDetails() async {
    tmpl
      ..activity = _activity.text.trim()
      ..distanceKm = _tryParseDouble(_distance.text)
      ..durationSeconds = _plannedTotalSeconds(tmpl.segments);
    await tmpl.save();
    if (mounted) setState(() {});
  }

  Future<void> _editHeader() async {
    final s = AppLocalizations.of(context);
    final name = TextEditingController(text: tmpl.name);
    final notes = TextEditingController(text: tmpl.notes);

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.editHeaderTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: s.templateName)),
                const SizedBox(height: 8),
                TextField(controller: notes, decoration: InputDecoration(labelText: s.notesOptional)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.close)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.save)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    tmpl
      ..name = name.text.trim()
      ..notes = notes.text.trim();
    await tmpl.save();
    if (!mounted) return;
    setState(() {});
  }

  int _plannedTotalSeconds(List<CardioSegment> segments) {
    return segments.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  double? _tryParseDouble(String input) {
    final v = input.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  String _formatDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
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
    final minutesCtrl = TextEditingController(text: (seg.durationSeconds ~/ 60).toString());
    final secondsCtrl = TextEditingController(text: (seg.durationSeconds % 60).toString().padLeft(2, '0'));
    final distanceCtrl = TextEditingController(text: seg.distanceKm?.toString() ?? '');
    final targetSpeedCtrl = TextEditingController(text: seg.targetSpeedKph?.toString() ?? '');
    final inclineCtrl = TextEditingController(text: seg.inclinePercent?.toString() ?? '');
    final rpeCtrl = TextEditingController(text: seg.rpe?.toString() ?? '');
    final notesCtrl = TextEditingController(text: seg.notes);
    var selectedType = seg.type;

    final result = await showModalBottomSheet<CardioSegment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final safeBottom = MediaQuery.of(ctx).viewPadding.bottom;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + bottomInset + safeBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? s.addInterval : s.editInterval,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                    DropdownMenuItem(value: 'warmup', child: Text(s.segmentWarmup)),
                    DropdownMenuItem(value: 'work', child: Text(s.segmentWork)),
                    DropdownMenuItem(value: 'recovery', child: Text(s.segmentRecovery)),
                    DropdownMenuItem(value: 'cooldown', child: Text(s.segmentCooldown)),
                    DropdownMenuItem(value: 'easy', child: Text(s.segmentEasy)),
                    DropdownMenuItem(value: 'other', child: Text(s.segmentOther)),
                  ],
                  onChanged: (v) => setSheetState(() => selectedType = v ?? 'work'),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.distanceKm),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetSpeedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.targetSpeedKph),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: inclineCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.inclinePercent),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rpeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final minutes = int.tryParse(minutesCtrl.text.trim()) ?? 0;
                        final seconds = int.tryParse(secondsCtrl.text.trim()) ?? 0;
                        final total = (minutes * 60) + seconds;
                        Navigator.pop(
                          ctx,
                          CardioSegment(
                            label: labelCtrl.text.trim(),
                            type: selectedType,
                            durationSeconds: total,
                            distanceKm: _tryParseDouble(distanceCtrl.text),
                            targetSpeedKph: _tryParseDouble(targetSpeedCtrl.text),
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
        );
      },
    );

    if (result == null) return;
    if (index == null) {
      tmpl.segments.add(result);
    } else {
      tmpl.segments[index] = result;
    }
    tmpl.durationSeconds = _plannedTotalSeconds(tmpl.segments);
    await tmpl.save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteSegment(int index) async {
    if (index < 0 || index >= tmpl.segments.length) return;
    tmpl.segments.removeAt(index);
    tmpl.durationSeconds = _plannedTotalSeconds(tmpl.segments);
    await tmpl.save();
    if (mounted) setState(() {});
  }

  Future<void> _addWorkRestPair() async {
    tmpl.segments.addAll([
      CardioSegment(type: 'work', durationSeconds: 60),
      CardioSegment(type: 'recovery', durationSeconds: 60),
    ]);
    tmpl.durationSeconds = _plannedTotalSeconds(tmpl.segments);
    await tmpl.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final duration = _plannedTotalSeconds(tmpl.segments);
    final durationLabel = duration > 0 ? _formatDuration(duration) : s.noDuration;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.cardioTemplateTitle),
        actions: [
          IconButton(
            onPressed: _editHeader,
            icon: const Icon(Icons.edit_note),
            tooltip: s.editHeaderTitle,
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _HeaderCard(
              name: tmpl.name.isNotEmpty ? tmpl.name : s.untitled,
              notes: tmpl.notes,
              segments: tmpl.segments.length,
              duration: durationLabel,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: s.cardioDetailsTitle,
              child: Column(
                children: [
                  TextField(
                    controller: _activity,
                    decoration: InputDecoration(labelText: s.activityLabel),
                    onChanged: (_) => _scheduleSave(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _distance,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: s.distanceKm),
                    onChanged: (_) => _scheduleSave(),
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
                  if (tmpl.segments.isEmpty) Text(s.noIntervalsYet),
                  if (tmpl.segments.isNotEmpty) _buildSegmentsList(s),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentsList(AppLocalizations s) {
    return Column(
      children: tmpl.segments.asMap().entries.map((entryMap) {
        final idx = entryMap.key;
        final seg = entryMap.value;
        final duration = seg.durationSeconds > 0 ? _formatDuration(seg.durationSeconds) : s.noDuration;
        final details = <String>[
          duration,
          if (seg.distanceKm != null) '${seg.distanceKm} km',
          if (seg.targetSpeedKph != null) '${seg.targetSpeedKph} km/h',
          if (seg.inclinePercent != null) '${seg.inclinePercent!.toStringAsFixed(1)} %',
        ];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(_segmentLabel(seg, s)),
            subtitle: Text(details.join(' - ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editSegment(existing: seg, index: idx),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteSegment(idx),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.notes,
    required this.segments,
    required this.duration,
  });

  final String name;
  final String notes;
  final int segments;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(notes),
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final chips = [
                _chip(s.segmentsLabel, '$segments'),
                _chip(s.plannedDurationLabel, duration),
              ];
              if (constraints.maxWidth < 360) {
                return Column(
                  children: [
                    chips[0],
                    const SizedBox(height: 8),
                    chips[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: chips[0]),
                  const SizedBox(width: 12),
                  Expanded(child: chips[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black12.withValues(alpha: 0.04),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
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
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
