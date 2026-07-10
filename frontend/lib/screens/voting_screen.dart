import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../services/vote_service.dart';
import '../services/auth_service.dart';
import '../widgets/place_image_carousel.dart';
import '../utils/place_navigation.dart';

class VotingScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final bool isCreator;

  const VotingScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
    this.isCreator = false,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final _tripService = TripService();
  final _voteService = VoteService();
  final _authService = AuthService();

  bool _loading = true;
  String? _error;
  String? _myUserId;
  List<Map<String, dynamic>> _places = [];
  Map<String, Map<String, dynamic>> _votesByPlace = {};
  Map<String, dynamic>? _flowStatus;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _myUserId = await _authService.getUserId();
      await _refresh();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await _tripService.listTripPlaces(widget.tripId);
      final votes = await _voteService.listTripVotes(widget.tripId);
      final flowStatus = await _tripService.getTripFlowStatus(widget.tripId);
      setState(() {
        _places = places;
        _votesByPlace = {
          for (final v in votes) v['trip_place_id'] as String: v,
        };
        _flowStatus = flowStatus;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _castVote(String placeId, int value) async {
    if (_myVotingComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reopen voting before changing votes.')),
      );
      return;
    }
    try {
      await _voteService.castVote(placeId, value);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _closeVoting() async {
    try {
      await _voteService.closeVoting(widget.tripId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voting closed. You can now generate the plan.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _markVotingComplete() async {
    try {
      await _tripService.markVotingComplete(widget.tripId);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voting marked complete.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _reopenVoting() async {
    try {
      await _tripService.reopenVoting(widget.tripId);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  bool get _myVotingComplete => _flowStatus?['my_voting_completed'] == true;
  bool get _canCloseVoting => _flowStatus?['can_close_voting'] == true;

  Map<String, List<Map<String, dynamic>>> _groupedByMember() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in _places) {
      final addedBy = (p['added_by'] ?? 'unknown').toString();
      groups.putIfAbsent(addedBy, () => []).add(p);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vote · ${widget.tripTitle}'),
        actions: [
          if (widget.isCreator)
            TextButton(
              onPressed: _places.isEmpty || !_canCloseVoting ? null : _closeVoting,
              child: const Text('Close voting',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      bottomNavigationBar: _loading || _error != null || _places.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 52,
                  child: _myVotingComplete
                      ? OutlinedButton(
                          onPressed: _reopenVoting,
                          child: const Text('Update my votes'),
                        )
                      : ElevatedButton(
                          onPressed: _markVotingComplete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4675B8),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('I am done voting'),
                        ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _places.isEmpty
                  ? const Center(
                      child: Text(
                        'No places to vote on yet.\nAdd places from the trip page first.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: _buildList(),
                    ),
    );
  }

  Widget _buildList() {
    final grouped = _groupedByMember();
    final sections = <Widget>[];
    grouped.forEach((memberId, places) {
      final memberLabel = _places
              .firstWhere((p) => p['added_by'] == memberId,
                  orElse: () => {'added_by_profile': null})['added_by_profile'] ??
          {};
      final name = (memberLabel is Map ? memberLabel['full_name'] : null) ??
          'Member ${memberId.substring(0, memberId.length.clamp(0, 6))}';
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            (memberId == _myUserId ? 'Your places' : 'Added by $name'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (final p in places) {
        sections.add(_buildPlaceCard(p, memberId == _myUserId));
      }
    });
    return ListView(children: sections);
  }

  Widget _buildPlaceCard(Map<String, dynamic> place, bool isMine) {
    final placeId = (place['id'] ?? '').toString();
    final voteRow = _votesByPlace[placeId];
    final myVote = voteRow != null ? voteRow['my_vote'] as int? : null;
    final voteCount = voteRow != null ? (voteRow['votes_count'] ?? 0) as int : 0;
    final avg = voteRow != null ? (voteRow['avg_value'] ?? 0).toDouble() : 0.0;
    final images = placeImagesFromMap(place);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openPlacePreviewFromMap(
          context,
          place,
          tripId: widget.tripId,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: PlaceImageCarousel(
                      images: images,
                      height: 60,
                      borderRadius: BorderRadius.circular(8),
                      showAttribution: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlaceNameLink(
                          name: (place['name'] ?? 'Place').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          onTap: () => openPlacePreviewFromMap(
                            context,
                            place,
                            tripId: widget.tripId,
                          ),
                        ),
                      if ((place['address'] ?? '').toString().isNotEmpty)
                        Text(
                          place['address'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  voteCount > 0
                      ? '${avg.toStringAsFixed(1)} avg · $voteCount votes'
                      : 'No votes yet',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                if (isMine)
                  const Text('Your place',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                else if (_myVotingComplete)
                  const Text('Voting complete',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                else
                  Row(
                    children: List.generate(5, (i) {
                      final value = i + 1;
                      final filled = (myVote ?? 0) >= value;
                      return IconButton(
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: filled ? Colors.amber : Colors.grey,
                        ),
                        onPressed:
                            _myVotingComplete ? null : () => _castVote(placeId, value),
                      );
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
