import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/earthquake_list_item.dart';
import '../services/api_service.dart';

// --- Top-level function for Isolate Processing ---
// LocationService cannot be directly used here. Pass necessary primitives.
Map<String, dynamic> _filterAndSortEarthquakesIsolate(
  Map<String, dynamic> args,
) {
  final List<Map<String, dynamic>> inputList = args['list'];
  final double minMagnitude = args['minMagnitude'];
  final String countryFilter = args['countryFilter'];
  final double? userLat = args['userLat'];
  final double? userLon = args['userLon'];

  List<Map<String, dynamic>> correctlyTypedInput =
      inputList.whereType<Map<String, dynamic>>().toList();

  // Extract unique countries while filtering
  Set<String> uniqueCountries = {};

  final List<Map<String, dynamic>> filteredList =
      correctlyTypedInput
          .where((quake) {
            final properties = quake["properties"];
            if (properties is! Map) return false;

            final magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;
            final place = properties["place"] as String? ?? "";
            // Extract country and add to set
            final String country =
                place.contains(", ") ? place.split(", ").last.trim() : "";
            if (country.isNotEmpty) {
              uniqueCountries.add(country);
            }

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

            // --- Distance Calculation in Isolate (Adds Overhead) ---
            if (userLat != null && userLon != null) {
              final geometry = currentQuake["geometry"];
              if (geometry is Map && geometry["coordinates"] is List) {
                final coordinates = geometry["coordinates"] as List;
                if (coordinates.length >= 2 &&
                    coordinates[0] is num &&
                    coordinates[1] is num) {
                  final double longitude = coordinates[0].toDouble();
                  final double latitude = coordinates[1].toDouble();
                  final distance =
                      Geolocator.distanceBetween(
                        userLat,
                        userLon,
                        latitude,
                        longitude,
                      ) /
                      1000.0; // km
                  properties["distance"] = distance.round();
                  currentQuake["properties"] = properties;
                }
              }
            }

            return currentQuake;
          })
          .toList();

  // Sort by time
  filteredList.sort((a, b) {
    int timeA = (a["properties"]?["time"] as int?) ?? 0;
    int timeB = (b["properties"]?["time"] as int?) ?? 0;
    return timeB.compareTo(timeA);
  });

  // Convert the result to a map containing both the filtered list and unique countries
  return {
    'filteredList': filteredList,
    'uniqueCountries': uniqueCountries.toList()..sort(),
  };
}

class EarthquakeListScreen extends StatefulWidget {
  const EarthquakeListScreen({super.key});

  @override
  State<EarthquakeListScreen> createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {

  // State Variables
  List<Map<String, dynamic>> _unfilteredEarthquakes =
      []; // Holds data from API fetch
  List<Map<String, dynamic>> allEarthquakes = []; // FILTERED list

  bool showFilters = false;
  bool isRefreshing = false;
  bool _showPullToRefreshSnackbar = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isLoading = true;
  bool _isFiltering = false;
  String? _error;

  // --- Scroll handling ---
  bool _snackbarHiddenOnScroll = false;
  bool _initialSnackbarShown =
      false; // guard to show snackbar only once per screen load

  // --- Filter animation tuning ---
  Duration _filterAnimDuration = const Duration(milliseconds: 220);
  Curve _filterAnimCurve = Curves.easeInOut;

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

  // Debounce timer for filter changes
  Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    // automatic location fetching
    //_fetchUserLocation();

    // Fetch initial data when screen loads
    _fetchAndSetInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterDebounce?.cancel();
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

      // Apply filters using compute
      await _applyFiltersWithCompute(); 
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
    });

    final args = {
      'list': _unfilteredEarthquakes,
      'minMagnitude': selectedMagnitude,
      'countryFilter': selectedCountry,
      'userLat': _userPosition?.latitude,
      'userLon': _userPosition?.longitude,
    };

    try {
      final Map<String, dynamic> result = await compute(
        _filterAndSortEarthquakesIsolate,
        args,
      );

      if (!mounted) return;

      setState(() {
        allEarthquakes = result['filteredList'] as List<Map<String, dynamic>>;
        // Update country list with the results from isolate
        countryList = ["All"] + (result['uniqueCountries'] as List<String>);
        _currentPage = 1;
        _hasMoreData = allEarthquakes.length > _itemsPerPage;
        _isLoading = false;
        isRefreshing = false;
        _isFiltering = false;
      });

      // Show the pull-to-refresh snackbar once after the list is ready (not during loading)
      if (mounted &&
          !_initialSnackbarShown &&
          _error == null &&
          _showPullToRefreshSnackbar) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showPullToRefreshSnackBar(context);
            _initialSnackbarShown = true; // don't schedule again
          }
        });
      }
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
    // Debounce to prevent back-to-back isolates while changing filters
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyFiltersWithCompute(); 
      _scrollToTop();
    });
  }

  void _onCountryChanged(String? value) {
    if (value == null || value == selectedCountry) return;
    setState(() {
      selectedCountry = value;
    });
    _onFilterChanged(); 
  }

  void _onMagnitudeChanged(double? value) {
    if (value == null || value == selectedMagnitude) return;
    setState(() {
      selectedMagnitude = value;
    });
    _onFilterChanged(); 
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
    final position = _scrollController.position;
    final direction = position.userScrollDirection;

    // Auto-dismiss filters when user scrolls down
    if (direction == ScrollDirection.reverse && showFilters) {
      setState(() {
        // Makes dismissal more gradual on downward scroll
        _filterAnimDuration = const Duration(milliseconds: 320); // Duration
        _filterAnimCurve = Curves.easeOutCubic;
        showFilters = false;
      });
    }

    // Hide Snackbar only once per scroll session
    if (_showPullToRefreshSnackbar &&
        !_snackbarHiddenOnScroll &&
        direction != ScrollDirection.idle) {
      _hidePullToRefreshSnackBar(context);
      _snackbarHiddenOnScroll = true;
    }

    // Lazy Loading Trigger
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreEarthquakes();
    }
  }

  // Load next page of earthquakes
  Future<void> _loadMoreEarthquakes() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    //await Future.delayed(const Duration(milliseconds: 500));

    final startIndex = _currentPage * _itemsPerPage;
    if (startIndex >= allEarthquakes.length) {
      if (mounted) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _currentPage++;
        _isLoadingMore = false;
        _hasMoreData = (_currentPage * _itemsPerPage) < allEarthquakes.length;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingMore = false;
        _hasMoreData = false;
      });
    }
  }

  // Scroll to top of list
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
          // Action buttons: Location & Filter
          IconButton(
            icon:
                _isLoadingLocation
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.my_location),
            onPressed: _isLoadingLocation ? null : _fetchUserLocation,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                // Use snappier animation when toggling via icon
                _filterAnimDuration = const Duration(milliseconds: 220);
                _filterAnimCurve = Curves.easeInOut;
                showFilters = !showFilters;
              });
            },
            tooltip: 'Filter',
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
          duration: _filterAnimDuration,
          curve: _filterAnimCurve,
          child: AnimatedOpacity(
            duration: _filterAnimDuration,
            curve: _filterAnimCurve,
            opacity: showFilters ? 1.0 : 0.0,
            child: ClipRect(
              child: AnimatedSize(
                duration: _filterAnimDuration,
                curve: _filterAnimCurve,
                child: Column(
                  children: [
                    if (showFilters) ...[
                      _buildFilterSection(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          "Earthquakes in the last 45 days: ${allEarthquakes.length}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox.shrink(),
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
                          (() {
                            final visibleCount = (_currentPage * _itemsPerPage);
                            final clampedCount =
                                visibleCount > allEarthquakes.length
                                    ? allEarthquakes.length
                                    : visibleCount;
                            return clampedCount +
                                (_isLoadingMore && _hasMoreData ? 1 : 0);
                          })(),
                      itemBuilder: (context, index) {
                        final visibleCount =
                            (_currentPage * _itemsPerPage) >
                                    allEarthquakes.length
                                ? allEarthquakes.length
                                : (_currentPage * _itemsPerPage);
                        if (index == visibleCount) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }

                        final quakeData = allEarthquakes[index];
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

  // --- Filter Section Widgets ---
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
    return SizedBox(
      height: 44,
      child: FilledButton.tonalIcon(
        onPressed: _showCountryPickerBottomSheet,
        icon: const Icon(Icons.public),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            selectedCountry == "All"
                ? "Region: All"
                : "Region: $selectedCountry",
            overflow: TextOverflow.ellipsis,
          ),
        ),
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildMagnitudeDropdown() {
    return SizedBox(
      height: 44,
      child: FilledButton.tonalIcon(
        onPressed: _showMagnitudePickerBottomSheet,
        icon: const Icon(Icons.speed),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text("Magnitude: ≥ ${selectedMagnitude.toStringAsFixed(1)}"),
        ),
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  // --- Utility Methods ---

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.red.shade900;
    if (magnitude >= 5.0) return Colors.orange;
    return Colors.green;
  }

  // --- Bottom Sheets for Filters ---
  void _showCountryPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final textController = TextEditingController();
        // Always keep 'All' pinned to the top; sort remaining items
        final List<String> initialCountries = [
          ...countryList.where((c) => c != 'All'),
        ]..sort();
        List<String> filtered = ['All', ...initialCountries];

        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyFilter(String query) {
              final q = query.trim().toLowerCase();
              setModalState(() {
                if (q.isEmpty) {
                  final rest =
                      countryList.where((c) => c != 'All').toList()..sort();
                  filtered = ['All', ...rest];
                } else {
                  final rest =
                      countryList
                          .where((c) => c != 'All')
                          .where((c) => c.toLowerCase().contains(q))
                          .toList()
                        ..sort();
                  // Keep 'All' pinned regardless of search
                  filtered = ['All', ...rest];
                }
              });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.public, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Select Region',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: textController,
                        onChanged: applyFilter,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search country/region',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final country = filtered[index];
                          final selected = country == selectedCountry;
                          return ListTile(
                            title: Text(country),
                            trailing:
                                selected
                                    ? Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                    )
                                    : null,
                            onTap: () {
                              Navigator.pop(context);
                              _onCountryChanged(country);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMagnitudePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Minimum Magnitude',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mag in magnitudeOptions)
                    ChoiceChip(
                      label: Text('≥ ${mag.toStringAsFixed(1)}'),
                      selected: selectedMagnitude == mag,
                      onSelected: (_) {
                        Navigator.pop(context);
                        _onMagnitudeChanged(mag);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- Snackbar & Dialog Helpers ---
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
