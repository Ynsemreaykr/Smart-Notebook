import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../../domain/models/habit.dart';
import '../../data/services/database_service.dart';
import '../../data/services/notification_service.dart';

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  final _uuid = const Uuid();

  // App limits and daily usage (real-time simulated)
  Map<String, int> _appLimits = {};

  // Usage in SECONDS for real-time precision; displayed as minutes in UI
  final Map<String, int> _appUsageSeconds = {
    'Smart Notebook': 105 * 60,
    'Youtube': 72 * 60,
    'WhatsApp': 40 * 60,
    'Instagram': 30 * 60,
    'Diğer': 15 * 60,
  };

  Timer? _usageTimer;

  // Convenience getter: returns minutes (floored)
  Map<String, int> get appUsageMinutes {
    return _appUsageSeconds.map((k, v) => MapEntry(k, v ~/ 60));
  }

  // Returns seconds for precise display
  Map<String, int> get appUsageSeconds => _appUsageSeconds;

  void startUsageTracking() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Smart Notebook increments every second (real usage)
      _appUsageSeconds['Smart Notebook'] =
          (_appUsageSeconds['Smart Notebook'] ?? 0) + 1;

      // Simulated slow increments for other apps (1 second every ~2 minutes)
      // This creates a realistic-feeling real-time update effect
      final now = DateTime.now();
      if (now.second % 120 == 0) {
        _appUsageSeconds['Youtube'] = (_appUsageSeconds['Youtube'] ?? 0) + 1;
      }
      if (now.second % 90 == 0) {
        _appUsageSeconds['WhatsApp'] = (_appUsageSeconds['WhatsApp'] ?? 0) + 1;
      }
      if (now.second % 150 == 0) {
        _appUsageSeconds['Instagram'] =
            (_appUsageSeconds['Instagram'] ?? 0) + 1;
      }

      // Check Smart Notebook limit
      final snMinutes = (_appUsageSeconds['Smart Notebook'] ?? 0) ~/ 60;
      final limit = _appLimits['Smart Notebook'] ?? 0;
      if (limit > 0 && snMinutes > 0 && snMinutes % limit == 0 &&
          (_appUsageSeconds['Smart Notebook'] ?? 0) % 60 == 0) {
        _triggerLimitAlert('Smart Notebook', snMinutes, limit);
      }

      notifyListeners();
    });
  }

  void stopUsageTracking() {
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    super.dispose();
  }

  List<Habit> get habits => _habits;
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;
  Map<String, int> get appLimits => _appLimits;

  // Legacy compat - no longer needed (replaced by startUsageTracking timer)
  void incrementSmartNotebookUsage() {}

  // Load habits and settings from Hive
  Future<void> loadHabits() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = DatabaseService.getHabitsBox();
      final List<Habit> loaded = [];
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          loaded.add(Habit.fromJson(data));
        }
      }
      _habits = loaded;

      // Load app limits
      final settingsBox = Hive.box(DatabaseService.settingsBox);
      final savedLimits = settingsBox.get('app_limits');
      if (savedLimits is Map) {
        _appLimits = Map<String, int>.from(savedLimits);
      }
    } catch (e) {
      debugPrint('Error loading habits: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Add new habit
  Future<void> addHabit(String name, {required String type, String? linkedNoteId, int? targetDays, String? startTime, String? endTime}) async {
    if (name.trim().isEmpty) return;

    final newHabit = Habit(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      createdAt: DateTime.now(),
      starRatings: {},
      trackedTime: {},
      linkedNoteId: linkedNoteId,
      targetDays: targetDays,
      startTime: startTime,
      endTime: endTime,
    );

    try {
      final box = DatabaseService.getHabitsBox();
      await box.put(newHabit.id, newHabit.toJson());
      _habits.add(newHabit);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding habit: $e');
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String id) async {
    try {
      final box = DatabaseService.getHabitsBox();
      await box.delete(id);
      _habits.removeWhere((h) => h.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting habit: $e');
    }
  }

  // Set rating for a star habit on a specific day
  Future<void> setRating(String habitId, DateTime date, int rating) async {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;

    final habit = _habits[habitIndex];
    final dateKey = _getDateKey(date);
    final updatedStarRatings = Map<String, int>.from(habit.starRatings);
    
    if (rating <= 0) {
      updatedStarRatings.remove(dateKey);
    } else {
      updatedStarRatings[dateKey] = rating;
    }

    final updatedHabit = habit.copyWith(starRatings: updatedStarRatings);
    _habits[habitIndex] = updatedHabit;
    notifyListeners();

    try {
      final box = DatabaseService.getHabitsBox();
      await box.put(habitId, updatedHabit.toJson());
    } catch (e) {
      debugPrint('Error setting rating: $e');
    }
  }

  // Add tracked focus seconds to a timer habit
  Future<void> addTrackedTime(String habitId, DateTime date, int seconds) async {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;

    final habit = _habits[habitIndex];
    final dateKey = _getDateKey(date);
    final updatedTrackedTime = Map<String, int>.from(habit.trackedTime);
    
    final currentSeconds = updatedTrackedTime[dateKey] ?? 0;
    updatedTrackedTime[dateKey] = currentSeconds + seconds;

    final updatedHabit = habit.copyWith(trackedTime: updatedTrackedTime);
    _habits[habitIndex] = updatedHabit;
    notifyListeners();

    try {
      final box = DatabaseService.getHabitsBox();
      await box.put(habitId, updatedHabit.toJson());
    } catch (e) {
      debugPrint('Error adding tracked time: $e');
    }
  }

  // Set selected month
  void setSelectedMonth(DateTime date) {
    _selectedMonth = date;
    notifyListeners();
  }

  // Set limit for an app and trigger immediate notification if exceeded
  Future<void> setAppLimit(String appName, int limitInMinutes) async {
    _appLimits[appName] = limitInMinutes;
    notifyListeners();

    try {
      final box = Hive.box(DatabaseService.settingsBox);
      await box.put('app_limits', _appLimits);

      // Check if usage exceeds limit immediately
      final usage = appUsageMinutes[appName] ?? 0;
      if (limitInMinutes > 0 && usage > limitInMinutes) {
        _triggerLimitAlert(appName, usage, limitInMinutes);
      }
    } catch (e) {
      debugPrint('Error setting app limit: $e');
    }
  }

  void _triggerLimitAlert(String appName, int usage, int limit) {
    NotificationService().showNotification(
      id: appName.hashCode.abs() % 2147483647,
      title: '⚠️ Ekran Süresi Sınırı Aşıldı!',
      body: '$appName kullanımı günlük $limit dakikalık sınırınızı aştı (Mevcut: $usage dakika).',
    );
  }

  // Date helper formatter YYYY-MM-DD
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Total days in selected month
  int get daysInMonth {
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    return lastDay.day;
  }

  // Completed days in selected month for a habit (days with rating > 0 or seconds > 0)
  int getCompletedDays(Habit habit) {
    int completed = 0;
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final totalDays = daysInMonth;
    for (int day = 1; day <= totalDays; day++) {
      final dateKey = _getDateKey(DateTime(year, month, day));
      if (habit.type == 'star') {
        final rating = habit.starRatings[dateKey] ?? 0;
        if (rating > 0) completed++;
      } else {
        final time = habit.trackedTime[dateKey] ?? 0;
        if (time > 0) completed++;
      }
    }
    return completed;
  }

  // Completion rate (0.0 to 1.0) for a habit in selected month
  double getHabitCompletionRate(Habit habit) {
    final target = habit.targetDays ?? daysInMonth;
    if (target == 0) return 0.0;
    
    if (habit.type == 'star') {
      double totalScore = 0.0;
      final year = _selectedMonth.year;
      final month = _selectedMonth.month;
      final totalDays = daysInMonth;
      for (int day = 1; day <= totalDays; day++) {
        final dateKey = _getDateKey(DateTime(year, month, day));
        final rating = habit.starRatings[dateKey] ?? 0;
        totalScore += rating / 5.0; // rating normalized to 0.0-1.0
      }
      final rate = totalScore / target;
      return rate > 1.0 ? 1.0 : rate;
    } else {
      final completed = getCompletedDays(habit);
      final rate = completed / target;
      return rate > 1.0 ? 1.0 : rate;
    }
  }

  // General Goals for selected month
  int get overallGoal {
    int totalGoal = 0;
    for (final habit in _habits) {
      totalGoal += habit.targetDays ?? daysInMonth;
    }
    return totalGoal;
  }

  // General Completed days for selected month
  int get overallCompleted {
    int totalCompleted = 0;
    for (final habit in _habits) {
      totalCompleted += getCompletedDays(habit);
    }
    return totalCompleted;
  }

  // General Left days for selected month
  int get overallLeft {
    final left = overallGoal - overallCompleted;
    return left < 0 ? 0 : left;
  }

  // General Completion Rate (0.0 to 1.0) for selected month
  double get overallCompletionRate {
    final goal = overallGoal;
    if (goal == 0) return 0.0;
    
    double totalNormalizedScore = 0.0;
    for (final habit in _habits) {
      final year = _selectedMonth.year;
      final month = _selectedMonth.month;
      final totalDays = daysInMonth;
      for (int day = 1; day <= totalDays; day++) {
        final dateKey = _getDateKey(DateTime(year, month, day));
        if (habit.type == 'star') {
          final rating = habit.starRatings[dateKey] ?? 0;
          totalNormalizedScore += rating / 5.0;
        } else {
          // Normalize focus time to daily target of 30 minutes
          final seconds = habit.trackedTime[dateKey] ?? 0;
          final rate = seconds / 1800.0;
          totalNormalizedScore += rate > 1.0 ? 1.0 : rate;
        }
      }
    }
    
    final rate = totalNormalizedScore / goal;
    return rate > 1.0 ? 1.0 : rate;
  }

  // Get Top Daily Habits sorted by completion rate
  List<Habit> getTopDailyHabits({int count = 3}) {
    if (_habits.isEmpty) return [];
    
    final sorted = List<Habit>.from(_habits);
    sorted.sort((a, b) {
      final rateA = getHabitCompletionRate(a);
      final rateB = getHabitCompletionRate(b);
      return rateB.compareTo(rateA); // Descending order
    });
    
    return sorted.take(count).toList();
  }

  // Last 7 days progress (day label, rate 0.0 - 1.0) with selected habit filter
  List<MapEntry<String, double>> getWeeklyProgress({String? selectedHabitId}) {
    return getProgressData(daysCount: 7, selectedHabitId: selectedHabitId);
  }

  // Get progress data for any days count
  List<MapEntry<String, double>> getProgressData({required int daysCount, String? selectedHabitId}) {
    final List<MapEntry<String, double>> progress = [];
    final now = DateTime.now();
    
    for (int i = daysCount - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = _getDateKey(date);
      final label = daysCount <= 7 ? _getDayLabel(date) : '${date.day}/${date.month}';
      
      if (selectedHabitId == null || selectedHabitId == 'all') {
        double sumRates = 0.0;
        int count = 0;
        for (final habit in _habits) {
          if (habit.type == 'star') {
            final rating = habit.starRatings[dateKey] ?? 0;
            sumRates += rating / 5.0;
            count++;
          } else {
            final seconds = habit.trackedTime[dateKey] ?? 0;
            final rate = seconds / 1800.0; // 30 mins standard focus target
            sumRates += rate > 1.0 ? 1.0 : rate;
            count++;
          }
        }
        final avgRate = count == 0 ? 0.0 : sumRates / count;
        progress.add(MapEntry(label, avgRate));
      } else {
        final habitIndex = _habits.indexWhere((h) => h.id == selectedHabitId);
        double rate = 0.0;
        if (habitIndex != -1) {
          final habit = _habits[habitIndex];
          if (habit.type == 'star') {
            final rating = habit.starRatings[dateKey] ?? 0;
            rate = rating / 5.0;
          } else {
            final seconds = habit.trackedTime[dateKey] ?? 0;
            rate = seconds / 1800.0;
            if (rate > 1.0) rate = 1.0;
          }
        }
        progress.add(MapEntry(label, rate));
      }
    }
    
    return progress;
  }

  // Dashboard Stats Getters
  Habit? get mostTrackedHabit {
    if (_habits.isEmpty) return null;
    Habit? best;
    int maxSeconds = -1;
    for (final habit in _habits) {
      if (habit.type == 'timer') {
        int totalSeconds = getHabitTotalTrackedTime(habit);
        if (totalSeconds > maxSeconds && totalSeconds > 0) {
          maxSeconds = totalSeconds;
          best = habit;
        }
      }
    }
    return best;
  }

  Habit? get highestRatedHabit {
    if (_habits.isEmpty) return null;
    Habit? best;
    double maxAvg = -1.0;
    for (final habit in _habits) {
      if (habit.type == 'star') {
        double avg = getHabitAverageRating(habit);
        if (avg > maxAvg && avg > 0) {
          maxAvg = avg;
          best = habit;
        }
      }
    }
    return best;
  }

  int get totalTrackedTimeToday {
    final dateKey = _getDateKey(DateTime.now());
    int total = 0;
    for (final habit in _habits) {
      if (habit.type == 'timer') {
        total += habit.trackedTime[dateKey] ?? 0;
      }
    }
    return total;
  }

  double getHabitAverageRating(Habit habit) {
    final ratings = habit.starRatings.values.where((r) => r > 0).toList();
    if (ratings.isEmpty) return 0.0;
    return ratings.fold(0.0, (sum, val) => sum + val) / ratings.length;
  }

  int getHabitTotalTrackedTime(Habit habit) {
    return habit.trackedTime.values.fold(0, (sum, val) => sum + val);
  }

  int getHabitTodayTrackedTime(Habit habit) {
    final dateKey = _getDateKey(DateTime.now());
    return habit.trackedTime[dateKey] ?? 0;
  }

  int getHabitWeeklyTrackedTime(Habit habit) {
    int total = 0;
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final dateKey = _getDateKey(now.subtract(Duration(days: i)));
      total += habit.trackedTime[dateKey] ?? 0;
    }
    return total;
  }

  String _getDayLabel(DateTime date) {
    final weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return weekdays[date.weekday - 1];
  }
}
