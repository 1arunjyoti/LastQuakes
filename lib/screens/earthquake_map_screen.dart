import 'package:flutter/material.dart';
import 'package:lastquake/presentation/providers/earthquake_provider.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/earthquake_map_widget.dart';
import 'package:provider/provider.dart';

class EarthquakeMapScreen extends StatefulWidget {
  const EarthquakeMapScreen({super.key});

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<EarthquakeMapWidgetState> _mapKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "LastQuakes Map",
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
      body: EarthquakeMapWidget(key: _mapKey),
    );
  }
}
