import 'package:flutter/material.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/presentation/providers/bookmark_provider.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/utils/formatting.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:lastquakes/widgets/earthquake_list_item.dart';
import 'package:provider/provider.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LastQuakesAppBar(title: "Saved Earthquakes"),
      body: Consumer<BookmarkProvider>(
        builder: (context, bookmarkProvider, child) {
          if (bookmarkProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = bookmarkProvider.bookmarks;

          if (bookmarks.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () => bookmarkProvider.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final earthquake = bookmarks[index];
                return _buildBookmarkItem(
                  context,
                  earthquake,
                  bookmarkProvider,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "No Saved Earthquakes",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the bookmark icon on any earthquake to save it for quick access later.",
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkItem(
    BuildContext context,
    Earthquake earthquake,
    BookmarkProvider provider,
  ) {
    final magnitudeColor = _getMagnitudeColor(earthquake.magnitude);

    return Dismissible(
      key: Key(earthquake.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Remove Bookmark"),
                content: const Text(
                  "Are you sure you want to remove this earthquake from your saved list?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      "Remove",
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),
                ],
              ),
        );
      },
      onDismissed: (direction) {
        provider.removeBookmark(earthquake.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Bookmark removed"),
            action: SnackBarAction(
              label: "Undo",
              onPressed: () => provider.toggleBookmark(earthquake),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: EarthquakeListItem(
        location: earthquake.place,
        magnitude: earthquake.magnitude,
        magnitudeColor: magnitudeColor,
        timestamp: earthquake.time,
        distanceKm: null,
        source: earthquake.source,
        formattedLocation: FormattingUtils.formatPlaceString(
          context,
          earthquake.place,
        ),
        formattedTime: FormattingUtils.formatDateTime(context, earthquake.time),
        formattedDistance: "Bookmarked",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EarthquakeDetailsScreen(earthquake: earthquake),
            ),
          );
        },
      ),
    );
  }

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 8.0) return Colors.red.shade900;
    if (magnitude >= 7.0) return Colors.red.shade700;
    if (magnitude >= 6.0) return Colors.orange.shade800;
    if (magnitude >= 5.0) return Colors.amber.shade700;
    return Colors.green.shade600;
  }
}
