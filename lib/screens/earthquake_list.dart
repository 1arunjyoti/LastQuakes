import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import '../services/api_service.dart';

class EarthquakeListScreen extends StatefulWidget {
  final List? earthquakes;

  const EarthquakeListScreen({Key? key, this.earthquakes}) : super(key: key);

  @override
  _EarthquakeListScreenState createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {
  // Memoization cache for country extraction
  final _memoizedCountryExtraction = <String, String>{};

  List filteredEarthquakes = [];
  bool showFilters = true;
  bool isRefreshing = false;

  String selectedCountry = "All";
  double selectedMagnitude = 3.0;
  late List<String> countryList = ["All"];

  static final List<double> magnitudeOptions = [
    3.0,
    4.0,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0,
    10.0,
  ];

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    if (widget.earthquakes != null) {
      _initializeEarthquakeData(widget.earthquakes!);
    }
  }

  void _initializeEarthquakeData(List earthquakes) {
    countryList = ["All"] + _getUniqueCountries(earthquakes);
    _filterEarthquakes(earthquakes);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentScrollDirection =
        _scrollController.position.userScrollDirection;

    if (currentScrollDirection == ScrollDirection.reverse && showFilters) {
      setState(() => showFilters = false);
    } else if (currentScrollDirection == ScrollDirection.forward &&
        !showFilters) {
      setState(() => showFilters = true);
    }
  }

  Future<void> _fetchEarthquakes({bool isPullToRefresh = false}) async {
    if (isPullToRefresh) {
      setState(() => isRefreshing = true);
    }

    try {
      final newData = await ApiService.fetchEarthquakes(
        minMagnitude: selectedMagnitude,
        days: 45,
      );

      if (mounted) {
        setState(() {
          countryList = ["All"] + _getUniqueCountries(newData);
          _filterEarthquakes(newData);
          isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  // Optimized unique countries extraction
  List<String> _getUniqueCountries(List data) {
    return data
        .map((quake) => _extractCountry(quake["properties"]["place"] ?? ""))
        .where((country) => country.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // Memoized country extraction
  String _extractCountry(String place) {
    return _memoizedCountryExtraction.putIfAbsent(
      place,
      () => place.contains(", ") ? place.split(", ").last.trim() : "",
    );
  }

  void _filterEarthquakes(List earthquakesToFilter) {
    setState(() {
      filteredEarthquakes =
          earthquakesToFilter.where((quake) {
            final properties = quake["properties"];
            final magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;
            final place = properties["place"] ?? "";
            final country = _extractCountry(place);

            return magnitude >= selectedMagnitude &&
                (selectedCountry == "All" || country == selectedCountry);
          }).toList();
    });
  }

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.red.shade900;
    if (magnitude >= 5.0) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text(
          "LastQuakes",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      drawer: const CustomDrawer(),
      body:
          widget.earthquakes == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Animated Filter Section
                  AnimatedSlide(
                    offset: showFilters ? Offset.zero : const Offset(0, -1),
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: showFilters ? 1.0 : 0.0,
                      child: Visibility(
                        visible: showFilters,
                        child: _buildFilterSection(),
                      ),
                    ),
                  ),

                  // Earthquake Count Display
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      "Total Earthquakes: ${filteredEarthquakes.length}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Earthquake List with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _fetchEarthquakes(isPullToRefresh: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredEarthquakes.length,
                        itemBuilder: (context, index) {
                          final quake =
                              filteredEarthquakes[index]["properties"];
                          final magnitude =
                              (quake["mag"] as num?)?.toDouble() ?? 0.0;
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            quake["time"],
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getMagnitudeColor(magnitude),
                                child: Text(
                                  magnitude.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                quake["place"] ?? "Unknown location",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat.yMMMd().add_jm().format(time),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => EarthquakeDetailsScreen(
                                          quakeData: filteredEarthquakes[index],
                                        ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Country Filter Dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedCountry,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Country",
                border: OutlineInputBorder(),
              ),
              items:
                  countryList.map((String country) {
                    return DropdownMenuItem<String>(
                      value: country,
                      child: Text(country, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCountry = value;
                    _filterEarthquakes(widget.earthquakes!);
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),

          // Magnitude Filter Dropdown
          Expanded(
            child: DropdownButtonFormField<double>(
              value: selectedMagnitude,
              decoration: const InputDecoration(
                labelText: "Magnitude",
                border: OutlineInputBorder(),
              ),
              items:
                  magnitudeOptions.map((double mag) {
                    return DropdownMenuItem<double>(
                      value: mag,
                      child: Text("≥ $mag"),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedMagnitude = value;
                    _filterEarthquakes(widget.earthquakes!);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
