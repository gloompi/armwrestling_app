import 'package:flutter/material.dart';

/// Represents a user-selectable theme preset consisting of a name and a
/// seed color. The seed color is used by Material 3 to generate the full
/// color scheme for both light and dark themes.
class ThemePreset {
  final String name;
  final Color seedColor;
  const ThemePreset(this.name, this.seedColor);
}

/// A list of predefined theme presets. Feel free to add more colours here.
/// Users can switch between these presets in the appearance settings page.
const List<ThemePreset> kThemePresets = [
  ThemePreset('Teal', Colors.teal),
  ThemePreset('Indigo', Colors.indigo),
  ThemePreset('Emerald', Colors.green),
  ThemePreset('Crimson', Colors.red),
  ThemePreset('Amber', Colors.amber),
  ThemePreset('Violet', Colors.deepPurple),
];