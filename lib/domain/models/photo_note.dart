class PhotoNote {
  final String id;
  final String title;
  final String imagePath;
  final String category;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  PhotoNote({
    required this.id,
    required this.title,
    required this.imagePath,
    this.category = '',
    this.color = '#1E3A8A',
    required this.createdAt,
    required this.updatedAt,
  });

  PhotoNote copyWith({
    String? title,
    String? imagePath,
    String? category,
    String? color,
    DateTime? updatedAt,
  }) {
    return PhotoNote(
      id: id,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'category': category,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PhotoNote.fromMap(Map<dynamic, dynamic> map) {
    return PhotoNote(
      id: map['id'] as String,
      title: map['title'] as String,
      imagePath: map['imagePath'] as String,
      category: map['category'] as String? ?? '',
      color: map['color'] as String? ?? '#1E3A8A',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
