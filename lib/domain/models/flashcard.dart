class Flashcard {
  final String id;
  final String frontText;
  final String backText;
  final String category;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Flashcard({
    required this.id,
    required this.frontText,
    required this.backText,
    required this.category,
    this.color = '#14B8A6',
    required this.createdAt,
    required this.updatedAt,
  });

  Flashcard copyWith({
    String? frontText,
    String? backText,
    String? category,
    String? color,
    DateTime? updatedAt,
  }) {
    return Flashcard(
      id: id,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      category: category ?? this.category,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'frontText': frontText,
      'backText': backText,
      'category': category,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Flashcard.fromMap(Map<dynamic, dynamic> map) {
    return Flashcard(
      id: map['id'] as String,
      frontText: map['frontText'] as String,
      backText: map['backText'] as String,
      category: map['category'] as String? ?? '',
      color: map['color'] as String? ?? '#14B8A6',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
