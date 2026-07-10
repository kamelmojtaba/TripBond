import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/poi_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../widgets/place_image_carousel.dart';
import '../utils/place_navigation.dart';

class POIExplorerScreen extends StatefulWidget {
  const POIExplorerScreen({super.key});

  @override
  State<POIExplorerScreen> createState() => _POIExplorerScreenState();
}

class _POIExplorerScreenState extends State<POIExplorerScreen> {
  final _poiService = POIService();
  final _aiService = AIService();
  final _authService = AuthService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> pois = [];
  List<AIRecommendation> aiRecommendations = [];
  bool isLoading = false;
  bool isLoadingAI = false;
  String? errorMessage;
  String selectedCategory = 'All';
  bool showAIRecommendations = false;

  final Map<String, String> categories = {
    'All': '',
    'Attractions': 'attraction',
    'Restaurants': 'restaurant',
    'Hotels': 'hotel',
    'Shopping': 'shopping',
    'Entertainment': 'entertainment',
  };

  @override
  void initState() {
    super.initState();
    _loadPOIs();
  }

  Future<void> _loadPOIs() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final results = await _poiService.searchPOIs(
        type: selectedCategory != 'All' ? categories[selectedCategory] : null,
        location:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        limit: 50,
      );

      // Try to load AI recommendations
      _loadAIRecommendations();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadAIRecommendations() async {
    try {
      setState(() => isLoadingAI = true);

      final userId = await _authService.getUserId();
      if (userId != null && userId.isNotEmpty) {
        final recs = await _aiService.getUserRecommendations(
          userId: userId,
          topK: 10,
          category:
              selectedCategory != 'All' ? categories[selectedCategory] : null,
        );

        if (!mounted) return;
        setState(() {
          aiRecommendations = recs;
          isLoadingAI = false;
        });
      } else {
        setState(() => isLoadingAI = false);
      }
    } catch (e) {
      print('[POIExplorer] AI recommendations error: $e');
      setState(() => isLoadingAI = false);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Explore Places'),
        backgroundColor: const Color(0xFF4675B8),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadPOIs();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _loadPOIs(),
            ),
          ),
          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.keys.map((category) {
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => selectedCategory = category);
                      _loadPOIs();
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF4675B8).withOpacity(0.2),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF4675B8)
                          : Colors.grey[300]!,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // POI list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text('Error: $errorMessage'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPOIs,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : pois.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_off_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No places found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: pois.length,
                            itemBuilder: (context, index) {
                              final poi = pois[index];
                              return _POICard(poi: poi);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _POICard extends StatelessWidget {
  final Map<String, dynamic> poi;

  const _POICard({required this.poi});

  @override
  Widget build(BuildContext context) {
    final name = poi['name'] ?? 'Unknown';
    final type = poi['type'] ?? 'Place';
    final rating = poi['rating'] as num?;
    final reviews = poi['user_ratings_total'] as int? ?? 0;
    final address = poi['address'] ?? 'No address';
    final images = placeImagesFromMap(poi);
    final googleMapsUrl = (poi['google_maps_url'] ?? poi['url'] ?? '').toString();

    return InkWell(
      onTap: () => openPlacePreviewFromMap(context, poi),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaceImageCarousel(
            images: images,
            height: 180,
            showAttribution: images.isNotEmpty,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4675B8).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFF4675B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4675B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (reviews > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$reviews reviews',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
                if (googleMapsUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(googleMapsUrl);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Open in Google Maps'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
