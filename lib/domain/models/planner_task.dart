import 'package:uuid/uuid.dart';

/// A small checklist item inside a daily task
class TaskSubItem {
  final String id;
  final String text;
  final String status; // 'todo' | 'doing' | 'done'
  final String? startTime; // 'HH:mm'
  final String? endTime;   // 'HH:mm'

  const TaskSubItem({
    required this.id,
    required this.text,
    this.status = 'todo',
    this.startTime,
    this.endTime,
  });

  bool get isDone => status == 'done';
  bool get isDoing => status == 'doing';

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'status': status,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory TaskSubItem.fromJson(Map json) => TaskSubItem(
        id: json['id'] as String? ?? const Uuid().v4(),
        text: json['text'] as String? ?? '',
        status: json['status'] as String? ?? 'todo',
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
      );

  TaskSubItem copyWith({
    String? text,
    String? status,
    String? startTime,
    String? endTime,
  }) =>
      TaskSubItem(
        id: id,
        text: text ?? this.text,
        status: status ?? this.status,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );
}

class PlannerTask {
  final String id;
  final String title;
  final bool isCompleted;
  final String date; // 'yyyy-MM-dd'
  final String? startTime; // 'HH:mm'
  final String? endTime;   // 'HH:mm'
  final int durationMinutes; // computed from start→end; 0 = all-day
  final bool notifyBefore;
  final List<TaskSubItem> subtasks;

  // Legacy compat
  final String type;
  final int targetDurationMinutes;
  final int completedSeconds;

  PlannerTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.date,
    this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.notifyBefore = false,
    this.subtasks = const [],
    this.type = 'normal',
    this.targetDurationMinutes = 0,
    this.completedSeconds = 0,
  });

  bool get isTimerUp => false;
  bool get hasTimeSlot => startTime != null;

  /// Completion percentage based on subtasks (0–100)
  int get subtaskPercent {
    if (subtasks.isEmpty) return isCompleted ? 100 : 0;
    final done = subtasks.where((s) => s.status == 'done').length;
    return ((done / subtasks.length) * 100).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': 'normal',
        'isCompleted': isCompleted,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'durationMinutes': durationMinutes,
        'notifyBefore': notifyBefore,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'targetDurationMinutes': targetDurationMinutes,
        'completedSeconds': completedSeconds,
      };

  factory PlannerTask.fromJson(Map<dynamic, dynamic> json) {
    final legacyTime = json['time'] as String?;
    final startTime = json['startTime'] as String? ?? legacyTime;
    String? endTime = json['endTime'] as String?;
    final durationMinutes = json['durationMinutes'] as int? ?? 0;

    if (endTime == null && startTime != null && durationMinutes > 0) {
      final parts = startTime.split(':');
      if (parts.length == 2) {
        final startHour = int.tryParse(parts[0]) ?? 0;
        final startMin = int.tryParse(parts[1]) ?? 0;
        final totalMin = startHour * 60 + startMin + durationMinutes;
        final endHour = (totalMin ~/ 60) % 24;
        final endMin = totalMin % 60;
        endTime =
            '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
      }
    }

    final rawSubtasks = json['subtasks'] as List<dynamic>? ?? [];
    final subtasks = rawSubtasks
        .whereType<Map>()
        .map((e) => TaskSubItem.fromJson(e))
        .toList();

    return PlannerTask(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String? ?? 'normal',
      isCompleted: json['isCompleted'] as bool? ?? false,
      date: json['date'] as String,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      notifyBefore: json['notifyBefore'] as bool? ?? false,
      subtasks: subtasks,
      targetDurationMinutes: json['targetDurationMinutes'] as int? ?? 0,
      completedSeconds: json['completedSeconds'] as int? ?? 0,
    );
  }

  PlannerTask copyWith({
    String? id,
    String? title,
    String? type,
    bool? isCompleted,
    String? date,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    bool? notifyBefore,
    List<TaskSubItem>? subtasks,
    int? targetDurationMinutes,
    int? completedSeconds,
  }) =>
      PlannerTask(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        isCompleted: isCompleted ?? this.isCompleted,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        notifyBefore: notifyBefore ?? this.notifyBefore,
        subtasks: subtasks ?? this.subtasks,
        targetDurationMinutes:
            targetDurationMinutes ?? this.targetDurationMinutes,
        completedSeconds: completedSeconds ?? this.completedSeconds,
      );
}
