import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<dynamic> _newsList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchEarthquakeNews();
  }

  Future<void> _fetchEarthquakeNews() async {
    try {
      // More precise earthquake-related keywords
      final searchTerms = [
        'major earthquake',
        'earthquake disaster',
        'seismic activity',
        'earthquake damage',
        'earthquake impact',
        'earthquake emergency',
        'earthquake',
        'seismic activity',
        'natural disaster',
        'geological event',
      ];

      // Construct a complex query to filter out generic news
      final query = searchTerms
          .map((term) => '(${term.replaceAll('"', '')})')
          .join(' OR ');

      // Replace with your actual API endpoint and key
      final apiKey = '2cf1e26ccff64243b30eaea7b31a6194';
      final url = Uri.parse(
        'https://newsapi.org/v2/everything?q=weather&language=en&sortBy=publishedAt&apiKey=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          // Filter out articles with no image or description
          _newsList =
              (data['articles'] as List? ?? [])
                  .where(
                    (article) =>
                        article['urlToImage'] != null &&
                        article['description'] != null &&
                        article['description'].toString().isNotEmpty,
                  )
                  .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load news');
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to fetch earthquake news. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null) return;

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
    }
  }

  Widget _buildNewsCard(dynamic article) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _launchUrl(article['url']),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: article['urlToImage'] ?? '',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                errorWidget:
                    (context, url, error) => const Icon(Icons.error_outline),
              ),
            ),

            // Article Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article['title'] ?? 'No Title',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article['description'] ?? 'No description available',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPublishDate(article['publishedAt']),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      Text(
                        article['source']['name'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPublishDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final DateTime dateTime = DateTime.parse(dateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earthquake News'), centerTitle: true),
      drawer: const CustomDrawer(),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchEarthquakeNews,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _newsList.isEmpty
              ? const Center(child: Text('No earthquake news available'))
              : RefreshIndicator(
                onRefresh: _fetchEarthquakeNews,
                child: ListView.builder(
                  itemCount: _newsList.length,
                  itemBuilder: (context, index) {
                    return _buildNewsCard(_newsList[index]);
                  },
                ),
              ),
    );
  }
}
