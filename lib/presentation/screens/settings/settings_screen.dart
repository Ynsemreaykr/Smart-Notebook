import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
import '../../../application/providers/photo_note_provider.dart';

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
    context.read<PhotoNoteProvider>().loadPhotoNotes();
  }

  Future<void> _runSyncWithProgressDialog({
    required BuildContext context,
    required SyncProvider syncProvider,
    required bool isRestore,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Consumer<SyncProvider>(
          builder: (context, sync, child) {
            final progressText = sync.imageProgress.isNotEmpty
                ? sync.imageProgress
                : (isRestore ? 'Verileriniz buluttan indiriliyor...' : 'Verileriniz buluta yedekleniyor...');

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppTheme.neonBlue.withValues(alpha: 0.4), width: 1.5),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.neonBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRestore ? Icons.cloud_download_rounded : Icons.cloud_upload_rounded,
                        size: 36,
                        color: AppTheme.neonBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isRestore ? 'Yedekten Geri Yükleniyor' : 'Buluta Yedekleniyor',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      progressText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neonBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonBlue),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Lütfen işlem tamamlanana kadar uygulamayı kapatmayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final success = isRestore
        ? await syncProvider.restoreFromCloud()
        : await syncProvider.backupToCloud();

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (context.mounted) {
      if (success) {
        if (isRestore) _refreshAllProviders(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRestore ? 'Verileriniz başarıyla geri yüklendi!' : 'Verileriniz başarıyla buluta yedeklendi!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncProvider.syncError ?? (isRestore ? 'Geri yükleme başarısız oldu.' : 'Yedekleme başarısız oldu.')),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
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

    if (confirmed == true && context.mounted) {
      await _runSyncWithProgressDialog(
        context: context,
        syncProvider: syncProvider,
        isRestore: true,
      );
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

  Future<void> _showEmailAuthDialog(BuildContext context, SyncProvider syncProvider) async {
    bool isLogin = true;
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? errorMsg;
    bool isLoading = false;
    bool obscurePass = true;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.orangeAccent.withOpacity(0.4), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.email_outlined, color: Colors.orangeAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isLogin ? 'E-posta ile Giriş' : 'Yeni Hesap Oluştur',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sekme seçici
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() { isLogin = true; errorMsg = null; }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isLogin ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isLogin ? Border.all(color: Colors.orangeAccent.withOpacity(0.6)) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      color: isLogin ? Colors.orangeAccent : Colors.grey,
                                      fontWeight: isLogin ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() { isLogin = false; errorMsg = null; }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: !isLogin ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: !isLogin ? Border.all(color: Colors.orangeAccent.withOpacity(0.6)) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Kayıt Ol',
                                    style: TextStyle(
                                      color: !isLogin ? Colors.orangeAccent : Colors.grey,
                                      fontWeight: !isLogin ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // E-posta alanı
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'E-posta',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.orangeAccent, size: 18),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.orangeAccent),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Şifre alanı
                    TextField(
                      controller: passCtrl,
                      obscureText: obscurePass,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 18,
                          ),
                          onPressed: () => setState(() => obscurePass = !obscurePass),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.orangeAccent),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                    ),

                    // Hata mesajı
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Giriş/Kayıt butonu
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent.withOpacity(0.85),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() { isLoading = true; errorMsg = null; });
                              String? err;
                              if (isLogin) {
                                err = await syncProvider.signInWithEmail(emailCtrl.text, passCtrl.text);
                              } else {
                                err = await syncProvider.registerWithEmail(emailCtrl.text, passCtrl.text);
                              }
                              setState(() { isLoading = false; errorMsg = err; });
                              if (err == null && ctx.mounted) {
                                Navigator.of(dialogCtx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isLogin ? 'Başarıyla giriş yapıldı!' : 'Hesabınız oluşturuldu!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),

                    // Şifremi unuttum
                    if (isLogin) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (emailCtrl.text.trim().isEmpty) {
                                  setState(() => errorMsg = 'Lütfen önce e-posta adresinizi girin.');
                                  return;
                                }
                                final err = await syncProvider.resetPassword(emailCtrl.text);
                                setState(() => errorMsg = err);
                                if (err == null && ctx.mounted) {
                                  setState(() => errorMsg = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Şifre sıfırlama e-postası gönderildi!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          'Şifremi Unuttum',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
              // Google Sign In card
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
                                'Telefon ve Google Play Services gerektiren cihazlar için.',
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
              const SizedBox(height: AppSpacing.sm),
              // Email/Password Sign In card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: EdgeInsets.zero,
                borderColor: Colors.orangeAccent.withOpacity(0.3),
                shadowColor: Colors.orangeAccent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: syncProvider.isSyncing
                      ? null
                      : () => _showEmailAuthDialog(context, syncProvider),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                          ),
                          child: const Center(
                            child: Icon(Icons.email_outlined, color: Colors.orangeAccent, size: 20),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'E-posta ile Giriş Yap',
                                styleType: AppTextStyleType.bodyMedium,
                                styleOverride: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              AppText(
                                'Huawei ve Google Play Services olmayan cihazlar için.',
                                styleType: AppTextStyleType.caption,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.orangeAccent),
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
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF14B8A6),
                          side: const BorderSide(color: Color(0xFF14B8A6), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        ),
                        icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                        label: const Text('Görsel Yedeği İçin Google Drive İznini Bağla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final success = await syncProvider.signInWithGoogle();
                          if (context.mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Google Drive izni başarıyla bağlandı!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else if (syncProvider.syncError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(syncProvider.syncError!),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText(
                              'Son Yedekleme Tarihi:',
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
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText(
                              'Yedekleyen Cihaz:',
                              styleType: AppTextStyleType.caption,
                              color: Colors.grey,
                            ),
                            AppText(
                              syncProvider.lastBackupDevice != null && syncProvider.lastBackupDevice!.isNotEmpty
                                  ? syncProvider.lastBackupDevice!
                                  : (syncProvider.lastBackupTime != null ? 'Bilinmeyen Cihaz' : '-'),
                              styleType: AppTextStyleType.caption,
                              styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                              color: const Color(0xFF14B8A6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText(
                              'Drive Bulut Klasörü:',
                              styleType: AppTextStyleType.caption,
                              color: Colors.grey,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final url = syncProvider.driveFolderUrl ?? 'https://drive.google.com/';
                                  final uri = Uri.parse(url);
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (e) {
                                    debugPrint('Launch Drive URL error: $e');
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(Icons.folder_open_rounded, size: 14, color: Color(0xFF38BDF8)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Google Drive / SmartNotebook_Backups',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF38BDF8),
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (syncProvider.isSyncing && syncProvider.imageProgress.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppText(
                              syncProvider.imageProgress,
                              styleType: AppTextStyleType.caption,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                                    await _runSyncWithProgressDialog(
                                      context: context,
                                      syncProvider: syncProvider,
                                      isRestore: false,
                                    );
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
