import 'package:flutter/material.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/services/earthquake_cache_service.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:lastquakes/services/tile_cache_service.dart';
import 'package:lastquakes/services/historical_comparison_service.dart';
import 'package:provider/provider.dart';

/// A settings card that allows users to clear all app cache data.
class CacheSettingsCard extends StatefulWidget {
  const CacheSettingsCard({super.key});

  @override
  State<CacheSettingsCard> createState() => _CacheSettingsCardState();
}

class _CacheSettingsCardState extends State<CacheSettingsCard> {
  bool _isClearing = false;

  Future<void> _clearAllCache() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Cache?'),
            content: const Text(
              'This will clear all cached earthquake data, historical comparisons, map tiles, and location data. '
              'The app will fetch fresh data from the server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear Cache'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);

    try {
      // Clear earthquake data cache
      await EarthquakeCacheService.clearCache();

      // Clear map tile cache
      await TileCacheService.instance.clearCache();

      // Clear location cache (in-memory)
      LocationService().clearCache();

      // Clear historical comparison cache
      await HistoricalComparisonService.instance.clearCache();

      if (!mounted) return;

      // Trigger data refresh
      final earthquakeProvider = context.read<EarthquakeProvider>();
      await earthquakeProvider.loadData(forceRefresh: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared! Fresh data loaded.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear cache: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: ListTile(
        leading: Icon(
          Icons.cleaning_services_outlined,
          color: colorScheme.primary,
        ),
        title: const Text(
          'Clear Cache',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          'Delete cached earthquake data, map tiles, and location',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing:
            _isClearing
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(Icons.delete_outline, color: colorScheme.error),
        onTap: _isClearing ? null : _clearAllCache,
      ),
    );
  }
}
