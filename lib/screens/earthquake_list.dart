import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/earthquake_list_item.dart';
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

  List allEarthquakes = []; // Store all filtered earthquakes
  List displayedEarthquakes = []; // Store currently displayed earthquakes
  bool showFilters = true;
  bool isRefreshing = false;
  bool _showPullToRefreshSnackbar = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Pagination constants
  static const int _itemsPerPage = 20;
  int _currentPage = 1;

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
  Position? _userPosition;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // automatic location fetching
    //_fetchUserLocation();

    if (widget.earthquakes != null) {
      _initializeEarthquakeData(widget.earthquakes!);
    }

    // Show the initial snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPullToRefreshSnackBar();
    });
  }

  Future<void> _fetchUserLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    // Check if location services are enabled first
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationServicesDisabledDialog();
        return;
      }
    }

    try {
      // Force refresh location
      final position = await _locationService.getCurrentLocation(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLoadingLocation = false;
        });

        if (position != null) {
          // If earthquakes are already loaded, update distances
          if (widget.earthquakes != null) {
            _filterEarthquakes(widget.earthquakes!);
            _showLocationSuccessSnackBar();
          }
        } else {
          // No position retrieved
          _showLocationErrorDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationErrorDialog();
      }
    }
  }

  void _showLocationSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location updated successfully',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Access Failed'),
            content: const Text(
              'We couldn\'t retrieve your location. This could be due to:\n\n'
              '• Location services are turned off\n'
              '• App doesn\'t have permission to access location\n'
              '• Network or GPS issues',
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

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services on your device to use this feature. '
              'Go to your device settings and turn on location services.',
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

    // Hide the snackbar when scrolling starts
    if (_showPullToRefreshSnackbar &&
        currentScrollDirection != ScrollDirection.idle) {
      _hidePullToRefreshSnackBar();
    }

    // Implement lazy loading when scrolling to the bottom
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreEarthquakes();
    }
  }

  // Load more earthquakes for lazy loading
  Future<void> _loadMoreEarthquakes() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(Duration(milliseconds: 500)); // Simulate network delay

    final nextPage = _currentPage + 1;
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= allEarthquakes.length) {
      setState(() {
        _hasMoreData = false;
        _isLoadingMore = false;
      });
      return;
    }

    final nextItems = allEarthquakes.sublist(
      startIndex,
      endIndex > allEarthquakes.length ? allEarthquakes.length : endIndex,
    );

    if (mounted) {
      setState(() {
        displayedEarthquakes.addAll(nextItems);
        _currentPage = nextPage;
        _isLoadingMore = false;
        _hasMoreData = endIndex < allEarthquakes.length;
      });
    }
  }

  Future<void> _fetchEarthquakes({bool isPullToRefresh = false}) async {
    if (isPullToRefresh) {
      setState(() => isRefreshing = true);
    }

    try {
      // Force refresh when pull to refresh is triggered
      final newData = await ApiService.fetchEarthquakes(
        minMagnitude: selectedMagnitude,
        days: 45,
        forceRefresh: isPullToRefresh,
      );

      if (mounted) {
        setState(() {
          countryList = ["All"] + _getUniqueCountries(newData);
          _filterEarthquakes(newData);
          isRefreshing = false;
          // Reset pagination on refresh
          _currentPage = 1;
          _hasMoreData = true;
        });
      }
    } catch (e) {
      if (mounted) {
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch earthquakes: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
    final List filteredList =
        earthquakesToFilter.where((quake) {
          final properties = quake["properties"];
          final magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;
          final place = properties["place"] ?? "";
          final country = _extractCountry(place);

          // Add distance calculation
          if (_userPosition != null) {
            final geometry = quake["geometry"];
            if (geometry != null && geometry["coordinates"] is List) {
              final double longitude = geometry["coordinates"][0].toDouble();
              final double latitude = geometry["coordinates"][1].toDouble();

              final distance = _locationService.calculateDistance(
                _userPosition!.latitude,
                _userPosition!.longitude,
                latitude,
                longitude,
              );

              // Attach distance to properties for display
              properties["distance"] = distance.round();
            }
          }

          return magnitude >= selectedMagnitude &&
              (selectedCountry == "All" || country == selectedCountry);
        }).toList();

    // Sort by time (most recent first) if needed
    filteredList.sort((a, b) {
      return (b["properties"]["time"] as int) -
          (a["properties"]["time"] as int);
    });

    setState(() {
      allEarthquakes = filteredList;

      // Reset pagination
      _currentPage = 1;
      _hasMoreData = filteredList.length > _itemsPerPage;

      // Load only first page
      displayedEarthquakes = filteredList.take(_itemsPerPage).toList();
    });
  }

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.red.shade900;
    if (magnitude >= 5.0) return Colors.orange;
    return Colors.green;
  }

  // Function to show the "pull to refresh" snackbar
  void _showPullToRefreshSnackBar() {
    if (_showPullToRefreshSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pull down to refresh earthquake data'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Function to hide the "pull to refresh" snackbar
  void _hidePullToRefreshSnackBar() {
    if (_showPullToRefreshSnackbar) {
      _showPullToRefreshSnackbar = false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

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
            onPressed: _fetchUserLocation,
            tooltip: 'Refresh Location',
          ),
        ],
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
                      "Quakes in the last 45 days: ${allEarthquakes.length}",
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
                        itemCount:
                            displayedEarthquakes.length +
                            (_hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading indicator at the bottom
                          if (index == displayedEarthquakes.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            );
                          }

                          // Prepare data for the list item widget
                          final quakeData =
                              displayedEarthquakes[index]; // Full quake map
                          final properties = quakeData["properties"];
                          final magnitude =
                              (properties["mag"] as num?)?.toDouble() ?? 0.0;
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            properties["time"],
                          );
                          final String place =
                              properties["place"] ?? "Unknown location";
                          final Color magnitudeColor = _getMagnitudeColor(
                            magnitude,
                          );
                          final String formattedTime = DateFormat.yMMMd()
                              .add_jm()
                              .format(time);
                          final String distanceText =
                              "${properties["distance"] ?? 'N/A'} km from you";

                          return EarthquakeListItem(
                            location: place,
                            distanceText: distanceText,
                            formattedTime: formattedTime,
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
              ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Country Filter Dropdown
          Expanded(child: _buildCountryDropdown()),
          const SizedBox(width: 12),

          // Magnitude Filter Dropdown
          Expanded(child: _buildMagnitudeDropdown()),
        ],
      ),
    );
  }

  // Extracted Country Dropdown Method
  Widget _buildCountryDropdown() {
    // Memoize dropdown items to prevent unnecessary recreations
    final countryDropdownItems =
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
      menuMaxHeight: 500,
    );
  }

  // Extracted Magnitude Dropdown Method
  Widget _buildMagnitudeDropdown() {
    // Memoize dropdown items to prevent unnecessary recreations
    final magnitudeDropdownItems =
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

  // Separate method for country change to improve readability and performance
  void _onCountryChanged(String? value) {
    if (value == null) return;

    setState(() {
      selectedCountry = value;
      _filterEarthquakes(widget.earthquakes!);
    });
  }

  // Separate method for magnitude change
  void _onMagnitudeChanged(double? value) {
    if (value == null) return;

    setState(() {
      selectedMagnitude = value;
      _filterEarthquakes(widget.earthquakes!);
    });
  }

  // Add these as class-level variables to cache memoized items
  List<DropdownMenuItem<String>>? _memoizedCountryItems;
  List<DropdownMenuItem<double>>? _memoizedMagnitudeItems;
}
