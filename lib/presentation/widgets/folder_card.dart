import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text.dart';
import 'bounce_button.dart';

/// A sleek folder card representing a book category/folder in the library grid
class FolderCard extends StatelessWidget {
  final String categoryName;
  final int bookCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const FolderCard({
    super.key,
    required this.categoryName,
    required this.bookCount,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFF59E0B); // Amber / Gold theme for folder cards

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: BounceButton(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Top Color Accent Bar (Amber gradient)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Folder Emblem & Menu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
                            ),
                            child: const Icon(
                              Icons.folder_special_rounded,
                              color: accentColor,
                              size: 26,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => _showContextMenu(context),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Folder Name
                      AppText(
                        categoryName,
                        styleType: AppTextStyleType.bodyLarge,
                        styleOverride: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Book Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 12, color: accentColor),
                            const SizedBox(width: 4),
                            AppText(
                              '$bookCount Kitap',
                              styleType: AppTextStyleType.caption,
                              styleOverride: const TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    const accentColor = Color(0xFFF59E0B);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppCard(
        margin: const EdgeInsets.all(12),
        borderColor: accentColor.withValues(alpha: 0.3),
        shadowColor: accentColor,
        borderRadius: 20,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_special_rounded, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          '$categoryName Klasörü',
                          styleType: AppTextStyleType.bodyLarge,
                          styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          '$bookCount kitap içeriyor',
                          styleType: AppTextStyleType.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: AppColors.glow),
              title: const AppText('Klasörü Yeniden Adlandır', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_delete_rounded, color: Colors.redAccent),
              title: const AppText('Klasörü Kaldır', styleType: AppTextStyleType.bodyMedium, color: Colors.redAccent),
              subtitle: const AppText('Kitaplar silinmez, klasör dışına çıkarılır.', styleType: AppTextStyleType.caption),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
