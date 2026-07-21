import 'package:hive/hive.dart';

class CalendarEvent extends HiveObject {
  String id;
  String title;
  String description;
  DateTime dateTime;
  String? linkedPageId;
  String? linkedBookId;
  bool hasReminder;
  DateTime? reminderTime;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.dateTime,
    this.linkedPageId,
    this.linkedBookId,
    this.hasReminder = false,
    this.reminderTime,
  });

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? dateTime,
    String? linkedPageId,
    String? linkedBookId,
    bool? hasReminder,
    DateTime? reminderTime,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      linkedPageId: linkedPageId ?? this.linkedPageId,
      linkedBookId: linkedBookId ?? this.linkedBookId,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'linkedPageId': linkedPageId,
        'linkedBookId': linkedBookId,
        'hasReminder': hasReminder,
        'reminderTime': reminderTime?.toIso8601String(),
      };

  factory CalendarEvent.fromJson(Map<dynamic, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        dateTime: DateTime.parse(json['dateTime'] as String),
        linkedPageId: json['linkedPageId'] as String?,
        linkedBookId: json['linkedBookId'] as String?,
        hasReminder: json['hasReminder'] as bool? ?? false,
        reminderTime: json['reminderTime'] != null ? DateTime.parse(json['reminderTime'] as String) : null,
      );
}

class CalendarEventAdapter extends TypeAdapter<CalendarEvent> {
  @override
  final int typeId = 2;

  @override
  CalendarEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CalendarEvent(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      dateTime: fields[3] as DateTime,
      linkedPageId: fields[4] as String?,
      linkedBookId: fields[5] as String?,
      hasReminder: fields[6] as bool? ?? false,
      reminderTime: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEvent obj) {
    writer.writeByte(8);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.description);
    writer.writeByte(3);
    writer.write(obj.dateTime);
    writer.writeByte(4);
    writer.write(obj.linkedPageId);
    writer.writeByte(5);
    writer.write(obj.linkedBookId);
    writer.writeByte(6);
    writer.write(obj.hasReminder);
    writer.writeByte(7);
    writer.write(obj.reminderTime);
  }
}
