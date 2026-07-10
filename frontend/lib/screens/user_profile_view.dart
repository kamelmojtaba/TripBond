import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/trip_service.dart';
import 'chat_screen.dart';

class UserProfileView extends StatefulWidget {
  final String userId;
  final String userName;

  const UserProfileView({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final UserService _userService = UserService();
  final TripService _tripService = TripService();

  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userTrips = [];

  bool _isFollowing = false;
  bool _isBonded = false;
  bool _bondRequestPending = false;
  String _bondRequestStatus = 'none';

  bool _isLoadingProfile = true;
  bool _isLoadingTrips = true;
  bool _isFollowLoading = false;
  bool _isBondLoading = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRelationship();
    _loadUserTrips();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _userService.getUserProfile(widget.userId);
      if (!mounted) return;

      setState(() {
        _userProfile = profile;
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      print('DEBUG: Profile load error: $e'); // Debug log
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserTrips() async {
    try {
      final trips = await _tripService.getTripsByUser(widget.userId);
      if (!mounted) return;

      setState(() {
        _userTrips = trips;
        _isLoadingTrips = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTrips = false;
      });
    }
  }

  Future<void> _loadRelationship() async {
    try {
      final relationship = await _userService.getRelationship(widget.userId);
      if (!mounted) return;

      final status = (relationship['bond_request_status'] ?? 'none').toString();
      setState(() {
        _isFollowing = relationship['is_following'] == true;
        _isBonded = relationship['is_friend'] == true;
        _bondRequestStatus = status;
        _bondRequestPending = status == 'pending_sent';
      });
    } catch (_) {
      // Relationship state is secondary to rendering the public profile.
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await _userService.unfollowUser(widget.userId);
      } else {
        await _userService.followUser(widget.userId);
      }

      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
        _isFollowLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowing
                ? 'Now following ${widget.userName}'
                : 'Unfollowed ${widget.userName}',
          ),
          backgroundColor: const Color(0xFF4675B8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFollowLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleBond() async {
    setState(() => _isBondLoading = true);
    try {
      if (_isBonded) {
        setState(() => _isBondLoading = false);
        return;
      } else if (_bondRequestStatus == 'pending_received') {
        await _userService.acceptBondRequest(widget.userId);
      } else if (_bondRequestPending) {
        await _userService.cancelBondRequest(widget.userId);
      } else {
        await _userService.sendBondRequest(widget.userId);
      }

      if (!mounted) return;
      final nextStatus = _bondRequestStatus == 'pending_received'
          ? 'accepted'
          : (_bondRequestPending ? 'none' : 'pending_sent');
      setState(() {
        _isBonded = nextStatus == 'accepted';
        _bondRequestStatus = nextStatus;
        _bondRequestPending = nextStatus == 'pending_sent';
        _isBondLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _bondRequestPending
                ? 'Bond request sent to ${widget.userName}'
                : (_isBonded ? 'You are now bonded' : 'Bond request cancelled'),
          ),
          backgroundColor: const Color(0xFFC8A858),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBondLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          otherUserId: widget.userId,
          otherUserName: widget.userName,
        ),
      ),
    );
  }

  Uint8List? _decodeDataUrlImage(String? value) {
    if (value == null) return null;
    final raw = value.trim();
    if (!raw.startsWith('data:image')) return null;
    final commaIndex = raw.indexOf(',');
    if (commaIndex < 0 || commaIndex >= raw.length - 1) return null;
    try {
      return base64Decode(raw.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  String _getDisplayName() {
    if (_userProfile == null) return widget.userName;
    return _userProfile?['full_name'] ??
        _userProfile?['username'] ??
        widget.userName;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF4675B8),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF4675B8),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade400),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final avatarUrl = _userProfile?['avatar_url']?.trim() ?? '';
    final avatarBytes = _decodeDataUrlImage(avatarUrl);
    final tripsCount = _userTrips.length;
    final followersCount = _userProfile?['followers_count'] ?? 0;
    final followingCount = _userProfile?['following_count'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF4675B8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color.fromARGB(255, 244, 242, 242),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarBytes != null
                          ? Image.memory(avatarBytes, fit: BoxFit.cover)
                          : (avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/people/profile.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/people/profile.png',
                                  fit: BoxFit.cover,
                                )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User Name
                  Text(
                    _getDisplayName(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Follow and Bond Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Follow Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isFollowLoading ? null : _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Colors.grey[300]
                                : const Color(0xFF4675B8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isFollowLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _isFollowing
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    color: _isFollowing
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bond / Message Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isBondLoading
                              ? null
                              : (_isBonded ? _openChat : _toggleBond),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isBonded
                                ? const Color(0xFF4675B8)
                                : ((_bondRequestPending || _isBonded)
                                    ? Colors.grey[300]
                                    : const Color(0xFFC8A858)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isBondLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      (_bondRequestPending || _isBonded) &&
                                              !_isBonded
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isBonded
                                      ? 'Message'
                                      : (_bondRequestStatus ==
                                              'pending_received'
                                          ? 'Accept Bond'
                                          : (_bondRequestPending
                                              ? 'Pending'
                                              : 'Bond')),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    color: _isBonded
                                        ? Colors.white
                                        : ((_bondRequestPending || _isBonded)
                                            ? Colors.black
                                            : Colors.white),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStat('Trips', tripsCount.toString()),
                      const SizedBox(width: 40),
                      _buildStat('Followers', followersCount.toString()),
                      const SizedBox(width: 40),
                      _buildStat('Following', followingCount.toString()),
                    ],
                  ),
                ],
              ),
            ),
            // Posted Trips Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Posted Trips',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_isLoadingTrips)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_userTrips.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No trips posted yet',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _userTrips.length,
                      itemBuilder: (context, index) {
                        final trip = _userTrips[index];
                        return _buildTripCard(trip);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final title = trip['title'] ?? 'Untitled Trip';
    final destination = trip['destination'] ?? '';
    final startDate = trip['start_date'] ?? '';
    final endDate = trip['end_date'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (destination.isNotEmpty)
              Text(
                'To: $destination',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            if (startDate.isNotEmpty)
              Text(
                'Dates: $startDate - $endDate',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
