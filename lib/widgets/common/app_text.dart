import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

enum AppTextStyleType {
  displayLarge,
  headingLarge,
  headingMedium,
  headingSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  caption,
  label
}

class AppText extends StatelessWidget {
  final String text;
  final AppTextStyleType styleType;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? styleOverride;

  const AppText(
    this.text, {
    super.key,
    this.styleType = AppTextStyleType.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.styleOverride,
  });

  TextStyle _getTextStyle() {
    TextStyle baseStyle;
    switch (styleType) {
      case AppTextStyleType.displayLarge:
        baseStyle = AppTextStyles.displayLarge;
        break;
      case AppTextStyleType.headingLarge:
        baseStyle = AppTextStyles.headingLarge;
        break;
      case AppTextStyleType.headingMedium:
        baseStyle = AppTextStyles.headingMedium;
        break;
      case AppTextStyleType.headingSmall:
        baseStyle = AppTextStyles.headingSmall;
        break;
      case AppTextStyleType.bodyLarge:
        baseStyle = AppTextStyles.bodyLarge;
        break;
      case AppTextStyleType.bodyMedium:
        baseStyle = AppTextStyles.bodyMedium;
        break;
      case AppTextStyleType.bodySmall:
        baseStyle = AppTextStyles.bodySmall;
        break;
      case AppTextStyleType.caption:
        baseStyle = AppTextStyles.caption;
        break;
      case AppTextStyleType.label:
        baseStyle = AppTextStyles.label;
        break;
    }
    
    if (color != null) {
      baseStyle = baseStyle.copyWith(color: color);
    }
    if (styleOverride != null) {
      baseStyle = baseStyle.merge(styleOverride);
    }
    return baseStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _getTextStyle(),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
