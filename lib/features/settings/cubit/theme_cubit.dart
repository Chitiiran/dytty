import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode selection, persisted across launches (mirrors
/// DevSettingsCubit's SharedPreferences pattern — before this, the theme
/// silently reset to system on every app start).
class ThemeCubit extends Cubit<ThemeMode> {
  static const _keyThemeMode = 'theme_mode';

  ThemeCubit() : super(ThemeMode.system);

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isClosed) return; // cubit can be closed while awaiting prefs
      final stored = prefs.getString(_keyThemeMode);
      final mode = ThemeMode.values.where((m) => m.name == stored).firstOrNull;
      if (mode != null && mode != state) {
        emit(mode);
      }
    } catch (e) {
      // Platform-channel hiccup at startup: keep the system default.
      debugPrint('Failed to load theme: $e');
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (state != mode) {
      emit(mode);
      // Fire-and-forget persistence; a failed write just means the old
      // theme comes back next launch.
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setString(_keyThemeMode, mode.name))
          .catchError((Object e) {
            debugPrint('Failed to persist theme mode: $e');
          });
    }
  }
}
