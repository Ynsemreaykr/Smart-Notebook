import 'package:flutter/material.dart';
import '../../application/providers/theme_provider.dart';
import 'app_theme.dart';

class AppColors {
  static ThemeModel get _current => ThemeProvider.activeTheme;

  static Color get primary => _current.primary;
  static Color get accent => _current.accent;
  static Color get background => _current.background;
  static Color get surface => _current.card;
  static Color get surfaceLighter => _current.cardLighter;
  static Color get textPrimary {
    final bg = background;
    final double luminance = bg.computeLuminance();
    if (luminance > 0.5) {
      return const Color(0xFF0F172A); // Göz yormayan koyu gri (Açık temada)
    } else {
      return const Color(0xFFF1F5F9); // Yumuşak kirli beyaz (Koyu temada)
    }
  }

  static Color get textSecondary {
    final bg = background;
    final double luminance = bg.computeLuminance();
    if (luminance > 0.5) {
      return const Color(0xFF475569); // İkincil koyu gri
    } else {
      return const Color(0xFF94A3B8); // Yumuşak ikincil açık mavi-gri
    }
  }

  static Color get textMuted {
    final bg = background;
    final double luminance = bg.computeLuminance();
    if (luminance > 0.5) {
      return const Color(0xFF94A3B8); // Pasif gri
    } else {
      return const Color(0xFF475569); // Koyu pasif gri
    }
  }
  static Color get error => _current.error;
  static Color get success => _current.success;
  static Color get warning => _current.warning;
  static Color get glow => _current.glow;

  // Compatibility getters for legacy code
  static Color get backgroundColor => background;
  static Color get cardColor => surface;
  static Color get primaryColor => primary;
  static Color get accentColor => accent;
  static Color get glowColor => glow;

  // Gradients
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient get headerGradient => LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get bgGradient => LinearGradient(
    colors: [surface, background, background],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glow shadows
  static List<BoxShadow> glowShadow({double intensity = 0.5}) => [
    BoxShadow(
      color: primary.withOpacity(intensity * 0.15),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(_current.isLight ? 0.06 : 0.35),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
