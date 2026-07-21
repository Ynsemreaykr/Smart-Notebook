import 'package:flutter/material.dart';
import '../../domain/models/page.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text.dart';
import 'fade_slide_entrance.dart';

class PageTile extends StatelessWidget {
  final NotePage page;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onShareAsPdf;
  final VoidCallback onSetReminder;

  const PageTile({
    super.key,
    required this.page,
    required this.index,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
    required this.onShareAsPdf,
    required this.onSetReminder,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = page.isAdvanced ? AppColors.accent : AppColors.primary;

    return FadeSlideEntrance(
      delay: Duration(milliseconds: index * 40),
      child: Dismissible(
        key: Key(page.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => onDelete(),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const AppText('Sayfayı Sil', styleType: AppTextStyleType.headingMedium, styleOverride: TextStyle(fontWeight: FontWeight.bold)),
              content: AppText('"${page.title}" silinecek. Emin misiniz?', styleType: AppTextStyleType.bodyMedium),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
                ),
              ],
            ),
          );
        },
        child: AppCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          backgroundColor: AppColors.surface,
          borderRadius: 16,
          borderColor: isSelected
              ? AppColors.primary.withValues(alpha: 0.7)
              : AppColors.textMuted.withValues(alpha: 0.12),
          shadowColor: isSelected ? AppColors.primary : Colors.transparent,
          shadowActive: true,
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: Center(
                child: isSelected
                    ? Icon(Icons.check, color: AppColors.primary, size: 20)
                    : Icon(
                        page.isAdvanced ? Icons.brush : Icons.text_snippet,
                        color: iconColor,
                        size: 18,
                      ),
              ),
            ),
            title: AppText(
              page.title,
              styleType: AppTextStyleType.bodyMedium,
              styleOverride: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: AppText(
              page.content.isEmpty
                  ? (page.isAdvanced ? 'Gelişmiş çizim sayfası' : 'Boş sayfa')
                  : page.content.length > 60
                      ? '${page.content.substring(0, 60)}...'
                      : page.content,
              styleType: AppTextStyleType.bodySmall,
              color: AppColors.textSecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                    color: AppColors.surfaceLighter,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const AppText('Sayfayı Sil', styleType: AppTextStyleType.headingMedium, styleOverride: TextStyle(fontWeight: FontWeight.bold)),
                            content: AppText('"${page.title}" silinecek. Emin misiniz?', styleType: AppTextStyleType.bodyMedium),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) onDelete();
                      } else if (value == 'pdf') {
                        onShareAsPdf();
                      } else if (value == 'reminder') {
                        onSetReminder();
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'pdf',
                        child: ListTile(
                          leading: Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                          title: AppText('PDF Olarak Paylaş', styleType: AppTextStyleType.bodyMedium),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'reminder',
                        child: ListTile(
                          leading: Icon(Icons.notifications_active, color: Colors.amber),
                          title: AppText('Hatırlatıcı Kur', styleType: AppTextStyleType.bodyMedium),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.redAccent),
                          title: AppText('Sil', styleType: AppTextStyleType.bodyMedium, color: Colors.redAccent),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }
}
