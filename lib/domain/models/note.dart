import 'package:hive/hive.dart';

class Note extends HiveObject {
  String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  String color;
  DateTime? reminderTime;

  Note({
    required this.id,
    required this.title,
    this.content = '',
    required this.createdAt,
    required this.updatedAt,
    this.color = '#FF9800',
    this.reminderTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'color': color,
        'reminderTime': reminderTime?.toIso8601String(),
      };

  factory Note.fromJson(Map<dynamic, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        color: json['color'] as String? ?? '#FF9800',
        reminderTime: json['reminderTime'] != null ? DateTime.parse(json['reminderTime'] as String) : null,
      );
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 3;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String? ?? '',
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      color: fields[5] as String? ?? '#FF9800',
      reminderTime: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.content);
    writer.writeByte(3);
    writer.write(obj.createdAt);
    writer.writeByte(4);
    writer.write(obj.updatedAt);
    writer.writeByte(5);
    writer.write(obj.color);
    writer.writeByte(6);
    writer.write(obj.reminderTime);
  }
}
