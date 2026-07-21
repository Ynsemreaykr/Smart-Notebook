import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/habit_provider.dart';
import '../../../application/providers/calendar_provider.dart';
import '../../../application/providers/note_provider.dart';
import '../../../application/providers/timer_provider.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/plan_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/models/habit.dart';
import '../../../domain/models/plan.dart';
import '../../../domain/models/planner_task.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';
import 'pomodoro_screen.dart';

// px per minute in the pixel-based timeline
const double _kPxPerMin = 1.3;
// left column width (time labels)
const double _kTimeColW = 54.0;

class PlannerScreen extends StatefulWidget {
  final int initialTab;
  const PlannerScreen({super.key, this.initialTab = 0});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with TickerProviderStateMixin {
  final Set<String> _expandedTaskIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
      context.read<NoteProvider>().loadNotes();
      context.read<TaskProvider>().loadTasks();
      context.read<PlanProvider>().loadPlans();
    });
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────
  int _timeToMinutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  String _getMonthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month - 1];
  }

  // ─────────────────────────────────────────────
  //  Info Dialog
  // ─────────────────────────────────────────────
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🗓️ Planlayıcı Hakkında'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Gününü Planla:\n'
            '   • Görevlere başlangıç/bitiş saati belirlenir.\n'
            '   • Görevler, zaman akışında gerçek süreleriyle listelenir.\n'
            '   • Görevlerin yanındaki ↓/↑ ile alt görevler açılır/kapanır.\n'
            '   • Alt görevler hiyerarşik olarak zaman dilimlerine göre sıralanır.\n'
            '   • Alt görev tamamlandığında ana görev de otomatik tamamlanır.\n'
            '   • 🔔 ile 10 dk önce bildirim alınabilir.\n\n'
            '2. Planlarım:\n'
            '   • ↓/↑ ile alt planları (3 seviyeye kadar) açıp kapatabilirsiniz.\n'
            '   • Alt planların durumuna göre tamamlanma yüzdeleri otomatik hesaplanır.\n'
            '   • Sürükle-bırak (≡) ile sıralama yapılabilir.\n'
            '   • Eklenen planlar ana ekran widget\'ı üzerinden canlı takip edilebilir.\n\n'
            '3. Kullanım Süreleri:\n'
            '   • Smart Notebook kullanımı gerçek zamanlı izlenir ve kısıtlanabilir.',
            style: TextStyle(height: 1.55),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Add Task Dialog  (start + end TimePicker)
  // ─────────────────────────────────────────────
  void _showAddTaskDialog(BuildContext context,
      {TimeOfDay? initialStart}) {
    final titleCtrl = TextEditingController();
    TimeOfDay? startTOD = initialStart;
    TimeOfDay? endTOD;
    bool notifyBefore = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(builder: (ctx, setModal) {
          // Compute duration string for preview
          String durationLabel = '';
          if (startTOD != null && endTOD != null) {
            final diff = (endTOD!.hour * 60 + endTOD!.minute) -
                (startTOD!.hour * 60 + startTOD!.minute);
            if (diff > 0) {
              durationLabel = diff < 60
                  ? '${diff}dk'
                  : '${diff ~/ 60}s${diff % 60 > 0 ? ' ${diff % 60}dk' : ''}';
            }
          }

          Future<void> pickStart() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: startTOD ?? TimeOfDay.now(),
              helpText: 'Başlangıç Saati',
              initialEntryMode: TimePickerEntryMode.inputOnly,
            );
            if (picked != null) setModal(() => startTOD = picked);
          }

          Future<void> pickEnd() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: endTOD ??
                  (startTOD != null
                      ? TimeOfDay(hour: (startTOD!.hour + 1) % 24,
                          minute: startTOD!.minute)
                      : TimeOfDay.now()),
              helpText: 'Bitiş Saati',
              initialEntryMode: TimePickerEntryMode.inputOnly,
            );
            if (picked != null) setModal(() => endTOD = picked);
          }

          String fmtTOD(TimeOfDay? t) => t == null
              ? '-- : --'
              : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          final hasTime = startTOD != null && endTOD != null;

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.add_task_rounded, color: Colors.cyan),
                    const SizedBox(width: 8),
                    const Text('Yeni Görev',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Görev Başlığı'),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: 18),

                // Time range row
                const Text('SAAT ARALIĞI',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Start
                    Expanded(
                      child: _timePickerButton(
                        label: 'Başlangıç',
                        value: fmtTOD(startTOD),
                        icon: Icons.play_arrow_rounded,
                        color: Colors.cyan,
                        onTap: pickStart,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: Colors.grey, size: 18),
                    ),
                    // End
                    Expanded(
                      child: _timePickerButton(
                        label: 'Bitiş',
                        value: fmtTOD(endTOD),
                        icon: Icons.stop_rounded,
                        color: Colors.orangeAccent,
                        onTap: pickEnd,
                      ),
                    ),
                  ],
                ),

                // Duration preview
                if (durationLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Süre: $durationLabel',
                          style: const TextStyle(
                              color: Colors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Notification toggle
                Container(
                  decoration: BoxDecoration(
                    color: notifyBefore && hasTime
                        ? AppTheme.neonBlue.withOpacity(0.1)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: notifyBefore && hasTime
                          ? AppTheme.neonBlue.withOpacity(0.35)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    value: notifyBefore && hasTime,
                    activeColor: AppTheme.neonBlue,
                    onChanged: hasTime
                        ? (v) => setModal(() => notifyBefore = v)
                        : null,
                    title: Row(children: [
                      Icon(Icons.notifications_active_rounded,
                          size: 16,
                          color: notifyBefore && hasTime
                              ? AppTheme.neonBlue
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text('10 dk önce bildirim',
                          style: TextStyle(
                              color: notifyBefore && hasTime
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 13)),
                    ]),
                    subtitle: hasTime
                        ? null
                        : const Text('Bildirim için saat seçin',
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final startStr = startTOD != null
                          ? '${startTOD!.hour.toString().padLeft(2, '0')}:${startTOD!.minute.toString().padLeft(2, '0')}'
                          : null;
                      final endStr = endTOD != null
                          ? '${endTOD!.hour.toString().padLeft(2, '0')}:${endTOD!.minute.toString().padLeft(2, '0')}'
                          : null;
                      context.read<TaskProvider>().addTask(
                            title,
                            startTime: startStr,
                            endTime: endStr,
                            notifyBefore: notifyBefore && hasTime,
                          );
                      Navigator.pop(context);
                    },
                    child: const Text('Kaydet',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _timePickerButton({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          title: const Text('🗓️ Planlayıcı & Takip'),
          actions: [
            IconButton(
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const PomodoroScreen())),
              tooltip: 'Pomodoro',
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => _showInfoDialog(context),
              tooltip: 'Bilgi',
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.neonBlue,
            indicatorWeight: 3,
            labelColor: AppTheme.neonAccent,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.calendar_view_day_rounded), text: 'Gününü Planla'),
              Tab(icon: Icon(Icons.checklist_rounded), text: 'Planlarım'),
              Tab(icon: Icon(Icons.query_stats_rounded), text: 'Kullanım Süreleri'),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.darkCard, AppTheme.darkBg],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Consumer3<HabitProvider, TimerProvider, TaskProvider>(
            builder: (context, habitProvider, timerProvider, taskProvider, _) {
              return TabBarView(
                children: [
                  _buildTimelineTab(context, habitProvider, taskProvider, timerProvider),
                  _buildPlansTab(context),
                  _buildUsageTab(context, habitProvider),
                ],
              );
            },
          ),
        ),
        floatingActionButton: Builder(builder: (context) {
          return BounceButton(
            onTap: () {
              final tabIdx = DefaultTabController.of(context).index;
              if (tabIdx == 0) {
                _showAddTaskDialog(context);
              } else if (tabIdx == 1) {
                _showAddPlanDialog(context);
              }
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.primaryGlow(intensity: 0.6),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  TAB 1: Gününü Planla
  // ═══════════════════════════════════════════════
  Widget _buildTimelineTab(
    BuildContext context,
    HabitProvider habitProvider,
    TaskProvider taskProvider,
    TimerProvider timerProvider,
  ) {
    if (taskProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final dateLabel =
        '${taskProvider.selectedDate.day} ${_getMonthName(taskProvider.selectedDate.month)} ${taskProvider.selectedDate.year}';

    // All-day tasks (no startTime)
    final allDayTasks =
        taskProvider.tasks.where((t) => t.startTime == null).toList();
    // Timed tasks
    final timedTasks =
        taskProvider.tasks.where((t) => t.startTime != null).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // ── Date Switcher ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => taskProvider.setSelectedDate(
                    taskProvider.selectedDate.subtract(const Duration(days: 1))),
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: taskProvider.selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) taskProvider.setSelectedDate(picked);
                },
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text(dateLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                onPressed: () => taskProvider.setSelectedDate(
                    taskProvider.selectedDate.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),

        // ── All-day tasks ──
        if (allDayTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('TÜM GÜN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey)),
                ),
                ...allDayTasks
                    .map((task) => _buildTaskCard(context, taskProvider, task)),
              ],
            ),
          ),

        // ── Timeline header ──
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
          child: Row(children: [
            const Icon(Icons.access_time_rounded,
                color: Colors.purpleAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              timedTasks.isEmpty
                  ? 'SAATLİK ZAMAN AKIŞI — Görev Eklemek İçin + Basın'
                  : 'SAATLİK ZAMAN AKIŞI (00:00 - 23:59)',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey),
            ),
          ]),
        ),

        // ── Pixel-based timeline ──
        _buildPixelTimeline(context, taskProvider, habitProvider, timerProvider),
      ],
    );
  }

  // ── Pixel-based timeline ──
  Widget _buildPixelTimeline(
    BuildContext context,
    TaskProvider taskProvider,
    HabitProvider habitProvider,
    TimerProvider timerProvider,
  ) {
    const totalMinutes = 24 * 60;
    final totalHeight = totalMinutes * _kPxPerMin;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // Is today?
    final isToday = taskProvider.selectedDate.year == now.year &&
        taskProvider.selectedDate.month == now.month &&
        taskProvider.selectedDate.day == now.day;

    final timedTasks =
        taskProvider.tasks.where((t) => t.startTime != null).toList();

    final habits = habitProvider.habits
        .where((h) => h.startTime != null)
        .toList();

    // Session
    final isSessionToday = timerProvider.sessionStartTime != null &&
        timerProvider.sessionStartTime!.year == taskProvider.selectedDate.year &&
        timerProvider.sessionStartTime!.month == taskProvider.selectedDate.month &&
        timerProvider.sessionStartTime!.day == taskProvider.selectedDate.day;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Hour lines & labels ──
                ...List.generate(24, (hour) {
                  final top = hour * 60 * _kPxPerMin;
                  return Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _kTimeColW,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, top: 0),
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // ── Current time indicator ──
                if (isToday)
                  Positioned(
                    top: nowMinutes * _kPxPerMin - 1,
                    left: _kTimeColW,
                    right: 0,
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.redAccent, shape: BoxShape.circle)),
                      Expanded(
                          child: Container(height: 2, color: Colors.redAccent)),
                    ]),
                  ),

                // ── Habit blocks ──
                ...habits.map((habit) {
                  final startMin = _timeToMinutes(habit.startTime!);
                  final endMin = habit.endTime != null
                      ? _timeToMinutes(habit.endTime!)
                      : startMin + 60;
                  final dur = (endMin - startMin).clamp(15, 24 * 60);
                  final h = dur * _kPxPerMin;
                  final top = startMin * _kPxPerMin;
                  return Positioned(
                    top: top,
                    left: _kTimeColW + 4,
                    right: 4,
                    height: max(28.0, h),
                    child: _buildTimelineHabitBlock(context, habit, h),
                  );
                }),

                // ── Pomodoro session block ──
                if (isSessionToday && timerProvider.sessionStartTime != null)
                  _buildSessionBlock(context, timerProvider),

                // ── Task blocks ──
                ...timedTasks.map((task) {
                  final startMin = _timeToMinutes(task.startTime!);
                  final dur = task.durationMinutes > 0
                      ? task.durationMinutes
                      : (task.endTime != null
                          ? _timeToMinutes(task.endTime!) - startMin
                          : 60);
                  final durClamped = dur.clamp(10, 24 * 60 - startMin);
                  final h = durClamped * _kPxPerMin;
                  final top = startMin * _kPxPerMin;
                  return Positioned(
                    top: top,
                    left: _kTimeColW + 4,
                    right: 4,
                    height: max(32.0, h),
                    child: _buildTimelineTaskBlock(
                        context, taskProvider, task, h),
                  );
                }),

                // ── Tap-to-add overlay (transparent, behind tasks) ──
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      final tapY = details.localPosition.dy;
                      final minutes = tapY / _kPxPerMin;
                      final hour = (minutes ~/ 60).clamp(0, 23);
                      final minute = ((minutes % 60) ~/ 15 * 15).clamp(0, 45);
                      _showAddTaskDialog(context,
                          initialStart: TimeOfDay(hour: hour, minute: minute));
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimelineSubtasks(
      BuildContext context, TaskProvider provider, PlannerTask task) {
    if (task.startTime == null) return [];
    final taskStartMin = _timeToMinutes(task.startTime!);
    int untimedCount = 0;

    return task.subtasks.map((subtask) {
      double topOffset;
      double subHeight;

      if (subtask.startTime != null) {
        final subStartMin = _timeToMinutes(subtask.startTime!);
        final subEndMin = subtask.endTime != null
            ? _timeToMinutes(subtask.endTime!)
            : subStartMin + 30;
        topOffset = (subStartMin - taskStartMin) * _kPxPerMin;
        subHeight = (subEndMin - subStartMin) * _kPxPerMin;
      } else {
        // Place untimed subtasks below header, stacking them
        topOffset = 38.0 + (untimedCount * 24.0);
        subHeight = 22.0;
        untimedCount++;
      }

      Color subColor;
      switch (subtask.status) {
        case 'done':
          subColor = Colors.green;
          break;
        case 'doing':
          subColor = Colors.amber;
          break;
        default:
          subColor = Colors.purpleAccent;
      }

      return Positioned(
        top: topOffset,
        left: 32,
        right: 6,
        height: max(20.0, subHeight),
        child: GestureDetector(
          onTap: () => provider.cycleSubtaskStatus(task.id, subtask.id),
          onLongPress: () =>
              _confirmDeleteSubtask(context, provider, task.id, subtask),
          child: Container(
            decoration: BoxDecoration(
              color: subColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: subColor.withOpacity(0.6), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            alignment: Alignment.centerLeft,
            child: Text(
              '|_ ${subtask.startTime ?? ""} ${subtask.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: subtask.isDone ? Colors.grey : Colors.white,
                decoration: subtask.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTimelineTaskBlock(
    BuildContext context,
    TaskProvider provider,
    PlannerTask task,
    double height,
  ) {
    final isShort = height < 44;
    final isExpanded = _expandedTaskIds.contains(task.id);

    return GestureDetector(
      onTap: () => provider.toggleTaskCompletion(task.id),
      onLongPress: () => _showTaskOptionsSheet(context, provider, task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: task.isCompleted
              ? Colors.green.withOpacity(0.18)
              : AppTheme.neonBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: task.isCompleted
                ? Colors.green.withOpacity(0.4)
                : AppTheme.neonBlue.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (task.isCompleted ? Colors.green : AppTheme.neonBlue)
                  .withOpacity(0.12),
              blurRadius: 6,
            )
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 8, vertical: isShort ? 4 : 6),
              child: isShort
                  ? Row(children: [
                      Icon(
                        task.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 12,
                        color: task.isCompleted ? Colors.green : AppTheme.neonBlue,
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (task.subtasks.isEmpty) {
                            _showAddSubtaskDialog(context, provider, task.id);
                          } else {
                            setState(() {
                              if (isExpanded) {
                                _expandedTaskIds.remove(task.id);
                              } else {
                                _expandedTaskIds.add(task.id);
                              }
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            task.subtasks.isEmpty
                                ? '↓'
                                : (isExpanded ? '↑' : '↓'),
                            style: TextStyle(
                                color: task.subtasks.isEmpty ? Colors.white30 : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: task.isCompleted
                                    ? Colors.grey
                                    : Colors.white,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null)),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showAddSubtaskDialog(context, provider, task.id),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Icon(Icons.add_rounded, size: 14, color: Colors.white70),
                        ),
                      ),
                      if (task.notifyBefore)
                        const Icon(Icons.notifications_active_rounded,
                            size: 10, color: Colors.amber),
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            task.isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 13,
                            color: task.isCompleted
                                ? Colors.green
                                : AppTheme.neonBlue,
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (task.subtasks.isEmpty) {
                                _showAddSubtaskDialog(context, provider, task.id);
                              } else {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedTaskIds.remove(task.id);
                                  } else {
                                    _expandedTaskIds.add(task.id);
                                  }
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Text(
                                task.subtasks.isEmpty
                                    ? '↓ '
                                    : (isExpanded ? '↑ ' : '↓ '),
                                style: TextStyle(
                                    color: task.subtasks.isEmpty ? Colors.white38 : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: task.isCompleted
                                        ? Colors.grey
                                        : Colors.white,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null)),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showAddSubtaskDialog(context, provider, task.id),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.add_rounded, size: 16, color: Colors.white70),
                            ),
                          ),
                          if (task.notifyBefore)
                            const Icon(Icons.notifications_active_rounded,
                                size: 12, color: Colors.amber),
                        ]),
                        if (task.startTime != null && task.endTime != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${task.startTime} – ${task.endTime}',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.neonBlue.withOpacity(0.8)),
                          ),
                        ],
                        if (task.subtasks.isNotEmpty && height > 70) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${task.subtasks.where((s) => s.status == 'done').length}/${task.subtasks.length} alt görev',
                            style:
                                const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
            ),
            if (isExpanded && task.startTime != null && task.subtasks.isNotEmpty)
              ..._buildTimelineSubtasks(context, provider, task),
          ],
        ),
      ),
    );
  }

  void _showTaskOptionsSheet(
      BuildContext context, TaskProvider provider, PlannerTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_box_outlined, color: Colors.green),
              title: Text(
                  task.isCompleted
                      ? 'Tamamlanmadı olarak işaretle'
                      : 'Tamamlandı olarak işaretle',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                provider.toggleTaskCompletion(task.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded, color: Colors.cyan),
              title: const Text('Alt Görev Ekle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showAddSubtaskDialog(context, provider, task.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted_rounded, color: Colors.purpleAccent),
              title: const Text('Alt Görevleri Yönet', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showManageSubtasksDialog(context, provider, task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Görevi Sil',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTask(context, provider, task);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManageSubtasksDialog(
      BuildContext context, TaskProvider provider, PlannerTask task) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<TaskProvider>(
          builder: (ctx2, taskProvider, _) {
            final taskIdx = taskProvider.tasks.indexWhere((t) => t.id == task.id);
            if (taskIdx == -1) return const SizedBox.shrink();
            final currentTask = taskProvider.tasks[taskIdx];

            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Row(
                children: [
                  const Icon(Icons.format_list_bulleted_rounded, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${currentTask.title} - Alt Görevler',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentTask.subtasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Henüz alt görev eklenmedi.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    else
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            buildDefaultDragHandles: false,
                            itemCount: currentTask.subtasks.length,
                            onReorder: (oldIdx, newIdx) {
                              taskProvider.reorderSubtasks(currentTask.id, oldIdx, newIdx);
                            },
                            itemBuilder: (ctx3, index) {
                              final item = currentTask.subtasks[index];
                              Color statusColor;
                              IconData statusIcon;
                              switch (item.status) {
                                case 'done':
                                  statusColor = Colors.green;
                                  statusIcon = Icons.check_circle_rounded;
                                  break;
                                case 'doing':
                                  statusColor = Colors.amber;
                                  statusIcon = Icons.timelapse_rounded;
                                  break;
                                default:
                                  statusColor = Colors.grey;
                                  statusIcon = Icons.radio_button_unchecked_rounded;
                              }

                              return Padding(
                                key: ValueKey(item.id),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(Icons.menu_rounded, color: Colors.grey, size: 18),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => taskProvider.cycleSubtaskStatus(currentTask.id, item.id),
                                        child: Icon(statusIcon, color: statusColor, size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.startTime != null
                                              ? '${item.text} (${item.startTime})'
                                              : item.text,
                                          style: TextStyle(
                                            color: item.isDone ? Colors.grey : Colors.white,
                                            fontSize: 12,
                                            decoration: item.isDone ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmDeleteSubtask(context, taskProvider, currentTask.id, item),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Alt Görev Ekle'),
                      onPressed: () {
                        _showAddSubtaskDialog(ctx2, taskProvider, currentTask.id);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineHabitBlock(
      BuildContext context, Habit habit, double height) {
    final color = habit.type == 'star' ? Colors.amber : Colors.purple;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          Icon(habit.type == 'star' ? Icons.star_rounded : Icons.timer_rounded,
              size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  Widget _buildSessionBlock(
      BuildContext context, TimerProvider timerProvider) {
    final start = timerProvider.sessionStartTime!;
    final startMin = start.hour * 60 + start.minute;
    final durMin = timerProvider.durationSeconds ~/ 60;
    final h = max(32.0, durMin * _kPxPerMin);
    return Positioned(
      top: startMin * _kPxPerMin,
      left: _kTimeColW + 4,
      right: 4,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          const Icon(Icons.timer_rounded, color: Colors.purpleAccent, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Pomodoro: ${timerProvider.formattedTime}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),
      ),
    );
  }

  // ── All-day task card with subtask support ──
  Widget _buildTaskCard(
      BuildContext context, TaskProvider provider, PlannerTask task) {
    final isExpanded = _expandedTaskIds.contains(task.id);
    final percent = task.subtaskPercent;
    final hasSubtasks = task.subtasks.isNotEmpty;

    Color statusColor;
    if (task.isCompleted || percent == 100) {
      statusColor = Colors.green;
    } else if (percent > 0) {
      statusColor = Colors.amber;
    } else {
      statusColor = AppTheme.neonBlue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      color: AppTheme.darkCard,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              // ↓ expand (only when has subtasks)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTaskIds.remove(task.id);
                    } else {
                      _expandedTaskIds.add(task.id);
                    }
                  });
                },
                child: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: (hasSubtasks ? AppTheme.neonBlue : Colors.grey)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        '↓',
                        style: TextStyle(
                            color: hasSubtasks ? AppTheme.neonBlue : Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Checkbox
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: task.isCompleted,
                  activeColor: Colors.green,
                  checkColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.4)),
                  onChanged: (_) => provider.toggleTaskCompletion(task.id),
                ),
              ),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                            color:
                                task.isCompleted ? Colors.grey : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null)),
                    if (task.startTime != null)
                      Text(
                        task.endTime != null
                            ? '${task.startTime} – ${task.endTime}'
                            : task.startTime!,
                        style: const TextStyle(
                            color: Colors.cyan, fontSize: 10),
                      ),
                  ],
                ),
              ),
              // % badge (when has subtasks)
              if (hasSubtasks) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text('%$percent',
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 6),
              ],
              // Notification icon
              if (task.notifyBefore)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.notifications_active_rounded,
                      size: 14, color: Colors.amber),
                ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteTask(context, provider, task),
              ),
            ]),
          ),

          // Progress bar
          if (hasSubtasks)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100.0,
                  minHeight: 3,
                  color: statusColor,
                  backgroundColor: Colors.white.withOpacity(0.07),
                ),
              ),
            ),

          // Expanded subtasks
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, thickness: 1),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: task.subtasks.length,
                  onReorder: (oldIdx, newIdx) {
                    provider.reorderSubtasks(task.id, oldIdx, newIdx);
                  },
                  itemBuilder: (ctx, index) {
                    final item = task.subtasks[index];
                    return _buildSubtaskRow(
                      ctx,
                      provider,
                      task.id,
                      item,
                      index,
                      key: ValueKey(item.id),
                    );
                  },
                ),
                // Add sub-task
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: GestureDetector(
                    onTap: () =>
                        _showAddSubtaskDialog(context, provider, task.id),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.neonBlue.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.neonBlue.withOpacity(0.25)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: AppTheme.neonBlue, size: 16),
                            const SizedBox(width: 6),
                            Text('Alt Görev Ekle',
                                style: TextStyle(
                                    color: AppTheme.neonBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),

          // Button to add first sub-task (when not expanded yet)
          if (!isExpanded && !hasSubtasks)
            TextButton.icon(
              onPressed: () {
                setState(() => _expandedTaskIds.add(task.id));
                _showAddSubtaskDialog(context, provider, task.id);
              },
              icon: const Icon(Icons.playlist_add_rounded,
                  size: 14, color: Colors.grey),
              label: const Text('Alt görev ekle',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
            ),
        ],
      ),
    );
  }

  Widget _buildSubtaskRow(
      BuildContext context, TaskProvider provider, String taskId, TaskSubItem item, int index, {required Key key}) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (item.status) {
      case 'done':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Tamamlandı';
        break;
      case 'doing':
        statusColor = Colors.amber;
        statusIcon = Icons.timelapse_rounded;
        statusLabel = 'Yapılıyor';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Bekliyor';
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Row(children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.menu_rounded, color: Colors.grey, size: 18),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => provider.cycleSubtaskStatus(taskId, item.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => provider.cycleSubtaskStatus(taskId, item.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.startTime != null && item.endTime != null
                        ? '${item.text} (${item.startTime}-${item.endTime})'
                        : item.startTime != null
                            ? '${item.text} (${item.startTime})'
                            : item.text,
                    style: TextStyle(
                        color: item.isDone ? Colors.grey : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null),
                  ),
                  Text(statusLabel,
                      style: TextStyle(
                          color: statusColor.withOpacity(0.8), fontSize: 9)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.redAccent, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _confirmDeleteSubtask(context, provider, taskId, item),
          ),
        ]),
      ),
    );
  }

  void _showAddSubtaskDialog(
      BuildContext context, TaskProvider provider, String taskId) {
    final ctrl = TextEditingController();
    
    // Find parent task to default times
    final parentIdx = provider.tasks.indexWhere((t) => t.id == taskId);
    TimeOfDay? startTOD;
    TimeOfDay? endTOD;
    
    if (parentIdx != -1) {
      final parent = provider.tasks[parentIdx];
      if (parent.startTime != null) {
        final parts = parent.startTime!.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 12;
          final minute = int.tryParse(parts[1]) ?? 0;
          startTOD = TimeOfDay(hour: hour, minute: minute);
          
          // Default end time to start time + 30 mins
          final endMinTotal = hour * 60 + minute + 30;
          endTOD = TimeOfDay(
              hour: (endMinTotal ~/ 60) % 24,
              minute: endMinTotal % 60);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> pickStart() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: startTOD ?? TimeOfDay.now(),
              helpText: 'Başlangıç Saati',
              initialEntryMode: TimePickerEntryMode.inputOnly,
            );
            if (picked != null) setState(() => startTOD = picked);
          }

          Future<void> pickEnd() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: endTOD ??
                  (startTOD != null
                      ? TimeOfDay(hour: (startTOD!.hour + 1) % 24, minute: startTOD!.minute)
                      : TimeOfDay.now()),
              helpText: 'Bitiş Saati',
              initialEntryMode: TimePickerEntryMode.inputOnly,
            );
            if (picked != null) setState(() => endTOD = picked);
          }

          String fmtTOD(TimeOfDay? t) => t == null
              ? '-- : --'
              : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            backgroundColor: AppTheme.darkCard,
            title: const Text('Alt Görev Ekle',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: 'Görev açıklaması...',
                        hintStyle: TextStyle(color: Colors.grey)),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 18),
                  const Text('SAAT ARALIĞI (İSTEĞE BAĞLI)',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: pickStart,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                const Text('Başlangıç', style: TextStyle(color: Colors.cyan, fontSize: 9)),
                                const SizedBox(height: 4),
                                Text(fmtTOD(startTOD), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: pickEnd,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                const Text('Bitiş', style: TextStyle(color: Colors.orangeAccent, fontSize: 9)),
                                const SizedBox(height: 4),
                                Text(fmtTOD(endTOD), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (startTOD != null || endTOD != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          startTOD = null;
                          endTOD = null;
                        }),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                        child: const Text('Saatleri Temizle', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal')),
              ElevatedButton(
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    final startStr = startTOD != null ? '${startTOD!.hour.toString().padLeft(2, '0')}:${startTOD!.minute.toString().padLeft(2, '0')}' : null;
                    final endStr = endTOD != null ? '${endTOD!.hour.toString().padLeft(2, '0')}:${endTOD!.minute.toString().padLeft(2, '0')}' : null;
                    provider.addSubtask(
                      taskId,
                      ctrl.text.trim(),
                      startTime: startStr,
                      endTime: endStr,
                    );
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonBlue),
                child: const Text('Ekle'),
              ),
            ],
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════════
  //  TAB 2: Planlarım
  // ═══════════════════════════════════════════════
  void _showAddPlanDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Yeni Plan',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Plan başlığı...',
              hintStyle: TextStyle(color: Colors.grey)),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<PlanProvider>().addPlan(ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonBlue),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlan(
      BuildContext context, PlanProvider provider, Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Planı Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '"${plan.title}" planını ve tüm alt görevlerini silmek istiyor musunuz?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      provider.deletePlan(plan.id);
    }
  }

  Future<void> _confirmDeleteSubtask(
      BuildContext context, TaskProvider provider, String taskId, TaskSubItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Alt Görevi Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '"${item.text}" alt görevini silmek istiyor musunuz?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteSubtask(taskId, item.id);
    }
  }

  Future<void> _confirmDeletePlanItem(
      BuildContext context, PlanProvider provider, String planId, PlanItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Alt Görevi Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '"${item.text}" alt görevini silmek istiyor musunuz?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteItem(planId, item.id);
    }
  }

  Future<void> _confirmDeleteTask(
      BuildContext context, TaskProvider provider, PlannerTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Görevi Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '"${task.title}" görevini ve tüm alt görevlerini silmek istiyor musunuz?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteTask(task.id);
    }
  }

  Widget _buildPlansTab(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        if (planProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (planProvider.plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checklist_rtl_rounded,
                    size: 64, color: Colors.white.withOpacity(0.12)),
                const SizedBox(height: 14),
                const Text('Henüz plan eklenmedi.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                const Text('+ butonuna basarak plan oluşturun.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return ReorderableListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          buildDefaultDragHandles: false,
          itemCount: planProvider.plans.length,
          onReorder: (oldIdx, newIdx) {
            planProvider.reorderPlans(oldIdx, newIdx);
          },
          itemBuilder: (ctx, i) {
            final plan = planProvider.plans[i];
            return _buildPlanCard(
              ctx,
              planProvider,
              plan,
              i,
              key: ValueKey(plan.id),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanCard(
      BuildContext context, PlanProvider provider, Plan plan, int index, {required Key key}) {
    final isExpanded = provider.isExpanded(plan.id);
    final percent = plan.completionPercent;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (plan.status) {
      case 'done':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Tamamlandı';
        break;
      case 'doing':
        statusColor = Colors.amber;
        statusIcon = Icons.timelapse_rounded;
        statusLabel = 'Yapılıyor';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Bekliyor';
    }

    Color progressColor;
    if (percent >= 100) {
      progressColor = Colors.green;
    } else if (percent >= 50) {
      progressColor = AppTheme.neonBlue;
    } else if (percent > 0) {
      progressColor = Colors.amber;
    } else {
      progressColor = Colors.grey;
    }

    return FadeSlideEntrance(
      key: key,
      delay: Duration.zero,
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: progressColor.withOpacity(0.3)),
        ),
        color: AppTheme.darkCard,
        child: Column(
          children: [
            // ── Header: ≡  ↓  plan_name  %XX  🗑 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.menu_rounded, color: Colors.grey, size: 22),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => provider.toggleExpanded(plan.id),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('↓',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Plan Status Cycle Icon
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => provider.cyclePlanStatus(plan.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Plan name + item count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white)),
                        Text(
                          plan.items.isEmpty
                              ? '$statusLabel • Alt görev yok'
                              : '${plan.items.length} alt görev • $statusLabel',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  // % badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: progressColor.withOpacity(0.4)),
                    ),
                    child: Text('%$percent',
                        style: TextStyle(
                            color: progressColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 8),

                  // Delete (with confirmation)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _confirmDeletePlan(context, provider, plan),
                  ),
                ],
              ),
            ),

            // Progress bar
            if (plan.items.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(left: 14, right: 14, bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100.0,
                    minHeight: 4,
                    color: progressColor,
                    backgroundColor: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),

            // Expanded items (Recursive Tree)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(height: 1, thickness: 1),
                  if (plan.items.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: plan.items.length,
                      onReorder: (oldIdx, newIdx) {
                        provider.reorderItemsRecursively(plan.id, null, oldIdx, newIdx);
                      },
                      itemBuilder: (ctx, index) {
                        final item = plan.items[index];
                        return _buildPlanItemTree(
                          ctx,
                          provider,
                          plan.id,
                          item,
                          1, // depth 1
                          index,
                          null,
                          key: ValueKey(item.id),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: GestureDetector(
                      onTap: () =>
                          _showAddPlanItemDialog(context, provider, plan.id),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.neonBlue.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.neonBlue.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: AppTheme.neonBlue, size: 18),
                            const SizedBox(width: 6),
                            Text('Alt Görev Ekle',
                                style: TextStyle(
                                    color: AppTheme.neonBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPlanItemDialog(
      BuildContext context, PlanProvider provider, String planId, {String? parentItemId}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Alt Görev Ekle',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Görev açıklaması...',
              hintStyle: TextStyle(color: Colors.grey)),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addItem(planId, ctrl.text.trim(), parentItemId: parentItemId);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonBlue),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItemTree(
      BuildContext context, PlanProvider provider, String planId, PlanItem item, int depth, int index, String? parentId, {required Key key}) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (item.status) {
      case 'done':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Tamamlandı';
        break;
      case 'doing':
        statusColor = Colors.amber;
        statusIcon = Icons.timelapse_rounded;
        statusLabel = 'Yapılıyor';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Bekliyor';
    }

    final double leftPadding = 14.0 + ((depth - 1) * 20.0);

    return Padding(
      key: key,
      padding: EdgeInsets.fromLTRB(leftPadding, 3, 14, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.menu_rounded, color: Colors.grey, size: 18),
                ),
              ),
              if (item.subItems.isNotEmpty)
                GestureDetector(
                  onTap: () => provider.toggleExpanded(item.id),
                  child: AnimatedRotation(
                    turns: provider.isExpanded(item.id) ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text('↓',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 30), // Alignment matching arrow space (width 24 + margin 6)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => provider.cycleItemStatus(planId, item.id),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => provider.cycleItemStatus(planId, item.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.text,
                          style: TextStyle(
                              color: item.isDone ? Colors.grey : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              decoration:
                                  item.isDone ? TextDecoration.lineThrough : null)),
                      Text(
                          item.subItems.isNotEmpty
                              ? '$statusLabel • %${item.completionPercent}'
                              : statusLabel,
                          style: TextStyle(
                              color: statusColor.withOpacity(0.8), fontSize: 9)),
                    ],
                  ),
                ),
              ),
              if (depth < 3)
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: Colors.cyan, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showAddPlanItemDialog(context, provider, planId, parentItemId: item.id),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.redAccent, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeletePlanItem(context, provider, planId, item),
              ),
            ]),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: item.subItems.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: item.subItems.length,
                      onReorder: (oldIdx, newIdx) {
                        provider.reorderItemsRecursively(planId, item.id, oldIdx, newIdx);
                      },
                      itemBuilder: (ctx, subIndex) {
                        final subItem = item.subItems[subIndex];
                        return _buildPlanItemTree(
                          ctx,
                          provider,
                          planId,
                          subItem,
                          depth + 1,
                          subIndex,
                          item.id,
                          key: ValueKey(subItem.id),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
            crossFadeState: provider.isExpanded(item.id)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  TAB 3: Kullanım Süreleri
  // ═══════════════════════════════════════════════
  Widget _buildUsageTab(BuildContext context, HabitProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appLimits = provider.appLimits;
    final usageSeconds = provider.appUsageSeconds;

    final List<Map<String, dynamic>> appData = [
      {
        'name': 'Smart Notebook',
        'seconds': usageSeconds['Smart Notebook'] ?? 0,
        'color': AppTheme.neonBlue,
        'icon': Icons.menu_book_rounded,
        'isRealtime': true,
      },
      {
        'name': 'Youtube',
        'seconds': usageSeconds['Youtube'] ?? 0,
        'color': Colors.red,
        'icon': Icons.play_circle_outline_rounded,
        'isRealtime': false,
      },
      {
        'name': 'WhatsApp',
        'seconds': usageSeconds['WhatsApp'] ?? 0,
        'color': Colors.green,
        'icon': Icons.chat_bubble_outline_rounded,
        'isRealtime': false,
      },
      {
        'name': 'Instagram',
        'seconds': usageSeconds['Instagram'] ?? 0,
        'color': Colors.purple,
        'icon': Icons.camera_alt_outlined,
        'isRealtime': false,
      },
      {
        'name': 'Diğer',
        'seconds': usageSeconds['Diğer'] ?? 0,
        'color': Colors.grey,
        'icon': Icons.more_horiz_rounded,
        'isRealtime': false,
      },
    ];

    final totalSecs = appData.fold<int>(0, (sum, a) => sum + (a['seconds'] as int));
    final totalHours = totalSecs ~/ 3600;
    final totalMins = (totalSecs % 3600) ~/ 60;
    final totalStr = totalHours > 0 ? '${totalHours}s ${totalMins}dk' : '${totalMins}dk';

    final maxMins = appData
        .map((a) => (a['seconds'] as int) ~/ 60)
        .fold<int>(1, (m, v) => v > m ? v : m);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── Header ──
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row — column to avoid overflow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Uygulama Kullanım Süreleri',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(children: [
                      // CANLI badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('CANLI',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  letterSpacing: 0.8)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      // Toplam badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.neonBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.query_stats_rounded,
                              size: 12, color: AppTheme.neonBlue),
                          const SizedBox(width: 4),
                          Text('Toplam: $totalStr',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.neonBlue)),
                        ]),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Smart Notebook kullanımı gerçek zamanlı izlenir.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // ── App rows ──
                Column(
                  children: appData.map((app) {
                    final name = app['name'] as String;
                    final secs = app['seconds'] as int;
                    final color = app['color'] as Color;
                    final icon = app['icon'] as IconData;
                    final isRealtime = app['isRealtime'] as bool;

                    final minutes = secs ~/ 60;
                    final remainSecs = secs % 60;
                    final timeStr = isRealtime
                        ? '${minutes}dk ${remainSecs}sn'
                        : '${minutes}dk';
                    final limit = appLimits[name] ?? 0;
                    final isExceeded = limit > 0 && minutes > limit;
                    final rate =
                        maxMins > 0 ? minutes / maxMins : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Name + realtime dot
                                  Expanded(
                                    child: Row(children: [
                                      Flexible(
                                        child: Text(name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white)),
                                      ),
                                      if (isRealtime) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 1)
                                            ],
                                          ),
                                        ),
                                      ],
                                    ]),
                                  ),
                                  // Time badge + edit icon
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isExceeded
                                              ? Colors.red.withOpacity(0.15)
                                              : color.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: isExceeded
                                                  ? Colors.red.withOpacity(0.5)
                                                  : color.withOpacity(0.5)),
                                        ),
                                        child: Text(timeStr,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isExceeded
                                                    ? Colors.red
                                                    : color)),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _showLimitDialog(
                                            context, provider, name),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withOpacity(0.07),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.edit_rounded,
                                              size: 14, color: Colors.white54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (limit > 0) ...[
                                const SizedBox(height: 3),
                                Text(
                                  isExceeded
                                      ? '⚠ Sınır aşıldı! (${limit}dk)'
                                      : 'Günlük sınır: ${limit}dk',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isExceeded
                                          ? Colors.red
                                          : Colors.grey),
                                ),
                              ],
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: rate.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade100,
                                  color: isExceeded ? Colors.red : color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLimitDialog(
      BuildContext context, HabitProvider provider, String appName) {
    final currentLimit = provider.appLimits[appName] ?? 0;
    final controller = TextEditingController(
        text: currentLimit > 0 ? '$currentLimit' : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$appName Sınırı'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Günlük limit (dakika)', suffixText: 'dk'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Sınırı Kaldır'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).then((val) {
      if (val != null && context.mounted) {
        provider.setAppLimit(appName, val as int);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(val > 0
              ? '$appName için ${val}dk sınır belirlendi.'
              : '$appName sınırı kaldırıldı.'),
          backgroundColor: Colors.green,
        ));
      }
    });
  }
}
