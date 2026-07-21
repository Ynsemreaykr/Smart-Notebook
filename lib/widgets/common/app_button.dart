import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height = 52.0,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      _pressController.reverse();
      if (widget.onTap != null) widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled && !widget.isLoading) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    BorderSide? border;

    if (widget.isDisabled) {
      bgColor = isDark ? Colors.white12 : Colors.black12;
      fgColor = isDark ? Colors.white38 : Colors.black38;
    } else {
      if (isPrimary) {
        bgColor = AppColors.primary;
        fgColor = theme.colorScheme.onPrimary;
      } else {
        bgColor = Colors.transparent;
        fgColor = AppColors.glow;
        border = BorderSide(color: AppColors.glow, width: 1.5);
      }
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: border != null ? Border.fromBorderSide(border) : null,
            boxShadow: (isPrimary && !widget.isDisabled && !widget.isLoading)
                ? AppColors.glowShadow(intensity: 0.5)
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: fgColor, size: 20),
                        AppSpacing.gapWSm,
                      ],
                      Text(
                        widget.label,
                        style: AppTextStyles.label.copyWith(color: fgColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
