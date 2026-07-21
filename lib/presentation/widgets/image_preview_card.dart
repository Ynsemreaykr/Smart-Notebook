import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ImagePreviewCard extends StatelessWidget {
  final File imageFile;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onOcr;

  const ImagePreviewCard({
    super.key,
    required this.imageFile,
    required this.index,
    required this.onRemove,
    this.onOcr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.15)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: Image.file(
                imageFile,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.broken_image, size: 48, color: AppTheme.textMuted),
                ),
              ),
            ),
          ),
          // Actions footer — dark surface
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.darkCardHigh,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sayfa ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onOcr != null)
                      IconButton(
                        icon: const Icon(Icons.text_fields_rounded, size: 20),
                        tooltip: 'OCR',
                        onPressed: onOcr,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        color: AppTheme.neonAccent,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Kaldır',
                      onPressed: onRemove,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      color: AppTheme.errorRed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
