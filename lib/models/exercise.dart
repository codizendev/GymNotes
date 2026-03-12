import 'package:hive/hive.dart';

part 'exercise.g.dart';

@HiveType(typeId: 10) // promijeni ako se sudari s nečim u tvojem projektu
class Exercise extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String category; // npr. "Prsa", "Noge", "Leđa"...

  @HiveField(2)
  bool isFavorite;

  Exercise({
    required this.name,
    this.category = '',
    this.isFavorite = false,
  });

  Exercise copyWith({String? name, String? category, bool? isFavorite}) {
    return Exercise(
      name: name ?? this.name,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
