import 'package:flutter/material.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:lastquakes/widgets/custom_drawer.dart';
import 'package:lastquakes/widgets/data_source_status_widget.dart';
import 'package:lastquakes/widgets/earthquake_list_widget.dart';
import 'package:provider/provider.dart';

class EarthquakeListScreen extends StatefulWidget {
  const EarthquakeListScreen({super.key});

  @override
  State<EarthquakeListScreen> createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {
  final GlobalKey<EarthquakeListWidgetState> _listKey = GlobalKey();
  String? _lastLocationError;

  void _handleLocationError(EarthquakeProvider provider) {
    if (provider.locationError != null && 
        provider.locationError != _lastLocationError) {
      _lastLocationError = provider.locationError;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.locationError!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  provider.clearLocationError();
                },
              ),
            ),
          );
        }
      });
    } else if (provider.locationError == null && _lastLocationError != null) {
      _lastLocationError = null;
    }
  }

  void _handleLocationSuccess(EarthquakeProvider provider) {
    if (provider.userPosition != null && !provider.isLoadingLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location updated! Distance info added to cards.'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "LastQuakes",
        actions: [
          Consumer<EarthquakeProvider>(
            builder: (context, provider, _) {
              // Handle location errors
              _handleLocationError(provider);
              
              return IconButton(
                icon:
                    provider.isLoadingLocation
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.my_location),
                onPressed:
                    provider.isLoadingLocation
                        ? null
                        : () async {
                            final hadLocation = provider.userPosition != null;
                            await provider.fetchUserLocation();
                            if (!hadLocation && provider.userPosition != null) {
                              _handleLocationSuccess(provider);
                            }
                          },
                tooltip: 'Refresh Location',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () {
              _listKey.currentState?.toggleFilters();
            },
            tooltip: 'Filter',
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          const DataSourceBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: EarthquakeListWidget(
                  key: _listKey,
                  showAppBar: true, // We are providing the AppBar via Scaffold
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
