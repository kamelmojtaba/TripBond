import 'package:flutter/material.dart';

import '../services/feed_service.dart';
import '../services/trip_service.dart';
import '../utils/place_navigation.dart';
import 'trip_flow_screen.dart';

class TripPreviewScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> initialTrip;
  final ValueChanged<Map<String, dynamic>>? onTripChanged;

  const TripPreviewScreen({
    super.key,
    required this.tripId,
    required this.initialTrip,
    this.onTripChanged,
  });

  @override
  State<TripPreviewScreen> createState() => _TripPreviewScreenState();
}

class _TripPreviewScreenState extends State<TripPreviewScreen> {
  final _tripService = TripService();
  final _feedService = FeedService();

  late Map<String, dynamic> _trip;
  Map<String, dynamic>? _itinerary;
  bool _loadingTrip = true;
  bool _loadingItinerary = true;
  bool _liking = false;
  bool _requestingJoin = false;
  String? _error;
  String? _itineraryError;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.initialTrip);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingTrip = true;
      _loadingItinerary = true;
      _error = null;
      _itineraryError = null;
    });

    try {
      final details = await _tripService.getPublicTripDetails(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = {..._trip, ...details};
        _loadingTrip = false;
      });
      widget.onTripChanged?.call(_trip);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _trip.isEmpty ? e.toString() : null;
        _loadingTrip = false;
      });
    }

    try {
      final itinerary = await _tripService.getPublicItinerary(widget.tripId);
      if (!mounted) return;
      setState(() {
        _itinerary = itinerary;
        _loadingItinerary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itineraryError = e.toString();
        _loadingItinerary = false;
      });
    }
  }

  void _syncTrip(Map<String, dynamic> updates) {
    setState(() {
      _trip = {..._trip, ...updates};
    });
    widget.onTripChanged?.call(_trip);
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    final wasLiked = _trip['has_liked'] == true;
    final currentLikes = _asInt(_trip['likes_count']);
    _syncTrip({
      'has_liked': !wasLiked,
      'likes_count': (currentLikes + (wasLiked ? -1 : 1)).clamp(0, 1 << 31),
    });

    setState(() => _liking = true);
    try {
      if (wasLiked) {
        await _feedService.unlikeTrip(widget.tripId);
      } else {
        await _feedService.likeTrip(widget.tripId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasLiked
              ? 'Removed from liked trips.'
              : 'Liked trip saved to your profile.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _syncTrip({'has_liked': wasLiked, 'likes_count': currentLikes});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _requestToJoin() async {
    if (_requestingJoin || _trip['has_pending_join_request'] == true) return;
    if (!_canRequestJoin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Join requests are only available for upcoming trips before they start.',
          ),
        ),
      );
      return;
    }
    setState(() => _requestingJoin = true);
    try {
      await _feedService.requestToJoin(widget.tripId);
      if (!mounted) return;
      _syncTrip({'has_pending_join_request': true});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingJoin = false);
    }
  }

  void _openTripFlow() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripFlowScreen(
        tripId: widget.tripId,
        tripTitle: _title,
        destination: _destination,
      ),
    ));
  }

  String get _title => (_trip['title'] ?? 'Trip').toString();
  String get _destination => (_trip['destination'] ?? '').toString();
  bool get _canOpenTrip =>
      _trip['is_creator'] == true || _trip['is_member'] == true;
  bool get _hasPendingJoin => _trip['has_pending_join_request'] == true;
  bool get _canRequestJoin {
    if (_trip['can_request_join'] is bool) {
      return _trip['can_request_join'] as bool;
    }
    final raw = _trip['start_date']?.toString();
    if (raw == null || raw.isEmpty) return false;
    final start = DateTime.tryParse(raw);
    if (start == null) return false;
    final today = DateTime.now();
    final startDay = DateTime(start.year, start.month, start.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return startDay.isAfter(todayDay);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDateRange() {
    final start = DateTime.tryParse(_trip['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(_trip['end_date']?.toString() ?? '');
    if (start == null || end == null) return 'Dates coming soon';
    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF4675B8),
      ),
      body: _loadingTrip
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      _buildHero(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 12),
                            _buildItineraryCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _buildActions(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final imageUrl = (_trip['image_url'] ?? '').toString();
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _heroFallback(),
            )
          : _heroFallback(),
    );
  }

  Widget _heroFallback() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.airplanemode_active, color: Colors.grey, size: 48),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final creator = (_trip['creator'] as Map?) ?? {};
    final creatorName =
        (creator['full_name'] ?? creator['username'] ?? 'Traveler').toString();
    final description = (_trip['description'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_destination.isNotEmpty)
                _chip(_destination, Icons.location_on_outlined),
              _chip(_formatDateRange(), Icons.calendar_today_outlined),
              _chip(
                  '${_asInt(_trip['member_count']).clamp(1, 1 << 31)} members',
                  Icons.group_outlined),
              _chip('${_asInt(_trip['likes_count'])} likes',
                  Icons.favorite_border),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hosted by $creatorName',
            style:
                TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildItineraryCard() {
    if (_loadingItinerary) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final days = _itinerary?['days'];
    if (days is! List || days.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: Color(0xFF4675B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _itineraryError != null
                    ? (_canRequestJoin
                        ? 'No public itinerary has been shared yet. You can still like it or request to join.'
                        : 'No public itinerary has been shared yet. You can still like this trip.')
                    : 'No itinerary has been added yet.',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Plan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...days.take(3).map((day) => _buildDayPreview(day)),
          if (days.length > 3)
            Text(
              '+ ${days.length - 3} more days',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _buildDayPreview(dynamic rawDay) {
    final day = rawDay is Map ? rawDay : const {};
    final activities = day['activities'];
    final activityList = activities is List ? activities : const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day['day'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...activityList.take(4).map((activity) {
            final item = activity is Map
                ? Map<String, dynamic>.from(activity)
                : <String, dynamic>{};
            final name =
                (item['name'] ?? item['title'] ?? 'Activity').toString();
            final time = (item['start_time'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => openPlacePreviewFromMap(
                  context,
                  item,
                  tripId: widget.tripId,
                ),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: Color(0xFF4675B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        time.isNotEmpty ? '$time · $name' : name,
                        style: const TextStyle(
                          color: Color(0xFF4675B8),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final hasLiked = _trip['has_liked'] == true;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _liking ? null : _toggleLike,
            icon: Icon(hasLiked ? Icons.favorite : Icons.favorite_border),
            label: Text(hasLiked ? 'Liked' : 'Like trip'),
            style: OutlinedButton.styleFrom(
              foregroundColor: hasLiked ? Colors.red : const Color(0xFF4675B8),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _canOpenTrip
              ? ElevatedButton.icon(
                  onPressed: _openTripFlow,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open trip'),
                  style: _primaryButtonStyle(),
                )
              : ElevatedButton.icon(
                  onPressed: !_canRequestJoin ||
                          _hasPendingJoin ||
                          _requestingJoin
                      ? null
                      : _requestToJoin,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    _hasPendingJoin
                        ? 'Request sent'
                        : !_canRequestJoin
                            ? 'Trip started'
                            : 'Request join',
                  ),
                  style: _primaryButtonStyle(),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4675B8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4675B8)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF4675B8),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
    );
  }
}
