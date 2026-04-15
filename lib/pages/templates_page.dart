import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout_template.dart';
import '../models/cardio_entry.dart';
import '../models/cardio_template.dart';
import 'template_detail_page.dart';
import 'cardio_template_detail_page.dart';

// localization
import '../l10n/l10n.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  late final Box<WorkoutTemplate> tbox;
  late final Box<CardioTemplate> ctbox;

  @override
  void initState() {
    super.initState();
    tbox = Hive.box<WorkoutTemplate>('templates');
    ctbox = Hive.box<CardioTemplate>('cardio_templates');
  }

  Future<void> _createTemplate() async {
    final s = AppLocalizations.of(context);
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.newTemplate),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.templateName)),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: InputDecoration(labelText: s.notesOptional)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.create)),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final tmpl = WorkoutTemplate(name: name, notes: notesCtrl.text.trim(), sets: []);
    await tbox.add(tmpl);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateDetailPage(templateKey: tmpl.key as int)));
  }

  Future<void> _duplicate(WorkoutTemplate t) async {
    final s = AppLocalizations.of(context);
    final copy = WorkoutTemplate(
      name: '${t.name} (copy)',
      notes: t.notes,
      sets: [
        for (final ss in t.sets)
          TemplateSet(
            exercise: ss.exercise,
            setNumber: ss.setNumber,
            reps: ss.reps,
            weightKg: ss.weightKg,
            rpe: ss.rpe,
            notes: ss.notes,
            isTimeBased: ss.isTimeBased,
            seconds: ss.seconds,
            isSuperset: ss.isSuperset,
          ),
      ],
    );
    await tbox.add(copy);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.templateDuplicated)));
    setState(() {});
  }

  Future<void> _delete(WorkoutTemplate t) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.deleteTemplateTitle),
            content: Text(s.deleteTemplateBody(t.name)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: Text(s.delete)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final backup = WorkoutTemplate(
      name: t.name,
      notes: t.notes,
      sets: [
        for (final ss in t.sets)
          TemplateSet(
            exercise: ss.exercise,
            setNumber: ss.setNumber,
            reps: ss.reps,
            weightKg: ss.weightKg,
            rpe: ss.rpe,
            notes: ss.notes,
            isTimeBased: ss.isTimeBased,
            seconds: ss.seconds,
            isSuperset: ss.isSuperset,
          ),
      ],
    );
    final deletedName = t.name;

    await t.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).templateDeleted(deletedName)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await tbox.add(backup);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _createCardioTemplate() async {
    final s = AppLocalizations.of(context);
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.newCardioTemplate),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.templateName)),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: InputDecoration(labelText: s.notesOptional)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.create)),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final tmpl = CardioTemplate(name: name, notes: notesCtrl.text.trim());
    await ctbox.add(tmpl);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CardioTemplateDetailPage(templateKey: tmpl.key as int)),
    );
  }

  Future<void> _duplicateCardioTemplate(CardioTemplate t) async {
    final s = AppLocalizations.of(context);
    final plannedSeconds = _plannedTotalSeconds(t.segments);
    final copy = CardioTemplate(
      name: '${t.name} (copy)',
      activity: t.activity,
      durationSeconds: plannedSeconds,
      distanceKm: t.distanceKm,
      elevationGainM: t.elevationGainM,
      inclinePercent: t.inclinePercent,
      avgHeartRate: t.avgHeartRate,
      maxHeartRate: t.maxHeartRate,
      rpe: t.rpe,
      calories: t.calories,
      zoneSeconds: List<int>.from(t.zoneSeconds),
      segments: t.segments.map((s) => s.copy()).toList(),
      environment: t.environment,
      terrain: t.terrain,
      weather: t.weather,
      equipment: t.equipment,
      mood: t.mood,
      energy: t.energy,
      notes: t.notes,
    );
    await ctbox.add(copy);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.templateDuplicated)));
    setState(() {});
  }

  Future<void> _deleteCardioTemplate(CardioTemplate t) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(s.deleteTemplateTitle),
            content: Text(s.deleteTemplateBody(t.name)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: Text(s.delete)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final plannedSeconds = _plannedTotalSeconds(t.segments);
    final backup = CardioTemplate(
      name: t.name,
      activity: t.activity,
      durationSeconds: plannedSeconds,
      distanceKm: t.distanceKm,
      elevationGainM: t.elevationGainM,
      inclinePercent: t.inclinePercent,
      avgHeartRate: t.avgHeartRate,
      maxHeartRate: t.maxHeartRate,
      rpe: t.rpe,
      calories: t.calories,
      zoneSeconds: List<int>.from(t.zoneSeconds),
      segments: t.segments.map((s) => s.copy()).toList(),
      environment: t.environment,
      terrain: t.terrain,
      weather: t.weather,
      equipment: t.equipment,
      mood: t.mood,
      energy: t.energy,
      notes: t.notes,
    );
    final deletedName = t.name;

    await t.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).templateDeleted(deletedName)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await ctbox.add(backup);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    setState(() {});
  }

  String _formatDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  int _plannedTotalSeconds(List<CardioSegment> segments) {
    return segments.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final listenable = Listenable.merge([tbox.listenable(), ctbox.listenable()]);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final extraBottom = 16.0 + bottomInset;

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final items = tbox.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final cardioItems = ctbox.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return Scaffold(
          appBar: AppBar(
            title: Text(s.templates),
          ),
          body: SafeArea(
            bottom: true,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, extraBottom),
              children: [
                _SectionHeader(
                  title: s.workoutTypeStrength,
                  actionLabel: s.newTemplate,
                  onPressed: _createTemplate,
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.noTemplatesYet),
                  )
                else
                  ...items.map((t) {
                    final supersetSets = t.sets.where((ss) => ss.isSuperset).length;
                    final subtitle =
                        '${t.sets.length} ${s.setsCount.toLowerCase()}'
                        '${supersetSets > 0 ? ' - Superset sets: $supersetSets' : ''}'
                        '${t.notes.isNotEmpty ? ' - ${t.notes}' : ''}';
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(t.name),
                            subtitle: Text(subtitle),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => TemplateDetailPage(templateKey: t.key as int)),
                                  );
                                } else if (v == 'dup') {
                                  await _duplicate(t);
                                } else if (v == 'del') {
                                  await _delete(t);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(leading: const Icon(Icons.edit), title: Text(s.edit)),
                                ),
                                PopupMenuItem(
                                  value: 'dup',
                                  child: ListTile(leading: const Icon(Icons.copy), title: Text(s.duplicate)),
                                ),
                                PopupMenuItem(
                                  value: 'del',
                                  child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(s.delete)),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TemplateDetailPage(templateKey: t.key as int)),
                              );
                            },
                          ),
                        ),
                      );
                  }),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: s.workoutTypeCardio,
                  actionLabel: s.newCardioTemplate,
                  onPressed: _createCardioTemplate,
                ),
                if (cardioItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.noCardioTemplates),
                  )
                else
                  ...cardioItems.map((t) {
                    final plannedSeconds = _plannedTotalSeconds(t.segments);
                    final duration = plannedSeconds > 0 ? _formatDuration(plannedSeconds) : s.noDuration;
                    final subtitle = '${s.segmentsLabel}: ${t.segments.length} - ${s.durationLabel}: $duration'
                        '${t.notes.isNotEmpty ? '\n${t.notes}' : ''}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(subtitle),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CardioTemplateDetailPage(templateKey: t.key as int)),
                                );
                              } else if (v == 'dup') {
                                await _duplicateCardioTemplate(t);
                              } else if (v == 'del') {
                                await _deleteCardioTemplate(t);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(leading: const Icon(Icons.edit), title: Text(s.edit)),
                              ),
                              PopupMenuItem(
                                value: 'dup',
                                child: ListTile(leading: const Icon(Icons.copy), title: Text(s.duplicate)),
                              ),
                              PopupMenuItem(
                                value: 'del',
                                child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(s.delete)),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CardioTemplateDetailPage(templateKey: t.key as int)),
                            );
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleWidget = Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          );
          final actionWidget = TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(actionLabel),
          );

          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                Align(alignment: Alignment.centerRight, child: actionWidget),
              ],
            );
          }

          return Row(
            children: [
              titleWidget,
              const Spacer(),
              actionWidget,
            ],
          );
        },
      ),
    );
  }
}
