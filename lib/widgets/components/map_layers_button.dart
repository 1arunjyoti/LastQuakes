import 'package:flutter/material.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map Layers Button Widget for Map Controls
class MapLayersButton extends StatelessWidget {
  final MapLayerType selectedMapType;
  final bool showFaultLines;
  final bool isLoadingFaultLines;
  final ValueChanged<MapLayerType> onMapTypeChanged;
  final ValueChanged<bool> onFaultLinesToggled;

  const MapLayersButton({
    super.key,
    required this.selectedMapType,
    required this.showFaultLines,
    required this.isLoadingFaultLines,
    required this.onMapTypeChanged,
    required this.onFaultLinesToggled,
  });

  void _showMapLayersBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // Local state for immediate UI updates
            MapLayerType currentMapType = selectedMapType;
            bool currentShowFaultLines = showFaultLines;

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Map Layers',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Map type options
                    Text(
                      'Map Style',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...MapLayerType.values.map((type) {
                      final isSelected = currentMapType == type;
                      String title;
                      IconData iconData;

                      switch (type) {
                        case MapLayerType.osm:
                          title = 'Street Map';
                          iconData = Icons.map_outlined;
                          break;
                        case MapLayerType.satellite:
                          title = 'Satellite';
                          iconData = Icons.satellite_alt_outlined;
                          break;
                        case MapLayerType.terrain:
                          title = 'Terrain';
                          iconData = Icons.terrain_outlined;
                          break;
                        case MapLayerType.dark:
                          title = 'Dark Mode';
                          iconData = Icons.dark_mode_outlined;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: Icon(iconData, color: colorScheme.primary),
                          title: Text(title),
                          trailing:
                              isSelected
                                  ? Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  )
                                  : const Icon(Icons.radio_button_unchecked),
                          onTap: () async {
                            if (type != currentMapType) {
                              // Update local state immediately for UI responsiveness
                              setSheetState(() {
                                currentMapType = type;
                              });
                              // Update parent state
                              onMapTypeChanged(type);
                              // Save preference
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                'map_layer_type_preference_v2',
                                type.name,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor:
                              isSelected
                                  ? colorScheme.primaryContainer.withValues(
                                    alpha: 0.3,
                                  )
                                  : null,
                        ),
                      );
                    }),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Fault lines toggle
                    Text(
                      'Overlays',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      leading: Icon(
                        Icons.timeline_outlined,
                        color:
                            currentShowFaultLines
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                      ),
                      title: const Text('Fault Lines'),
                      subtitle:
                          isLoadingFaultLines ? const Text('Loading...') : null,
                      trailing:
                          isLoadingFaultLines
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Switch(
                                value: currentShowFaultLines,
                                onChanged: (_) {
                                  // Calculate new value first
                                  final newValue = !currentShowFaultLines;
                                  // Update local state immediately for UI responsiveness
                                  setSheetState(() {
                                    currentShowFaultLines = newValue;
                                  });
                                  // Update parent state with the new value
                                  onFaultLinesToggled(newValue);
                                },
                              ),
                      onTap:
                          isLoadingFaultLines
                              ? null
                              : () {
                                // Calculate new value first
                                final newValue = !currentShowFaultLines;
                                // Update local state immediately for UI responsiveness
                                setSheetState(() {
                                  currentShowFaultLines = newValue;
                                });
                                // Update parent state with the new value
                                onFaultLinesToggled(newValue);
                              },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor:
                          currentShowFaultLines
                              ? colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                              : null,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Map Layers',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showMapLayersBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.layers_outlined,
                size: 24,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
