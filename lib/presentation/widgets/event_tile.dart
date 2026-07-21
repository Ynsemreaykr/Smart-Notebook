import 'package:flutter/material.dart';
import '../../domain/models/event.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'fade_slide_entrance.dart';

class EventTile extends StatelessWidget {
  final CalendarEvent event;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const EventTile({
    super.key,
    required this.event,
    this.index = 0,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return FadeSlideEntrance(
      delay: Duration(milliseconds: index * 40),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textMuted.withValues(alpha: 0.12),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: AppTheme.neonBlue.withValues(alpha: 0.08),
          highlightColor: AppTheme.neonBlue.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Time indicator — neon blue box
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.neonBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.neonBlue.withValues(alpha: 0.30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonBlue.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 17,
                        color: AppTheme.neonAccent,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeFormat.format(event.dateTime),
                        style: TextStyle(
                          color: AppTheme.neonAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Event info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.description,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (event.linkedPageId != null) ...[
                            Icon(
                              Icons.link_rounded,
                              size: 13,
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Not bağlı',
                              style: TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (event.hasReminder) ...[
                            Icon(
                              Icons.notifications_active_rounded,
                              size: 13,
                              color: AppTheme.warningAmber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Hatırlatıcı',
                              style: TextStyle(
                                color: AppTheme.warningAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.textMuted.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
