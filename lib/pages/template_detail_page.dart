import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout_template.dart';
import '../models/exercise.dart';
// 👇 lokalizacija
import '../l10n/l10n.dart';

class TemplateDetailPage extends StatefulWidget {
  final int templateKey;
  const TemplateDetailPage({super.key, required this.templateKey});

  @override
  State<TemplateDetailPage> createState() => _TemplateDetailPageState();
}

class _TemplateDetailPageState extends State<TemplateDetailPage> {
  late final Box<WorkoutTemplate> tbox;

  @override
  void initState() {
    super.initState();
    tbox = Hive.box<WorkoutTemplate>('templates');
  }

  WorkoutTemplate get tmpl => tbox.get(widget.templateKey)!;

  List<TemplateSet> get _sets {
    final list = [...tmpl.sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    return list;
  }

  Future<void> _saveHeader() async {
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

  Future<void> _applyNewOrder(List<TemplateSet> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].setNumber = i + 1;
    }
    tmpl.sets
      ..clear()
      ..addAll(ordered);
    await tmpl.save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _addSet() async {
    final nextNo = (_sets.isEmpty ? 0 : _sets.last.setNumber) + 1;

    final res = await showModalBottomSheet<TemplateSet>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _TemplateSetForm(
            initial: TemplateSet(
              exercise: '',
              setNumber: nextNo,
              reps: 10,
              weightKg: 20,
              isTimeBased: false,
              seconds: null,
            ),
          ),
        ),
      ),
    );
    if (res == null) return;

    tmpl.sets.add(res);
    await tmpl.save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editSet(TemplateSet s) async {
    final res = await showModalBottomSheet<TemplateSet>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _TemplateSetForm(initial: s),
        ),
      ),
    );
    if (res == null) return;

    s
      ..exercise = res.exercise
      ..setNumber = res.setNumber
      ..reps = res.reps
      ..weightKg = res.weightKg
      ..rpe = res.rpe
      ..notes = res.notes
      ..isTimeBased = res.isTimeBased
      ..seconds = res.seconds;

    final ordered = _sets..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    await _applyNewOrder(ordered);
  }

  Future<void> _duplicateSet(TemplateSet source) async {
    final list = _sets;
    final pivot = source.setNumber + 1;
    for (final e in list.reversed) {
      if (e.setNumber >= pivot) e.setNumber = e.setNumber + 1;
    }
    final dup = TemplateSet(
      exercise: source.exercise,
      setNumber: source.setNumber + 1,
      reps: source.reps,
      weightKg: source.weightKg,
      rpe: source.rpe,
      notes: source.notes,
      isTimeBased: source.isTimeBased,
      seconds: source.seconds,
    );
    list.add(dup);
    await _applyNewOrder(list);
  }

  Future<void> _deleteSet(TemplateSet s) async {
    tmpl.sets.remove(s);
    await tmpl.save();
    final ordered = _sets..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    await _applyNewOrder(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final sets = _sets;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final extraBottom = 56.0 + 16.0 + bottomInset;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.templateTitle),
        actions: [
          IconButton(
            onPressed: _saveHeader,
            icon: const Icon(Icons.edit_note),
            tooltip: s.editHeaderTitle,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSet,
        icon: const Icon(Icons.add),
        label: Text(s.addSet),
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _HeaderCard(
                name: tmpl.name.isNotEmpty ? tmpl.name : s.untitled,
                notes: tmpl.notes,
                count: sets.length,
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: sets.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(bottom: extraBottom),
                      child: Center(child: Text(s.noSetsInTemplate)),
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.only(bottom: extraBottom),
                      buildDefaultDragHandles: false,
                      itemCount: sets.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final reordered = List<TemplateSet>.from(sets);
                        final moved = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, moved);
                        await _applyNewOrder(reordered);
                      },
                      itemBuilder: (_, i) {
                        final x = sets[i];
                        return ListTile(
                          key: ValueKey('tmplset-$i-${x.exercise}'),
                          title: Text('${x.exercise}  •  ${s.setNumberShort} ${x.setNumber}'),
                          subtitle: Text(_formatTemplateSubtitle(x, s)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: s.duplicate,
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () => _duplicateSet(x),
                              ),
                              IconButton(
                                tooltip: s.delete,
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteSet(x),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.drag_indicator),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _editSet(x),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String notes;
  final int count;
  const _HeaderCard({required this.name, required this.notes, required this.count});

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
          Row(
            children: [
              Expanded(child: _chip(s.setsCount, '$count')),
            ],
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
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _TemplateSetForm extends StatefulWidget {
  final TemplateSet initial;
  const _TemplateSetForm({required this.initial});
  @override
  State<_TemplateSetForm> createState() => _TemplateSetFormState();
}

String _formatTemplateSubtitle(TemplateSet x, AppLocalizations s) {
  String details;
  if (x.isTimeBased) {
    final total = x.seconds ?? 0;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    final add = x.weightKg > 0 ? '  +${x.weightKg.toStringAsFixed(1)} kg' : '';
    details = '$mm:$ss$add';
  } else {
    details = '${x.reps} ${s.reps.toLowerCase()} @ ${x.weightKg.toStringAsFixed(1)} kg';
  }
  final extras = '${x.rpe != null ? '  ƒ?ô  RPE ${x.rpe}' : ''}${x.notes.isNotEmpty ? '\n${x.notes}' : ''}';
  return '$details$extras';
}

enum _TEntryMode { reps, time }

class _TemplateSetFormState extends State<_TemplateSetForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _exercise;
  late TextEditingController _setNo;
  late TextEditingController _reps;
  late TextEditingController _weight;
  late TextEditingController _rpe;
  late TextEditingController _notes;
  late TextEditingController _minutes;
  late TextEditingController _seconds;
  _TEntryMode mode = _TEntryMode.reps;
  bool _exerciseFieldInitialized = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _exercise = TextEditingController(text: i.exercise);
    _setNo = TextEditingController(text: i.setNumber.toString());
    _reps = TextEditingController(text: i.reps.toString());
    _weight = TextEditingController(text: i.weightKg.toString());
    _rpe = TextEditingController(text: i.rpe?.toString() ?? '');
    _notes = TextEditingController(text: i.notes);
    mode = i.isTimeBased ? _TEntryMode.time : _TEntryMode.reps;
    final totalSecs = i.seconds ?? 0;
    _minutes = TextEditingController(text: (totalSecs ~/ 60).toString());
    _seconds = TextEditingController(text: (totalSecs % 60).toString());
  }

  @override
  void dispose() {
    _exercise.dispose();
    _setNo.dispose();
    _reps.dispose();
    _weight.dispose();
    _rpe.dispose();
    _notes.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _save() {
    final s = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final isTime = mode == _TEntryMode.time;
    int reps = 0;
    int? seconds;
    if (isTime) {
      final m = int.tryParse(_minutes.text.trim()) ?? 0;
      final ss = int.tryParse(_seconds.text.trim()) ?? 0;
      final total = (m * 60) + ss;
      if (total <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.durationGreaterThanZero)),
        );
        return;
      }
      seconds = total;
    } else {
      reps = int.tryParse(_reps.text.trim()) ?? 0;
      if (reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.enterRepsGreaterThanZero)),
        );
        return;
      }
    }

    final updated = TemplateSet(
      exercise: _exercise.text.trim(),
      setNumber: int.parse(_setNo.text.trim()),
      reps: isTime ? 0 : int.parse(_reps.text.trim()),
      weightKg: double.parse(_weight.text.trim().replaceAll(',', '.')),
      rpe: _rpe.text.trim().isEmpty ? null : double.parse(_rpe.text.trim().replaceAll(',', '.')),
      notes: _notes.text.trim(),
      isTimeBased: isTime,
      seconds: seconds,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final ebox = Hive.box<Exercise>('exercises');
    final allNames = ebox.values.map((e) => e.name).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              s.templateSetTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue te) {
                final q = te.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return allNames.where((n) => n.toLowerCase().contains(q));
              },
              fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
                if (!_exerciseFieldInitialized) {
                  textCtrl.text = _exercise.text;
                  textCtrl.selection = TextSelection.collapsed(offset: textCtrl.text.length);
                  _exerciseFieldInitialized = true;
                }
                textCtrl.addListener(() {
                  if (textCtrl.text != _exercise.text) {
                    _exercise.text = textCtrl.text;
                    _exercise.selection = textCtrl.selection;
                  }
                });
                return TextFormField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(labelText: s.exercise, prefixIcon: const Icon(Icons.fitness_center)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? s.requiredField : null,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
              onSelected: (val) => _exercise.text = val,
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.fitness_center),
                          title: Text(opt),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _setNo,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: s.setNumberShort, prefixIcon: const Icon(Icons.format_list_numbered)),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0) ? '> 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: s.weightKg, prefixIcon: const Icon(Icons.scale)),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (n == null || n < 0) ? '>= 0' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ToggleButtons(
              isSelected: [mode == _TEntryMode.reps, mode == _TEntryMode.time],
              onPressed: (i) => setState(() => mode = i == 0 ? _TEntryMode.reps : _TEntryMode.time),
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s.reps)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s.time)),
              ],
            ),
            const SizedBox(height: 10),
            if (mode == _TEntryMode.reps)
              TextFormField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.reps, prefixIcon: const Icon(Icons.repeat)),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n <= 0) ? '> 0' : null;
                },
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: s.minutes, prefixIcon: const Icon(Icons.timer)),
                      validator: (v) {
                        final n = int.tryParse(v ?? '0') ?? 0;
                        return (n < 0) ? '>= 0' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _seconds,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: s.seconds, prefixIcon: const Icon(Icons.timer_outlined)),
                      validator: (v) {
                        final n = int.tryParse(v ?? '0') ?? 0;
                        if (n < 0 || n > 59) return '0-59';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rpe,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.rpeOptional, prefixIcon: const Icon(Icons.speed)),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: s.notesLabel, prefixIcon: const Icon(Icons.note_alt_outlined)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: Text(s.save)),
          ],
        ),
      ),
    );
  }
}


