class PhotoNote {
  final String id;
  final String title;
  final String imagePath;
  final List<String> imagePaths;
  final List<String> imageNotes;
  final String category;
  final String color;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  PhotoNote({
    required this.id,
    required this.title,
    required this.imagePath,
    List<String>? imagePaths,
    List<String>? imageNotes,
    this.category = '',
    this.color = '#1E3A8A',
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  })  : imagePaths = (imagePaths != null && imagePaths.isNotEmpty)
            ? imagePaths
            : [imagePath],
        imageNotes = _initImageNotes(
          imageNotes,
          (imagePaths != null && imagePaths.isNotEmpty) ? imagePaths.length : 1,
          note,
        );

  static List<String> _initImageNotes(
      List<String>? notes, int length, String defaultNote) {
    final list = <String>[];
    for (int i = 0; i < length; i++) {
      if (notes != null && i < notes.length) {
        list.add(notes[i]);
      } else if (i == 0) {
        list.add(defaultNote);
      } else {
        list.add('');
      }
    }
    return list;
  }

  PhotoNote copyWith({
    String? title,
    String? imagePath,
    List<String>? imagePaths,
    List<String>? imageNotes,
    String? category,
    String? color,
    String? note,
    DateTime? updatedAt,
  }) {
    final newPaths = imagePaths ?? this.imagePaths;
    final newNotes = imageNotes ?? this.imageNotes;
    return PhotoNote(
      id: id,
      title: title ?? this.title,
      imagePath: imagePath ?? (newPaths.isNotEmpty ? newPaths.first : this.imagePath),
      imagePaths: newPaths,
      imageNotes: newNotes,
      category: category ?? this.category,
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'imagePaths': imagePaths,
      'imageNotes': imageNotes,
      'category': category,
      'color': color,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PhotoNote.fromMap(Map<dynamic, dynamic> map) {
    final singlePath = map['imagePath'] as String;
    final rawPaths = map['imagePaths'];
    final List<String> parsedPaths = rawPaths != null
        ? List<String>.from(rawPaths)
        : [singlePath];

    final rawNotes = map['imageNotes'];
    final defaultNote = map['note'] as String? ?? '';
    List<String>? parsedNotes;
    if (rawNotes != null && rawNotes is List) {
      parsedNotes = List<String>.from(rawNotes.map((e) => e.toString()));
    }

    return PhotoNote(
      id: map['id'] as String,
      title: map['title'] as String,
      imagePath: singlePath,
      imagePaths: parsedPaths,
      imageNotes: parsedNotes,
      category: map['category'] as String? ?? '',
      color: map['color'] as String? ?? '#1E3A8A',
      note: defaultNote,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
