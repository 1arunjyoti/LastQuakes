import 'package:flutter/material.dart';
import 'package:lastquakes/provider/theme_provider.dart';

class ClockSettingsCard extends StatefulWidget {
  final ThemeProvider themeProvider;

  const ClockSettingsCard({super.key, required this.themeProvider});

  @override
  State<ClockSettingsCard> createState() => _ClockSettingsCardState();
}

class _ClockSettingsCardState extends State<ClockSettingsCard> {
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
              'Clock Format',
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
              child: RadioGroup<bool>(
                groupValue: widget.themeProvider.use24HourClock,
                onChanged: (bool? value) {
                  if (value != null) {
                    widget.themeProvider.setUse24HourClock(value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('12-hour (AM/PM)'),
                      value: false,
                    ),
                    RadioListTile<bool>(
                      title: const Text('24-hour'),
                      value: true,
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
