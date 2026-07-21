import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/providers/habit_provider.dart';
import '../../application/providers/timer_provider.dart';
import '../../domain/models/habit.dart';
import '../screens/notes/note_editor_screen.dart';
import '../screens/planner/pomodoro_screen.dart';
import 'bounce_button.dart';
import 'fade_slide_entrance.dart';

class HabitGridWidget extends StatelessWidget {
  const HabitGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 650;

    return Consumer2<HabitProvider, TimerProvider>(
      builder: (context, provider, timerProvider, _) {
        final habits = provider.habits;
        if (habits.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz Alışkanlık Eklenmedi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aşağıdaki ekleme butonunu kullanarak ilk Alışkanlığınızı oluşturun ve takibe başlayın!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'ALIŞKANLIKLARINIZ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              isTablet
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.9,
                      ),
                      itemCount: habits.length,
                      itemBuilder: (context, index) {
                        final habit = habits[index];
                        return FadeSlideEntrance(
                          delay: Duration(milliseconds: 100 + (index * 50)),
                          child: _buildHabitCard(context, provider, timerProvider, habit),
                        );
                      },
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: habits.length,
                      itemBuilder: (context, index) {
                        final habit = habits[index];
                        return FadeSlideEntrance(
                          delay: Duration(milliseconds: 100 + (index * 50)),
                          child: _buildHabitCard(context, provider, timerProvider, habit),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHabitCard(BuildContext context, HabitProvider provider, TimerProvider timerProvider, Habit habit) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isStar = habit.type == 'star';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row 1: Type icon, Name, Note link, Delete button
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isStar 
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isStar ? Icons.star_rounded : Icons.timer_rounded,
                    color: isStar ? Colors.amber.shade700 : Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Type Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isStar 
                            ? '⭐ Yıldız (Kalite Puanlama)' 
                            : (habit.isScheduled 
                                ? '⏱️ Zamanlı (${habit.startTime} - ${habit.endTime})' 
                                : '⏱️ Sayaç (Süre Takibi)'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Linked Note Button
                if (habit.linkedNoteId != null)
                  IconButton(
                    icon: Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                    tooltip: 'Bağlantılı Notu Aç',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(noteId: habit.linkedNoteId!),
                        ),
                      );
                    },
                  ),
                // Delete Button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                  tooltip: 'Alışkanlığı Sil',
                  onPressed: () => _confirmDelete(context, provider, habit),
                ),
              ],
            ),
            const Divider(height: 20),
            // Row 2: Stats & Log Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: Stats Display
                Expanded(
                  child: isStar 
                      ? _buildStarStats(provider, habit) 
                      : _buildTimerStats(provider, timerProvider, habit),
                ),
                // Right side: Action Button
                if (isStar)
                  BounceButton(
                    child: _buildStarActionButton(context, provider, habit),
                  )
                else
                  BounceButton(
                    child: _buildTimerActionButton(context, timerProvider, habit),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Stats for Star habits
  Widget _buildStarStats(HabitProvider provider, Habit habit) {
    final avg = provider.getHabitAverageRating(habit);
    final completed = provider.getCompletedDays(habit);
    final target = habit.targetDays ?? provider.daysInMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              '${avg.toStringAsFixed(1)} / 5.0 Ortalama',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'İlerleme: $completed / $target gün',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // Stats for Timer habits (Support Live Updates)
  Widget _buildTimerStats(HabitProvider provider, TimerProvider timerProvider, Habit habit) {
    int totalSecs = provider.getHabitTotalTrackedTime(habit);
    int todaySecs = provider.getHabitTodayTrackedTime(habit);
    int weeklySecs = provider.getHabitWeeklyTrackedTime(habit);

    // If active and ticking, add live seconds
    if (timerProvider.isRunning && timerProvider.selectedHabitId == habit.id) {
      final elapsed = timerProvider.elapsedSecondsSinceLastSave;
      totalSecs += elapsed;
      todaySecs += elapsed;
      weeklySecs += elapsed;
    }

    final total = _formatSecondsDigital(totalSecs);
    final today = _formatSecondsDigital(todaySecs);
    final weekly = _formatSecondsDigital(weeklySecs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⏱️ Toplam: $total',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Bugün: $today | Bu Hafta: $weekly',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStarActionButton(BuildContext context, HabitProvider provider, Habit habit) {
    final theme = Theme.of(context);
    final todayKey = _getDateKey(DateTime.now());
    final rating = habit.starRatings[todayKey] ?? 0;

    return ElevatedButton.icon(
      icon: Icon(rating > 0 ? Icons.star_rounded : Icons.star_outline_rounded, size: 14),
      label: Text(rating > 0 ? 'Puan: $rating★' : 'Puan Ver'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: rating > 0 ? Colors.amber.shade700 : theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      onPressed: () => _showRatingPicker(context, provider, habit, DateTime.now()),
    );
  }

  Widget _buildTimerActionButton(BuildContext context, TimerProvider timerProvider, Habit habit) {
    final theme = Theme.of(context);
    final isActiveTimer = timerProvider.selectedHabitId == habit.id;

    return OutlinedButton.icon(
      icon: Icon(isActiveTimer && timerProvider.isRunning ? Icons.pause_rounded : Icons.timer_rounded, size: 14),
      label: Text(isActiveTimer && timerProvider.isRunning ? 'Fokusu Durdur' : 'Pomodoro Başlat'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: theme.primaryColor),
      ),
      onPressed: () {
        if (isActiveTimer) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PomodoroScreen(),
            ),
          );
        } else {
          timerProvider.setSelectedHabitId(habit.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PomodoroScreen(),
            ),
          );
        }
      },
    );
  }

  // Delete confirm dialog
  void _confirmDelete(BuildContext context, HabitProvider provider, Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alışkanlığı Sil'),
        content: Text('"${habit.name}" silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteHabit(habit.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Rating picker bottom sheet
  void _showRatingPicker(BuildContext context, HabitProvider provider, Habit habit, DateTime date) {
    final dateKey = _getDateKey(date);
    final currentRating = habit.starRatings[dateKey] ?? 0;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int selectedRating = currentRating;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bugünün Performansını Puanla',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      habit.name,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isSelected = starValue <= selectedRating;
                        return IconButton(
                          icon: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: isSelected ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          onPressed: () {
                            setModalState(() {
                              selectedRating = starValue;
                            });
                            provider.setRating(habit.id, date, starValue);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (currentRating > 0)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        label: const Text('Bugünün Puanını Kaldır', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          provider.setRating(habit.id, date, 0);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatSecondsDigital(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    
    return '$hStr:$mStr:$sStr';
  }
}
