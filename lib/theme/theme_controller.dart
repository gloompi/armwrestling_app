import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_presets.dart';

/// A [ChangeNotifier] that manages the application's theme. It persists
/// the selected theme preset and theme mode (light/dark/system) using
/// [SharedPreferences] so that the user's choice is restored on app startup.
class ThemeController extends ChangeNotifier {
  static const _prefPreset = 'theme_preset';
  static const _prefMode = 'theme_mode';

  /// The currently selected colour preset.
  ThemePreset _preset = kThemePresets.first;

  /// The currently selected theme mode (light/dark/system).
  ThemeMode _mode = ThemeMode.system;

  /// Load the saved theme preset and mode from local storage. This should
  /// be called before the controller is used so that the UI can apply
  /// persisted settings immediately.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetName = prefs.getString(_prefPreset);
    final modeIndex = prefs.getInt(_prefMode);
    if (presetName != null) {
      final match = kThemePresets.firstWhere(
        (p) => p.name == presetName,
        orElse: () => kThemePresets.first,
      );
      _preset = match;
    }
    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < ThemeMode.values.length) {
      _mode = ThemeMode.values[modeIndex];
    }
  }

  /// Persist the theme preset and notify listeners.
  Future<void> setPreset(ThemePreset preset) async {
    if (_preset == preset) return;
    _preset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPreset, preset.name);
  }

  /// Persist the theme mode and notify listeners.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefMode, mode.index);
  }

  ThemePreset get preset => _preset;
  ThemeMode get mode => _mode;

  /// Provide a Material 3 light theme based on the current preset.
  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _preset.seedColor,
        brightness: Brightness.light,
      );

  /// Provide a Material 3 dark theme based on the current preset.
  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _preset.seedColor,
        brightness: Brightness.dark,
      );
}