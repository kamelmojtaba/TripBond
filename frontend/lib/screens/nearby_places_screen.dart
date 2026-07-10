import 'package:flutter/material.dart';
import '../services/places_service.dart';
import '../models/place_model.dart';
import '../widgets/place_image_carousel.dart';
import '../utils/place_navigation.dart';

class NearbyPlacesScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? title;

  const NearbyPlacesScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.title,
  }) : super(key: key);

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen> {
  final PlacesService _placesService = PlacesService();

  PlacesSearchResponse? _nearbyPlaces;
  bool _isLoading = true;
  String? _error;
  int _selectedRadius = 5000; // 5km default
  String? _selectedType;

  final Map<String, String> _placeTypes = {
    'All': '',
    'Restaurants': 'catering',
    'Shopping': 'shopping',
    'Accommodation': 'accommodation',
    'Tourism': 'tourism',
    'Entertainment': 'entertainment',
  };

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _placesService.getNearbyPlaces(
        latitude: widget.latitude,
        longitude: widget.longitude,
        radius: _selectedRadius,
        type: _selectedType?.isNotEmpty ?? false ? _selectedType : null,
      );
      setState(() {
        _nearbyPlaces = results;
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
        title: Text(widget.title ?? 'Nearby Places'),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Radius:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [1000, 2000, 5000, 10000]
                        .map((radius) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text('${radius ~/ 1000}km'),
                                selected: _selectedRadius == radius,
                                onSelected: (selected) {
                                  setState(() => _selectedRadius = radius);
                                  _loadNearbyPlaces();
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Type:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _placeTypes.entries
                        .map((entry) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(entry.key),
                                selected: _selectedType == entry.value,
                                onSelected: (selected) {
                                  setState(() => _selectedType = entry.value);
                                  _loadNearbyPlaces();
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          // Results
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_nearbyPlaces != null)
            Expanded(
              child: _buildPlacesList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlacesList() {
    final places = _nearbyPlaces!.results;

    if (places.isEmpty) {
      return const Center(
        child: Text('No places found nearby'),
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
    final distance = _calculateDistance(place);
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaceImageCarousel(
            images: images,
            height: 150,
            showAttribution: images.isNotEmpty,
          ),
          ListTile(
            title: Text(place.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (place.formattedAddress != null)
                  Text(
                    place.formattedAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (distance != null)
                      Text(
                        '${distance.toStringAsFixed(1)}m away',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(width: 16),
                    if (place.rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(place.rating!.toString(),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.location_on),
            onTap: () => openPlacePreviewFromResult(context, place),
          ),
        ],
      ),
    );
  }

  double? _calculateDistance(PlaceResult place) {
    if (place.geometry == null) return null;

    const earthRadiusMeters = 6371000;
    final lat1 = _degreesToRadians(widget.latitude);
    final lat2 = _degreesToRadians(place.geometry!.lat);
    final deltaLat = _degreesToRadians(place.geometry!.lat - widget.latitude);
    final deltaLng = _degreesToRadians(place.geometry!.lng - widget.longitude);

    final a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
        Math.cos(lat1) *
            Math.cos(lat2) *
            Math.sin(deltaLng / 2) *
            Math.sin(deltaLng / 2);
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) =>
      degrees * (3.141592653589793 / 180);
}

// Simple Math class to avoid dependency
class Math {
  static double sin(double x) => _sin(x);
  static double cos(double x) => _cos(x);
  static double sqrt(double x) => x.toDouble() < 0 ? 0 : _sqrt(x);
  static double atan2(double y, double x) => _atan2(y, x);

  static double _sin(double x) {
    // Simplified sin approximation
    x = x % (2 * 3.141592653589793);
    return (4 * x * (3.141592653589793 - x)) /
        (3.141592653589793 * 3.141592653589793 +
            4 * x * (3.141592653589793 - x));
  }

  static double _cos(double x) => _sin(3.141592653589793 / 2 - x);

  static double _sqrt(double x) {
    if (x < 0) return 0;
    double res = x;
    while ((res * res - x).abs() > 0.0001) {
      res = (res + x / res) / 2;
    }
    return res;
  }

  static double _atan2(double y, double x) {
    if (x > 0) {
      return _atan(y / x);
    } else if (x < 0 && y >= 0) {
      return _atan(y / x) + 3.141592653589793;
    } else if (x < 0 && y < 0) {
      return _atan(y / x) - 3.141592653589793;
    } else if (x == 0 && y > 0) {
      return 3.141592653589793 / 2;
    } else if (x == 0 && y < 0) {
      return -3.141592653589793 / 2;
    }
    return 0;
  }

  static double _atan(double x) {
    double res = 0;
    double pow = x;
    res = pow;
    for (int i = 1; i < 13; i++) {
      pow *= -x * x * (2 * i - 1) / (2 * i + 1);
      res += pow / (2 * i + 1);
    }
    return res;
  }
}
