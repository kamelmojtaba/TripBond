import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Bonder.dart';
import 'profile.dart';
import 'DestinationLandingPage.dart';
import 'AI_Plan.dart';
import 'plans_list.dart';
import 'BondersSuggestions.dart';
import '../services/poi_service.dart';
import '../services/trip_service.dart';
import '../services/vote_service.dart';
import '../providers/user_provider.dart';
import '../widgets/place_image_carousel.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/place_navigation.dart';
import 'voting_screen.dart';
import 'trip_join_requests_screen.dart';

DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

ItineraryItem _activityToItem(
    Map<String, dynamic> activity, String fallbackLocation) {
  final images = placeImagesFromMap(activity);
  return ItineraryItem(
    id: activity['id']?.toString(),
    startTime: (activity['start_time'] ?? '09:00').toString(),
    endTime: (activity['end_time'] ?? '10:30').toString(),
    title: (activity['name'] ?? activity['title'] ?? 'Activity').toString(),
    subtitle: (activity['category'] ?? activity['notes'] ?? '').toString(),
    location: (activity['address'] ?? activity['location'] ?? fallbackLocation)
        .toString(),
    imageUrl: (activity['photo_url'] ?? activity['image_url'])?.toString(),
    images: images,
    person: 'AI',
    color: Colors.white,
  );
}

class GroupSuggestedItinerary extends StatefulWidget {
  final String? tripId;
  final String? tripTitle;
  final String? destination;

  const GroupSuggestedItinerary({
    super.key,
    this.tripId,
    this.tripTitle,
    this.destination,
  });

  @override
  State<GroupSuggestedItinerary> createState() =>
      _GroupSuggestedItineraryState();
}

class _GroupSuggestedItineraryState extends State<GroupSuggestedItinerary> {
  final _tripService = TripService();
  final _voteService = VoteService();
  final _poiService = POIService();

  DateTime? _selectedDay;
  List<DateTime> _tripDays = [];
  Map<DateTime, List<Map<String, dynamic>>> _calendarItinerary = {};

  bool isEditMode = false;
  bool hasNotification = false;
  bool _loading = true;
  bool _generating = false;
  bool _openingVoting = false;
  bool _loadingPlaces = false;
  bool _savingPlanChange = false;
  String? _phase;
  bool _isCreator = false;
  String? _error;
  String? _placesError;
  Map<String, dynamic>? _trip;
  String? _resolvedTripId;
  List<Map<String, dynamic>> _cityPlaces = [];

  List<Map<String, dynamic>> suggestions = [];

  static const List<Map<String, String>> _timeSlots = [
    {'label': 'Morning', 'start': '09:00', 'end': '11:00'},
    {'label': 'Afternoon', 'start': '13:00', 'end': '15:00'},
    {'label': 'Evening', 'start': '18:00', 'end': '20:00'},
  ];

  List<Map<String, dynamic>> _activitiesForDay(DateTime day) {
    return _calendarItinerary[_norm(day)] ?? const [];
  }

  String get _activeDestination =>
      (_trip?['destination'] ?? _trip?['location'] ?? widget.destination ?? '')
          .toString()
          .trim();

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _placeName(Map<String, dynamic> place) =>
      (place['name'] ?? place['title'] ?? 'Place').toString();

  String _placeLocation(Map<String, dynamic> place) => (place['address'] ??
          place['location'] ??
          place['formatted_address'] ??
          _activeDestination)
      .toString();

  String _placeType(Map<String, dynamic> place) =>
      (place['type'] ?? place['category'] ?? place['poi_type'] ?? 'Place')
          .toString();

  String? _placeImageUrl(Map<String, dynamic> place) {
    final image =
        place['photo_url'] ?? place['image_url'] ?? place['thumbnail_url'];
    final imageText = image?.toString();
    return imageText != null && imageText.startsWith('http') ? imageText : null;
  }

  int _dayIndexForDate(DateTime day) {
    final index =
        _tripDays.indexWhere((tripDay) => _norm(tripDay) == _norm(day));
    if (index >= 0) return index + 1;
    return day.difference(_tripStartDate()).inDays + 1;
  }

  Map<String, String> _slotForActivity(Map<String, dynamic> activity) {
    final start = (activity['start_time'] ?? '').toString();
    return _timeSlots.firstWhere(
      (slot) => slot['start'] == start,
      orElse: () => {
        'label': 'Custom',
        'start': start.isNotEmpty ? start : '09:00',
        'end': (activity['end_time'] ?? '10:30').toString(),
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    String? tripId = widget.tripId;

    if (tripId == null || tripId.isEmpty) {
      // Auto-resolve: pick current trip or first upcoming trip
      tripId = await _resolveCurrentTrip();
      if (tripId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No current or upcoming trips found.';
        });
        return;
      }
    }

    _resolvedTripId = tripId;

    try {
      final trip = await _tripService.getTripDetails(tripId);
      if (!mounted) return;
      _trip = trip;
      _phase = trip['phase']?.toString();
      final currentUserId = Provider.of<UserProvider>(context, listen: false)
          .currentProfile?['id'];
      _isCreator = trip['created_by'] == currentUserId;
      await _loadTripItinerary(trip);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String?> _resolveCurrentTrip() async {
    try {
      final trips = await _tripService.getMyTrips();
      if (trips.isEmpty) return null;
      final now = DateTime.now();

      // Find a current (ongoing) trip first
      for (final trip in trips) {
        final start = trip['start_date'] != null
            ? DateTime.tryParse(trip['start_date'])
            : null;
        final end = trip['end_date'] != null
            ? DateTime.tryParse(trip['end_date'])
            : null;
        if (start != null &&
            end != null &&
            start.isBefore(now) &&
            end.isAfter(now)) {
          return trip['id']?.toString();
        }
      }

      // Otherwise, pick the first upcoming trip
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

      // Fallback: return the most recent trip
      return trips.first['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  DateTime _tripStartDate() {
    final raw = _trip?['start_date'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw).toLocal();
      } catch (_) {}
    }
    return DateTime.now();
  }

  Future<void> _loadTripItinerary(Map<String, dynamic> trip) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final itineraryData =
          await _tripService.getLatestItinerary(_resolvedTripId!);
      final selectedBeforeReload = _selectedDay;
      final days = itineraryData['days'];
      final mappedDays = <DateTime>[];
      final mappedCalendar = <DateTime, List<Map<String, dynamic>>>{};
      final start = _tripStartDate();

      if (days is List) {
        for (final dayData in days) {
          if (dayData is! Map<String, dynamic>) continue;
          final dayNumber = dayData['day'] is int
              ? dayData['day'] as int
              : int.tryParse(dayData['day']?.toString() ?? '') ?? 1;
          final dayDate = start.add(Duration(days: dayNumber - 1));

          final activities = dayData['activities'];
          final acts = <Map<String, dynamic>>[];
          if (activities is List) {
            for (final item in activities) {
              if (item is Map) {
                acts.add(Map<String, dynamic>.from(item));
              }
            }
          }
          mappedDays.add(dayDate);
          mappedCalendar[_norm(dayDate)] = acts;
        }
      }

      List<Map<String, dynamic>> placeSuggestions = const [];
      try {
        placeSuggestions =
            await _tripService.getPlaceSuggestions(_resolvedTripId!);
      } catch (_) {}
      final currentUserId = Provider.of<UserProvider>(context, listen: false)
          .currentProfile?['id'];
      final mappedPlaceSuggestions =
          _mapPlaceSuggestions(placeSuggestions, currentUserId);
      final nextSelectedDay = mappedDays.isEmpty
          ? null
          : selectedBeforeReload == null
              ? mappedDays.first
              : mappedDays.firstWhere(
                  (day) => _norm(day) == _norm(selectedBeforeReload),
                  orElse: () => mappedDays.first,
                );

      if (!mounted) return;
      setState(() {
        _tripDays = mappedDays;
        _calendarItinerary = mappedCalendar;
        _selectedDay = nextSelectedDay;
        suggestions = mappedPlaceSuggestions;
        hasNotification = mappedPlaceSuggestions.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generatePlan() async {
    if (_resolvedTripId == null) return;
    setState(() => _generating = true);
    try {
      await _tripService.generateItinerary(_resolvedTripId!, {});
      _phase = 'planned';
      if (_trip != null) {
        await _loadTripItinerary(_trip!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan generated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openVoting() async {
    if (_resolvedTripId == null || _resolvedTripId!.isEmpty) return;
    setState(() => _openingVoting = true);
    try {
      final places = await _tripService.listTripPlaces(_resolvedTripId!);
      if (places.isEmpty) {
        if (!mounted) return;
        setState(() => _openingVoting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Add at least one place before starting voting.')),
        );
        return;
      }
      await _voteService.openVoting(_resolvedTripId!);
      if (!mounted) return;
      setState(() {
        _phase = 'voting';
        _openingVoting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voting is open. Members can now rate places.')),
      );
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VotingScreen(
          tripId: _resolvedTripId!,
          tripTitle: widget.tripTitle ?? 'Trip',
          isCreator: _isCreator,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingVoting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open voting: $e')),
      );
    }
  }

  Future<void> _loadCityPlaces({bool forceRefresh = false}) async {
    final destination = _activeDestination;
    if (destination.isEmpty) {
      setState(() => _placesError = 'This trip has no destination set.');
      return;
    }
    if (!forceRefresh && _cityPlaces.isNotEmpty) return;

    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });
    try {
      final places = await _poiService.searchPOIs(
        location: destination,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _cityPlaces = places;
        _loadingPlaces = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _placesError = e.toString();
        _loadingPlaces = false;
      });
    }
  }

  Future<void> _openPlaceBrowser() async {
    await _loadCityPlaces();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PlaceBrowserSheet(
        destination: _activeDestination,
        places: _cityPlaces,
        isLoading: _loadingPlaces,
        error: _placesError,
        onAdd: (place) {
          Navigator.pop(context);
          _showSchedulePlaceSheet(place);
        },
      ),
    );
  }

  Map<String, dynamic> _payloadForPlace(
    Map<String, dynamic> place,
    int day,
    Map<String, String> slot,
  ) {
    return {
      'day': day,
      'name': _placeName(place),
      'type': _placeType(place),
      'location': _placeLocation(place),
      'start_time': slot['start'],
      'end_time': slot['end'],
      'description':
          (place['description'] ?? place['ai_reason'] ?? '').toString(),
      'priority': 1,
      'rating': _toDouble(place['rating']),
      'user_ratings_total':
          place['review_count'] ?? place['user_ratings_total'],
      'photo_url': _placeImageUrl(place),
      'images': place['images'] ?? [],
      'fsq_id': place['fsq_id']?.toString(),
      'external_place_id': (place['place_id'] ??
              place['external_place_id'] ??
              place['id'] ??
              place['poi_id'])
          ?.toString(),
      'address': (place['address'] ?? place['formatted_address'])?.toString(),
      'latitude': _toDouble(place['latitude'] ?? place['lat']),
      'longitude':
          _toDouble(place['longitude'] ?? place['lng'] ?? place['lon']),
    };
  }

  Map<String, dynamic> _tripPlacePayloadForPlace(Map<String, dynamic> place) {
    final type = _placeType(place);
    final imageUrl = _placeImageUrl(place);
    return {
      'name': _placeName(place),
      'address': _placeLocation(place),
      'latitude': _toDouble(place['latitude'] ?? place['lat']),
      'longitude':
          _toDouble(place['longitude'] ?? place['lng'] ?? place['lon']),
      'rating': _toDouble(place['rating']),
      'user_ratings_total':
          place['review_count'] ?? place['user_ratings_total'],
      'types': place['types'] ?? (type.isNotEmpty ? [type] : []),
      'image_url': imageUrl,
      'photo_url': imageUrl,
      'images': place['images'] ?? [],
      'external_place_id': (place['place_id'] ??
              place['external_place_id'] ??
              place['id'] ??
              place['poi_id'])
          ?.toString(),
    };
  }

  Map<String, dynamic> _payloadForActivity(
    Map<String, dynamic> activity,
    int day,
    Map<String, String> slot,
  ) {
    return {
      'day': day,
      'name': (activity['name'] ?? activity['title'] ?? 'Activity').toString(),
      'type': (activity['type'] ?? 'activity').toString(),
      'location': (activity['address'] ??
              activity['location'] ??
              widget.destination ??
              'Trip')
          .toString(),
      'start_time': slot['start'],
      'end_time': slot['end'],
      'description':
          (activity['description'] ?? activity['notes'] ?? '').toString(),
      'priority': activity['priority'] ?? 1,
      'rating': _toDouble(activity['rating'] ?? activity['score']),
      'photo_url': (activity['photo_url'] ?? activity['image_url'])?.toString(),
      'images': activity['images'] ?? [],
      'fsq_id': activity['fsq_id']?.toString(),
      'external_place_id': (activity['external_place_id'] ??
              activity['place_id'] ??
              activity['id'])
          ?.toString(),
      'address': activity['address']?.toString(),
      'latitude': _toDouble(activity['latitude'] ?? activity['lat']),
      'longitude': _toDouble(
          activity['longitude'] ?? activity['lng'] ?? activity['lon']),
    };
  }

  Future<void> _addPlaceToItinerary(
    Map<String, dynamic> place,
    DateTime day,
    Map<String, String> slot,
  ) async {
    if (_resolvedTripId == null || _trip == null) return;
    final dayIndex = _dayIndexForDate(day);
    setState(() => _savingPlanChange = true);
    try {
      final tripPlacePayload = _tripPlacePayloadForPlace(place);
      if (tripPlacePayload['latitude'] != null &&
          tripPlacePayload['longitude'] != null) {
        try {
          await _tripService.addPlaceToTrip(_resolvedTripId!, tripPlacePayload);
        } catch (_) {
          // Duplicate or trip-place failures should not block editing the plan.
        }
      }
      await _tripService.addItineraryItem(
        _resolvedTripId!,
        dayIndex,
        _payloadForPlace(place, dayIndex, slot),
      );
      _selectedDay = day;
      await _loadTripItinerary(_trip!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${_placeName(place)} to Day $dayIndex.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add place: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPlanChange = false);
    }
  }

  Future<void> _moveActivity(
    Map<String, dynamic> activity,
    DateTime day,
    Map<String, String> slot,
  ) async {
    final itemId = activity['id']?.toString();
    if (_resolvedTripId == null || _trip == null || itemId == null) return;
    final dayIndex = _dayIndexForDate(day);
    setState(() => _savingPlanChange = true);
    try {
      await _tripService.updateItineraryItem(
        _resolvedTripId!,
        itemId,
        _payloadForActivity(activity, dayIndex, slot),
      );
      _selectedDay = day;
      await _loadTripItinerary(_trip!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to Day $dayIndex, ${slot['label']}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move activity: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPlanChange = false);
    }
  }

  void _showSchedulePlaceSheet(Map<String, dynamic> place) {
    _showDayTimeSheet(
      title: 'Add ${_placeName(place)}',
      subtitle: 'Choose where this place fits in your plan.',
      initialDay:
          _selectedDay ?? (_tripDays.isNotEmpty ? _tripDays.first : null),
      initialSlot: _timeSlots.first,
      actionLabel: 'Add to plan',
      onConfirm: (day, slot) => _addPlaceToItinerary(place, day, slot),
    );
  }

  void _showRescheduleSheet(Map<String, dynamic> activity) {
    final currentDay =
        _selectedDay ?? (_tripDays.isNotEmpty ? _tripDays.first : null);
    _showDayTimeSheet(
      title: 'Move ${(activity['name'] ?? activity['title'] ?? 'activity')}',
      subtitle: 'Pick a new day and time of day.',
      initialDay: currentDay,
      initialSlot: _slotForActivity(activity),
      actionLabel: 'Move activity',
      onConfirm: (day, slot) => _moveActivity(activity, day, slot),
    );
  }

  void _showDayTimeSheet({
    required String title,
    required String subtitle,
    required DateTime? initialDay,
    required Map<String, String> initialSlot,
    required String actionLabel,
    required Future<void> Function(DateTime day, Map<String, String> slot)
        onConfirm,
  }) {
    if (_tripDays.isEmpty) return;
    var selectedDay = initialDay ?? _tripDays.first;
    var selectedSlot = initialSlot;

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 18),
                  const Text('Day',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _tripDays.map((day) {
                      final selected = _norm(day) == _norm(selectedDay);
                      return ChoiceChip(
                        label: Text('Day ${_dayIndexForDate(day)}'),
                        selected: selected,
                        onSelected: (_) =>
                            setSheetState(() => selectedDay = day),
                        selectedColor: const Color(0xFF4675B8),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text('Time of day',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((slot) {
                      final selected = selectedSlot['label'] == slot['label'];
                      return ChoiceChip(
                        label: Text(
                            '${slot['label']} - ${slot['start']}-${slot['end']}'),
                        selected: selected,
                        onSelected: (_) =>
                            setSheetState(() => selectedSlot = slot),
                        selectedColor: const Color(0xFF4675B8),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingPlanChange
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await onConfirm(selectedDay, selectedSlot);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4675B8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteActivity(Map<String, dynamic> activity) async {
    final id = activity['id']?.toString();
    if (id == null || id.isEmpty || _resolvedTripId == null) return;
    try {
      await _tripService.deleteItineraryItem(_resolvedTripId!, id);
      if (_trip != null) await _loadTripItinerary(_trip!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  String _dayLabel(DateTime day) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[day.month]} ${day.year}';
  }

  List<Map<String, dynamic>> _mapPlaceSuggestions(
      List<Map<String, dynamic>> placeSuggestions, dynamic currentUserId) {
    return placeSuggestions.map((suggestion) {
      final isCurrentUserSuggestion =
          suggestion['suggested_by'] == currentUserId;
      return {
        'name': (suggestion['name'] ?? 'Place').toString(),
        'type': (suggestion['place_types'] is List &&
                (suggestion['place_types'] as List).isNotEmpty)
            ? ((suggestion['place_types'] as List).first).toString()
            : 'Place',
        'location':
            (suggestion['address'] ?? widget.destination ?? 'Trip').toString(),
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

  String _weekdayLabel(DateTime day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day.weekday - 1];
  }

  void _showActivityDetail(
      BuildContext context, Map<String, dynamic> activity) {
    final extraActions = isEditMode && activity['id'] != null
        ? <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showRescheduleSheet(activity);
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Move to another day or time'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4675B8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteActivity(activity);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove from plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]
        : null;

    openPlacePreviewFromMap(
      context,
      activity,
      tripId: _resolvedTripId ?? widget.tripId,
      fallbackLocation: widget.destination,
      extraActions: extraActions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _selectedDay != null
        ? _activitiesForDay(_selectedDay!)
        : const <Map<String, dynamic>>[];
    final selectedDay = _selectedDay ?? DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                _buildPlanToggle(context),
                if (_loading)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ),
                  )
                else if (_tripDays.isEmpty)
                  Expanded(child: _buildEmptyPlanView(context))
                else
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${selectedDay.day}',
                                    style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(_weekdayLabel(selectedDay),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF9E9E9E))),
                                  Text(_dayLabel(selectedDay),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF9E9E9E))),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Trip Days',
                                  style: TextStyle(
                                      color: Color(0xFFC8A858),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: _tripDays.map((day) {
                                final bool isSelected = _selectedDay != null &&
                                    _norm(_selectedDay!) == _norm(day);
                                const weekdays = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun'
                                ];
                                final String wd = weekdays[day.weekday - 1];
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedDay = day;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 72,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFC8A858)
                                          : const Color(0xFFFFF4E0),
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFFC8A858),
                                              width: 2)
                                          : Border.all(
                                              color: const Color(0xFFEDD98A),
                                              width: 1),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          wd,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFFC8A858),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFFC8A858),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: activities.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No activities for this day.',
                                      style: TextStyle(
                                          color: Color(0xFF9E9E9E),
                                          fontSize: 14),
                                    ),
                                  )
                                : ListView.builder(
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: activities.length,
                                    padding: const EdgeInsets.only(bottom: 20),
                                    itemBuilder: (context, index) {
                                      final activity = activities[index];
                                      final item = _activityToItem(activity,
                                          widget.destination ?? 'Trip');
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: GestureDetector(
                                          onTap: () => _showActivityDetail(
                                              context, activity),
                                          onLongPress: isEditMode &&
                                                  activity['id'] != null
                                              ? () =>
                                                  _showRescheduleSheet(activity)
                                              : null,
                                          child: _CalendarItineraryCard(
                                            item: item,
                                            showDelete: isEditMode &&
                                                activity['id'] != null,
                                            onDelete: () =>
                                                _deleteActivity(activity),
                                            onMove: isEditMode &&
                                                    activity['id'] != null
                                                ? () => _showRescheduleSheet(
                                                    activity)
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PlansList(source: 'generatedPlan')),
            ),
            child: const Icon(Icons.arrow_back,
                size: 24, color: Color(0xFF1E1E1E)),
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
                        final placeSuggestions = await _tripService
                            .getPlaceSuggestions(_resolvedTripId!);
                        final currentUserId =
                            Provider.of<UserProvider>(context, listen: false)
                                .currentProfile?['id'];
                        final mappedPlaceSuggestions = _mapPlaceSuggestions(
                            placeSuggestions, currentUserId);

                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BondersSuggestions(
                                suggestions: mappedPlaceSuggestions,
                                source: 'home',
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
                                source: 'home',
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
              if (_resolvedTripId != null && _tripDays.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 22),
                  tooltip: 'Add city place',
                  onPressed: _loadingPlaces ? null : _openPlaceBrowser,
                ),
              if (_isCreator && _resolvedTripId != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.group_add_outlined, size: 22),
                  tooltip: 'Join requests',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TripJoinRequestsScreen(
                      tripId: _resolvedTripId!,
                      tripTitle: widget.tripTitle ?? 'Trip',
                    ),
                  )),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  isEditMode ? Icons.check : Icons.edit_outlined,
                  size: 22,
                ),
                onPressed: () => setState(() => isEditMode = !isEditMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlanView(BuildContext context) {
    final canGenerate = _isCreator && _phase == 'finalized';
    final votingOpen = _phase == 'voting';
    final canOpenVoting = _isCreator && _phase == 'planning';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.airplanemode_active, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No plan generated yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _phase == 'planning'
                  ? 'Open voting once members have added their picks.'
                  : votingOpen
                      ? 'Voting is open. Wait for the creator to close it.'
                      : canGenerate
                          ? 'Voting is closed. Generate the AI plan from voted places.'
                          : 'Waiting for the creator to generate the plan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            if (_resolvedTripId != null) ...[
              if (canOpenVoting)
                ElevatedButton.icon(
                  onPressed: _openingVoting ? null : _openVoting,
                  icon: _openingVoting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.how_to_vote),
                  label: const Text('Start voting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4675B8),
                    foregroundColor: Colors.white,
                  ),
                ),
              if (votingOpen)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VotingScreen(
                        tripId: _resolvedTripId!,
                        tripTitle: widget.tripTitle ?? 'Trip',
                        isCreator: _isCreator,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.how_to_vote),
                  label: const Text('Open voting'),
                ),
              if (canGenerate)
                ElevatedButton.icon(
                  onPressed: _generating ? null : _generatePlan,
                  icon: _generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Generate plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4675B8),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ],
        ),
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
            child: GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AI_Plan(
                    tripId: _resolvedTripId ?? widget.tripId,
                    tripTitle: widget.tripTitle,
                    destination: widget.destination,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Text(
                  'Your Plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4675B8),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                'Calendar View',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return AppBottomNav(
      currentTab: AppNavTab.plan,
      planBuilder: (_) => GroupSuggestedItinerary(
        tripId: _resolvedTripId ?? widget.tripId,
        destination: widget.destination,
        tripTitle: widget.tripTitle,
      ),
    );
  }
}

class _PlaceBrowserSheet extends StatefulWidget {
  final String destination;
  final List<Map<String, dynamic>> places;
  final bool isLoading;
  final String? error;
  final ValueChanged<Map<String, dynamic>> onAdd;

  const _PlaceBrowserSheet({
    required this.destination,
    required this.places,
    required this.isLoading,
    required this.error,
    required this.onAdd,
  });

  @override
  State<_PlaceBrowserSheet> createState() => _PlaceBrowserSheetState();
}

class _PlaceBrowserSheetState extends State<_PlaceBrowserSheet> {
  String _query = '';

  String _textValue(Map<String, dynamic> place, List<String> keys) {
    for (final key in keys) {
      final value = place[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return '';
  }

  String _name(Map<String, dynamic> place) =>
      _textValue(place, ['name', 'title']);

  String _location(Map<String, dynamic> place) =>
      _textValue(place, ['address', 'location', 'formatted_address']);

  String _type(Map<String, dynamic> place) =>
      _textValue(place, ['type', 'category', 'poi_type']);

  double? _rating(Map<String, dynamic> place) {
    final value = place['rating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String? _imageUrl(Map<String, dynamic> place) {
    final image = place['photo_url'] ?? place['image_url'];
    final text = image?.toString();
    return text != null && text.startsWith('http') ? text : null;
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.places;
    return widget.places.where((place) {
      final haystack = [
        _name(place),
        _location(place),
        _type(place),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final places = _filteredPlaces;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add a city place',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.destination.isEmpty
                              ? 'Browse places'
                              : 'Browse ${widget.destination} places',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search places',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                widget.error!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : places.isEmpty
                            ? const Center(child: Text('No places found.'))
                            : ListView.separated(
                                itemCount: places.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) =>
                                    _PlaceBrowserTile(
                                  place: places[index],
                                  name: _name(places[index]),
                                  location: _location(places[index]),
                                  type: _type(places[index]),
                                  rating: _rating(places[index]),
                                  imageUrl: _imageUrl(places[index]),
                                  onAdd: () => widget.onAdd(places[index]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceBrowserTile extends StatelessWidget {
  final Map<String, dynamic> place;
  final String name;
  final String location;
  final String type;
  final double? rating;
  final String? imageUrl;
  final VoidCallback onAdd;

  const _PlaceBrowserTile({
    required this.place,
    required this.name,
    required this.location,
    required this.type,
    required this.rating,
    required this.imageUrl,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final images = placeImagesFromMap(place);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => openPlacePreviewFromMap(context, place),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: images.isNotEmpty
                    ? PlaceImageCarousel(
                        images: images,
                        height: 76,
                        showAttribution: false,
                      )
                    : imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _PlaceImageFallback(),
                          )
                        : const _PlaceImageFallback(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => openPlacePreviewFromMap(context, place),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlaceNameLink(
                    name: name.isEmpty ? 'Place' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    onTap: () => openPlacePreviewFromMap(context, place),
                  ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (type.isNotEmpty)
                      Flexible(
                        child: Text(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4675B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF4675B8)),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _PlaceImageFallback extends StatelessWidget {
  const _PlaceImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF4675B8),
      child: const Icon(Icons.place, color: Colors.white),
    );
  }
}

class _CalendarItineraryCard extends StatelessWidget {
  final ItineraryItem item;
  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback? onMove;

  const _CalendarItineraryCard({
    required this.item,
    required this.showDelete,
    required this.onDelete,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWhite = item.color == Colors.white;
    final images = item.images.isNotEmpty
        ? item.images
        : (item.imageUrl != null && item.imageUrl!.startsWith('http')
            ? [PlaceImageData(url: item.imageUrl!)]
            : <PlaceImageData>[]);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(16),
            border: isWhite ? Border.all(color: const Color(0xFFE0E0E0)) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                SizedBox(
                  width: 86,
                  child: PlaceImageCarousel(
                    images: images,
                    height: 118,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    showAttribution: false,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.startTime,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isWhite ? Colors.black : Colors.white,
                      ),
                    ),
                    Text(
                      item.endTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isWhite
                            ? const Color(0xFF9E9E9E)
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isWhite ? Colors.black : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isWhite
                                      ? const Color(0xFF757575)
                                      : Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                          if (!showDelete)
                            Icon(
                              Icons.more_vert,
                              color: isWhite
                                  ? const Color(0xFF9E9E9E)
                                  : Colors.white,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: isWhite
                                ? const Color(0xFF9E9E9E)
                                : Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: isWhite
                                    ? const Color(0xFF757575)
                                    : Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: const Color(0xFF4675B8),
                            child: Text(
                              item.person[0],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.person,
                            style: TextStyle(
                              fontSize: 12,
                              color: isWhite
                                  ? const Color(0xFF757575)
                                  : Colors.white.withOpacity(0.9),
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
        if (onMove != null)
          Positioned(
            top: 4,
            right: showDelete ? 32 : 4,
            child: GestureDetector(
              onTap: onMove,
              child: const Icon(
                Icons.settings_outlined,
                color: Color.fromARGB(255, 0, 0, 0),
                size: 20,
              ),
            ),
          ),
        if (showDelete)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close,
                color: Color.fromARGB(255, 0, 0, 0),
                size: 20,
              ),
            ),
          ),
      ],
    );
  }
}

class ItineraryItem {
  final String? id;
  final String? imageUrl;
  final List<PlaceImageData> images;
  final String startTime, endTime, title, subtitle, location, person;
  final Color color;

  ItineraryItem({
    this.id,
    this.imageUrl,
    this.images = const [],
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.person,
    required this.color,
  });
}
