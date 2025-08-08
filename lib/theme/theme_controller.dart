import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_presets.dart';

/// Controls the application's theme settings. This controller stores the
/// current theme preset and mode (light/dark/system) and notifies listeners
/// when changes occur. It also persists the user's selection using
/// SharedPreferences so that their choices are remembered on restart.
class ThemeController extends ChangeNotifier {
  static const _prefKeyPreset = 'theme_preset';
  static const _prefKeyMode = 'theme_mode';

  /// The currently selected colour preset. Defaults to the first preset in
  /// [kThemePresets] if nothing has been persisted.
  ThemePreset _preset = kThemePresets.first;

  /// The current theme mode (light, dark or system). Defaults to system.
  ThemeMode _mode = ThemeMode.system;

  /// Get the selected preset.
  ThemePreset get preset => _preset;

  /// Get the selected theme mode.
  ThemeMode get mode => _mode;

  /// Loads the user's saved theme settings from SharedPreferences. If no
  /// preferences have been saved, the defaults (teal and system) are used.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetName = prefs.getString(_prefKeyPreset);
    final modeIndex = prefs.getInt(_prefKeyMode);
    if (presetName != null) {
      final match = kThemePresets.firstWhere(
        (p) => p.name == presetName,
        orElse: () => kThemePresets.first,
      );
      _preset = match;
    }
    if (modeIndex != null) {
      _mode = ThemeMode.values[modeIndex];
    }
    notifyListeners();
  }

  /// Updates the current preset and persists the change.
  Future<void> updatePreset(ThemePreset preset) async {
    _preset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPreset, preset.name);
  }

  /// Updates the theme mode (light/dark/system) and persists the change.
  Future<void> updateMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyMode, mode.index);
  }

  /// The light theme derived from the current preset. Uses Material3 and
  /// generates a colour scheme from the seed colour.
  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _preset.seedColor,
        brightness: Brightness.light,
      );

  /// The dark theme derived from the current preset.
  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _preset.seedColor,
        brightness: Brightness.dark,
      );
}