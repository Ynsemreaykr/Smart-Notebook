import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Horizontal spacings (width helper)
  static const SizedBox gapWXs = SizedBox(width: xs);
  static const SizedBox gapWSm = SizedBox(width: sm);
  static const SizedBox gapWMd = SizedBox(width: md);
  static const SizedBox gapWLg = SizedBox(width: lg);
  static const SizedBox gapWXl = SizedBox(width: xl);
  static const SizedBox gapWXxl = SizedBox(width: xxl);

  // Vertical spacings (height helper)
  static const SizedBox gapHXs = SizedBox(height: xs);
  static const SizedBox gapHSm = SizedBox(height: sm);
  static const SizedBox gapHMd = SizedBox(height: md);
  static const SizedBox gapHLg = SizedBox(height: lg);
  static const SizedBox gapHXl = SizedBox(height: xl);
  static const SizedBox gapHXxl = SizedBox(height: xxl);

  // Padding EdgeInsets templates
  static const EdgeInsets pAllXs = EdgeInsets.all(xs);
  static const EdgeInsets pAllSm = EdgeInsets.all(sm);
  static const EdgeInsets pAllMd = EdgeInsets.all(md);
  static const EdgeInsets pAllLg = EdgeInsets.all(lg);
  static const EdgeInsets pAllXl = EdgeInsets.all(xl);

  static const EdgeInsets pxSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets pxMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets pxLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pxXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets pySm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets pyMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets pyLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets pyXl = EdgeInsets.symmetric(vertical: xl);
}
