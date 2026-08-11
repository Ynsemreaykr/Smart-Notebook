import 'package:hive/hive.dart';

class NotePage extends HiveObject {
  String id;
  String bookId;
  String title;
  String content;
  String? drawingImagePath;
  String? drawingJson;
  bool isAdvanced;
  int orderIndex;
  DateTime createdAt;
  DateTime updatedAt;
  @HiveField(10)
  DateTime? reminderTime;
  @HiveField(11)
  String? drawingRect;

  NotePage({
    required this.id,
    required this.bookId,
    required this.title,
    this.content = '',
    this.drawingImagePath,
    this.drawingJson,
    this.isAdvanced = false,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
    this.reminderTime,
    this.drawingRect,
  });

  NotePage copyWith({
    String? title,
    String? content,
    String? drawingImagePath,
    String? drawingJson,
    bool? isAdvanced,
    int? orderIndex,
    DateTime? updatedAt,
    DateTime? reminderTime,
    String? drawingRect,
  }) {
    return NotePage(
      id: id,
      bookId: bookId,
      title: title ?? this.title,
      content: content ?? this.content,
      drawingImagePath: drawingImagePath ?? this.drawingImagePath,
      drawingJson: drawingJson ?? this.drawingJson,
      isAdvanced: isAdvanced ?? this.isAdvanced,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderTime: reminderTime ?? this.reminderTime,
      drawingRect: drawingRect ?? this.drawingRect,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'title': title,
        'content': content,
        'drawingImagePath': drawingImagePath,
        'drawingJson': drawingJson,
        'isAdvanced': isAdvanced,
        'orderIndex': orderIndex,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'reminderTime': reminderTime?.toIso8601String(),
        'drawingRect': drawingRect,
      };

  factory NotePage.fromJson(Map<dynamic, dynamic> json) => NotePage(
        id: json['id']?.toString() ?? '',
        bookId: json['bookId']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Sayfa',
        content: json['content']?.toString() ?? '',
        drawingImagePath: json['drawingImagePath']?.toString(),
        drawingJson: json['drawingJson']?.toString(),
        isAdvanced: json['isAdvanced'] as bool? ?? false,
        orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] != null
            ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? (DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now())
            : DateTime.now(),
        reminderTime: json['reminderTime'] != null
            ? DateTime.tryParse(json['reminderTime'].toString())
            : null,
        drawingRect: json['drawingRect']?.toString(),
      );
}

class NotePageAdapter extends TypeAdapter<NotePage> {
  @override
  final int typeId = 1;

  @override
  NotePage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return NotePage(
      id: fields[0] as String,
      bookId: fields[1] as String,
      title: fields[2] as String,
      content: fields[3] as String? ?? '',
      orderIndex: fields[4] as int? ?? 0,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      drawingImagePath: fields[7] as String?,
      drawingJson: fields[8] as String?,
      isAdvanced: fields[9] as bool? ?? false,
      reminderTime: fields[10] as DateTime?,
      drawingRect: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NotePage obj) {
    writer.writeByte(12);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.bookId);
    writer.writeByte(2);
    writer.write(obj.title);
    writer.writeByte(3);
    writer.write(obj.content);
    writer.writeByte(4);
    writer.write(obj.orderIndex);
    writer.writeByte(5);
    writer.write(obj.createdAt);
    writer.writeByte(6);
    writer.write(obj.updatedAt);
    writer.writeByte(7);
    writer.write(obj.drawingImagePath);
    writer.writeByte(8);
    writer.write(obj.drawingJson);
    writer.writeByte(9);
    writer.write(obj.isAdvanced);
    writer.writeByte(10);
    writer.write(obj.reminderTime);
    writer.writeByte(11);
    writer.write(obj.drawingRect);
  }
}
