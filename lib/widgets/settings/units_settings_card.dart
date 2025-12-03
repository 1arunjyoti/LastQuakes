import 'package:flutter/material.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/utils/enums.dart';

class UnitsSettingsCard extends StatefulWidget {
  final ThemeProvider themeProvider;

  const UnitsSettingsCard({super.key, required this.themeProvider});

  @override
  State<UnitsSettingsCard> createState() => _UnitsSettingsCardState();
}

class _UnitsSettingsCardState extends State<UnitsSettingsCard> {
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
              'Units',
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
              child: RadioGroup<DistanceUnit>(
                groupValue: widget.themeProvider.distanceUnit,
                onChanged: (DistanceUnit? value) {
                  if (value != null) {
                    widget.themeProvider.setDistanceUnit(value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<DistanceUnit>(
                      title: const Text('Kilometers (km)'),
                      value: DistanceUnit.km,
                    ),
                    RadioListTile<DistanceUnit>(
                      title: const Text('Miles (mi)'),
                      value: DistanceUnit.miles,
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
