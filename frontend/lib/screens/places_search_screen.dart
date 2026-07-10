import 'package:flutter/material.dart';
import '../services/places_service.dart';
import '../models/place_model.dart';
import '../widgets/place_image_carousel.dart';
import '../utils/place_navigation.dart';

class PlacesSearchScreen extends StatefulWidget {
  const PlacesSearchScreen({Key? key}) : super(key: key);

  @override
  State<PlacesSearchScreen> createState() => _PlacesSearchScreenState();
}

class _PlacesSearchScreenState extends State<PlacesSearchScreen> {
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();

  PlacesSearchResponse? _searchResults;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    if (_searchController.text.isEmpty) {
      setState(() => _error = 'Please enter a search query');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _placesService.searchPlaces(
        query: _searchController.text,
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Places'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for places (e.g., "restaurants in Paris")',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchPlaces,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _searchPlaces(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults != null)
            Expanded(
              child: _buildPlacesList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlacesList() {
    final places = _searchResults!.results;

    if (places.isEmpty) {
      return const Center(
        child: Text('No places found'),
      );
    }

    return ListView.builder(
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return _buildPlaceCard(place);
      },
    );
  }

  Widget _buildPlaceCard(PlaceResult place) {
    final images = [
      ...place.images.map(
        (image) => PlaceImageData(
          url: image.url,
          attributions: image.attributions,
        ),
      ),
      if (place.imageUrl != null &&
          place.imageUrl!.isNotEmpty &&
          !place.images.any((image) => image.url == place.imageUrl))
        PlaceImageData(url: place.imageUrl!),
    ];

    return InkWell(
      onTap: () => openPlacePreviewFromResult(context, place),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaceImageCarousel(
            images: images,
            height: 200,
            showAttribution: images.isNotEmpty,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4675B8),
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 8),
                if (place.formattedAddress != null)
                  Text(
                    place.formattedAddress!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (place.geometry != null)
                      Text(
                        '📍 ${place.geometry!.lat.toStringAsFixed(4)}, ${place.geometry!.lng.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    const Spacer(),
                    if (place.rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(place.rating!.toString()),
                        ],
                      ),
                  ],
                ),
                if (place.types.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: place.types
                        .take(3)
                        .map(
                          (type) => Chip(
                            label: Text(type),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        )
                        .toList(),
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
