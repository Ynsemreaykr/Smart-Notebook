import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/timer_provider.dart';
import '../../../application/providers/habit_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏱️ Pomodoro Hakkında'),
        content: const SingleChildScrollView(
          child: Text(
            'Pomodoro modülü, odaklanma sürelerinizi 25 dakikalık çalışma ve 5 dakikalık mola periyotlarıyla yönetmenize yardımcı olan bir zaman yönetim tekniğidir.\n\n'
            'Nasıl Çalışır?\n'
            '1. Alışkanlık Seç: Süreyi hangi alışkanlığınızla ilişkilendirmek istediğinizi açılır menüden seçin.\n'
            '2. Başlat: Büyük dairesel butona basarak seansı başlatın.\n'
            '3. Canlı Takip: Pomodoro seansını başlattıktan sonra, Planlayıcı timeline akışında (Gününü Planla) bu saate ait canlı bir odaklanma kartı belirecektir.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('⏱️ Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Bilgi',
            onPressed: _showInfoDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkCard, AppTheme.darkBg, AppTheme.darkBgDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Consumer2<TimerProvider, HabitProvider>(
          builder: (context, timerProvider, habitProvider, _) {
            final timerHabits = habitProvider.habits.where((h) => h.type == 'timer').toList();
            final isRunning = timerProvider.isRunning;
            final currentHabit = timerProvider.selectedHabit;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: FadeSlideEntrance(
                      delay: const Duration(milliseconds: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Habit selector / running label ──────────────────
                          if (isRunning)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppTheme.primaryGlow(intensity: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    currentHabit != null
                                        ? 'Odaklanılıyor: ${currentHabit.name}'
                                        : 'Pomodoro Süresi Devam Ediyor',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // Habit Selector Dropdown
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.darkCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.2)),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bu süreyi hangi alışkanlığa bağlamak istiyorsun?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: timerProvider.selectedHabitId,
                                      hint: Text(
                                        'Bir alışkanlık seçin (İsteğe bağlı)',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                      ),
                                      isExpanded: true,
                                      dropdownColor: AppTheme.darkCardHigh,
                                      style: TextStyle(color: AppTheme.textPrimary),
                                      onChanged: (val) => timerProvider.setSelectedHabitId(val),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('Bağlantı Yok'),
                                        ),
                                        ...timerHabits.map((h) => DropdownMenuItem<String?>(
                                              value: h.id,
                                              child: Text(h.name),
                                            )),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (!isRunning && timerHabits.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                              child: Text(
                                'İpucu: Sürenizi bir alışkanlığa kaydetmek için önce "Sayaç" türünde bir alışkanlık oluşturun.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted.withValues(alpha: 0.7),
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),

                          // ── Neon Glow Timer Dial ────────────────────────────
                          NeonPulseTimer(
                            isRunning: isRunning,
                            formattedTime: timerProvider.formattedTime,
                            progress: timerProvider.durationSeconds == 0
                                ? 0
                                : timerProvider.remainingSeconds / timerProvider.durationSeconds,
                          ),

                          const SizedBox(height: 36),

                          // ── Quick Presets ───────────────────────────────────
                          if (!isRunning)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildPresetChip(context, timerProvider, '5 dk', 5),
                                  _buildPresetChip(context, timerProvider, '15 dk', 15),
                                  _buildPresetChip(context, timerProvider, '25 dk', 25),
                                  _buildPresetChip(context, timerProvider, '50 dk', 50),
                                  _buildPresetChip(context, timerProvider, '60 dk', 60),
                                ],
                              ),
                            )
                          else
                            const SizedBox(height: 48),

                          const SizedBox(height: 28),

                          // ── Control Buttons ─────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Reset
                              BounceButton(
                                onTap: timerProvider.resetTimer,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.textMuted.withValues(alpha: 0.25),
                                    ),
                                    boxShadow: AppTheme.cardShadow,
                                  ),
                                  child: Icon(
                                    Icons.replay_rounded,
                                    size: 26,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),
                              // Play / Pause — Neon gradient button
                              BounceButton(
                                onTap: isRunning
                                    ? timerProvider.pauseTimer
                                    : timerProvider.startTimer,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: AppTheme.primaryGlow(intensity: isRunning ? 0.8 : 0.5),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(scale: animation, child: child),
                                    child: Icon(
                                      isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      key: ValueKey<bool>(isRunning),
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPresetChip(BuildContext context, TimerProvider timerProvider, String label, int minutes) {
    final isSelected = timerProvider.durationSeconds == minutes * 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: BounceButton(
        onTap: () => timerProvider.setDuration(minutes),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.neonBlue.withValues(alpha: 0.5)
                  : AppTheme.textMuted.withValues(alpha: 0.2),
            ),
            boxShadow: isSelected ? AppTheme.primaryGlow(intensity: 0.4) : AppTheme.cardShadow,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  Neon Glow Pulse Timer Widget
// ─────────────────────────────────────────────────

class NeonPulseTimer extends StatefulWidget {
  final bool isRunning;
  final String formattedTime;
  final double progress;

  const NeonPulseTimer({
    super.key,
    required this.isRunning,
    required this.formattedTime,
    required this.progress,
  });

  @override
  State<NeonPulseTimer> createState() => _NeonPulseTimerState();
}

class _NeonPulseTimerState extends State<NeonPulseTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _glowAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isRunning) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(NeonPulseTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.animateTo(0.0, duration: const Duration(milliseconds: 350));
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = _glowAnim.value;
        final scale = _scaleAnim.value;

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ambient glow layers (behind everything)
                if (widget.isRunning) ...[
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonBlue.withValues(alpha: glow * 0.35),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: AppTheme.neonPurple.withValues(alpha: glow * 0.20),
                          blurRadius: 80,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ],

                // Background track circle
                Container(
                  width: 248,
                  height: 248,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.darkCard,
                    border: Border.all(
                      color: AppTheme.textMuted.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                ),

                // Circular progress ring (neon blue)
                SizedBox(
                  width: 248,
                  height: 248,
                  child: CircularProgressIndicator(
                    value: widget.progress,
                    strokeWidth: 10,
                    backgroundColor: AppTheme.darkCardHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isRunning ? AppTheme.neonBlue : AppTheme.textMuted,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),

                // Timer text content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => (widget.isRunning
                              ? AppTheme.primaryGradient
                              : LinearGradient(
                                  colors: [AppTheme.textSecondary, AppTheme.textMuted],
                                ))
                          .createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        widget.formattedTime,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: widget.isRunning ? AppTheme.neonAccent : AppTheme.textMuted,
                      ),
                      child: const Text('POMODORO'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Keep old PulseWidget and TimerScreen class aliases for compatibility if needed
class PulseWidget extends StatelessWidget {
  final Widget child;
  final bool isRunning;
  const PulseWidget({super.key, required this.child, required this.isRunning});

  @override
  Widget build(BuildContext context) => child;
}
