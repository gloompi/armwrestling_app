import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_controller.dart';
import '../theme/theme_presets.dart';

/// A simple settings page that allows the user to choose their preferred
/// colour preset and theme mode. Selections are applied immediately and
/// persisted via [ThemeController].
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance & Theme'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Color Preset'),
            subtitle: Text('Choose a colour scheme for the app'),
          ),
          ...kThemePresets.map((preset) => RadioListTile<ThemePreset>(
                title: Text(preset.name),
                secondary: CircleAvatar(
                  backgroundColor: preset.seedColor,
                ),
                value: preset,
                groupValue: controller.preset,
                onChanged: (ThemePreset? value) {
                  if (value != null) {
                    controller.updatePreset(value);
                  }
                },
              )),
          const Divider(),
          const ListTile(
            title: Text('Theme Mode'),
            subtitle: Text('Switch between light, dark or follow system'),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            value: ThemeMode.system,
            groupValue: controller.mode,
            onChanged: (ThemeMode? mode) {
              if (mode != null) {
                controller.updateMode(mode);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: controller.mode,
            onChanged: (ThemeMode? mode) {
              if (mode != null) {
                controller.updateMode(mode);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: controller.mode,
            onChanged: (ThemeMode? mode) {
              if (mode != null) {
                controller.updateMode(mode);
              }
            },
          ),
        ],
      ),
    );
  }
}