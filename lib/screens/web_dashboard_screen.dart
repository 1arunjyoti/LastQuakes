import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:lastquakes/widgets/components/earthquake_bottom_sheet.dart';
import 'package:lastquakes/widgets/custom_drawer.dart';
import 'package:lastquakes/widgets/earthquake_list_widget.dart';
import 'package:lastquakes/widgets/earthquake_map_widget.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  late final MapController _mapController;
  final GlobalKey<EarthquakeMapWidgetState> _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onEarthquakeSelected(Earthquake earthquake) {
    // Fly to the earthquake location
    _mapController.move(
      LatLng(earthquake.latitude, earthquake.longitude),
      6.0, // Zoom level
    );
    
    // Show bottom sheet with earthquake details
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return EarthquakeBottomSheet(
          earthquake: earthquake,
          onViewDetails: () {
            Navigator.push(
              context,
              AppPageTransitions.scaleRoute(
                page: EarthquakeDetailsScreen(
                  earthquake: earthquake,
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
    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "Dashboard",
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _mapKey.currentState?.showFilters();
            },
            tooltip: 'Filter Earthquakes',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => context.read<EarthquakeProvider>().loadData(
                  forceRefresh: true,
                ),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Row(
        children: [
          // Left Panel: List
          SizedBox(
            width: 400,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: EarthquakeListWidget(
                showAppBar: false, // Use custom header
                onEarthquakeTap: _onEarthquakeSelected,
              ),
            ),
          ),
          // Right Panel: Map
          Expanded(
            child: EarthquakeMapWidget(
              key: _mapKey,
              mapController: _mapController,
            ),
          ),
        ],
      ),
    );
  }
}
