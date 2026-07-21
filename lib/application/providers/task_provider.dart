import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/planner_task.dart';
import '../../data/services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  List<PlannerTask> _tasks = [];
  bool _isLoading = false;
  final _uuid = const Uuid();
  DateTime _selectedDate = DateTime.now();

  List<PlannerTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  String? get activeTaskId => null;
  bool get isTimerRunning => false;

  String get _selectedDateKey => _getDateKey(_selectedDate);

  String _getDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadTasks();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();
    try {
      final box = Hive.box('planner_tasks');
      final loaded = <PlannerTask>[];
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final task = PlannerTask.fromJson(data);
          if (task.date == _selectedDateKey) loaded.add(task);
        }
      }
      _sortTasks(loaded);
      _tasks = loaded;
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  void _sortTasks(List<PlannerTask> list) {
    list.sort((a, b) {
      if (a.startTime == null && b.startTime == null) return 0;
      if (a.startTime == null) return 1;
      if (b.startTime == null) return -1;
      return a.startTime!.compareTo(b.startTime!);
    });
  }

  // ── Add task with start + end time ──
  Future<void> addTask(
    String title, {
    String? startTime,
    String? endTime,
    bool notifyBefore = false,
  }) async {
    if (title.trim().isEmpty) return;

    // Compute duration from start→end
    int durationMinutes = 0;
    if (startTime != null && endTime != null) {
      durationMinutes = _timeDiff(startTime, endTime);
    }

    final task = PlannerTask(
      id: _uuid.v4(),
      title: title.trim(),
      date: _selectedDateKey,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      notifyBefore: notifyBefore,
      isCompleted: false,
      subtasks: const [],
    );

    try {
      final box = Hive.box('planner_tasks');
      await box.put(task.id, task.toJson());
      _tasks.add(task);
      _sortTasks(_tasks);
      notifyListeners();
      if (notifyBefore && startTime != null) _scheduleNotification(task);
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  int _timeDiff(String start, String end) {
    final sp = start.split(':');
    final ep = end.split(':');
    if (sp.length != 2 || ep.length != 2) return 0;
    final startMin = (int.tryParse(sp[0]) ?? 0) * 60 + (int.tryParse(sp[1]) ?? 0);
    final endMin   = (int.tryParse(ep[0]) ?? 0) * 60 + (int.tryParse(ep[1]) ?? 0);
    final diff = endMin - startMin;
    return diff > 0 ? diff : 0;
  }

  void _scheduleNotification(PlannerTask task) {
    try {
      if (task.startTime == null) return;
      final parts = task.startTime!.split(':');
      if (parts.length != 2) return;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final taskDateTime = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
      final notifyAt = taskDateTime.subtract(const Duration(minutes: 10));
      if (notifyAt.isAfter(DateTime.now())) {
        Future.delayed(notifyAt.difference(DateTime.now()), () {
          NotificationService().showNotification(
            id: task.id.hashCode.abs() % 2147483647,
            title: '⏰ Görev Yaklaşıyor!',
            body: '"${task.title}" görevi 10 dakika sonra başlıyor (${task.startTime}).',
          );
        });
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    
    final newIsCompleted = !_tasks[idx].isCompleted;
    final updatedSubtasks = _tasks[idx].subtasks.map((sub) {
      return sub.copyWith(status: newIsCompleted ? 'done' : 'todo');
    }).toList();
    
    final updated = _tasks[idx].copyWith(
      isCompleted: newIsCompleted,
      subtasks: updatedSubtasks,
    );
    
    _tasks[idx] = updated;
    notifyListeners();
    try {
      await Hive.box('planner_tasks').put(taskId, updated.toJson());
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await Hive.box('planner_tasks').delete(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  // ── Subtask methods ──

  Future<void> addSubtask(
    String taskId,
    String text, {
    String? startTime,
    String? endTime,
  }) async {
    if (text.trim().isEmpty) return;
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final newItem = TaskSubItem(
      id: _uuid.v4(),
      text: text.trim(),
      status: 'todo',
      startTime: startTime,
      endTime: endTime,
    );
    final updatedSubtasks = List<TaskSubItem>.from(_tasks[idx].subtasks)..add(newItem);
    await _updateTask(idx, _tasks[idx].copyWith(subtasks: updatedSubtasks));
  }

  Future<void> reorderSubtasks(String taskId, int oldIndex, int newIndex) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final items = List<TaskSubItem>.from(_tasks[idx].subtasks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    await _updateTask(idx, _tasks[idx].copyWith(subtasks: items));
  }

  Future<void> cycleSubtaskStatus(String taskId, String itemId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final items = List<TaskSubItem>.from(_tasks[idx].subtasks);
    final iIdx = items.indexWhere((i) => i.id == itemId);
    if (iIdx == -1) return;

    final next = _nextStatus(items[iIdx].status);
    items[iIdx] = items[iIdx].copyWith(status: next);
    await _updateTask(idx, _tasks[idx].copyWith(subtasks: items));
  }

  String _nextStatus(String current) {
    switch (current) {
      case 'todo': return 'doing';
      case 'doing': return 'done';
      default: return 'todo';
    }
  }

  Future<void> deleteSubtask(String taskId, String itemId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final items = _tasks[idx].subtasks.where((i) => i.id != itemId).toList();
    await _updateTask(idx, _tasks[idx].copyWith(subtasks: items));
  }

  PlannerTask _syncTaskCompletion(PlannerTask task) {
    if (task.subtasks.isEmpty) {
      return task;
    }
    final allDone = task.subtasks.every((s) => s.status == 'done');
    return task.copyWith(isCompleted: allDone);
  }

  Future<void> _updateTask(int idx, PlannerTask updated) async {
    final synced = _syncTaskCompletion(updated);
    _tasks[idx] = synced;
    notifyListeners();
    try {
      await Hive.box('planner_tasks').put(synced.id, synced.toJson());
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  // Legacy stubs
  void startTaskTimer(String taskId) {}
  void pauseTaskTimer() {}
  void resetTaskTimer(String taskId) {}
}
