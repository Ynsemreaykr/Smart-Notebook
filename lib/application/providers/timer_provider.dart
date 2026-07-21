import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/habit.dart';
import '../../data/services/notification_service.dart';
import 'habit_provider.dart';

class TimerProvider extends ChangeNotifier {
  final HabitProvider _habitProvider;

  Timer? _timer;
  int _durationSeconds = 25 * 60; // Default 25 minutes
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  
  String? _selectedHabitId;
  int _elapsedSecondsSinceLastSave = 0;
  DateTime? _sessionStartTime;

  TimerProvider(this._habitProvider);

  // Getters
  int get durationSeconds => _durationSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  String? get selectedHabitId => _selectedHabitId;
  int get elapsedSecondsSinceLastSave => _elapsedSecondsSinceLastSave;
  DateTime? get sessionStartTime => _sessionStartTime;

  // Find selected habit object
  Habit? get selectedHabit {
    if (_selectedHabitId == null) return null;
    final index = _habitProvider.habits.indexWhere((h) => h.id == _selectedHabitId);
    return index != -1 ? _habitProvider.habits[index] : null;
  }

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void setSelectedHabitId(String? habitId) {
    // Flush any pending seconds before changing habit
    _flushElapsedSeconds();
    _selectedHabitId = habitId;
    notifyListeners();
  }

  void setDuration(int minutes) {
    _flushElapsedSeconds();
    _durationSeconds = minutes * 60;
    _remainingSeconds = _durationSeconds;
    notifyListeners();
  }

  void startTimer() {
    if (_isRunning) return;
    _isRunning = true;
    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSecondsSinceLastSave++;
        notifyListeners();
        
        // Auto-save/persist every 10 seconds of active focus to be safe
        if (_elapsedSecondsSinceLastSave >= 10) {
          _flushElapsedSeconds();
        }
      } else {
        _onTimerComplete();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
    _flushElapsedSeconds();
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _flushElapsedSeconds();
    _remainingSeconds = _durationSeconds;
    _sessionStartTime = null;
    notifyListeners();
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _isRunning = false;
    _sessionStartTime = null;
    
    final finalFlushSeconds = _elapsedSecondsSinceLastSave;
    _elapsedSecondsSinceLastSave = 0;

    final habit = selectedHabit;
    if (habit != null) {
      _habitProvider.addTrackedTime(habit.id, DateTime.now(), finalFlushSeconds);
      
      // Trigger completion notification
      NotificationService().showNotification(
        id: 9999,
        title: '🎉 Odaklanma Süresi Tamamlandı!',
        body: '${habit.name} için ${_durationSeconds ~/ 60} dakikalık çalışma hedefinize ulaştınız!',
      );
    } else {
      NotificationService().showNotification(
        id: 9999,
        title: '🎉 Süre Tamamlandı!',
        body: '${_durationSeconds ~/ 60} dakikalık odaklanma süreniz bitti. Tebrikler!',
      );
    }
    
    _remainingSeconds = _durationSeconds;
    notifyListeners();
  }

  // Save accumulated seconds to the selected habit in the provider
  void _flushElapsedSeconds() {
    if (_selectedHabitId != null && _elapsedSecondsSinceLastSave > 0) {
      final secondsToSave = _elapsedSecondsSinceLastSave;
      _elapsedSecondsSinceLastSave = 0;
      _habitProvider.addTrackedTime(_selectedHabitId!, DateTime.now(), secondsToSave);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flushElapsedSeconds();
    super.dispose();
  }
}
