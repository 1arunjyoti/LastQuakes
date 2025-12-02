import 'package:flutter/material.dart';
import 'package:lastquake/utils/enums.dart';

class DataSourceSettingsCard extends StatefulWidget {
  final Set<DataSource> selectedDataSources;
  final Function(Set<DataSource>) onSourcesChanged;

  const DataSourceSettingsCard({
    super.key,
    required this.selectedDataSources,
    required this.onSourcesChanged,
  });

  @override
  State<DataSourceSettingsCard> createState() => _DataSourceSettingsCardState();
}

class _DataSourceSettingsCardState extends State<DataSourceSettingsCard> {
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
              'Data Sources',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${widget.selectedDataSources.length} source${widget.selectedDataSources.length != 1 ? 's' : ''} selected',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select earthquake data sources:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildCheckbox(
                    'USGS (United States Geological Survey)',
                    'Comprehensive global earthquake data',
                    DataSource.usgs,
                  ),
                  _buildCheckbox(
                    'EMSC (European-Mediterranean Seismological Centre)',
                    'European and Mediterranean region focus',
                    DataSource.emsc,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String title, String subtitle, DataSource source) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: widget.selectedDataSources.contains(source),
      onChanged: (bool? value) {
        final newSources = Set<DataSource>.from(widget.selectedDataSources);
        if (value == true) {
          newSources.add(source);
        } else {
          if (newSources.length > 1) {
            newSources.remove(source);
          }
        }
        widget.onSourcesChanged(newSources);
      },
    );
  }
}
