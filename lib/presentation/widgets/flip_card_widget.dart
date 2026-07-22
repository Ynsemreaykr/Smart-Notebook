import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/flashcard.dart';
import '../../core/constants/app_radius.dart';
import '../../widgets/common/app_text.dart';
import '../../widgets/common/app_card.dart';

class FlipCardWidget extends StatefulWidget {
  final Flashcard flashcard;
  final VoidCallback? onOptionsTap;

  const FlipCardWidget({
    super.key,
    required this.flashcard,
    this.onOptionsTap,
  });

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF14B8A6);
    }
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(widget.flashcard.color);

    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 3D Perspective
            ..rotateY(angle);

          final isBackFacing = angle > (math.pi / 2);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBackFacing
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildCardSide(
                      titleBadge: 'ARKA YÜZ • AÇIKLAMA',
                      text: widget.flashcard.backText,
                      isFront: false,
                      color: themeColor,
                    ),
                  )
                : _buildCardSide(
                    titleBadge: 'ÖN YÜZ • KAVRAM',
                    text: widget.flashcard.frontText,
                    isFront: true,
                    color: themeColor,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardSide({
    required String titleBadge,
    required String text,
    required bool isFront,
    required Color color,
  }) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      borderColor: isFront ? color.withOpacity(0.4) : const Color(0xFF14B8A6),
      shadowColor: color,
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.medium - 1),
          gradient: LinearGradient(
            colors: isFront
                ? [
                    color.withOpacity(0.90),
                    color.withOpacity(0.65),
                  ]
                : [
                    const Color(0xFF0F766E),
                    const Color(0xFF14B8A6).withOpacity(0.85),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Top Badge
            Positioned(
              top: 0,
              left: 0,
              child: Row(
                children: [
                  Icon(
                    isFront ? Icons.flip_to_back_rounded : Icons.flip_to_front_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  AppText(
                    titleBadge,
                    styleType: AppTextStyleType.caption,
                    styleOverride: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Options menu (3 dots)
            if (widget.onOptionsTap != null)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: widget.onOptionsTap,
                  ),
                ),
              ),

            // Content Center
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                child: AppText(
                  text,
                  styleType: isFront ? AppTextStyleType.bodyLarge : AppTextStyleType.bodyMedium,
                  styleOverride: TextStyle(
                    color: Colors.white,
                    fontWeight: isFront ? FontWeight.bold : FontWeight.normal,
                    fontSize: isFront ? 16 : 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Bottom flip hint
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(
                children: const [
                  AppText(
                    'Çevir 🔄',
                    styleType: AppTextStyleType.caption,
                    styleOverride: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
