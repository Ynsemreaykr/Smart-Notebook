import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../application/providers/calendar_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../theme/app_theme.dart';

import '../../../domain/models/event.dart';
import '../../widgets/event_tile.dart';
import '../../widgets/bounce_button.dart';

import '../notebook/page_editor_screen.dart';
import 'event_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
    });
  }

  void _onEventTap(CalendarEvent event) {
    if (event.linkedPageId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PageEditorScreen(pageId: event.linkedPageId!)),
      );
    } else {
      // Show event details
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(event.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.description.isNotEmpty) Text(event.description),
              const SizedBox(height: 8),
              Text('Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(event.dateTime)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              if (event.hasReminder && event.reminderTime != null)
                Text('Hatırlatıcı: ${DateFormat('dd.MM.yyyy HH:mm').format(event.reminderTime!)}', style: TextStyle(color: Colors.orange.shade600, fontSize: 13)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
    }
  }

  void _deleteEvent(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Etkinliği Sil'),
        content: Text('"${event.title}" silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CalendarProvider>().deleteEvent(event.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📅 Takvim Hakkında'),
        content: const SingleChildScrollView(
          child: Text(
            'Takvim modülü, günlerinizi planlamanızı ve önemli etkinliklerinizi zamanlamanızı kolaylaştırır.\n\n'
            'Nasıl Kullanılır?\n'
            '1. Gün Seç: Takvim üzerinden bir güne dokunun, o güne ait etkinlikleri altta listeleyin.\n'
            '2. Etkinlik Ekle: Sağ alttaki (+) butona basarak yeni randevu, etkinlik ve hatırlatıcı ekleyin.\n'
            '3. Defter Bağlantısı: Etkinlik oluştururken kütüphanenizdeki defter sayfalarını bağlayarak takvimden tek tıkla o sayfaya uçabilirsiniz.',
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 750;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Takvim'),
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
            colors: [AppTheme.darkCard, AppTheme.darkBg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer<CalendarProvider>(
          builder: (context, calProvider, _) {
            final calendarWidget = Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonBlue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                  ...AppTheme.cardShadow,
                ],
              ),
              child: TableCalendar<CalendarEvent>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: calProvider.focusedDay,
                selectedDayPredicate: (day) => isSameDay(calProvider.selectedDay, day),
                calendarFormat: _calendarFormat,
                eventLoader: calProvider.getEventsForDay,
                onDaySelected: (selected, focused) {
                  calProvider.setSelectedDay(selected);
                  calProvider.setFocusedDay(focused);
                },
                onFormatChanged: (format) => setState(() => _calendarFormat = format),
                onPageChanged: (focused) => calProvider.setFocusedDay(focused),
                locale: 'tr_TR',
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: AppTheme.textPrimary),
                  weekendTextStyle: TextStyle(color: AppTheme.neonAccent),
                  outsideTextStyle: TextStyle(color: AppTheme.textMuted),
                  todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.neonBlue, AppTheme.neonPurple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: const Color(0x553B82F6),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: AppTheme.neonBlue, width: 1.5)),
                  ),
                  markerDecoration: BoxDecoration(
                    color: AppTheme.neonAccent,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 5,
                  markersMaxCount: 3,
                  isTodayHighlighted: true,
                  tablePadding: const EdgeInsets.all(8),
                ),
                headerStyle: HeaderStyle(
                  formatButtonDecoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.neonBlue, AppTheme.neonPurple]),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  formatButtonTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppTheme.neonAccent),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppTheme.neonAccent),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(color: AppTheme.neonAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            );

            final eventsHeaderWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy', 'tr_TR').format(calProvider.selectedDay),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.neonBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      '${calProvider.selectedDayEvents.length} etkinlik',
                      style: TextStyle(color: AppTheme.neonAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );

            final eventsListWidget = calProvider.selectedDayEvents.isEmpty
                ? Center(
                    child: Text(
                      'Bu gün için etkinlik yok',
                      style: TextStyle(color: AppTheme.textMuted),
                    ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: calProvider.selectedDayEvents.length,
                    itemBuilder: (ctx, i) {
                      final event = calProvider.selectedDayEvents[i];
                      return EventTile(
                        event: event,
                        index: i,
                        onTap: () => _onEventTap(event),
                        onDelete: () => _deleteEvent(event),
                      );
                    },
                  );

            if (isTablet) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(child: calendarWidget),
                  ),
                  VerticalDivider(width: 1, color: AppTheme.textMuted.withValues(alpha: 0.15)),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        eventsHeaderWidget,
                        Divider(height: 1, color: AppTheme.textMuted.withValues(alpha: 0.15)),
                        Expanded(child: eventsListWidget),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  calendarWidget,
                  eventsHeaderWidget,
                  Divider(height: 1, color: AppTheme.textMuted.withValues(alpha: 0.15)),
                  Expanded(child: eventsListWidget),
                ],
              );
            }
          },
        ),
      ),
      floatingActionButton: BounceButton(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EventFormScreen())).then((_) {
            if (mounted) context.read<CalendarProvider>().loadEvents();
          });
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
      ),
    );
  }
}
