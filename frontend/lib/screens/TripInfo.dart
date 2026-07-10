import 'package:flutter/material.dart';
import 'trip_flow_screen.dart';
import '../services/trip_service.dart';
import '../services/user_service.dart';
import '../state/trip_creation_state.dart';

const List<String> _tripTypes = [
  'Solo Trip',
  'Group Trip',
];

bool _isGroupType(String? type) {
  if (type == null) return false;
  return type.toLowerCase().contains('group');
}

class TripInfo extends StatefulWidget {
  final String selectedDates;
  final DateTime startDate;
  final DateTime endDate;
  // Optional explicit destination. If empty, falls back to the global
  // [selectedCityForTrip] set when the user picked a city card.
  final String? destination;

  const TripInfo({
    super.key,
    required this.selectedDates,
    required this.startDate,
    required this.endDate,
    this.destination,
  });

  @override
  State<TripInfo> createState() => _TripinfoState();
}

class _TripinfoState extends State<TripInfo> {
  String? _selectedTripType;
  bool _isSubmitting = false;
  bool _isPublic = true;
  bool _loadingInvitees = true;
  final TextEditingController _titleController = TextEditingController();
  late String _destination;
  final List<Map<String, dynamic>> _inviteCandidates = [];
  final Set<String> _selectedInviteeIds = {};

  final _tripService = TripService();
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    final ctorDest = widget.destination?.trim() ?? '';
    _destination = ctorDest.isNotEmpty ? ctorDest : selectedCityForTrip.trim();
    if (_destination.isNotEmpty) {
      // Keep the global in sync so any legacy reader still gets the right value.
      selectedCityForTrip = _destination;
    }
    _loadInviteCandidates();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadInviteCandidates() async {
    try {
      final friends = await _userService.getMyFriends();
      final byId = <String, Map<String, dynamic>>{};
      for (final user in friends) {
        final id = (user['id'] ?? '').toString();
        if (id.isEmpty) continue;
        byId[id] = user;
      }
      if (!mounted) return;
      setState(() {
        _inviteCandidates
          ..clear()
          ..addAll(byId.values);
        _loadingInvitees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInvitees = false);
    }
  }

  bool get _canProceed {
    if (_selectedTripType == null) return false;
    if (_isGroupType(_selectedTripType)) {
      return _selectedInviteeIds.isNotEmpty;
    }
    return true;
  }

  Future<int> _sendSelectedInvites(String tripId) async {
    var failures = 0;
    for (final userId in _selectedInviteeIds) {
      try {
        await _tripService.addTripMember(tripId, userId);
      } catch (_) {
        failures++;
      }
    }
    return failures;
  }

  Future<void> _createTripAndPickPlaces() async {
    if (_destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No destination selected. Go back and choose a city first.',
          ),
        ),
      );
      return;
    }
    if (_selectedTripType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trip type')),
      );
      return;
    }
    if (_isGroupType(_selectedTripType) && _selectedInviteeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one bonder for a group trip'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : '$_destination Trip';
      final tripData = {
        'title': title,
        'destination': _destination,
        'location': _destination,
        'start_date': widget.startDate.toIso8601String().split('T').first,
        'end_date': widget.endDate.toIso8601String().split('T').first,
        'trip_type': _selectedTripType,
        'description': 'Planned with TripBond',
        'is_public': _isPublic,
      };

      final createdTrip = await _tripService.createTrip(tripData);
      final tripId = (createdTrip['id'] ?? '').toString();
      if (tripId.isEmpty) {
        throw Exception('Trip creation returned no ID');
      }

      final isGroupTrip = _isGroupType(_selectedTripType);
      final inviteFailures =
          isGroupTrip ? await _sendSelectedInvites(tripId) : 0;

      if (!mounted) return;
      if (isGroupTrip && _selectedInviteeIds.isNotEmpty) {
        final invited = _selectedInviteeIds.length - inviteFailures;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inviteFailures == 0
                  ? 'Invited $invited friend${invited == 1 ? '' : 's'} to add places.'
                  : 'Invited $invited, $inviteFailures failed.',
            ),
          ),
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TripFlowScreen(
            tripId: tripId,
            destination:
                (createdTrip['destination'] ?? _destination).toString(),
            tripTitle: (createdTrip['title'] ?? title).toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create trip: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Plan your Trip',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$_destination, Saudi Arabia",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildDepartureField(),
                    const SizedBox(height: 24),
                    _buildTitleField(),
                    const SizedBox(height: 24),
                    _buildDropdownField(
                      label: 'Trip Type',
                      value: _selectedTripType,
                      options: _tripTypes,
                      onChanged: (v) => setState(() {
                        _selectedTripType = v;
                        if (!_isGroupType(v)) {
                          _selectedInviteeIds.clear();
                        }
                      }),
                    ),
                    const SizedBox(height: 24),
                    _buildPublicToggle(),
                    const SizedBox(height: 16),
                    if (_isGroupType(_selectedTripType))
                      _buildSelectBondersSection(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _isSubmitting || !_canProceed ? null : _createTripAndPickPlaces,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4675B8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isGroupType(_selectedTripType)
                            ? 'Create trip · Invite & pick places'
                            : 'Continue · Pick places',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      child: Stack(
        // Using Stack to keep the back button on the left while centering the middle content
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back,
                    size: 24, color: Color(0xFF1E1E1E)),
              ),
            ),
          ),
          // Centered Row for Location and Dates
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey.shade800),
                    const SizedBox(width: 4),
                    Text(
                      _destination,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.selectedDates, // Displaying dates
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down,
                        size: 16, color: Colors.grey.shade800),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartureField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Departure point',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                _destination,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(25),
          ),
          child: options.isEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Colors.grey.shade500),
                  ],
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Colors.grey.shade500),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    items: options.map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trip Title',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: '$_destination Trip',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPublicToggle() {
    return Row(
      children: [
        const Icon(Icons.public, size: 18, color: Color(0xFF4675B8)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Share publicly in the feed',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        Switch.adaptive(
          value: _isPublic,
          activeColor: const Color(0xFF4675B8),
          onChanged: (v) => setState(() => _isPublic = v),
        ),
      ],
    );
  }

  Widget _buildSelectBondersSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBDCEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.group_outlined, color: Color(0xFF4675B8), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select bonders to join this trip. They can add places and vote together.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingInvitees)
            const SizedBox(
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_inviteCandidates.isEmpty)
            const Text(
              'No bonders found yet. Bond with people first, then add them to your group trip.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _inviteCandidates.map((user) {
                final id = (user['id'] ?? '').toString();
                final name = (user['name'] ??
                        user['full_name'] ??
                        user['username'] ??
                        'TripBond User')
                    .toString();
                final selected = _selectedInviteeIds.contains(id);
                return FilterChip(
                  selected: selected,
                  label: Text(name),
                  avatar: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF4675B8).withValues(alpha: 0.12),
                    child: Text(
                      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF4675B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  selectedColor: const Color(0xFFDCEAF8),
                  checkmarkColor: const Color(0xFF4675B8),
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _selectedInviteeIds.remove(id);
                      } else {
                        _selectedInviteeIds.add(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
