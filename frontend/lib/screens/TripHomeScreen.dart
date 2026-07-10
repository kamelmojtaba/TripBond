import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/trip_service.dart';
import '../services/auth_service.dart';
import '../services/poi_service.dart';
import '../core/api_config.dart';
import '../core/api_service.dart';
import 'DestinationLandingPage.dart';
import 'profile.dart';
import 'group_suggested_itinerary.dart';
import 'AI_Plan.dart';
import 'Bonder.dart';
import 'plans_list.dart';
import 'voting_screen.dart';
import 'trip_places_picker_screen.dart';
import '../widgets/place_image_carousel.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/place_navigation.dart';

class TripHomeScreen extends StatefulWidget {
  final String? tripId;
  final String? destination;
  final String? tripTitle;

  const TripHomeScreen({
    super.key,
    this.tripId,
    this.destination,
    this.tripTitle,
  });

  @override
  State<TripHomeScreen> createState() => _TripHomeScreenState();
}

class _TripHomeScreenState extends State<TripHomeScreen>
    with SingleTickerProviderStateMixin {
  final _tripService = TripService();
  final _authService = AuthService();
  final _poiService = POIService();

  List<Map<String, dynamic>> _allPlaces = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTripPlaces();
  }


  Future<void> _loadTripPlaces() async {
    try {
      setState(() => _isLoading = true);

      final destination = widget.destination ?? 'Unknown';
      
      try {
        // Fetch places from Google Maps API via POI Service
        final places = await _poiService.searchPOIs(
          location: destination,
          limit: 100,
        );

        if (places.isNotEmpty) {
          setState(() {
            _allPlaces = places;
            _isLoading = false;
          });
        } else {
          // If no places from API, show a message but don't fail
          setState(() {
            _allPlaces = [];
            _error = 'No recommendations found for $destination';
            _isLoading = false;
          });
        }
      } catch (apiError) {
        // If API fails, show error but allow screen to display
        print('POI Service Error: $apiError');
        setState(() {
          _allPlaces = [];
          _error = 'Unable to fetch recommendations';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    return AppBottomNav(
      currentTab: AppNavTab.search,
      planBuilder: (_) => GroupSuggestedItinerary(
        tripId: widget.tripId,
        destination: widget.destination,
        tripTitle: widget.tripTitle,
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavigationItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.location_on),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.airplanemode_active),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.group),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: '',
      ),
    ];
  }


  Future<void> _showAddToTripSheet(Map<String, dynamic> place) async {
    if (widget.tripId == null || widget.tripId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open this from a trip to add places.')),
      );
      return;
    }
    final name = place['name']?.toString() ?? 'Place';
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Add to my list'),
              subtitle: const Text('Other members can vote on it'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _addPlaceToMyList(place);
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_vote_outlined),
              title: const Text('Open voting'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VotingScreen(
                    tripId: widget.tripId!,
                    tripTitle: widget.tripTitle ?? 'Trip',
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPlaceToMyList(Map<String, dynamic> place) async {
    try {
      final lat = (place['latitude'] ??
              place['lat'] ??
              place['geometry']?['location']?['lat'])
          ?.toDouble();
      final lng = (place['longitude'] ??
              place['lng'] ??
              place['geometry']?['location']?['lng'])
          ?.toDouble();
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This place is missing coordinates.')),
        );
        return;
      }
      final payload = <String, dynamic>{
        'name': place['name'],
        'address': place['address'] ?? place['formatted_address'] ?? '',
        'latitude': lat,
        'longitude': lng,
        'rating': place['rating'],
        'user_ratings_total': place['user_ratings_total'],
        'types': place['types'] ?? place['place_types'] ?? [],
        'image_url': place['image_url'],
        'photo_url': place['image_url'],
        'images': place['images'] ?? [],
        'external_place_id': place['place_id'] ?? place['external_place_id'],
      };
      final result = await _tripService.addPlaceToTrip(widget.tripId!, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: (widget.tripId != null && widget.tripId!.isNotEmpty)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'fab-pick',
                  backgroundColor: const Color(0xFFC4A44A),
                  icon: const Icon(Icons.add_location_alt_outlined,
                      color: Colors.white),
                  label: const Text('Pick places',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TripPlacesPickerScreen(
                        tripId: widget.tripId!,
                        destination: widget.destination ?? '',
                        tripTitle: widget.tripTitle ?? 'Trip',
                        goToVotingAfter: false,
                      ),
                    ));
                  },
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'fab-vote',
                  backgroundColor: const Color(0xFF4675B8),
                  icon: const Icon(Icons.how_to_vote, color: Colors.white),
                  label: const Text('Voting',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VotingScreen(
                        tripId: widget.tripId!,
                        tripTitle: widget.tripTitle ?? 'Trip',
                      ),
                    ));
                  },
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Discover Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    'Discover ${widget.destination ?? "Places"}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Places Grid
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text('Error: $_error'),
                                ],
                              ),
                            )
                          : _allPlaces.isEmpty
                              ? const Center(child: Text('No places found'))
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2.0,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                  ),
                                  itemCount: _allPlaces.length,
                                  itemBuilder: (context, index) {
                                    final place = _allPlaces[index];
                                    return _buildPlaceCard(place);
                                  },
                                ),
                ),
                // Top Place Section removed - now in Popular tab only
              ],
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    // Handle multiple possible field names from different APIs
    final images = placeImagesFromMap(place);
    final name = place['name'] as String? ?? 'Unknown';
    final rating = place['rating'] as num? ?? 0;
    final description = place['description'] as String? ?? 
                       place['summary'] as String? ?? '';
    final address = place['address'] as String? ?? 
                    place['formatted_address'] as String? ?? 
                    place['vicinity'] as String? ?? '';
    final placeType = place['type'] as String? ?? 
                      place['category'] as String? ?? 'Place';
    final googleMapsUrl = (place['google_maps_url'] ?? place['url'] ?? '').toString();

    return GestureDetector(
      onTap: () => openPlacePreviewFromMap(
        context,
        place,
        tripId: widget.tripId,
        fallbackLocation: widget.destination,
        extraActions: widget.tripId != null && widget.tripId!.isNotEmpty
            ? [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddToTripSheet(place);
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add to trip'),
                  ),
                ),
              ]
            : null,
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlaceImageCarousel(
              images: images,
              height: 80,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              showAttribution: images.isNotEmpty,
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4675B8).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            placeType,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4675B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (googleMapsUrl.isNotEmpty)
                              IconButton(
                                onPressed: () => _openExternalUrl(googleMapsUrl),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                color: const Color(0xFF4675B8),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ElevatedButton(
                              onPressed: () => _addPlaceToItinerary(place),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4675B8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _hasValidCoordinates(Map<String, dynamic> place) {
    final lat = place['latitude'];
    final lon = place['longitude'];
    
    // Coordinates are valid if they exist and are not 0
    bool latValid = lat != null && (lat is num) && lat != 0.0;
    bool lonValid = lon != null && (lon is num) && lon != 0.0;
    
    return latValid && lonValid;
  }
  
  Map<String, double> _getCoordinatesWithFallback(Map<String, dynamic> place, String destination) {
    final lat = place['latitude'];
    final lon = place['longitude'];
    
    // Use actual coordinates if available
    if (lat != null && (lat is num) && lat != 0.0 &&
        lon != null && (lon is num) && lon != 0.0) {
      return {
        'latitude': (lat as num).toDouble(),
        'longitude': (lon as num).toDouble(),
      };
    }
    
    // Fallback: Use destination center coordinates (Jeddah example: 21.5426, 39.1725)
    // For Jeddah
    if (destination.toLowerCase().contains('jeddah')) {
      return {
        'latitude': 21.5426,
        'longitude': 39.1725,
      };
    }
    
    // Generic fallback (could improve with geocoding API)
    return {
      'latitude': 0.0,
      'longitude': 0.0,
    };
  }

  Future<void> _addPlaceToItinerary(Map<String, dynamic> place) async {
    try {
      final name = place['name'] as String? ?? 'Unknown Place';
      final address = place['location'] as String? ?? '';
      final rating = place['rating'] as num? ?? 0.0;
      final userRatingsTotal = place['review_count'] as int? ?? 0;
      
      // Get coordinates with fallback to destination center if missing
      final coords = _getCoordinatesWithFallback(place, widget.destination ?? 'Jeddah');
      final latitude = coords['latitude']!;
      final longitude = coords['longitude']!;

      // Build itinerary item with backend expected fields
      // API returns 'type' (singular), backend endpoint expects 'types' (list)
      final placeType = place['type'] as String? ?? 'attraction';
      
      final placeData = {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'rating': rating,
        'user_ratings_total': userRatingsTotal,
        'types': [placeType],  // Convert single type to list
        'image_url': place['image_url'] ?? '',
        'photo_url': place['image_url'] ?? '',
        'images': place['images'] ?? [],
      };

      // Suggest place to Bonders Suggestions (AI will evaluate)
      await _tripService.suggestPlaceForTrip(
        widget.tripId ?? '',
        placeData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $name added'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error suggesting place: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
