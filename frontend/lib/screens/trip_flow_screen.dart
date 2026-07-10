import 'dart:async';

import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../services/vote_service.dart';
import 'group_suggested_itinerary.dart';
import 'trip_join_requests_screen.dart';
import 'trip_places_picker_screen.dart';
import 'voting_screen.dart';

class TripFlowScreen extends StatefulWidget {
  final String tripId;
  final String? tripTitle;
  final String? destination;

  const TripFlowScreen({
    super.key,
    required this.tripId,
    this.tripTitle,
    this.destination,
  });

  @override
  State<TripFlowScreen> createState() => _TripFlowScreenState();
}

class _TripFlowScreenState extends State<TripFlowScreen> {
  final _tripService = TripService();
  final _voteService = VoteService();

  bool _loading = true;
  bool _acting = false;
  String? _error;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _title =>
      (_trip?['title'] ?? widget.tripTitle ?? 'Trip').toString();

  String get _destination =>
      (_trip?['destination'] ?? widget.destination ?? '').toString();

  Map<String, dynamic>? get _trip {
    final trip = _status?['trip'];
    return trip is Map<String, dynamic> ? trip : null;
  }

  bool _bool(String key) => _status?[key] == true;

  int _int(String key) {
    final value = _status?[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _tripService.getTripFlowStatus(widget.tripId);
      if (!mounted) return;
      setState(() {
        _status = status;
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

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openPlacePicker() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripPlacesPickerScreen(
        tripId: widget.tripId,
        destination: _destination,
        tripTitle: _title,
        isCreator: _bool('is_creator'),
        goToVotingAfter: true,
        useStarterPlan: true,
      ),
    ));
    await _load();
  }

  Future<void> _openVoting() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VotingScreen(
        tripId: widget.tripId,
        tripTitle: _title,
        isCreator: _bool('is_creator'),
      ),
    ));
    await _load();
  }

  Future<void> _startVoting() => _runAction(() async {
        await _voteService.openVoting(widget.tripId);
      });

  Future<void> _closeVoting() => _runAction(() async {
        await _voteService.closeVoting(widget.tripId);
      });

  Future<void> _markPlacesComplete() => _runAction(() async {
        await _tripService.markPlacesComplete(widget.tripId);
      });

  Future<void> _markVotingComplete() => _runAction(() async {
        await _tripService.markVotingComplete(widget.tripId);
      });

  Future<void> _generatePlan() => _runAction(() async {
        await _tripService.generateItinerary(widget.tripId, {});
      });

  void _viewPlan() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GroupSuggestedItinerary(
        tripId: widget.tripId,
        tripTitle: _title,
        destination: _destination,
      ),
    ));
  }

  void _viewJoinRequests() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripJoinRequestsScreen(
        tripId: widget.tripId,
        tripTitle: _title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF4675B8),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 12),
                      _buildStageCard(),
                      const SizedBox(height: 12),
                      _buildMembersCard(),
                    ],
                  ),
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

  Widget _buildHeader() {
    final phase = (_status?['phase'] ?? 'planning').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (_destination.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_destination, style: TextStyle(color: Colors.grey[700])),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(_phaseLabel(phase), Icons.flag_outlined),
              _chip('${_int('member_count')} members', Icons.group_outlined),
              _chip('${_int('places_count')} places', Icons.place_outlined),
              if (_int('pending_invites_count') > 0)
                _chip('${_int('pending_invites_count')} pending',
                    Icons.mail_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard() {
    final phase = (_status?['phase'] ?? 'planning').toString();
    if (_bool('has_itinerary')) {
      return _buildPlannedStage();
    }
    switch (phase) {
      case 'voting':
        return _buildVotingStage();
      case 'finalized':
        return _buildGenerateStage();
      case 'planned':
        return _buildPlannedStage();
      case 'planning':
      default:
        return _buildPlanningStage();
    }
  }

  Widget _buildPlanningStage() {
    final myComplete = _bool('my_places_completed');
    final canOpen = _bool('can_open_voting');
    return _stageShell(
      icon: Icons.add_location_alt_outlined,
      title: myComplete ? 'Waiting for places' : 'Choose your places',
      body: myComplete
          ? 'You marked your picks complete. Voting starts after everyone is done and the creator opens voting.'
          : 'Start with a suggested itinerary for the destination, adjust the places, then add them to the shared voting pool.',
      children: [
        if (!myComplete)
          _primaryButton('Review suggested itinerary', _openPlacePicker),
        if (!myComplete && _int('my_places_count') > 0)
          _secondaryButton('I am done adding places', _markPlacesComplete),
        if (_bool('is_creator')) ...[
          _secondaryButton('Review join requests', _viewJoinRequests),
          _primaryButton(
            canOpen ? 'Start voting' : 'Waiting for members',
            canOpen ? _startVoting : null,
          ),
        ],
      ],
    );
  }

  Widget _buildVotingStage() {
    final myComplete = _bool('my_voting_completed');
    final canClose = _bool('can_close_voting');
    return _stageShell(
      icon: Icons.how_to_vote_outlined,
      title: myComplete ? 'Waiting for votes' : 'Vote on places',
      body: myComplete
          ? 'Your voting is complete. The creator can close voting once everyone is done.'
          : 'Rate the group places. You cannot vote on places you added yourself.',
      children: [
        if (!myComplete)
          _primaryButton('Vote on places', _openVoting)
        else
          _secondaryButton('Review votes', _openVoting),
        if (!myComplete)
          _secondaryButton('I am done voting', _markVotingComplete),
        if (_bool('is_creator'))
          _primaryButton(
            canClose ? 'Close voting' : 'Waiting for voters',
            canClose ? _closeVoting : null,
          ),
      ],
    );
  }

  Widget _buildGenerateStage() {
    final canGenerate = _bool('can_generate_plan');
    return _stageShell(
      icon: Icons.auto_awesome,
      title: _bool('is_creator') ? 'Ready to generate' : 'Waiting for the plan',
      body: _bool('is_creator')
          ? 'Voting is closed. Generate the AI plan from the ranked vote results.'
          : 'Voting is closed. The creator can now generate the AI plan.',
      children: [
        if (_bool('is_creator'))
          _primaryButton(
            canGenerate ? 'Generate plan' : 'Plan already generated',
            canGenerate ? _generatePlan : null,
          )
        else
          _secondaryButton('Refresh status', _load),
      ],
    );
  }

  Widget _buildPlannedStage() {
    return _stageShell(
      icon: Icons.map_outlined,
      title: 'Plan is ready',
      body:
          'The AI itinerary has been generated. Open it to follow the trip plan.',
      children: [
        _primaryButton('View plan', _viewPlan),
      ],
    );
  }

  Widget _buildMembersCard() {
    final members = _status?['members'];
    final rows = members is List ? members : const [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Member progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            if (row is Map) _memberRow(Map<String, dynamic>.from(row)),
        ],
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> member) {
    final name = (member['full_name'] ?? 'Member').toString();
    final isCreator = member['is_creator'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF4675B8),
            backgroundImage: (member['avatar_url'] ?? '').toString().isNotEmpty
                ? NetworkImage(member['avatar_url'].toString())
                : null,
            child: (member['avatar_url'] ?? '').toString().isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreator ? '$name · Creator' : name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${member['places_count'] ?? 0} places · ${member['votes_count'] ?? 0} votes',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          _statusIcon(member['places_completed'] == true, Icons.place),
          const SizedBox(width: 8),
          _statusIcon(member['voting_completed'] == true, Icons.how_to_vote),
        ],
      ),
    );
  }

  Widget _stageShell({
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4675B8), size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: Colors.grey[700], height: 1.35)),
          const SizedBox(height: 16),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, FutureOr<void> Function()? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _acting || onPressed == null ? null : () => onPressed(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4675B8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _acting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _secondaryButton(String label, FutureOr<void> Function()? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _acting || onPressed == null ? null : () => onPressed(),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4675B8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF4675B8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF4675B8)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statusIcon(bool complete, IconData icon) {
    return Tooltip(
      message: complete ? 'Complete' : 'Waiting',
      child: Icon(
        complete ? Icons.check_circle : icon,
        color: complete ? Colors.green : Colors.grey[400],
        size: 22,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'voting':
        return 'Voting';
      case 'finalized':
        return 'Ready for AI plan';
      case 'planned':
        return 'Plan ready';
      case 'planning':
      default:
        return 'Adding places';
    }
  }
}
