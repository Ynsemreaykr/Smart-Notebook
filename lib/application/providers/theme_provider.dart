import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../presentation/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _themeModeKey = 'theme_mode';
  static const String _themeNameKey = 'selected_theme';

  static ThemeModel activeTheme = AppTheme.navyTheme;

  ThemeMode _themeMode = ThemeMode.dark;
  String _selectedThemeName = 'lacivert';

  ThemeMode get themeMode => _themeMode;
  String get selectedThemeName => _selectedThemeName;

  ThemeData get activeThemeData => AppTheme.activeThemeData;

  ThemeModel get currentTheme {
    switch (_selectedThemeName) {
      case 'mor':
        return AppTheme.purpleTheme;
      case 'yesil':
        return AppTheme.greenTheme;
      case 'acik':
        return AppTheme.lightTheme;
      case 'lacivert':
      default:
        return AppTheme.navyTheme;
    }
  }

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() {
    final box = Hive.box(_boxName);
    _selectedThemeName = box.get(_themeNameKey, defaultValue: 'lacivert');
    
    // Auto align theme mode based on theme name
    if (_selectedThemeName == 'acik') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    
    activeTheme = currentTheme;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final box = Hive.box(_boxName);
    await box.put(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    _selectedThemeName = themeName;
    activeTheme = currentTheme;
    
    // Automatically toggle ThemeMode based on selected theme
    if (themeName == 'acik') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    
    final box = Hive.box(_boxName);
    await box.put(_themeNameKey, themeName);
    await box.put(_themeModeKey, _themeMode.index);
    
    notifyListeners();
  }
}
