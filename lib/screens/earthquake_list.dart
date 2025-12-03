import 'package:flutter/material.dart';
import 'package:lastquake/presentation/providers/earthquake_provider.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/earthquake_list_widget.dart';
import 'package:provider/provider.dart';

class EarthquakeListScreen extends StatefulWidget {
  const EarthquakeListScreen({super.key});

  @override
  State<EarthquakeListScreen> createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {
  final GlobalKey<EarthquakeListWidgetState> _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "LastQuakes",
        actions: [
          Consumer<EarthquakeProvider>(
            builder: (context, provider, _) {
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
                        : () => provider.fetchUserLocation(),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: EarthquakeListWidget(
            key: _listKey,
            showAppBar: true, // We are providing the AppBar via Scaffold
          ),
        ),
      ),
    );
  }
}
