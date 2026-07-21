import 'package:flutter/material.dart';
import '../../application/providers/theme_provider.dart';
import 'app_colors.dart';

class ThemeModel {
  final String name;
  final Color background;
  final Color card;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color cardLighter;
  final Color glow;
  final Color error;
  final Color success;
  final Color warning;
  final bool isLight;

  ThemeModel({
    required this.name,
    required this.background,
    required this.card,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.cardLighter,
    required this.glow,
    required this.error,
    required this.success,
    required this.warning,
    required this.isLight,
  });
}

class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.03, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

class AppTheme {
  // Predefined Themes
  static final navyTheme = ThemeModel(
    name: 'lacivert',
    background: const Color(0xFF0F172A),
    card: const Color(0xFF1E293B),
    primary: const Color(0xFF5B8BF7),
    accent: const Color(0xFF818CF8),
    textPrimary: const Color(0xFFF1F5F9),
    textSecondary: const Color(0xFF94A3B8),
    textMuted: const Color(0xFF475569),
    cardLighter: const Color(0xFF334155),
    glow: const Color(0xFF93C5FD),
    error: const Color(0xFFEF4444),
    success: const Color(0xFF22C55E),
    warning: const Color(0xFFF59E0B),
    isLight: false,
  );

  static final purpleTheme = ThemeModel(
    name: 'mor',
    background: const Color(0xFF1E1B4B),
    card: const Color(0xFF2E2A67),
    primary: const Color(0xFFA78BFA),
    accent: const Color(0xFFF472B6),
    textPrimary: const Color(0xFFF5F3FF),
    textSecondary: const Color(0xFFC7D2FE),
    textMuted: const Color(0xFF6366F1),
    cardLighter: const Color(0xFF4338CA),
    glow: const Color(0xFFC7D2FE),
    error: const Color(0xFFEF4444),
    success: const Color(0xFF22C55E),
    warning: const Color(0xFFF59E0B),
    isLight: false,
  );

  static final greenTheme = ThemeModel(
    name: 'yesil',
    background: const Color(0xFF0F291E),
    card: const Color(0xFF1E3F2F),
    primary: const Color(0xFF52B788),
    accent: const Color(0xFF64A6BD),
    textPrimary: const Color(0xFFF2F9F5),
    textSecondary: const Color(0xFFB7E4C7),
    textMuted: const Color(0xFF40916C),
    cardLighter: const Color(0xFF2D6A4F),
    glow: const Color(0xFFD8F3DC),
    error: const Color(0xFFEF4444),
    success: const Color(0xFF22C55E),
    warning: const Color(0xFFF59E0B),
    isLight: false,
  );

  static final lightTheme = ThemeModel(
    name: 'acik',
    background: const Color(0xFFF8FAFC),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF3B82F6),
    accent: const Color(0xFF6366F1),
    textPrimary: const Color(0xFF0F172A),
    textSecondary: const Color(0xFF475569),
    textMuted: const Color(0xFF94A3B8),
    cardLighter: const Color(0xFFF1F5F9),
    glow: const Color(0xFF93C5FD),
    error: const Color(0xFFDC2626),
    success: const Color(0xFF16A34A),
    warning: const Color(0xFFD97706),
    isLight: true,
  );

  static ThemeModel get currentTheme => ThemeProvider.activeTheme;

  // Compatibility fields pointing to active ThemeModel
  static Color get darkBg       => currentTheme.background;
  static Color get darkBgDeep   => currentTheme.background;
  static Color get darkCard     => currentTheme.card;
  static Color get darkCardHigh => currentTheme.cardLighter;

  static Color get neonBlue     => currentTheme.primary;
  static Color get neonPurple   => currentTheme.accent;
  static Color get neonAccent   => currentTheme.glow;

  static Color get textPrimary   => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textMuted     => AppColors.textMuted;

  static Color get errorRed     => currentTheme.error;
  static Color get successGreen => currentTheme.success;
  static Color get warningAmber => currentTheme.warning;

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [neonBlue, neonPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient get headerGradient => LinearGradient(
    colors: [darkCard, darkBg],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get bgGradient => LinearGradient(
    colors: [darkCard, darkBg, darkBg],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> neonBlueGlow({double intensity = 0.5}) => [
    BoxShadow(
      color: neonBlue.withOpacity(intensity * 0.15),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> neonPurpleGlow({double intensity = 0.5}) => [
    BoxShadow(
      color: neonPurple.withOpacity(intensity * 0.15),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> primaryGlow({double intensity = 0.6}) => [
    BoxShadow(
      color: neonBlue.withOpacity(intensity * 0.15),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(currentTheme.isLight ? 0.06 : 0.35),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get lightThemeData => _buildTheme(lightTheme);
  static ThemeData get darkThemeData => _buildTheme(navyTheme);
  static ThemeData get activeThemeData => _buildTheme(currentTheme);

  static ThemeData _buildTheme(ThemeModel theme) {
    return ThemeData(
      useMaterial3: true,
      brightness: theme.isLight ? Brightness.light : Brightness.dark,

      colorScheme: ColorScheme(
        brightness: theme.isLight ? Brightness.light : Brightness.dark,
        primary:          theme.primary,
        onPrimary:        theme.isLight ? Colors.white : Colors.black,
        secondary:        theme.accent,
        onSecondary:      Colors.white,
        tertiary:         theme.glow,
        onTertiary:       Colors.white,
        error:            theme.error,
        onError:          Colors.white,
        surface:          theme.card,
        onSurface:        theme.textPrimary,
        onSurfaceVariant: theme.textSecondary,
        outline:          theme.textMuted,
        shadow:           Colors.black,
      ),

      scaffoldBackgroundColor: theme.background,
      fontFamily: 'Roboto',

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS:     FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS:   FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux:   FadeSlidePageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textPrimary,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.textPrimary,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: theme.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: theme.isLight ? Colors.white : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.glow,
          side: BorderSide(color: theme.glow, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: theme.glow,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: theme.primary,
        foregroundColor: theme.isLight ? Colors.white : Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: theme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.textMuted.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.textMuted.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.5), fontSize: 14),
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: 14),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.card,
        selectedItemColor: theme.primary,
        unselectedItemColor: theme.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.textPrimary,
        ),
        contentTextStyle: TextStyle(color: theme.textSecondary, fontSize: 14),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: theme.cardLighter,
        selectedColor: theme.primary.withOpacity(0.25),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: theme.textMuted.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? theme.primary : theme.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? theme.primary.withOpacity(0.35)
              : theme.textMuted.withOpacity(0.15),
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: theme.primary,
        inactiveTrackColor: theme.textMuted.withOpacity(0.2),
        thumbColor: theme.primary,
        overlayColor: theme.primary.withOpacity(0.2),
        valueIndicatorColor: theme.accent,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: theme.primary,
        linearTrackColor: theme.cardLighter,
        circularTrackColor: theme.cardLighter,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.cardLighter,
        contentTextStyle: TextStyle(color: theme.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: DividerThemeData(
        color: theme.textMuted.withOpacity(0.15),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        textColor: theme.textPrimary,
        iconColor: theme.glow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),

      iconTheme: IconThemeData(color: theme.glow, size: 24),
      primaryIconTheme: IconThemeData(color: theme.primary, size: 24),

      textTheme: TextTheme(
        displayLarge:   TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        displayMedium:  TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        displaySmall:   TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge:  TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700),
        headlineSmall:  TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        titleMedium:    TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
        titleSmall:     TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w500),
        bodyLarge:      TextStyle(color: theme.textPrimary),
        bodyMedium:     TextStyle(color: theme.textPrimary),
        bodySmall:      TextStyle(color: theme.textSecondary),
        labelLarge:     TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        labelMedium:    TextStyle(color: theme.textSecondary),
        labelSmall:     TextStyle(color: theme.textMuted, fontSize: 11),
      ),
    );
  }
}
