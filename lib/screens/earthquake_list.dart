import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/appbar.dart'; // Assumed correct name
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/earthquake_list_item.dart';
import '../services/api_service.dart';

// --- Top-level function for Isolate Processing ---
// NOTE: LocationService cannot be directly used here. Pass necessary primitives.
List<Map<String, dynamic>> _filterAndSortEarthquakesIsolate(
  Map<String, dynamic> args,
) {
  final List<Map<String, dynamic>> inputList = args['list'];
  final double minMagnitude = args['minMagnitude'];
  final String countryFilter = args['countryFilter'];
  final double? userLat = args['userLat'];
  final double? userLon = args['userLon'];

  // Simple distance calculation (can be replaced with Geolocator version if needed,
  // but would require passing Geolocator's static method or pre-calculating)
  // For simplicity, keep the core filtering logic here. Distance calc adds overhead.
  // Let's calculate distance on the main thread only for displayed items later if needed,
  // or accept the overhead here if filtering by distance becomes a feature.
  // For now, focus on filtering by mag/country in isolate.

  List<Map<String, dynamic>> correctlyTypedInput =
      inputList.whereType<Map<String, dynamic>>().toList();

  final List<Map<String, dynamic>> filteredList =
      correctlyTypedInput
          .where((quake) {
            final properties = quake["properties"];
            if (properties is! Map) return false;

            final magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;
            final place = properties["place"] as String? ?? "";
            // Simple country extraction (must be self-contained)
            final String country =
                place.contains(", ") ? place.split(", ").last.trim() : "";

            bool passesMagnitude = magnitude >= minMagnitude;
            bool passesCountry =
                (countryFilter == "All" || country == countryFilter);

            return passesMagnitude && passesCountry;
          })
          .map((quake) {
            // Create a mutable copy IF distance calculation is done here
            final Map<String, dynamic> currentQuake = Map<String, dynamic>.from(
              quake,
            );
            final Map<String, dynamic> properties = Map<String, dynamic>.from(
              currentQuake["properties"] ?? {},
            );

            // --- OPTIONAL: Distance Calculation in Isolate (Adds Overhead) ---
            if (userLat != null && userLon != null) {
              final geometry = currentQuake["geometry"];
              if (geometry is Map && geometry["coordinates"] is List) {
                final coordinates = geometry["coordinates"] as List;
                if (coordinates.length >= 2 &&
                    coordinates[0] is num &&
                    coordinates[1] is num) {
                  final double longitude = coordinates[0].toDouble();
                  final double latitude = coordinates[1].toDouble();
                  // Using Geolocator's static method IS possible in isolates
                  final distance =
                      Geolocator.distanceBetween(
                        userLat,
                        userLon,
                        latitude,
                        longitude,
                      ) /
                      1000.0; // km
                  properties["distance"] = distance.round();
                  currentQuake["properties"] =
                      properties; // Update the copied properties
                }
              }
            }
            // --- End Optional Distance Calc ---

            return currentQuake; // Return the (potentially modified) quake map
          })
          .toList();

  // Sort by time
  filteredList.sort((a, b) {
    int timeA = (a["properties"]?["time"] as int?) ?? 0;
    int timeB = (b["properties"]?["time"] as int?) ?? 0;
    return timeB.compareTo(timeA);
  });

  return filteredList;
}

class EarthquakeListScreen extends StatefulWidget {
  const EarthquakeListScreen({Key? key}) : super(key: key);

  @override
  _EarthquakeListScreenState createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {
  final _memoizedCountryExtraction = <String, String>{};

  // State Variables
  List<Map<String, dynamic>> _unfilteredEarthquakes =
      []; // Holds data from API fetch
  List<Map<String, dynamic>> allEarthquakes = []; // FILTERED list
  List<Map<String, dynamic>> displayedEarthquakes =
      []; // Holds the paginated subset of filtered list

  bool showFilters = true;
  bool isRefreshing = false;
  bool _showPullToRefreshSnackbar = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isLoading = true;
  bool _isFiltering = false;
  String? _error;

  // Pagination
  static const int _itemsPerPage = 20;
  int _currentPage = 1;

  // Filters
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
  ];

  // UI / Services
  late ScrollController _scrollController;
  Position? _userPosition;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  // Memoization Caches
  List<DropdownMenuItem<String>>? _memoizedCountryItems;
  List<DropdownMenuItem<double>>? _memoizedMagnitudeItems;

  // Debounce timer for filter changes (Optional)
  // Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // automatic location fetching

    //_fetchUserLocation();
    // Fetch initial data when screen loads
    _fetchAndSetInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPullToRefreshSnackBar(context); // Pass context
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // _filterDebounce?.cancel(); // Cancel debounce timer if used
    super.dispose();
  }

  // --- Data Fetching & Processing ---

  Future<void> _fetchAndSetInitialData({bool forceRefresh = false}) async {
    if (!mounted) return;
    // Set loading only if it's the very first load
    if (_unfilteredEarthquakes.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }
    setState(() {
      _error = null; // Clear previous errors on fetch/refresh
      if (forceRefresh) isRefreshing = true;
      _isFiltering = true;
    });

    try {
      final fetchedData = await ApiService.fetchEarthquakes(
        minMagnitude: 3.0,
        days: 45,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      // Store the raw fetched data
      _unfilteredEarthquakes = fetchedData;

      // Update country list based on unfiltered data
      countryList = ["All"] + _getUniqueCountries(_unfilteredEarthquakes);
      _memoizedCountryItems = null; // Clear memoized dropdown

      // Apply filters using compute
      await _applyFiltersWithCompute(); // This will handle setting state
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load earthquakes: ${e.toString()}";
          _isLoading = false;
          isRefreshing = false;
          _isFiltering = false;
        });
      }
    } finally {
      // Ensure loading indicators are off if fetch succeeded but compute failed (or vice versa)
      if (mounted &&
          !_isLoading &&
          !isRefreshing &&
          _isFiltering &&
          _error == null) {
        // This case shouldn't happen often if compute handles state, but as a safeguard
        // setState(() { _isFiltering = false; });
      }
    }
  }

  // --- Apply Filters using Compute ---
  Future<void> _applyFiltersWithCompute() async {
    if (!mounted) return;
    setState(() {
      _isFiltering = true;
    }); // Show filtering indicator

    final args = {
      'list': _unfilteredEarthquakes,
      'minMagnitude': selectedMagnitude,
      'countryFilter': selectedCountry,
      'userLat': _userPosition?.latitude, // Pass user location primitives
      'userLon': _userPosition?.longitude,
    };

    try {
      // Run filtering in an isolate
      final List<Map<String, dynamic>> filteredData = await compute(
        _filterAndSortEarthquakesIsolate,
        args,
      );

      if (!mounted) return;

      // Update state with results from isolate
      setState(() {
        allEarthquakes = filteredData;
        _currentPage = 1;
        displayedEarthquakes = filteredData.take(_itemsPerPage).toList();
        _hasMoreData = filteredData.length > _itemsPerPage;
        _isLoading = false; // Ensure initial loading is off
        isRefreshing = false; // Ensure refreshing is off
        _isFiltering = false; // Hide filtering indicator
      });
    } catch (e) {
      debugPrint("Error during filtering isolate: $e");
      if (mounted) {
        setState(() {
          _error = "Error applying filters.";
          _isLoading = false;
          isRefreshing = false;
          _isFiltering = false;
        });
      }
    }
  }

  // Refresh triggered by Pull-to-Refresh
  Future<void> _refreshEarthquakes() async {
    await _fetchAndSetInitialData(forceRefresh: true);
  }

  // --- Filter Change Handlers ---

  void _onFilterChanged() {
    // Optional Debounce:
    /*
      _filterDebounce?.cancel();
      _filterDebounce = Timer(const Duration(milliseconds: 400), () {
         if (mounted) {
             _applyFiltersWithCompute(); // Apply filters after debounce period
         }
      });
      */

    // Apply filters immediately using compute (without debounce)
    _applyFiltersWithCompute();
    _scrollToTop();
  }

  void _onCountryChanged(String? value) {
    if (value == null || value == selectedCountry) return;
    setState(() {
      selectedCountry = value;
    });
    _onFilterChanged(); // Trigger combined filter logic
  }

  void _onMagnitudeChanged(double? value) {
    if (value == null || value == selectedMagnitude) return;
    setState(() {
      selectedMagnitude = value;
    });
    _onFilterChanged(); // Trigger combined filter logic
  }

  // --- Location Handling ---

  Future<void> _fetchUserLocation() async {
    if (!mounted) return;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      _showLocationServicesDisabledDialog(context);
      return;
    }

    setState(() => _isLoadingLocation = true);

    try {
      final position = await _locationService.getCurrentLocation(
        forceRefresh: true,
      );
      if (!mounted) return;

      setState(() {
        _userPosition = position;
        // Re-apply filters using compute, which will now include location data
        // This ensures distances are recalculated in the isolate if implemented there
        _applyFiltersWithCompute(); // Re-run filtering to update distances
      });

      if (position != null) {
        _showLocationSuccessSnackBar(context);
      } else {
        _showLocationErrorDialog(context);
      }
    } catch (e) {
      if (mounted) _showLocationErrorDialog(context);
      debugPrint('Error fetching location: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // --- Scrolling & Pagination ---

  void _onScroll() {
    final currentScrollDirection =
        _scrollController.position.userScrollDirection;

    // Show/Hide Filters
    if (currentScrollDirection == ScrollDirection.reverse && showFilters) {
      setState(() => showFilters = false);
    } else if (currentScrollDirection == ScrollDirection.forward &&
        !showFilters) {
      setState(() => showFilters = true);
    }

    // Hide Snackbar
    if (_showPullToRefreshSnackbar &&
        currentScrollDirection != ScrollDirection.idle) {
      _hidePullToRefreshSnackBar(context);
    }

    // Lazy Loading Trigger
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreEarthquakes();
    }
  }

  Future<void> _loadMoreEarthquakes() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final startIndex = _currentPage * _itemsPerPage;
    // Use the 'allEarthquakes' (filtered) list for pagination
    final endIndex =
        (startIndex + _itemsPerPage > allEarthquakes.length)
            ? allEarthquakes.length
            : startIndex + _itemsPerPage;

    if (startIndex >= allEarthquakes.length) {
      if (mounted)
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
      return;
    }

    final nextItems = allEarthquakes.sublist(startIndex, endIndex);

    if (mounted && nextItems.isNotEmpty) {
      setState(() {
        displayedEarthquakes.addAll(nextItems);
        _currentPage++;
        _isLoadingMore = false;
        _hasMoreData = displayedEarthquakes.length < allEarthquakes.length;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingMore = false;
        _hasMoreData = false;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "LastQuakes",
        actions: [
          IconButton(
            icon:
                _isLoadingLocation
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.location_searching),
            onPressed: _isLoadingLocation ? null : _fetchUserLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    () => _fetchAndSetInitialData(
                      forceRefresh: true,
                    ), // Retry button
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // Show filters section even if list is empty after filtering
    return Column(
      children: [
        // Animated Filter Section
        AnimatedSlide(
          offset: showFilters ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 200),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showFilters ? 1.0 : 0.0,
            child: Column(
              children: [
                Visibility(visible: showFilters, child: _buildFilterSection()),
                if (_isFiltering) // Show linear progress when filtering in isolate
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),

        // Earthquake Count Display (Shows count of *filtered* items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            "Earthquakes in the last 45 days: ${allEarthquakes.length}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),

        // List or Empty State Message
        Expanded(
          child:
              _isFiltering && allEarthquakes.isEmpty
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : allEarthquakes.isEmpty
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "No earthquakes found matching your criteria.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _refreshEarthquakes,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          displayedEarthquakes.length +
                          (_isLoadingMore && _hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == displayedEarthquakes.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }

                        final quakeData = displayedEarthquakes[index];
                        final properties =
                            quakeData["properties"] as Map<String, dynamic>? ??
                            {};
                        final magnitude =
                            (properties["mag"] as num?)?.toDouble() ?? 0.0;
                        final DateTime time =
                            DateTime.fromMillisecondsSinceEpoch(
                              properties["time"] as int? ?? 0,
                            );
                        final String place =
                            properties["place"] as String? ??
                            "Unknown location";
                        final Color magnitudeColor = _getMagnitudeColor(
                          magnitude,
                        );

                        // --- Use distance calculated in isolate
                        double? distanceKm;
                        if (_userPosition != null) {
                          if (properties.containsKey("distance")) {
                            distanceKm =
                                (properties["distance"] as num?)?.toDouble();
                          }
                        }

                        return EarthquakeListItem(
                          location: place,
                          distanceKm: distanceKm,
                          timestamp: time,
                          magnitude: magnitude,
                          magnitudeColor: magnitudeColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => EarthquakeDetailsScreen(
                                      quakeData: quakeData,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildCountryDropdown()),
          const SizedBox(width: 12),
          Expanded(child: _buildMagnitudeDropdown()),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown() {
    final List<DropdownMenuItem<String>> countryDropdownItems =
        _memoizedCountryItems ??=
            countryList.map((country) {
              return DropdownMenuItem<String>(
                value: country,
                child: Text(
                  country,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList();

    return DropdownButtonFormField<String>(
      value: selectedCountry,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Country",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: countryDropdownItems,
      onChanged: _onCountryChanged,
      menuMaxHeight: 400,
    );
  }

  Widget _buildMagnitudeDropdown() {
    final List<DropdownMenuItem<double>> magnitudeDropdownItems =
        _memoizedMagnitudeItems ??=
            magnitudeOptions.map((mag) {
              return DropdownMenuItem<double>(
                value: mag,
                child: Text("≥ $mag", style: const TextStyle(fontSize: 14)),
              );
            }).toList();

    return DropdownButtonFormField<double>(
      value: selectedMagnitude,
      decoration: const InputDecoration(
        labelText: "Magnitude",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: magnitudeDropdownItems,
      onChanged: _onMagnitudeChanged,
    );
  }

  // --- Utility Methods ---

  List<String> _getUniqueCountries(List data) {
    return data
        .whereType<Map>()
        .map((quake) => _extractCountry(quake["properties"]?["place"] ?? ""))
        .where((country) => country.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String _extractCountry(String place) {
    return _memoizedCountryExtraction.putIfAbsent(
      place,
      () => place.contains(", ") ? place.split(", ").last.trim() : "",
    );
  }

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.red.shade900;
    if (magnitude >= 5.0) return Colors.orange;
    return Colors.green;
  }

  // --- Snackbar & Dialog Helpers (Pass Context) ---
  void _showPullToRefreshSnackBar(BuildContext context) {
    if (_showPullToRefreshSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pull down to refresh'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _hidePullToRefreshSnackBar(BuildContext context) {
    if (_showPullToRefreshSnackbar && mounted) {
      _showPullToRefreshSnackbar = false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _showLocationSuccessSnackBar(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location updated'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLocationErrorDialog(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Error'),
            content: const Text(
              'Unable to fetch your location. Please check permissions and ensure location services are enabled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showLocationServicesDisabledDialog(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services on your device to use distance features.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openLocationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}
