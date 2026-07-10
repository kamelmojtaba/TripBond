import 'package:flutter/material.dart';
import '../services/poi_service.dart';
import '../services/trip_service.dart';
import '../widgets/place_image_carousel.dart';
import '../utils/place_navigation.dart';
import 'group_suggested_itinerary.dart';

/// Place-picker shown to every trip member during the planning phase.
///
/// Shows POIs for the trip destination (from `/api/pois?location=<city>`).
/// The user taps a few cards to add them to their personal pick list, then
/// confirms; on confirm we call `addPlaceToTrip` once per pick and mark this
/// member's place-picking stage complete.
class TripPlacesPickerScreen extends StatefulWidget {
  final String tripId;
  // May be empty when opened from a trip card whose destination is unknown
  // locally (older trips, deep links, etc.). The screen will fetch it from
  // the trip details endpoint in that case.
  final String destination;
  final String tripTitle;
  final bool isCreator;

  /// Legacy navigation flags kept for existing callers. The main flow now
  /// returns to the trip hub after marking place-picking complete.
  final bool goToVotingAfter;
  final bool goToPlanAfter;
  final bool useStarterPlan;

  const TripPlacesPickerScreen({
    super.key,
    required this.tripId,
    required this.destination,
    required this.tripTitle,
    this.isCreator = false,
    this.goToVotingAfter = true,
    this.goToPlanAfter = false,
    this.useStarterPlan = false,
  });

  @override
  State<TripPlacesPickerScreen> createState() => _TripPlacesPickerScreenState();
}

class _TripPlacesPickerScreenState extends State<TripPlacesPickerScreen> {
  final _poiService = POIService();
  final _tripService = TripService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _starterDays = [];
  String _starterPlanSource = '';
  final Set<String> _selected = {};
  bool _saving = false;
  String _destination = '';

  @override
  void initState() {
    super.initState();
    _destination = widget.destination.trim();
    _load();
  }

  String _placeKey(Map<String, dynamic> p) =>
      (p['id'] ?? p['poi_id'] ?? p['place_id'] ?? p['name'] ?? '').toString();

  Map<String, dynamic> _mergePlaceImages(
    Map<String, dynamic> primary,
    Map<String, dynamic> secondary,
  ) {
    final merged = Map<String, dynamic>.from(primary);
    for (final key in ['image_url', 'image_asset', 'photo_url']) {
      final current = (merged[key] ?? '').toString();
      final fallback = (secondary[key] ?? '').toString();
      if (current.isEmpty && fallback.isNotEmpty) {
        merged[key] = fallback;
      }
    }

    final primaryImages = merged['images'];
    final secondaryImages = secondary['images'];
    final primaryHasImages =
        primaryImages is List && primaryImages.isNotEmpty;
    final secondaryHasImages =
        secondaryImages is List && secondaryImages.isNotEmpty;
    if (!primaryHasImages && secondaryHasImages) {
      merged['images'] = secondaryImages;
    }

    return merged;
  }

  List<Map<String, dynamic>> _mergeUniquePlaces(
    List<Map<String, dynamic>> primary,
    List<Map<String, dynamic>> secondary,
  ) {
    final byKey = <String, Map<String, dynamic>>{};

    for (final place in primary) {
      final key = _placeKey(place).trim().toLowerCase();
      if (key.isEmpty) continue;
      byKey[key] = place;
    }

    for (final place in secondary) {
      final key = _placeKey(place).trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = place;
      } else {
        byKey[key] = _mergePlaceImages(existing, place);
      }
    }

    return byKey.values.toList();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Map<String, dynamic>? _coordinatesMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  double? _placeLatitude(Map<String, dynamic> place) {
    final coordinates = _coordinatesMap(place['coordinates']);
    return _toDouble(
      place['latitude'] ??
          place['lat'] ??
          coordinates?['latitude'] ??
          coordinates?['lat'],
    );
  }

  double? _placeLongitude(Map<String, dynamic> place) {
    final coordinates = _coordinatesMap(place['coordinates']);
    return _toDouble(
      place['longitude'] ??
          place['lng'] ??
          place['lon'] ??
          coordinates?['longitude'] ??
          coordinates?['lng'] ??
          coordinates?['lon'],
    );
  }

  Future<void> _resolveDestinationIfMissing() async {
    if (_destination.isNotEmpty) return;
    try {
      final trip = await _tripService.getTripDetails(widget.tripId);
      final dest =
          (trip['destination'] ?? trip['location'] ?? '').toString().trim();
      _destination = dest;
    } catch (_) {
      // Keep destination empty; the load step will surface a friendly error.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _resolveDestinationIfMissing();
      if (_destination.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error =
              'This trip has no destination set, so we cannot suggest places. '
              'Open the trip details and add a destination first.';
          _loading = false;
        });
        return;
      }
      var starterDays = <Map<String, dynamic>>[];
      var starterSource = '';
      var selectedKeys = <String>{};
      var places = <Map<String, dynamic>>[];

      if (widget.useStarterPlan) {
        final starter = await _loadStarterPlanPlaces();
        places = starter['places'] as List<Map<String, dynamic>>;
        starterDays = starter['days'] as List<Map<String, dynamic>>;
        starterSource = starter['source'] as String;
        selectedKeys = starter['selected'] as Set<String>;

        try {
          final cityPlaces = await _poiService.searchPOIs(
            location: _destination,
            limit: 200,
          );
          places = _mergeUniquePlaces(places, cityPlaces);
        } catch (_) {
          // Keep the AI starter choices usable even if the broader city list fails.
        }
      }

      if (places.isEmpty) {
        places = await _loadRankedRecommendations();
      }
      if (places.isEmpty) {
        places = await _poiService.searchPOIs(
          location: _destination,
          limit: 60,
        );
      }
      if (!mounted) return;
      setState(() {
        _places = places;
        _starterDays = starterDays;
        _starterPlanSource = starterSource;
        _selected
          ..clear()
          ..addAll(selectedKeys);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadStarterPlanPlaces() async {
    try {
      final starter = await _tripService.getStarterPlan(widget.tripId);
      final rawDays = starter['days'];
      final days = rawDays is List
          ? rawDays
              .whereType<Map>()
              .map((day) => Map<String, dynamic>.from(day))
              .toList()
          : <Map<String, dynamic>>[];

      final byKey = <String, Map<String, dynamic>>{};
      final selected = <String>{};
      final rawPlaces = starter['recommended_places'];
      if (rawPlaces is List) {
        for (final item in rawPlaces) {
          if (item is! Map) continue;
          final itemMap = Map<String, dynamic>.from(item);
          final poi = itemMap['poi'];
          if (poi is! Map) continue;
          final mapped = Map<String, dynamic>.from(poi);
          mapped['ai_score'] = itemMap['score'];
          mapped['ai_reason'] = itemMap['reason'];
          mapped['starter_day'] = itemMap['day'];
          mapped['starter_start_time'] = itemMap['start_time'];
          mapped['starter_end_time'] = itemMap['end_time'];
          mapped['id'] = mapped['id'] ??
              mapped['poi_id'] ??
              mapped['place_id'] ??
              mapped['external_place_id'];
          mapped['place_id'] = mapped['place_id'] ??
              mapped['external_place_id'] ??
              mapped['id'] ??
              mapped['poi_id'];
          mapped['type'] = mapped['type'] ?? mapped['poi_type'];
          mapped['image_url'] =
              mapped['image_url'] ?? poi['image_url'] ?? poi['photo_url'];
          mapped['photo_url'] =
              mapped['photo_url'] ?? mapped['image_url'] ?? poi['photo_url'];
          mapped['image_asset'] = mapped['image_asset'] ?? poi['image_asset'];
          mapped['images'] = mapped['images'] ?? poi['images'] ?? const [];

          final lat = _placeLatitude(mapped);
          final lng = _placeLongitude(mapped);
          if (lat == null || lng == null) continue;
          mapped['latitude'] = lat;
          mapped['longitude'] = lng;

          final key = _placeKey(mapped);
          if (key.isEmpty) continue;
          byKey[key] = mapped;
          if (itemMap['day'] != null) {
            selected.add(key);
          }
        }
      }

      if (selected.isEmpty && byKey.isNotEmpty) {
        final scheduledCount = days.fold<int>(0, (count, day) {
          final activities = day['activities'];
          return count + (activities is List ? activities.length : 0);
        });
        final fallbackCount = scheduledCount > 0 ? scheduledCount : 12;
        selected.addAll(byKey.keys.take(fallbackCount));
      }

      return {
        'places': byKey.values.toList(),
        'days': days,
        'source': (starter['preferences_source'] ?? '').toString(),
        'selected': selected,
      };
    } catch (_) {
      return {
        'places': <Map<String, dynamic>>[],
        'days': <Map<String, dynamic>>[],
        'source': '',
        'selected': <String>{},
      };
    }
  }

  Future<List<Map<String, dynamic>>> _loadRankedRecommendations() async {
    try {
      final recommendations =
          await _tripService.getRecommendations(widget.tripId);
      return recommendations
          .map((recommendation) {
            final poi = recommendation['poi'];
            final mapped = poi is Map
                ? Map<String, dynamic>.from(poi)
                : <String, dynamic>{};
            mapped['ai_score'] = recommendation['score'];
            mapped['ai_reason'] = recommendation['reason'];
            mapped['id'] = mapped['id'] ??
                mapped['poi_id'] ??
                mapped['place_id'] ??
                mapped['external_place_id'];
            mapped['place_id'] = mapped['place_id'] ??
                mapped['external_place_id'] ??
                mapped['id'] ??
                mapped['poi_id'];
            mapped['type'] = mapped['type'] ?? mapped['poi_type'];
            final lat = _placeLatitude(mapped);
            final lng = _placeLongitude(mapped);
            if (lat == null || lng == null) {
              return null;
            }
            mapped['latitude'] = lat;
            mapped['longitude'] = lng;
            return mapped;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one place to continue.')),
      );
      return;
    }
    setState(() => _saving = true);

    var added = 0;
    var skipped = 0;
    var failed = 0;
    String? firstError;
    for (final place in _places) {
      if (!_selected.contains(_placeKey(place))) continue;
      try {
        final lat = _placeLatitude(place);
        final lng = _placeLongitude(place);
        if (lat == null || lng == null) {
          failed++;
          firstError ??= 'Some selected places are missing coordinates.';
          continue;
        }
        final payload = <String, dynamic>{
          'name': place['name'],
          'address': place['address'] ?? place['location'] ?? '',
          'latitude': lat,
          'longitude': lng,
          'rating': place['rating'],
          'user_ratings_total':
              place['review_count'] ?? place['user_ratings_total'],
          'types':
              place['types'] ?? (place['type'] != null ? [place['type']] : []),
          'image_url': place['image_url'],
          'photo_url': place['image_url'],
          'images': place['images'] ?? [],
          'external_place_id': place['place_id'] ??
              place['external_place_id'] ??
              place['id'] ??
              place['poi_id'],
        };
        final result =
            await _tripService.addPlaceToTrip(widget.tripId, payload);
        if (result['success'] == false && result['already_exists'] == true) {
          skipped++;
        } else {
          added++;
        }
      } catch (e) {
        firstError ??= e.toString();
        failed++;
      }
    }

    if (!mounted) return;

    final usablePlaces = added + skipped;
    if (usablePlaces > 0) {
      try {
        await _tripService.markPlacesComplete(widget.tripId);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Places added, but could not mark complete: $e')),
        );
        return;
      }
    }

    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(
        failed == 0 && skipped == 0
            ? 'Added $added place${added == 1 ? '' : 's'} and marked your picks complete.'
            : failed == 0
                ? 'Added $added, skipped $skipped already in the trip, and marked complete.'
                : firstError == null
                    ? 'Added $added, skipped $skipped, $failed failed.'
                    : 'Added $added, skipped $skipped, $failed failed: $firstError',
      ),
    ));

    if (usablePlaces == 0) {
      return;
    }

    if (widget.goToVotingAfter) {
      Navigator.of(context).pop(usablePlaces);
    } else if (widget.goToPlanAfter) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GroupSuggestedItinerary(
          tripId: widget.tripId,
          destination: _destination,
          tripTitle: widget.tripTitle,
        ),
      ));
    } else {
      Navigator.of(context).pop(added);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tripTitle, style: const TextStyle(fontSize: 16)),
            Text(
              _destination.isEmpty
                  ? 'Pick your places'
                  : widget.useStarterPlan
                      ? 'Review suggested itinerary · $_destination'
                      : 'Pick your places · $_destination',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving || _selected.isEmpty ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4675B8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selected.isEmpty
                          ? 'Select places'
                          : widget.goToVotingAfter
                              ? 'Add ${_selected.length} & mark complete'
                              : 'Add ${_selected.length} & mark complete',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _places.isEmpty
                  ? Center(
                      child: Text(
                        _destination.isEmpty
                            ? 'No places to suggest yet.'
                            : 'No places found for $_destination.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        slivers: [
                          if (widget.useStarterPlan)
                            SliverToBoxAdapter(
                                child: _buildStarterPlanPreview()),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.78,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => _buildCard(_places[i]),
                                childCount: _places.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStarterPlanPreview() {
    final sourceText = _starterPlanSource == 'group_model' ||
            _starterPlanSource == 'member_preferences'
        ? 'based on group preferences'
        : 'based on the trip details and destination';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF4675B8).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF4675B8).withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF4675B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suggested itinerary',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    color: Color(0xFF4675B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _starterDays.isEmpty
                  ? 'We could not build a day-by-day plan yet. Choose from the AI-ranked places below.'
                  : 'We preselected a recommended plan $sourceText. Uncheck places to remove them, or pick any other city place below.',
              style: TextStyle(color: Colors.grey[700], height: 1.35),
            ),
            if (_starterDays.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final day in _starterDays) _buildStarterDay(day),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStarterDay(Map<String, dynamic> day) {
    final activities = day['activities'];
    final rows = activities is List ? activities.whereType<Map>().toList() : [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day['day'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            _buildStarterActivity(Map<String, dynamic>.from(row)),
        ],
      ),
    );
  }

  Widget _buildStarterActivity(Map<String, dynamic> activity) {
    final key = _placeKey(activity);
    final selected = _selected.contains(key);
    final name = (activity['name'] ?? activity['title'] ?? 'Place').toString();
    final start = (activity['start_time'] ?? '').toString();
    final end = (activity['end_time'] ?? '').toString();

    return InkWell(
      onTap: key.isEmpty
          ? null
          : () {
              setState(() {
                if (selected) {
                  _selected.remove(key);
                } else {
                  _selected.add(key);
                }
              });
            },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? const Color(0xFF4675B8) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PlaceNameLink(
                name: name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
                onTap: () => openPlacePreviewFromMap(
                  context,
                  activity,
                  tripId: widget.tripId,
                  fallbackLocation: _destination,
                ),
              ),
            ),
            if (start.isNotEmpty && end.isNotEmpty)
              Text(
                '$start-$end',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> place) {
    final key = _placeKey(place);
    final isSelected = _selected.contains(key);
    final images = placeImagesFromMap(place);
    final name = (place['name'] ?? 'Place').toString();
    final address = (place['address'] ?? place['location'] ?? '').toString();
    final rating = place['rating'];
    final type = (place['type'] ?? place['category'] ?? '').toString();
    final score = _toDouble(place['ai_score']);
    final reason = (place['ai_reason'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selected.remove(key);
          } else {
            _selected.add(key);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF4675B8) : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: PlaceImageCarousel(
                      images: images,
                      height: 160,
                      showAttribution: images.isNotEmpty,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4675B8),
                        ),
                        child: const Icon(Icons.check,
                            size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlaceNameLink(
                      name: name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      onTap: () => openPlacePreviewFromMap(
                        context,
                        place,
                        tripId: widget.tripId,
                        fallbackLocation: _destination,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (rating is num)
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 13, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        const Spacer(),
                        if (type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4675B8)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF4675B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (score != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'AI match ${(score * 100).round()}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4675B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
