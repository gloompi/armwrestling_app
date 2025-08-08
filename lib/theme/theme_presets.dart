import 'package:flutter/material.dart';

/// A simple data class representing a theme preset with a human friendly name
/// and a seed color. The seed color is used to generate a Material 3
/// color scheme via `colorSchemeSeed` in ThemeData.
class ThemePreset {
  /// The display name of the theme, shown in the appearance settings.
  final String name;

  /// The seed color used to derive the color scheme.
  final Color seedColor;

  const ThemePreset(this.name, this.seedColor);
}

/// A list of all available theme presets. Feel free to add more colours
/// here to provide users with additional options. Each entry consists of
/// a descriptive name and a primary seed colour that defines the palette.
const List<ThemePreset> kThemePresets = [
  ThemePreset('Teal', Colors.teal),
  ThemePreset('Indigo', Colors.indigo),
  ThemePreset('Emerald', Colors.green),
  ThemePreset('Crimson', Colors.red),
  ThemePreset('Amber', Colors.amber),
  ThemePreset('Violet', Colors.deepPurple),
];