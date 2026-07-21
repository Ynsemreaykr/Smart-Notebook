import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final bool borderActive;
  final Color? borderColor;
  final bool shadowActive;
  final Color? shadowColor;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.borderActive = true,
    this.borderColor,
    this.shadowActive = true,
    this.shadowColor,
    this.onTap,
    this.backgroundColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final activeBgColor = backgroundColor ?? AppColors.surface;
    final activeRadius = borderRadius ?? AppRadius.large;
    final borderCol = borderColor ?? AppColors.textMuted.withOpacity(0.12);
    final activeShadowColor = shadowColor ?? AppColors.primary;

    Widget cardWidget = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: gradient != null ? null : activeBgColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(activeRadius),
        border: borderActive
            ? Border.all(color: borderCol, width: 1.0)
            : null,
        boxShadow: shadowActive
            ? [
                BoxShadow(
                  color: activeShadowColor.withOpacity(0.06),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                ...AppColors.cardShadow,
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(activeRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      cardWidget = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
