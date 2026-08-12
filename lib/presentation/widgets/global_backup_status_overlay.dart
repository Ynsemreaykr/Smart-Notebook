import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/providers/sync_provider.dart';

class GlobalBackupStatusOverlay extends StatefulWidget {
  final Widget child;

  const GlobalBackupStatusOverlay({super.key, required this.child});

  @override
  State<GlobalBackupStatusOverlay> createState() => _GlobalBackupStatusOverlayState();
}

class _GlobalBackupStatusOverlayState extends State<GlobalBackupStatusOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        Consumer<SyncProvider>(
          builder: (context, sync, _) {
            final status = sync.backupStatus;
            final isVisible = status != BackupStatus.idle;
            final isRunning = status == BackupStatus.running;
            final isCompleted = status == BackupStatus.completed;
            final isError = status == BackupStatus.error;

            if (!isVisible) return const SizedBox.shrink();

            final topPadding = MediaQuery.of(context).padding.top;
            final message = sync.backupStatusMessage ??
                (isCompleted
                    ? 'Yedekleme işlemi tamamlandı'
                    : isError
                        ? 'Yedekleme başarısız oldu'
                        : 'Yedekleme yapılıyor...');

            return Stack(
              children: [
                // Top-Right Small Square Status Indicator (Küçük Kare İçinde Işık)
                Positioned(
                  top: topPadding + 10,
                  right: 14,
                  child: SafeArea(
                    top: false,
                    child: Material(
                      type: MaterialType.transparency,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isVisible ? 1.0 : 0.0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : isError
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: isRunning
                                ? AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: _pulseAnimation.value),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                              .withValues(alpha: 0.8),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: isCompleted
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 9)
                                        : null,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Floating Notification Toast (Ekran Altında Uyarı Mesajı)
                if (isCompleted || isError)
                  Positioned(
                    bottom: 28,
                    left: 20,
                    right: 20,
                    child: SafeArea(
                      child: Material(
                        type: MaterialType.transparency,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: (isCompleted || isError) ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: (isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                        .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check_circle_rounded : Icons.error_rounded,
                                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
