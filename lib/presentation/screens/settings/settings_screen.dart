import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';

// Import providers to reload them on restore
import '../../../application/providers/sync_provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/calendar_provider.dart';
import '../../../application/providers/note_provider.dart';
import '../../../application/providers/plan_provider.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/habit_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _refreshAllProviders(BuildContext context) {
    context.read<BookProvider>().loadBooks();
    context.read<CalendarProvider>().loadEvents();
    context.read<NoteProvider>().loadNotes();
    context.read<NoteProvider>().loadVoiceNotes();
    context.read<PlanProvider>().loadPlans();
    context.read<TaskProvider>().loadTasks();
    context.read<HabitProvider>().loadHabits();
  }

  Future<void> _showRestoreConfirmation(BuildContext context, SyncProvider syncProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.glow.withOpacity(0.3), width: 1),
        ),
        title: const AppText(
          'Yedekten Geri Yükle',
          styleType: AppTextStyleType.headingSmall,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const AppText(
          'Buluttaki verileriniz bu cihaza indirilecek ve mevcut tüm verilerinizin üzerine yazılacaktır. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
          styleType: AppTextStyleType.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('İptal', styleType: AppTextStyleType.label, color: Colors.grey),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Evet, Yükle', styleType: AppTextStyleType.label, color: Colors.redAccent),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await syncProvider.restoreFromCloud();
      if (context.mounted) {
        if (success) {
          _refreshAllProviders(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verileriniz başarıyla geri yüklendi!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncProvider.syncError ?? 'Geri yükleme başarısız oldu.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Widget _buildAvatarFallback(SyncProvider syncProvider) {
    final initials = syncProvider.currentUser?.displayName != null &&
            syncProvider.currentUser!.displayName!.isNotEmpty
        ? syncProvider.currentUser!.displayName!.substring(0, 1).toUpperCase()
        : 'U';
    return Container(
      color: AppColors.background,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();

    return AppContainer(
      hasGradient: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const AppText(
            'Ayarlar',
            styleType: AppTextStyleType.headingMedium,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          children: [
            // Cloud sync section header
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
              child: AppText(
                '☁️ BULUT SENKRONİZASYONU',
                styleType: AppTextStyleType.caption,
                styleOverride: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),
            ),

            // Cloud Sync status
            if (!syncProvider.isFirebaseAvailable) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: EdgeInsets.zero,
                borderColor: Colors.amber.withOpacity(0.3),
                shadowColor: Colors.amber,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppText(
                            'Yedekleme Devre Dışı',
                            styleType: AppTextStyleType.bodyMedium,
                            styleOverride: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppText(
                      'Uygulama yerel modda çalışıyor. Google hesabı ile bulut yedeklemeyi aktif etmek için Firebase yapılandırma dosyalarının (google-services.json) projeye eklenmesi gerekmektedir.',
                      styleType: AppTextStyleType.caption,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ] else if (syncProvider.currentUser == null) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: EdgeInsets.zero,
                borderColor: AppColors.glow.withOpacity(0.18),
                shadowColor: AppColors.glow,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: syncProvider.isSyncing
                      ? null
                      : () async {
                          final success = await syncProvider.signInWithGoogle();
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Google hesabınız başarıyla bağlandı!')),
                            );
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.glow.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: syncProvider.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF4285F4),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AppText(
                                'Google Hesabını Bağla',
                                styleType: AppTextStyleType.bodyMedium,
                                styleOverride: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              AppText(
                                'Verilerinizi buluta yedekleyin ve senkronize edin.',
                                styleType: AppTextStyleType.caption,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.glow),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: EdgeInsets.zero,
                borderColor: AppColors.glow.withOpacity(0.18),
                shadowColor: AppColors.glow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.glow, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.glow.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: syncProvider.currentUser?.photoURL != null
                                ? Image.network(
                                    syncProvider.currentUser!.photoURL!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildAvatarFallback(syncProvider),
                                  )
                                : _buildAvatarFallback(syncProvider),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                syncProvider.currentUser?.displayName ?? 'Google Kullanıcısı',
                                styleType: AppTextStyleType.bodyMedium,
                                styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                syncProvider.currentUser?.email ?? '',
                                styleType: AppTextStyleType.caption,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          tooltip: 'Bağlantıyı Kes',
                          onPressed: () async {
                            await syncProvider.signOut();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hesap bağlantısı kesildi.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AppText(
                          'Son Yedekleme:',
                          styleType: AppTextStyleType.caption,
                          color: Colors.grey,
                        ),
                        AppText(
                          syncProvider.lastBackupTime != null
                              ? _formatDateTime(syncProvider.lastBackupTime!)
                              : 'Hiç yedek alınmadı',
                          styleType: AppTextStyleType.caption,
                          styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                          color: AppColors.glow,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.glow.withOpacity(0.12),
                              foregroundColor: AppColors.glow,
                              side: BorderSide(color: AppColors.glow.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: syncProvider.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_outlined, size: 18),
                            label: const Text('Şimdi Yedekle'),
                            onPressed: syncProvider.isSyncing
                                ? null
                                : () async {
                                    final success = await syncProvider.backupToCloud();
                                    if (context.mounted) {
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Verileriniz başarıyla buluta yedeklendi!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(syncProvider.syncError ?? 'Yedekleme başarısız oldu.'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.06),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.12)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.cloud_download_outlined, size: 18),
                            label: const Text('Yedekten Yükle'),
                            onPressed: syncProvider.isSyncing ? null : () => _showRestoreConfirmation(context, syncProvider),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Theme info (read-only, navy default)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
              child: AppText(
                '🎨 TEMA',
                styleType: AppTextStyleType.caption,
                styleOverride: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderColor: AppColors.glow.withOpacity(0.18),
              shadowColor: AppColors.glow,
              child: ListTile(
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.textPrimary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                title: const AppText(
                  'Lacivert (Varsayılan)',
                  styleType: AppTextStyleType.bodyMedium,
                  styleOverride: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Icon(Icons.check_circle_rounded, color: AppColors.glow),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // About section
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
              child: AppText(
                'UYGULAMA HAKKINDA',
                styleType: AppTextStyleType.caption,
                styleOverride: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),
            ),

            AppCard(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderColor: AppColors.glow.withOpacity(0.18),
              shadowColor: AppColors.glow,
              child: ListTile(
                title: const AppText(
                  'Versiyon',
                  styleType: AppTextStyleType.headingSmall,
                  styleOverride: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: AppText(
                  '1.0.0',
                  styleType: AppTextStyleType.label,
                  color: AppColors.glow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
