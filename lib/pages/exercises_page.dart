import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/exercise.dart';
import '../l10n/l10n.dart';
import 'exercise_history_page.dart';

enum _ExerciseSort { favorites, name, category }

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  // visina FAB-a + margin – koristimo za donji padding da sadržaj ne upadne ispod FAB-a
  static const double _fabHeight = 56;
  static const double _fabSpace = kFloatingActionButtonMargin + _fabHeight;

  late final Box<Exercise> ebox;
  final _searchCtrl = TextEditingController();
  _ExerciseSort _sort = _ExerciseSort.favorites;

  @override
  void initState() {
    super.initState();
    ebox = Hive.box<Exercise>('exercises');
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Exercise> _filtered() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = ebox.values.toList();

    list.sort((a, b) {
      switch (_sort) {
        case _ExerciseSort.favorites:
          if (a.isFavorite != b.isFavorite) return b.isFavorite ? 1 : -1;
          final c = (a.category).toLowerCase().compareTo((b.category).toLowerCase());
          if (c != 0) return c;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _ExerciseSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _ExerciseSort.category:
          final c = (a.category).toLowerCase().compareTo((b.category).toLowerCase());
          if (c != 0) return c;
          if (a.isFavorite != b.isFavorite) return b.isFavorite ? 1 : -1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    if (q.isEmpty) return list;
    return list.where((e) {
      return e.name.toLowerCase().contains(q) || e.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addOrEdit({Exercise? existing}) async {
    final l = AppLocalizations.of(context);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    bool fav = existing?.isFavorite ?? false;
    final categories = ebox.values
        .map((e) => e.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    var catFieldInitialized = false;

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => StatefulBuilder(
            builder: (c, setSt) => AlertDialog(
              title: Text(existing == null ? l.newExercise : l.editExercise),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l.nameLabel,
                      prefixIcon: const Icon(Icons.fitness_center),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (categories.isEmpty) return const Iterable<String>.empty();
                      final q = textEditingValue.text.trim().toLowerCase();
                      if (q.isEmpty) return categories;
                      return categories.where((c) => c.toLowerCase().contains(q));
                    },
                    fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
                      if (!catFieldInitialized) {
                        textCtrl.text = catCtrl.text;
                        textCtrl.selection = TextSelection.collapsed(offset: textCtrl.text.length);
                        catFieldInitialized = true;
                      }
                      return TextField(
                        controller: textCtrl,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: l.categoryOptionalLabel,
                          prefixIcon: const Icon(Icons.category_outlined),
                        ),
                        onChanged: (value) => catCtrl.text = value,
                        onSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    onSelected: (value) => catCtrl.text = value,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: fav,
                    onChanged: (v) => setSt(() => fav = v),
                    title: Text(l.favoriteLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.save)),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok) return;

    final name = nameCtrl.text.trim();
    final cat = catCtrl.text.trim();

    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.nameIsRequired)));
      return;
    }

    // provjera duplikata po nazivu (case-insensitive)
    final exists = ebox.values.any((e) =>
        e.name.toLowerCase() == name.toLowerCase() &&
        (existing == null || e.key != existing.key));
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.exerciseAlreadyExists)));
      return;
    }

    if (existing == null) {
      await ebox.add(Exercise(name: name, category: cat, isFavorite: fav));
    } else {
      existing
        ..name = name
        ..category = cat
        ..isFavorite = fav;
      await existing.save();
    }
  }

  Future<void> _delete(Exercise e) async {
    final l = AppLocalizations.of(context);

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.deleteExerciseQuestion),
            content: Text(l.deleteExerciseWarning(e.name)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
            ],
          ),
        ) ??
        false;

    if (ok) {
      await e.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.exercises), // koristimo postojeći "Exercises"
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: Text(l.addExercise),
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l.searchExercisesHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: (_searchCtrl.text.isEmpty)
                      ? null
                      : IconButton(
                          onPressed: () => _searchCtrl.clear(),
                          icon: const Icon(Icons.clear),
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 8),
                  DropdownButton<_ExerciseSort>(
                    value: _sort,
                    onChanged: (v) => setState(() => _sort = v ?? _sort),
                    items: const [
                      DropdownMenuItem(
                        value: _ExerciseSort.favorites,
                        child: Text('Favorites, category, name'),
                      ),
                      DropdownMenuItem(
                        value: _ExerciseSort.name,
                        child: Text('Name A–Z'),
                      ),
                      DropdownMenuItem(
                        value: _ExerciseSort.category,
                        child: Text('Category, favorites'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: ebox.listenable(),
                builder: (context, _, _child) {
                  final items = _filtered();
                  if (items.isEmpty) {
                    return ListView(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, _fabSpace + bottomInset),
                      children: [
                        Center(child: Text(l.noExercisesHint)),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, _fabSpace + bottomInset),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      final e = items[i];
                      return ListTile(
                        leading: Icon(e.isFavorite ? Icons.star : Icons.fitness_center_outlined),
                        title: Text(e.name),
                        subtitle: e.category.isNotEmpty ? Text(e.category) : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _addOrEdit(existing: e);
                            } else if (v == 'history') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ExerciseHistoryPage(exerciseName: e.name)),
                              );
                            } else if (v == 'fav') {
                              e.isFavorite = !e.isFavorite;
                              e.save();
                            } else if (v == 'del') {
                              _delete(e);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: const Icon(Icons.edit),
                                title: Text(l.edit),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'history',
                              child: ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(l.exerciseHistoryTitle(e.name)),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'fav',
                              child: ListTile(
                                leading: Icon(e.isFavorite ? Icons.star_border : Icons.star),
                                title: Text(e.isFavorite ? l.removeFromFavorites : l.addToFavorites),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'del',
                              child: ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: Text(l.delete),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _addOrEdit(existing: e),
                      );
                    },
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
