import 'package:hive/hive.dart';

class Book extends HiveObject {
  String id;
  String title;
  DateTime createdAt;
  DateTime updatedAt;
  String coverColor;

  Book({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.coverColor = '#4A90D9',
  });

  Book copyWith({
    String? title,
    DateTime? updatedAt,
    String? coverColor,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverColor: coverColor ?? this.coverColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'coverColor': coverColor,
      };

  factory Book.fromJson(Map<dynamic, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        coverColor: json['coverColor'] as String? ?? '#4A90D9',
      );
}

class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Book(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      coverColor: fields[4] as String? ?? '#4A90D9',
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.createdAt);
    writer.writeByte(3);
    writer.write(obj.updatedAt);
    writer.writeByte(4);
    writer.write(obj.coverColor);
  }
}
