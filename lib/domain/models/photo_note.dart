class PhotoNote {
  final String id;
  final String title;
  final String imagePath;
  final List<String> imagePaths;
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
    this.category = '',
    this.color = '#1E3A8A',
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  }) : imagePaths = (imagePaths != null && imagePaths.isNotEmpty)
            ? imagePaths
            : [imagePath];

  PhotoNote copyWith({
    String? title,
    String? imagePath,
    List<String>? imagePaths,
    String? category,
    String? color,
    String? note,
    DateTime? updatedAt,
  }) {
    final newPaths = imagePaths ?? this.imagePaths;
    return PhotoNote(
      id: id,
      title: title ?? this.title,
      imagePath: imagePath ?? (newPaths.isNotEmpty ? newPaths.first : this.imagePath),
      imagePaths: newPaths,
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

    return PhotoNote(
      id: map['id'] as String,
      title: map['title'] as String,
      imagePath: singlePath,
      imagePaths: parsedPaths,
      category: map['category'] as String? ?? '',
      color: map['color'] as String? ?? '#1E3A8A',
      note: map['note'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
