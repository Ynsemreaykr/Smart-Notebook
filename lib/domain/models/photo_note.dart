class PhotoNote {
  final String id;
  final String title;
  final String imagePath;
  final List<String> imagePaths;
  final List<String> imageNotes;
  final List<bool> questionFlags;
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
    List<bool>? questionFlags,
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
        ),
        questionFlags = _initQuestionFlags(
          questionFlags,
          (imagePaths != null && imagePaths.isNotEmpty) ? imagePaths.length : 1,
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

  static List<bool> _initQuestionFlags(List<bool>? flags, int length) {
    final list = <bool>[];
    for (int i = 0; i < length; i++) {
      if (flags != null && i < flags.length) {
        list.add(flags[i]);
      } else {
        list.add(false);
      }
    }
    return list;
  }

  static Map<String, dynamic> reorderLists(
      List<String> paths, List<String> notes, List<bool> flags) {
    final infoPaths = <String>[];
    final infoNotes = <String>[];
    final infoFlags = <bool>[];

    final questionPaths = <String>[];
    final questionNotes = <String>[];
    final questionFlags = <bool>[];

    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      final n = (i < notes.length) ? notes[i] : '';
      final f = (i < flags.length) ? flags[i] : false;

      if (f) {
        questionPaths.add(p);
        questionNotes.add(n);
        questionFlags.add(true);
      } else {
        infoPaths.add(p);
        infoNotes.add(n);
        infoFlags.add(false);
      }
    }

    return {
      'paths': [...infoPaths, ...questionPaths],
      'notes': [...infoNotes, ...questionNotes],
      'flags': [...infoFlags, ...questionFlags],
    };
  }

  PhotoNote copyWith({
    String? title,
    String? imagePath,
    List<String>? imagePaths,
    List<String>? imageNotes,
    List<bool>? questionFlags,
    String? category,
    String? color,
    String? note,
    DateTime? updatedAt,
  }) {
    final newPaths = imagePaths ?? this.imagePaths;
    final newNotes = imageNotes ?? this.imageNotes;
    final newFlags = questionFlags ?? this.questionFlags;

    final reordered = reorderLists(newPaths, newNotes, newFlags);
    final sortedPaths = List<String>.from(reordered['paths']);
    final sortedNotes = List<String>.from(reordered['notes']);
    final sortedFlags = List<bool>.from(reordered['flags']);

    return PhotoNote(
      id: id,
      title: title ?? this.title,
      imagePath: imagePath ?? (sortedPaths.isNotEmpty ? sortedPaths.first : this.imagePath),
      imagePaths: sortedPaths,
      imageNotes: sortedNotes,
      questionFlags: sortedFlags,
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
      'questionFlags': questionFlags,
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

    final rawFlags = map['questionFlags'];
    List<bool>? parsedFlags;
    if (rawFlags != null && rawFlags is List) {
      parsedFlags = List<bool>.from(rawFlags.map((e) => e == true));
    }

    return PhotoNote(
      id: map['id'] as String,
      title: map['title'] as String,
      imagePath: singlePath,
      imagePaths: parsedPaths,
      imageNotes: parsedNotes,
      questionFlags: parsedFlags,
      category: map['category'] as String? ?? '',
      color: map['color'] as String? ?? '#1E3A8A',
      note: defaultNote,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
