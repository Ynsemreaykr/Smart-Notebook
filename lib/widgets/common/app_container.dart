import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppContainer extends StatelessWidget {
  final Widget child;
  final bool hasGradient;
  final bool useSafeArea;
  final EdgeInsetsGeometry? padding;

  const AppContainer({
    super.key,
    required this.child,
    this.hasGradient = true,
    this.useSafeArea = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget containerBody = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (useSafeArea) {
      containerBody = SafeArea(child: containerBody);
    }

    if (hasGradient) {
      containerBody = Container(
        decoration: BoxDecoration(
          gradient: AppColors.bgGradient,
        ),
        child: containerBody,
      );
    } else {
      containerBody = Container(
        color: AppColors.background,
        child: containerBody,
      );
    }

    return containerBody;
  }
}
