import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'DestinationLandingPage.dart';
import 'Bonder.dart';
import 'profile.dart';
import 'group_suggested_itinerary.dart';
import 'plans_list.dart';
import 'BondersSuggestions.dart';
import '../services/trip_service.dart';
import '../providers/user_provider.dart';
import '../widgets/place_image_carousel.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/place_navigation.dart';

class Place {
  final String name;
  final String image; // Can be asset path or network URL
  final double rating;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? externalPlaceId;
  final String? fsqId; // Foursquare ID for detail lookups
  final String? photoUrl; // Direct photo URL from Foursquare
  final List<PlaceImageData> images;

  const Place({
    required this.name,
    required this.image,
    required this.rating,
    required this.location,
    this.latitude,
    this.longitude,
    this.externalPlaceId,
    this.fsqId,
    this.photoUrl,
    this.images = const [],
  });
}

final List<Map<String, dynamic>> _fallbackItinerary = [
  {
    'day': 1,
    'places': [
      const Place(
          name: 'Ithra',
          image: 'assets/images/places/Ithra.png',
          rating: 4.8,
          location: 'Dhahran'),
      const Place(
          name: 'City Walk',
          image: 'assets/images/places/CityWalk.png',
          rating: 4.8,
          location: 'Olaya'),
      const Place(
          name: 'Salt',
          image: 'assets/images/places/salt.jpg',
          rating: 4.6,
          location: 'Olaya'),
    ],
  },
  {
    'day': 2,
    'places': [
      const Place(
          name: 'Ajdan Walk',
          image: 'assets/images/cities/khobar2.png',
          rating: 4.3,
          location: 'Alkurnaish'),
      const Place(
          name: 'AMC Cinema',
          image: 'assets/images/places/Cinema.png',
          rating: 4.3,
          location: 'Alkurnaish'),
      const Place(
          name: 'The Shed',
          image: 'assets/images/places/TheShed.png',
          rating: 4.5,
          location: 'Alkurnaish'),
    ],
  },
  {
    'day': 3,
    'places': [
      const Place(
          name: 'Parkers',
          image: 'assets/images/places/Parkers.png',
          rating: 4.4,
          location: 'Dhahran'),
      const Place(
          name: 'Escape The Room',
          image: 'assets/images/places/escapeTheRoom.png',
          rating: 4.2,
          location: 'Khobar'),
      const Place(
          name: 'AlKhobar Beach',
          image: 'assets/images/places/Beach.png',
          rating: 4.2,
          location: 'Khobar'),
    ],
  },
];

class AI_Plan extends StatefulWidget {
  final String? tripId;
  final String? tripTitle;
  final String? destination;

  const AI_Plan({
    super.key,
    this.tripId,
    this.tripTitle,
    this.destination,
  });
  @override
  State<AI_Plan> createState() => _AI_PlanState();
}

class _AI_PlanState extends State<AI_Plan> {
  final _tripService = TripService();
  bool isEditMode = false;
  bool hasNotification = false;
  bool _isLoadingData = false;
  String? _resolvedTripId;

  late List<Map<String, dynamic>> _itinerary;
  late String _activeDestination;
  late String _activeTitle;

  // Tracking the "deleted" places (shaded)
  Set<String> deletedPlaceNames = {};

  // Suggestions list moved here to be dynamic
  List<Map<String, dynamic>> suggestions = [
    {
      'name': 'Ithra',
      'type': 'Center for World Culture',
      'location': 'Gharb Al Dhahran, Dhahran',
      'person': 'Sarah Mohammad',
      'personColor': const Color(0xFF4675B8),
      'highlight': true,
      'action': 'add',
    },
    {
      'name': 'Rakah Beach',
      'type': 'Beach',
      'location': 'Rakah',
      'person': 'Leen Mohammad',
      'personColor': const Color(0xFFC4A44A),
      'highlight': false,
      'action': 'add',
    },
  ];

  @override
  void initState() {
    super.initState();
    _itinerary = List<Map<String, dynamic>>.from(_fallbackItinerary);
    _activeDestination = widget.destination ?? 'Khobar';
    _activeTitle = widget.tripTitle ??
        'Wonderful ${_activeDestination.isEmpty ? 'Trip' : _activeDestination}';
    _resolvedTripId = widget.tripId;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_resolvedTripId == null || _resolvedTripId!.isEmpty) {
      _resolvedTripId = await _resolveCurrentTrip();
      if (_resolvedTripId != null && mounted) {
        // Update destination/title from the resolved trip
        try {
          final trip = await _tripService.getTripDetails(_resolvedTripId!);
          if (!mounted) return;
          final dest = (trip['destination'] ?? '').toString();
          final title = (trip['title'] ?? '').toString();
          setState(() {
            if (dest.isNotEmpty) _activeDestination = dest;
            if (title.isNotEmpty) _activeTitle = title;
          });
        } catch (_) {}
      }
    }
    _loadTripData();
  }

  Future<String?> _resolveCurrentTrip() async {
    try {
      final trips = await _tripService.getMyTrips();
      if (trips.isEmpty) return null;
      final now = DateTime.now();

      for (final trip in trips) {
        final start = trip['start_date'] != null
            ? DateTime.tryParse(trip['start_date'])
            : null;
        final end = trip['end_date'] != null
            ? DateTime.tryParse(trip['end_date'])
            : null;
        if (start != null && end != null && start.isBefore(now) && end.isAfter(now)) {
          return trip['id']?.toString();
        }
      }

      final upcoming = trips.where((trip) {
        final start = trip['start_date'] != null
            ? DateTime.tryParse(trip['start_date'])
            : null;
        return start != null && start.isAfter(now);
      }).toList();
      upcoming.sort((a, b) {
        final aStart = DateTime.parse(a['start_date']);
        final bStart = DateTime.parse(b['start_date']);
        return aStart.compareTo(bStart);
      });
      if (upcoming.isNotEmpty) return upcoming.first['id']?.toString();

      return trips.first['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadTripData() async {
    if (_resolvedTripId == null || _resolvedTripId!.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      final itineraryData =
          await _tripService.getLatestItinerary(_resolvedTripId!);
      final mapped = _mapItineraryFromApi(itineraryData);

      if (!mounted) return;
      if (mapped.isNotEmpty) {
        setState(() {
          _itinerary = mapped;
        });
      }

      // Load recommendations and suggestions separately so failures don't
      // prevent the itinerary from displaying.
      List<Map<String, dynamic>> mappedSuggestions = [];
      List<Map<String, dynamic>> mappedPlaceSuggestions = [];
      try {
        final recommendations =
            await _tripService.getRecommendations(_resolvedTripId!);
        mappedSuggestions = _mapSuggestionsFromRecommendations(recommendations);
      } catch (_) {}

      try {
        final placeSuggestions =
            await _tripService.getPlaceSuggestions(_resolvedTripId!);
        final currentUserId =
            Provider.of<UserProvider>(context, listen: false)
                .currentProfile?['id'];
        mappedPlaceSuggestions =
            _mapPlaceSuggestions(placeSuggestions, currentUserId);
      } catch (_) {}

      if (!mounted) return;
      final allSuggestions = [...mappedSuggestions, ...mappedPlaceSuggestions];
      if (allSuggestions.isNotEmpty) {
        setState(() {
          suggestions = allSuggestions;
          hasNotification = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  List<Map<String, dynamic>> _mapItineraryFromApi(
      Map<String, dynamic> itineraryData) {
    final days = itineraryData['days'];
    if (days is! List) return [];

    final mapped = <Map<String, dynamic>>[];
    for (final dayData in days) {
      if (dayData is! Map<String, dynamic>) continue;
      final dayNumber = dayData['day'] is int
          ? dayData['day'] as int
          : int.tryParse(dayData['day']?.toString() ?? '') ?? 1;
      final activities = dayData['activities'];
      final places = <Place>[];
      if (activities is List) {
        for (final item in activities) {
          if (item is! Map<String, dynamic>) continue;

          final images = placeImagesFromMap(item);
          final photoUrl = (item['photo_url'] ?? item['image_url'])?.toString();
          final imageAsset = (item['image_asset'] ?? '').toString();
          final imageToUse = [
            if (photoUrl != null && photoUrl.isNotEmpty) photoUrl,
            if (images.isNotEmpty) images.first.url,
            if (imageAsset.isNotEmpty) imageAsset,
          ].firstWhere(
            (url) => url.isNotEmpty,
            orElse: () => 'assets/images/icons/logo.png',
          );

          places.add(
            Place(
              name: (item['name'] ?? 'Activity').toString(),
              image: imageToUse,
              rating: (item['rating'] is num)
                  ? (item['rating'] as num).toDouble()
                  : (item['score'] is num)
                      ? (item['score'] as num).toDouble()
                      : 4.0,
              location:
                  (item['location'] ?? item['notes'] ?? _activeDestination)
                      .toString(),
              photoUrl: (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
              fsqId: item['fsq_id']?.toString(),
              images: images.isNotEmpty
                  ? images
                  : [PlaceImageData(url: imageToUse)],
            ),
          );
        }
      }

      mapped.add({'day': dayNumber, 'places': places});
    }

    return mapped;
  }

  List<Map<String, dynamic>> _mapSuggestionsFromRecommendations(
      List<Map<String, dynamic>> recommendations) {
    return recommendations.take(8).map((entry) {
      final poi = (entry['poi'] is Map<String, dynamic>)
          ? entry['poi'] as Map<String, dynamic>
          : <String, dynamic>{};

      return {
        'name': (poi['name'] ?? 'Suggested Place').toString(),
        'type': (poi['type'] ?? 'Recommendation').toString(),
        'location': (poi['location'] ?? _activeDestination).toString(),
        'person': 'TripBond AI',
        'personColor': const Color(0xFF4675B8),
        'highlight': false,
        'action': 'add',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _mapPlaceSuggestions(
      List<Map<String, dynamic>> placeSuggestions, dynamic currentUserId) {
    return placeSuggestions.map((suggestion) {
      final isCurrentUserSuggestion = suggestion['suggested_by'] == currentUserId;
      return {
        'name': (suggestion['name'] ?? 'Place').toString(),
        'type': (suggestion['place_types'] is List &&
                (suggestion['place_types'] as List).isNotEmpty)
            ? ((suggestion['place_types'] as List).first).toString()
            : 'Place',
        'location': (suggestion['address'] ?? _activeDestination).toString(),
        'person': isCurrentUserSuggestion ? 'You' : 'Bonder',
        'personColor': isCurrentUserSuggestion
            ? const Color(0xFFC4A44A)
            : const Color(0xFF4675B8),
        'highlight': isCurrentUserSuggestion,
        'action': 'add',
        'suggested_by': suggestion['suggested_by'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(context),
              _buildPlanToggle(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (_isLoadingData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ..._itinerary.map((day) => _buildDaySection(day)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlansList(source: 'generatedPlan')),
            ),
            child: const Icon(Icons.arrow_back, size: 24),
          ),
          const Text(
            'Generated Plan',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                    onPressed: () async {
                      // Reload suggestions before opening the page
                      try {
                        final placeSuggestions =
                            await _tripService.getPlaceSuggestions(_resolvedTripId!);
                        final currentUserId =
                            Provider.of<UserProvider>(context, listen: false)
                                .currentProfile?['id'];
                        final mappedPlaceSuggestions =
                            _mapPlaceSuggestions(placeSuggestions, currentUserId);

                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BondersSuggestions(
                                suggestions: mappedPlaceSuggestions,
                                source: 'generatedPlan',
                              ),
                            ),
                          );
                          setState(() => hasNotification = false);
                        }
                      } catch (e) {
                        print('Error reloading suggestions: $e');
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BondersSuggestions(
                                suggestions: suggestions,
                                source: 'generatedPlan',
                              ),
                            ),
                          );
                          setState(() => hasNotification = false);
                        }
                      }
                    },
                  ),
                  if (hasNotification)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(isEditMode ? Icons.check : Icons.edit_outlined,
                    size: 22),
                onPressed: () => setState(() => isEditMode = !isEditMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanToggle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4675B8),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                'Your Plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSuggestedItinerary(
                    tripId: _resolvedTripId ?? widget.tripId,
                    tripTitle: widget.tripTitle,
                    destination: widget.destination,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Text(
                  'Calendar View',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _activeTitle.isNotEmpty
                ? _activeTitle
                : 'Wonderful $_activeDestination,',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          Text(
            "Let's Bond Together",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Color(0xFF4675B8),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlacePreview(BuildContext context, Place place) {
    openPlacePreview(
      context,
      data: PlacePreviewData(
        name: place.name,
        location: place.location,
        rating: place.rating,
        placeId: place.externalPlaceId ?? place.fsqId,
        latitude: place.latitude,
        longitude: place.longitude,
        sourceMap: {
          'name': place.name,
          'address': place.location,
          'rating': place.rating,
          'external_place_id': place.externalPlaceId,
          'fsq_id': place.fsqId,
          'latitude': place.latitude,
          'longitude': place.longitude,
          'photo_url': place.photoUrl,
          'image_url': place.image,
          'images': place.images
              .map((image) => {'url': image.url, 'attributions': image.attributions})
              .toList(),
        },
      ),
      tripId: widget.tripId,
    );
  }

  Widget _buildDaySection(Map<String, dynamic> day) {
    final int dayNum = day['day'];
    final List<Place> places = day['places'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day $dayNum:',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                const Icon(Icons.arrow_forward,
                    size: 20, color: Color(0xFF1E1E1E)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200, // Adjusted height to accommodate responsive cards
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: places.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                final bool isDeleted = deletedPlaceNames.contains(place.name);
                return Opacity(
                  opacity: isDeleted ? 0.4 : 1.0,
                  child: AbsorbPointer(
                    absorbing: isDeleted,
                    child: GestureDetector(
                      onTap: () => _showPlacePreview(context, place),
                      child: _PlaceCard(
                        place: place,
                        showDelete: isEditMode && !isDeleted,
                        onDelete: () {
                          setState(() {
                            hasNotification = true;
                            deletedPlaceNames.add(place.name);
                            suggestions.insert(0, {
                              'name': place.name,
                              'type': 'Removed from Plan',
                              'location': place.location,
                              'person': 'You',
                              'personColor': const Color(0xFF4675B8),
                              'highlight': false,
                              'action': 'delete',
                            });
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return AppBottomNav(
      currentTab: AppNavTab.plan,
      planBuilder: (_) => AI_Plan(
        tripId: _resolvedTripId ?? widget.tripId,
        tripTitle: widget.tripTitle,
        destination: widget.destination,
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  final bool showDelete;
  final VoidCallback onDelete;

  const _PlaceCard(
      {required this.place, required this.showDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Responsive Dimensions
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth * 0.42; // Uses percentage instead of fixed 165
    final double imageHeight = 115;

    return Stack(
      children: [
        Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: _buildPlaceImage(place, cardWidth, imageHeight),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.star, size: 12, color: Color(0xFFFACC15)),
                          const SizedBox(width: 2),
                          Text(
                            '${place.rating}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 10, color: Color(0xFF4675B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.location,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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
        if (showDelete)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceImage(Place place, double width, double height) {
    final resolved = <PlaceImageData>[
      ...place.images.where((image) => image.url.isNotEmpty),
    ];
    if (resolved.isEmpty &&
        place.photoUrl != null &&
        place.photoUrl!.isNotEmpty) {
      resolved.add(PlaceImageData(url: place.photoUrl!));
    }
    if (resolved.isEmpty && place.image.isNotEmpty) {
      resolved.add(PlaceImageData(url: place.image));
    }

    return SizedBox(
      width: width,
      height: height,
      child: PlaceImageCarousel(
        images: resolved,
        height: height,
        showAttribution: resolved.isNotEmpty &&
            resolved.any((image) => image.url.startsWith('http')),
      ),
    );
  }
}