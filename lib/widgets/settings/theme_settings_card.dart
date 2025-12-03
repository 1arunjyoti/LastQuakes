import 'package:flutter/material.dart';
import 'package:lastquakes/provider/theme_provider.dart';

class ThemeSettingsCard extends StatefulWidget {
  final ThemeProvider themeProvider;

  const ThemeSettingsCard({super.key, required this.themeProvider});

  @override
  State<ThemeSettingsCard> createState() => _ThemeSettingsCardState();
}

class _ThemeSettingsCardState extends State<ThemeSettingsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Theme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: RadioGroup<ThemeMode>(
                groupValue: widget.themeProvider.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.themeProvider.setThemeMode(value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System Default'),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light Theme'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark Theme'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
