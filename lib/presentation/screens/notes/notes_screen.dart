import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/note_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/models/note.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteProvider>().loadNotes();
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A); // Navy blue-compatible cover color
    }
  }

  void _showCreateDialog() {
    context.read<NoteProvider>().addNote('').then((note) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => NoteEditorScreen(noteId: note.id),
      )).then((_) => context.read<NoteProvider>().loadNotes());
    });
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText(
          'Notu Sil',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: AppText('"${note.title}" silinecek. Emin misiniz?', styleType: AppTextStyleType.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<NoteProvider>().deleteNote(note.id);
            },
            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _setReminder(Note note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppText(
                  'Hatırlatıcı Seçenekleri',
                  styleType: AppTextStyleType.headingSmall,
                  styleOverride: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(Icons.timer, color: AppColors.glow),
                title: const AppText('1 Saat Sonra', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveReminder(note.id, DateTime.now().add(const Duration(hours: 1)));
                },
              ),
              ListTile(
                leading: Icon(Icons.today, color: AppColors.accent),
                title: const AppText('1 Gün Sonra', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveReminder(note.id, DateTime.now().add(const Duration(days: 1)));
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_calendar, color: AppColors.primary),
                title: const AppText('Özel Zaman Seç...', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomReminder(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickCustomReminder(Note note) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: note.reminderTime ?? DateTime.now().add(const Duration(minutes: 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(note.reminderTime ?? DateTime.now().add(const Duration(minutes: 5))),
        initialEntryMode: TimePickerEntryMode.dial,
      );
      if (pickedTime != null && mounted) {
        final reminderDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _saveReminder(note.id, reminderDateTime);
      }
    }
  }

  void _saveReminder(String noteId, DateTime dt) async {
    await context.read<NoteProvider>().setReminder(noteId, dt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hatırlatıcı kuruldu: ${dt.toString().substring(0, 16)}')),
      );
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(
          '📝 Not Defteri Hakkında',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: AppText(
            'Not Defteri modülü, günlük yapacağınız listeleri, fikirleri ve hatırlatıcıları pratik ve hızlıca kaydetmenize yarayan bir araçtır.\n\n'
            'Nasıl Kullanılır?\n'
            '1. Not Ekle: Sağ alttaki (+) butona basarak yeni bir not yazın.\n'
            '2. Hatırlatıcı Kur: Her notun altındaki saat simgesine tıklayarak alarm veya bildirim kurabilirsiniz.\n'
            '3. Sil: İhtiyacınız kalmayan notları çöp kutusu simgesiyle silebilirsiniz.',
            styleType: AppTextStyleType.bodyMedium,
            styleOverride: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText('Kapat', styleType: AppTextStyleType.label, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 650;

    return AppContainer(
      hasGradient: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const AppText(
            '📝 Notlar',
            styleType: AppTextStyleType.headingMedium,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Bilgi',
              onPressed: _showInfoDialog,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: Consumer<NoteProvider>(
          builder: (context, noteProvider, _) {
            if (noteProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (noteProvider.notes.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.sticky_note_2_outlined,
                title: 'Henüz not yok',
                subtitle: 'Hızlı notlar oluşturmaya başlayın',
                actionLabel: 'Not Oluştur',
                onAction: _showCreateDialog,
              );
            }

            Widget buildNoteCard(Note note, int index) {
              final color = _parseColor(note.color);
              return FadeSlideEntrance(
                delay: Duration(milliseconds: index * 40),
                child: BounceButton(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(noteId: note.id),
                    )).then((_) => context.read<NoteProvider>().loadNotes());
                  },
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    borderColor: color.withOpacity(0.22),
                    shadowColor: color,
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                note.title.isEmpty ? 'Yeni Not' : note.title,
                                styleType: AppTextStyleType.headingSmall,
                                styleOverride: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: note.title.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              AppText(
                                note.content.isEmpty ? 'Boş not' : note.content,
                                styleType: AppTextStyleType.bodySmall,
                                color: AppColors.textSecondary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppText(
                                _formatDate(note.updatedAt),
                                styleType: AppTextStyleType.caption,
                                color: AppColors.textMuted.withOpacity(0.8),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            note.reminderTime != null ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                            color: note.reminderTime != null ? AppColors.warning : AppColors.textMuted.withOpacity(0.5),
                            size: 22,
                          ),
                          onPressed: () => _setReminder(note),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: AppColors.textMuted.withOpacity(0.5), size: 22),
                          onPressed: () => _deleteNote(note),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (isTablet) {
              final int crossAxisCount = screenWidth > 950 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 2.1,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: noteProvider.notes.length,
                itemBuilder: (context, index) => buildNoteCard(noteProvider.notes[index], index),
              );
            } else {
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: noteProvider.notes.length,
                itemBuilder: (context, index) => buildNoteCard(noteProvider.notes[index], index),
              );
            }
          },
      ),
      floatingActionButton: BounceButton(
        onTap: _showCreateDialog,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: AppColors.glowShadow(intensity: 0.6),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    ),
  );
}

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
