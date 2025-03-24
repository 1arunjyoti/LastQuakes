import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:lastquake/screens/earthquake_details.dart';
//import 'package:lastquake/screens/earthquake_map_screen.dart';
import '../services/api_service.dart';

class EarthquakeListScreen extends StatefulWidget {
  final List? earthquakes; // Receive the data from NavigationHandler

  const EarthquakeListScreen({Key? key, this.earthquakes}) : super(key: key);

  @override
  _EarthquakeListScreenState createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {
  //List earthquakes = [];
  List filteredEarthquakes = [];
  //bool isLoading = true;
  //bool hasError = false;
  bool showFilters = true;
  bool isRefreshing = false;

  String selectedCountry = "All";
  double selectedMagnitude = 3.0;
  List<String> countryList = ["All"];
  List<double> magnitudeOptions = [3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];

  late ScrollController _scrollController;
  //int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    //fetchEarthquakes(isInitialLoad: true);
    _scrollController = ScrollController()..addListener(_onScroll);
    if (widget.earthquakes != null) {
      countryList = ["All"] + getUniqueCountries(widget.earthquakes!);
      filterEarthquakes(widget.earthquakes!);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (showFilters) {
        setState(() {
          showFilters = false;
        });
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!showFilters) {
        setState(() {
          showFilters = true;
        });
      }
    }
  }

  /// Fetch earthquake data from API and update UI
  Future<void> fetchEarthquakes({bool isPullToRefresh = false}) async {
    if (isPullToRefresh) {
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      final newData = await ApiService.fetchEarthquakes(
        minMagnitude: selectedMagnitude,
        days: 45,
      );
      if (mounted) {
        setState(() {
          countryList = ["All"] + getUniqueCountries(newData);
          filterEarthquakes(newData);
          isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  List<String> getUniqueCountries(List data) {
    Set<String> countries = {};
    for (var quake in data) {
      String country = extractCountry(quake["properties"]["place"] ?? "");
      if (country.isNotEmpty) {
        countries.add(country);
      }
    }
    return countries.toList()..sort();
  }

  String extractCountry(String place) {
    return place.contains(", ") ? place.split(", ").last.trim() : "";
  }

  void filterEarthquakes(List earthquakesToFilter) {
    setState(() {
      filteredEarthquakes =
          earthquakesToFilter.where((quake) {
            return filterByMagnitude(quake) && filterByCountry(quake);
          }).toList();
    });
  }

  bool filterByMagnitude(Map quake) {
    var mag = quake["properties"]["mag"];
    double magnitude = double.tryParse(mag.toString()) ?? 0.0; //Safer parsing
    return magnitude >= selectedMagnitude;
  }

  bool filterByCountry(Map quake) {
    String place = quake["properties"]["place"] ?? "";
    String country = extractCountry(place);
    return selectedCountry == "All" || country == selectedCountry;
  }

  Color getMagnitudeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.red.shade900;
    if (magnitude >= 5.0) return Colors.orange;
    return Colors.green;
  }

  //bool get wantKeepAlive => true; // Keep the state alive

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(251, 248, 239, 1),
        title: Text(
          "LastQuakes",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body:
          widget.earthquakes == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Animated Filter Section (Hides when scrolling)
                  AnimatedSlide(
                    offset: showFilters ? Offset(0, 0) : Offset(0, -1),
                    duration: Duration(milliseconds: 200),
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: 200),
                      opacity: showFilters ? 1.0 : 0.0,
                      child: Visibility(
                        visible: showFilters,
                        child: buildFilterSection(),
                      ),
                    ),
                  ),

                  // Earthquake Count Display
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      "Total Earthquakes: ${filteredEarthquakes.length}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Earthquake List with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => fetchEarthquakes(isPullToRefresh: true),
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            itemCount: filteredEarthquakes.length,
                            itemBuilder: (context, index) {
                              final quake =
                                  filteredEarthquakes[index]["properties"];
                              double magnitude =
                                  (quake["mag"] is int)
                                      ? (quake["mag"] as int).toDouble()
                                      : (quake["mag"] ?? 0.0);
                              final time = DateTime.fromMillisecondsSinceEpoch(
                                quake["time"],
                              );

                              return Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: getMagnitudeColor(
                                      magnitude,
                                    ),
                                    child: Text(
                                      magnitude.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    quake["place"] ?? "Unknown location",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat.yMMMd().add_jm().format(time),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (
                                              context,
                                            ) => EarthquakeDetailsScreen(
                                              quakeData:
                                                  filteredEarthquakes[index],
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          /* if (isRefreshing)
                            const Center(child: CircularProgressIndicator()), */
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      /* bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        EarthquakeMapScreen(earthquakes: filteredEarthquakes),
              ),
            );
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
      ), */
    );
  }

  /// Build the Filter Section
  Widget buildFilterSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Country Filter Dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedCountry,
              isExpanded: true,
              decoration: InputDecoration(
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
                setState(() {
                  selectedCountry = value!;
                  filterEarthquakes(widget.earthquakes!);
                });
              },
            ),
          ),
          SizedBox(width: 12),

          // Magnitude Filter Dropdown
          Expanded(
            child: DropdownButtonFormField<double>(
              value: selectedMagnitude,
              decoration: InputDecoration(
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
                setState(() {
                  selectedMagnitude = value!;
                  filterEarthquakes(widget.earthquakes!);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
