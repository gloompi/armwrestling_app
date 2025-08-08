import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_controller.dart';
import '../theme/theme_presets.dart';

/// Allows the user to select a colour preset and light/dark/system mode.
/// Changes are applied immediately and persisted via [ThemeController].
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance & Theme'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'Colour preset',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Generate a radio list tile for each preset. Show the colour
          // as a leading circle avatar.
          ...kThemePresets.map((preset) {
            final selected = preset == themeController.preset;
            return RadioListTile<ThemePreset>(
              value: preset,
              groupValue: themeController.preset,
              onChanged: (value) {
                if (value != null) {
                  themeController.setPreset(value);
                }
              },
              title: Text(preset.name),
              secondary: CircleAvatar(
                backgroundColor: preset.seedColor,
              ),
              selected: selected,
            );
          }),
          const Divider(),
          const ListTile(
            title: Text(
              'Theme mode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: themeController.mode,
            onChanged: (mode) {
              if (mode != null) {
                themeController.setMode(mode);
              }
            },
            title: const Text('Use system setting'),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: themeController.mode,
            onChanged: (mode) {
              if (mode != null) {
                themeController.setMode(mode);
              }
            },
            title: const Text('Light'),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: themeController.mode,
            onChanged: (mode) {
              if (mode != null) {
                themeController.setMode(mode);
              }
            },
            title: const Text('Dark'),
          ),
        ],
      ),
    );
  }
}