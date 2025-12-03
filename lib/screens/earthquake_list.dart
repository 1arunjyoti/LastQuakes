import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:lastquake/presentation/providers/earthquake_provider.dart';
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/earthquake_list_item.dart';
import 'package:lastquake/utils/app_page_transitions.dart';
import 'package:provider/provider.dart';

class EarthquakeListScreen extends StatefulWidget {
  const EarthquakeListScreen({super.key});

  @override
  State<EarthquakeListScreen> createState() => _EarthquakeListScreenState();
}

class _EarthquakeListScreenState extends State<EarthquakeListScreen> {
  // UI State
  bool showFilters = false;
  bool _isScrolling = false;
  
  // Animation
  Duration _filterAnimDuration = const Duration(milliseconds: 220);
  Curve _filterAnimCurve = Curves.easeInOut;

  // Scroll Controller
  late ScrollController _scrollController;
  Timer? _filterDebounce;
  Timer? _scrollDebounce;
  
  // Constants for list item height (for itemExtent optimization)
  static const double _itemHeight = 120.0; // Approximate height of EarthquakeListItem

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterDebounce?.cancel();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    final direction = position.userScrollDirection;

    // Auto-dismiss filters with debounce to avoid setState during scroll
    if (direction == ScrollDirection.reverse && showFilters && !_isScrolling) {
      _isScrolling = true;
      // Use post-frame callback to avoid setState during scroll
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && showFilters) {
          setState(() {
            _filterAnimDuration = const Duration(milliseconds: 320);
            _filterAnimCurve = Curves.easeOutCubic;
            showFilters = false;
          });
        }
      });
      // Reset scrolling flag after a short delay
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 150), () {
        _isScrolling = false;
      });
    }

    // Lazy Loading - only trigger when not already loading
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      final provider = context.read<EarthquakeProvider>();
      if (!provider.listIsLoadingMore) {
        provider.loadMoreList();
      }
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
              setState(() {
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
      body: Consumer<EarthquakeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.listEarthquakes.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.error != null && provider.listEarthquakes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadData(forceRefresh: true),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildAnimatedFilterSection(provider),
              Expanded(
                child:
                    provider.listEarthquakes.isEmpty
                        ? const Center(
                          child: Text(
                            "No earthquakes found matching your criteria.",
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh:
                              () => provider.loadData(forceRefresh: true),
                          child: ListView.builder(
                            controller: _scrollController,
                            // Performance optimizations for high refresh rate displays
                            cacheExtent: 800, // Increased cache for smoother scrolling
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            // Use physics with reduced overscroll for smoother feel
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount:
                                provider.listVisibleEarthquakes.length +
                                (provider.listIsLoadingMore ? 1 : 0),
                            // Using prototypeItem for better performance than itemExtent
                            // when items have consistent but not exact heights
                            itemBuilder: (context, index) {
                              if (index ==
                                  provider.listVisibleEarthquakes.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator.adaptive(),
                                  ),
                                );
                              }

                              final earthquake =
                                  provider.listVisibleEarthquakes[index];
                              final distance = provider.getDistanceForQuake(
                                earthquake.id,
                              );

                              return RepaintBoundary(
                                child: EarthquakeListItem(
                                  location: earthquake.place,
                                  distanceKm: distance,
                                  timestamp: earthquake.time,
                                  magnitude: earthquake.magnitude,
                                  magnitudeColor: _getMagnitudeColor(
                                    earthquake.magnitude,
                                  ),
                                  source: earthquake.source,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      AppPageTransitions.scaleRoute(
                                        page: EarthquakeDetailsScreen(
                                          earthquake: earthquake,
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
          );
        },
      ),
    );
  }

  Widget _buildAnimatedFilterSection(EarthquakeProvider provider) {
    return AnimatedSlide(
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
                  _buildFilterSection(provider),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      "Earthquakes in the last 45 days: ${provider.listEarthquakes.length}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox.shrink(),
                if (provider.isListFiltering)
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
    );
  }

  Widget _buildFilterSection(EarthquakeProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildCountryDropdown(provider)),
          const SizedBox(width: 12),
          Expanded(child: _buildMagnitudeDropdown(provider)),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown(EarthquakeProvider provider) {
    return SizedBox(
      height: 44,
      child: FilledButton.tonalIcon(
        onPressed: () => _showCountryPickerBottomSheet(provider),
        icon: const Icon(Icons.public),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            provider.listSelectedCountry == "All"
                ? "Region: All"
                : "Region: ${provider.listSelectedCountry}",
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

  Widget _buildMagnitudeDropdown(EarthquakeProvider provider) {
    return SizedBox(
      height: 44,
      child: FilledButton.tonalIcon(
        onPressed: () => _showMagnitudePickerBottomSheet(provider),
        icon: const Icon(Icons.speed),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Magnitude: ≥ ${provider.listSelectedMagnitude.toStringAsFixed(1)}",
          ),
        ),
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.red.shade900;
    if (magnitude >= 5.0) return Colors.orange;
    return Colors.green;
  }

  void _showCountryPickerBottomSheet(EarthquakeProvider provider) {
    final countryList = provider.countryList;
    final List<String> initialCountries = [
      ...countryList.where((c) => c != 'All'),
    ]..sort();
    List<String> filtered = ['All', ...initialCountries];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 20,
                          right: 20,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.public, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Choose Region",
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.setListCountryFilter('All');
                                _scrollToTop();
                                Navigator.pop(context);
                              },
                              child: const Text("Reset"),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "Search region",
                            hintText: "Search country or area",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: theme.colorScheme.primary.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (query) {
                            final q = query.trim().toLowerCase();
                            setModalState(() {
                              if (q.isEmpty) {
                                final rest = countryList
                                    .where((c) => c != 'All')
                                    .toList()
                                      ..sort();
                                filtered = ['All', ...rest];
                              } else {
                                final rest = countryList
                                    .where(
                                      (c) =>
                                          c != 'All' &&
                                          c.toLowerCase().contains(q),
                                    )
                                    .toList()
                                      ..sort();
                                filtered = ['All', ...rest];
                              }
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.only(
                            top: 4,
                            bottom: 8,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (context, index) {
                            final country = filtered[index];
                            final isSelected =
                                country == provider.listSelectedCountry;
                            return ListTile(
                              title: Text(country),
                              trailing: isSelected
                                  ? Icon(Icons.check,
                                      color: theme.colorScheme.primary)
                                  : null,
                              onTap: () {
                                provider.setListCountryFilter(country);
                                Navigator.pop(context);
                                _scrollToTop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMagnitudePickerBottomSheet(EarthquakeProvider provider) {
    final List<double> magnitudeOptions = [3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.only(
            top: 18,
            left: 20,
            right: 20,
            bottom: 24,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.speed, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Minimum Magnitude",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      provider.setListMagnitudeFilter(3.0);
                      Navigator.pop(context);
                      _scrollToTop();
                    },
                    child: const Text("Reset"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: magnitudeOptions.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final mag = magnitudeOptions[index];
                    final isSelected = mag == provider.listSelectedMagnitude;
                    return ListTile(
                      leading: const Icon(Icons.show_chart),
                      title: Text("Magnitude ≥ ${mag.toStringAsFixed(1)}"),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        provider.setListMagnitudeFilter(mag);
                        Navigator.pop(context);
                        _scrollToTop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
