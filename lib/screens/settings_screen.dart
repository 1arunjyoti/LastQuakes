import 'package:flutter/material.dart';

import 'package:lastquakes/presentation/providers/settings_provider.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:lastquakes/widgets/data_source_status_widget.dart';
import 'package:lastquakes/widgets/settings/clock_settings_card.dart';
import 'package:lastquakes/widgets/settings/theme_settings_card.dart';
import 'package:lastquakes/widgets/settings/units_settings_card.dart';
import 'package:lastquakes/widgets/settings/cache_settings_card.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Expansion state
  bool _dataSourcesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final prefsProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: LastQuakesAppBar(title: 'Settings'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Consumer<SettingsProvider>(
                builder: (context, settingsProvider, child) {
                  if (settingsProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView(
                    padding: const EdgeInsets.all(12.0),
                    children: [
                      _buildDataSourcesCard(settingsProvider),
                      const SizedBox(height: 12),
                      ThemeSettingsCard(
                        themeProvider: prefsProvider,
                      ),
                      const SizedBox(height: 12),
                      UnitsSettingsCard(
                        themeProvider: prefsProvider,
                      ),
                      const SizedBox(height: 12),
                      ClockSettingsCard(
                        themeProvider: prefsProvider,
                      ),
                      const SizedBox(height: 12),
                      const CacheSettingsCard(),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Data Sources Settings Card ---
  Widget _buildDataSourcesCard(SettingsProvider provider) {
    final selectedSources = provider.selectedDataSources;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Data Sources',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${selectedSources.length} source${selectedSources.length != 1 ? 's' : ''} selected',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: IconButton(
              icon: Icon(
                _dataSourcesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed:
                  () => setState(
                    () => _dataSourcesExpanded = !_dataSourcesExpanded,
                  ),
            ),
            onTap:
                () => setState(
                  () => _dataSourcesExpanded = !_dataSourcesExpanded,
                ),
          ),
          if (_dataSourcesExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show current status of data sources
                  const DataSourceStatusWidget(compact: false),
                  const SizedBox(height: 16),
                  const Text(
                    'Select earthquake data sources:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('USGS (United States Geological Survey)'),
                    subtitle: const Text(
                      'Comprehensive global earthquake data',
                    ),
                    value: selectedSources.contains(DataSource.usgs),
                    onChanged: (bool? value) {
                      final newSources = Set<DataSource>.from(selectedSources);
                      if (value == true) {
                        newSources.add(DataSource.usgs);
                      } else {
                        if (newSources.length > 1) {
                          newSources.remove(DataSource.usgs);
                        }
                      }
                      provider.updateDataSources(newSources);
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'EMSC (European-Mediterranean Seismological Centre)',
                    ),
                    subtitle: const Text(
                      'European and Mediterranean region focus',
                    ),
                    value: selectedSources.contains(DataSource.emsc),
                    onChanged: (bool? value) {
                      final newSources = Set<DataSource>.from(selectedSources);
                      if (value == true) {
                        newSources.add(DataSource.emsc);
                      } else {
                        if (newSources.length > 1) {
                          newSources.remove(DataSource.emsc);
                        }
                      }
                      provider.updateDataSources(newSources);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}