import 'package:flutter/material.dart';
import '../../domain/models/book.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text.dart';
import 'bounce_button.dart';

/// A vertical "book spine" widget that looks like a real book standing on a shelf.
class BookCard extends StatelessWidget {
  final Book book;
  final int pageCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const BookCard({
    super.key,
    required this.book,
    required this.pageCount,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _parseColor(book.coverColor);
    final spineColor = accentColor;
    final darkSpine = HSLColor.fromColor(spineColor)
        .withLightness((HSLColor.fromColor(spineColor).lightness - 0.18).clamp(0.0, 1.0))
        .toColor();
    final lightSpine = HSLColor.fromColor(spineColor)
        .withLightness((HSLColor.fromColor(spineColor).lightness + 0.22).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: BounceButton(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Book body ──
              Expanded(
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(6),
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(4),
                    ),
                    gradient: LinearGradient(
                      colors: [darkSpine, spineColor, lightSpine, spineColor],
                      stops: const [0.0, 0.08, 0.92, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(4, 4),
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle top highlight (like a real book edge catching light)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      // Left dark edge (spine binding)
                      Positioned(
                        top: 0,
                        left: 0,
                        bottom: 0,
                        child: Container(
                          width: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      // Decorative horizontal lines (page edges at top)
                      Positioned(
                        top: 16,
                        left: 8,
                        right: 8,
                        child: Column(
                          children: List.generate(
                            3,
                            (i) => Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                      // Title text (rotated vertically)
                      Positioned.fill(
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Page count badge at bottom
                      Positioned(
                        bottom: 10,
                        left: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$pageCount s.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Book base (bottom thick edge) ──
              Container(
                height: 8,
                width: 76,
                decoration: BoxDecoration(
                  color: darkSpine,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final accentColor = _parseColor(book.coverColor);
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
                    width: 36,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          book.title,
                          styleType: AppTextStyleType.bodyLarge,
                          styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          '$pageCount sayfa',
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
              title: const AppText('Yeniden Adlandır', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              title: const AppText('Sil', styleType: AppTextStyleType.bodyMedium, color: Colors.redAccent),
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
