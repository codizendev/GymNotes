import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/cardio_template.dart';
import '../models/program_block.dart';
import '../models/workout_template.dart';
import '../services/program_service.dart';

class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  late final Box<ProgramBlock> pbox;
  late final Box<WorkoutTemplate> tbox;
  late final Box<CardioTemplate> ctbox;

  @override
  void initState() {
    super.initState();
    pbox = Hive.box<ProgramBlock>('program_blocks');
    tbox = Hive.box<WorkoutTemplate>('templates');
    ctbox = Hive.box<CardioTemplate>('cardio_templates');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Program blocks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProgramEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New program'),
      ),
      body: ValueListenableBuilder(
        valueListenable: pbox.listenable(),
        builder: (context, box, child) {
          final programs = box.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (programs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No program blocks yet. Create one to auto-generate scheduled workouts with custom progression.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: programs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final program = programs[i];
              final programKey = program.key as int;
              final sessionsCount = program.sessions.length;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              program.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Switch.adaptive(
                            value: program.isActive,
                            onChanged: (v) async {
                              program.isActive = v;
                              await program.save();
                              if (v) {
                                await ProgramService.regenerateSchedulesForProgram(programKey: programKey);
                              }
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start: ${DateFormat('dd.MM.yyyy').format(program.startDate)}  •  ${program.durationWeeks} weeks  •  $sessionsCount sessions/week',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _progressionSummary(program.progression),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(this.context);
                              await ProgramService.regenerateSchedulesForProgram(programKey: programKey);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Program schedule regenerated.')),
                              );
                            },
                            icon: const Icon(Icons.event_repeat),
                            label: const Text('Regenerate'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openProgramEditor(existing: program),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _deleteProgram(programKey),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteProgram(int programKey) async {
    final program = pbox.get(programKey);
    if (program == null) return;

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete program block?'),
            content: Text('Delete "${program.name}". Existing generated schedules stay unless manually removed.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    await pbox.delete(programKey);
    if (mounted) setState(() {});
  }

  Future<void> _openProgramEditor({ProgramBlock? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final durationCtrl = TextEditingController(text: (existing?.durationWeeks ?? 8).toString());

    final strengthEveryCtrl = TextEditingController(
      text: (existing?.progression.strengthStepEveryWeeks ?? 1).toString(),
    );
    final strengthKgCtrl = TextEditingController(
      text: (existing?.progression.strengthStepValueKg ?? 2.5).toStringAsFixed(2),
    );
    final strengthPercentCtrl = TextEditingController(
      text: (existing?.progression.strengthStepPercent ?? 2.5).toStringAsFixed(2),
    );
    final strengthRoundCtrl = TextEditingController(
      text: (existing?.progression.strengthRoundingKg ?? 0.5).toStringAsFixed(2),
    );

    final cardioEveryCtrl = TextEditingController(
      text: (existing?.progression.cardioStepEveryWeeks ?? 1).toString(),
    );
    final cardioSecCtrl = TextEditingController(
      text: (existing?.progression.cardioStepValueSeconds ?? 60).toString(),
    );
    final cardioPercentCtrl = TextEditingController(
      text: (existing?.progression.cardioStepPercent ?? 5).toStringAsFixed(2),
    );
    final cardioWorkSecCtrl = TextEditingController(
      text: (existing?.progression.cardioWorkIntervalStepSeconds ?? 10).toString(),
    );

    final deloadEveryCtrl = TextEditingController(
      text: (existing?.progression.deloadEveryWeeks ?? 4).toString(),
    );
    final deloadLoadCtrl = TextEditingController(
      text: (existing?.progression.deloadLoadPercent ?? -10).toStringAsFixed(1),
    );
    final deloadVolumeCtrl = TextEditingController(
      text: (existing?.progression.deloadVolumePercent ?? -15).toStringAsFixed(1),
    );

    var startDate = existing?.startDate ?? DateTime.now();
    var strengthMode = existing?.progression.strengthMode ?? 'fixed_kg';
    var cardioMode = existing?.progression.cardioMode ?? 'duration_percent';
    var deloadEnabled = existing?.progression.deloadEnabled ?? false;
    var applyReadiness = existing?.progression.applyReadinessModifiers ?? false;

    var sessions = existing?.sessions
            .map(
              (s) => _SessionDraft(
                id: s.id,
                weekDay: s.weekDay,
                kind: s.kind,
                templateKey: s.templateKey,
                hour: s.hour,
                minute: s.minute,
                reminderEnabled: s.reminderEnabled,
                note: s.note,
              ),
            )
            .toList() ??
        <_SessionDraft>[];

    if (sessions.isEmpty) {
      sessions = [
        _SessionDraft(
          id: _newId(),
          weekDay: 1,
          kind: 'strength',
          templateKey: _defaultTemplateKey('strength'),
          hour: 9,
          minute: 0,
        ),
      ];
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;

              Future<void> pickStartDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked == null) return;
                setModalState(() => startDate = picked);
              }

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null ? 'New program block' : 'Edit program block',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Program name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Duration (weeks)'),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start date'),
                        subtitle: Text(DateFormat('dd.MM.yyyy').format(startDate)),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: pickStartDate,
                      ),
                      const Divider(height: 24),
                      Text(
                        'Weekly sessions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...sessions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final templateName = _templateName(item.kind, item.templateKey);
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Session ${index + 1}',
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: sessions.length == 1
                                          ? null
                                          : () {
                                              setModalState(() => sessions.removeAt(index));
                                            },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                DropdownButtonFormField<int>(
                                  initialValue: item.weekDay,
                                  decoration: const InputDecoration(labelText: 'Day'),
                                  items: List.generate(7, (i) {
                                    final day = i + 1;
                                    return DropdownMenuItem(value: day, child: Text(_weekdayLabel(day)));
                                  }),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setModalState(() => item.weekDay = v);
                                  },
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: item.kind,
                                  decoration: const InputDecoration(labelText: 'Type'),
                                  items: const [
                                    DropdownMenuItem(value: 'strength', child: Text('Strength')),
                                    DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setModalState(() {
                                      item.kind = v;
                                      item.templateKey = _defaultTemplateKey(v);
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Template'),
                                  subtitle: Text(templateName),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    final picked = await _pickTemplate(item.kind, item.templateKey);
                                    if (picked == null) return;
                                    setModalState(() => item.templateKey = picked);
                                  },
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Time'),
                                  subtitle: Text('${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}'),
                                  trailing: const Icon(Icons.access_time),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: item.hour, minute: item.minute),
                                    );
                                    if (picked == null) return;
                                    setModalState(() {
                                      item.hour = picked.hour;
                                      item.minute = picked.minute;
                                    });
                                  },
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Reminder'),
                                  value: item.reminderEnabled,
                                  onChanged: (v) => setModalState(() => item.reminderEnabled = v),
                                ),
                                TextFormField(
                                  initialValue: item.note,
                                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                                  onChanged: (v) => item.note = v,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            sessions.add(
                              _SessionDraft(
                                id: _newId(),
                                weekDay: 1,
                                kind: 'strength',
                                templateKey: _defaultTemplateKey('strength'),
                                hour: 9,
                                minute: 0,
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add session'),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Progression settings',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: strengthMode,
                        decoration: const InputDecoration(labelText: 'Strength progression mode'),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(value: 'fixed_kg', child: Text('Fixed kg per step')),
                          DropdownMenuItem(value: 'percent', child: Text('Percent per step')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => strengthMode = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: strengthEveryCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Strength progression every N weeks'),
                      ),
                      const SizedBox(height: 8),
                      if (strengthMode == 'fixed_kg')
                        TextField(
                          controller: strengthKgCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Strength step (kg)'),
                        ),
                      if (strengthMode == 'percent')
                        TextField(
                          controller: strengthPercentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Strength step (%)'),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: strengthRoundCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight rounding step (kg)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: cardioMode,
                        decoration: const InputDecoration(labelText: 'Cardio progression mode'),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(value: 'duration_percent', child: Text('Duration percent')),
                          DropdownMenuItem(value: 'duration_seconds', child: Text('Add seconds per step')),
                          DropdownMenuItem(value: 'work_interval_seconds', child: Text('Add seconds to work intervals')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => cardioMode = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cardioEveryCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cardio progression every N weeks'),
                      ),
                      const SizedBox(height: 8),
                      if (cardioMode == 'duration_percent')
                        TextField(
                          controller: cardioPercentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Cardio step (%)'),
                        ),
                      if (cardioMode == 'duration_seconds')
                        TextField(
                          controller: cardioSecCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cardio step (seconds)'),
                        ),
                      if (cardioMode == 'work_interval_seconds')
                        TextField(
                          controller: cardioWorkSecCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Work interval step (seconds)'),
                        ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable deload weeks'),
                        value: deloadEnabled,
                        onChanged: (v) => setModalState(() => deloadEnabled = v),
                      ),
                      if (deloadEnabled) ...[
                        TextField(
                          controller: deloadEveryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Deload every N weeks'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: deloadLoadCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Deload load change (%)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: deloadVolumeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Deload volume change (%)'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Apply readiness modifiers'),
                        value: applyReadiness,
                        onChanged: (v) => setModalState(() => applyReadiness = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(this.context);
                              final modalNavigator = Navigator.of(context);
                              final name = nameCtrl.text.trim();
                              final weeks = int.tryParse(durationCtrl.text.trim()) ?? 0;
                              if (name.isEmpty || weeks <= 0 || sessions.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Name, duration, and at least one session are required.')),
                                );
                                return;
                              }

                              final validSessions = sessions.where((s) => s.templateKey >= 0).toList();
                              if (validSessions.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Pick at least one valid template.')),
                                );
                                return;
                              }

                              final progression = ProgramProgressionConfig(
                                strengthMode: strengthMode,
                                strengthStepValueKg: _toDouble(strengthKgCtrl.text, 2.5),
                                strengthStepPercent: _toDouble(strengthPercentCtrl.text, 2.5),
                                strengthStepEveryWeeks: _toInt(strengthEveryCtrl.text, 1),
                                strengthRoundingKg: _toDouble(strengthRoundCtrl.text, 0.5),
                                cardioMode: cardioMode,
                                cardioStepValueSeconds: _toInt(cardioSecCtrl.text, 60),
                                cardioStepPercent: _toDouble(cardioPercentCtrl.text, 5),
                                cardioWorkIntervalStepSeconds: _toInt(cardioWorkSecCtrl.text, 10),
                                cardioStepEveryWeeks: _toInt(cardioEveryCtrl.text, 1),
                                deloadEnabled: deloadEnabled,
                                deloadEveryWeeks: _toInt(deloadEveryCtrl.text, 4),
                                deloadLoadPercent: _toDouble(deloadLoadCtrl.text, -10),
                                deloadVolumePercent: _toDouble(deloadVolumeCtrl.text, -15),
                                applyReadinessModifiers: applyReadiness,
                              );

                              final sessionPlans = validSessions
                                  .map(
                                    (s) => ProgramSessionPlan(
                                      id: s.id,
                                      weekDay: s.weekDay,
                                      kind: s.kind,
                                      templateKey: s.templateKey,
                                      hour: s.hour,
                                      minute: s.minute,
                                      reminderEnabled: s.reminderEnabled,
                                      note: s.note,
                                    ),
                                  )
                                  .toList();

                              final block = ProgramBlock(
                                name: name,
                                startDate: DateTime(startDate.year, startDate.month, startDate.day),
                                durationWeeks: _clampInt(weeks, 1, 52),
                                sessions: sessionPlans,
                                progression: progression,
                                isActive: existing?.isActive ?? true,
                                generatedUntilWeek: existing?.generatedUntilWeek ?? 0,
                                createdAt: existing?.createdAt,
                              );

                              final key = await ProgramService.upsertProgram(block, key: existing?.key as int?);
                              await ProgramService.regenerateSchedulesForProgram(
                                programKey: key,
                                removeExistingAutoGenerated: true,
                              );

                              if (!mounted) return;
                              modalNavigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Program saved and schedule generated.')),
                              );
                              setState(() {});
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      durationCtrl.dispose();
      strengthEveryCtrl.dispose();
      strengthKgCtrl.dispose();
      strengthPercentCtrl.dispose();
      strengthRoundCtrl.dispose();
      cardioEveryCtrl.dispose();
      cardioSecCtrl.dispose();
      cardioPercentCtrl.dispose();
      cardioWorkSecCtrl.dispose();
      deloadEveryCtrl.dispose();
      deloadLoadCtrl.dispose();
      deloadVolumeCtrl.dispose();
    }
  }

  Future<int?> _pickTemplate(String kind, int? currentKey) async {
    final options = kind == 'cardio'
        ? ctbox.values.map((t) => (key: t.key as int, name: t.name)).toList()
        : tbox.values.map((t) => (key: t.key as int, name: t.name)).toList();

    return showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (options.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('No templates available.')),
          );
        }
        return ListView.separated(
          itemCount: options.length,
          separatorBuilder: (context, index) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final option = options[i];
            final selected = option.key == currentKey;
            return ListTile(
              title: Text(option.name),
              trailing: selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, option.key),
            );
          },
        );
      },
    );
  }

  int _defaultTemplateKey(String kind) {
    if (kind == 'cardio') {
      if (ctbox.isEmpty) return -1;
      return ctbox.values.first.key as int;
    }
    if (tbox.isEmpty) return -1;
    return tbox.values.first.key as int;
  }

  String _templateName(String kind, int key) {
    if (key < 0) return 'Pick template';
    if (kind == 'cardio') {
      return ctbox.get(key)?.name ?? 'Missing template';
    }
    return tbox.get(key)?.name ?? 'Missing template';
  }

  String _weekdayLabel(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  String _progressionSummary(ProgramProgressionConfig c) {
    final strength = c.strengthMode == 'none'
        ? 'Strength: none'
        : c.strengthMode == 'fixed_kg'
            ? 'Strength: +${c.strengthStepValueKg.toStringAsFixed(2)} kg every ${c.strengthStepEveryWeeks}w'
            : 'Strength: +${c.strengthStepPercent.toStringAsFixed(1)}% every ${c.strengthStepEveryWeeks}w';
    final cardio = c.cardioMode == 'none'
        ? 'Cardio: none'
        : c.cardioMode == 'duration_percent'
            ? 'Cardio: +${c.cardioStepPercent.toStringAsFixed(1)}% every ${c.cardioStepEveryWeeks}w'
            : c.cardioMode == 'duration_seconds'
                ? 'Cardio: +${c.cardioStepValueSeconds}s every ${c.cardioStepEveryWeeks}w'
                : 'Cardio: +${c.cardioWorkIntervalStepSeconds}s work intervals every ${c.cardioStepEveryWeeks}w';
    final deload = c.deloadEnabled
        ? 'Deload every ${c.deloadEveryWeeks}w (${c.deloadLoadPercent}% load, ${c.deloadVolumePercent}% volume)'
        : 'No deload';
    final readiness = c.applyReadinessModifiers ? 'Readiness ON' : 'Readiness OFF';
    return '$strength\n$cardio\n$deload • $readiness';
  }

  int _toInt(String raw, int fallback) => int.tryParse(raw.trim()) ?? fallback;
  double _toDouble(String raw, double fallback) => double.tryParse(raw.trim().replaceAll(',', '.')) ?? fallback;
  int _clampInt(int value, int min, int max) => value < min ? min : (value > max ? max : value);

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

class _SessionDraft {
  _SessionDraft({
    required this.id,
    required this.weekDay,
    required this.kind,
    required this.templateKey,
    required this.hour,
    required this.minute,
    this.reminderEnabled = true,
    this.note = '',
  });

  String id;
  int weekDay;
  String kind;
  int templateKey;
  int hour;
  int minute;
  bool reminderEnabled;
  String note;
}

