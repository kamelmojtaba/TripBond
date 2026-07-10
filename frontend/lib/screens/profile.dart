import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'settings.dart';
import 'editProfile.dart';
import 'chat_screen.dart';
import 'personality_quiz_screen.dart';
import 'feedback_screen.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import '../services/profileService.dart';
import '../services/feed_service.dart';
import '../services/trip_service.dart';
import '../services/user_service.dart';
import '../models/profile_model.dart';
import '../widgets/app_bottom_nav.dart';

const List<String> _tabs = ['Posted Trips', 'Liked Trips'];

class Profile extends StatefulWidget {
  const Profile({super.key});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String _activeTab = 'Posted Trips';
  //int _followerCount = 503;
  //final int _followingCount = 600;

  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _error;
  final FeedService _feedService = FeedService();
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _postedTrips = [];
  bool _isLoadingPostedTrips = true;
  String? _postedTripsError;
  List<Map<String, dynamic>> _likedTrips = [];
  bool _isLoadingLikedTrips = true;
  String? _likedTripsError;
  final List<Map<String, dynamic>> _followersData = [];
  final List<Map<String, dynamic>> _followingData = [];
  bool _isLoadingFollowers = false;
  bool _isLoadingFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPostedTrips();
    _loadLikedTrips();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService().fetchProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLikedTrips() async {
    try {
      final likedTrips = await _feedService.getMyLikedTrips();
      if (!mounted) return;
      setState(() {
        _likedTrips = likedTrips;
        _isLoadingLikedTrips = false;
        _likedTripsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _likedTripsError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLikedTrips = false;
      });
    }
  }

  Future<void> _loadPostedTrips() async {
    try {
      final trips = await _tripService.getMyTrips();
      if (!mounted) return;
      setState(() {
        _postedTrips = trips;
        _isLoadingPostedTrips = false;
        _postedTripsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postedTripsError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingPostedTrips = false;
      });
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
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

  String _displayName() {
    final fullName = _userProfile?.fullName?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final username = _userProfile?.username?.trim();
    if (username != null && username.isNotEmpty) return username;

    final email = _userProfile?.email.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return 'User';
  }

  // ---  DELETE DIALOG ---
  Future<void> _confirmDeleteTrip(Map<String, dynamic> trip) async {
    final tripId = (trip['id'] ?? '').toString();
    if (tripId.isEmpty) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            const Text("Delete Post",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this trip post? This action cannot be undone.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _tripService.deleteTrip(tripId);
                if (!mounted) return;
                setState(() {
                  _postedTrips
                      .removeWhere((item) => item['id']?.toString() == tripId);
                });
                Navigator.pop(context);
                showTopSnackBar(
                  Overlay.of(context),
                  const CustomSnackBar.success(
                    message: "Post deleted successfully",
                    backgroundColor: Color(0xFF4675B8),
                    icon: Icon(Icons.delete_outline,
                        color: Colors.white24, size: 80),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Delete",
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFollowersList() {
    final followersCount = _userProfile?.followers ?? 0;
    if (followersCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No followers yet'),
          backgroundColor: Color(0xFF4675B8),
        ),
      );
      return;
    }

    _loadFollowers().then((_) {
      if (!mounted) return;
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildFollowersModal());
    });
  }

  void _showFollowingList() {
    final followingCount = _userProfile?.following ?? 0;
    if (followingCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not following anyone yet'),
          backgroundColor: Color(0xFF4675B8),
        ),
      );
      return;
    }

    _loadFollowing().then((_) {
      if (!mounted) return;
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildFollowingModal());
    });
  }

  Future<void> _loadFollowers() async {
    if (_isLoadingFollowers) return;
    setState(() => _isLoadingFollowers = true);
    try {
      final followers = await _userService.getMyFollowers();
      if (!mounted) return;
      setState(() {
        _followersData
          ..clear()
          ..addAll(followers);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollowers = false);
      }
    }
  }

  Future<void> _loadFollowing() async {
    if (_isLoadingFollowing) return;
    setState(() => _isLoadingFollowing = true);
    try {
      final following = await _userService.getMyFollowing();
      if (!mounted) return;
      setState(() {
        _followingData
          ..clear()
          ..addAll(following);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollowing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildProfileInfo(),
                  _buildTabs(),
                  _buildContent(),
                ],
              ),
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            child:
                const Icon(Icons.more_vert, size: 20, color: Color(0xFF1E1E1E)),
            onSelected: (value) {
              switch (value) {
                case 'chat':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()));
                  break;
                case 'quiz':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PersonalityQuizScreen()));
                  break;
                case 'feedback':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FeedbackScreen()));
                  break;
                case 'settings':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const Settings()));
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Messages'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'quiz',
                child: Row(
                  children: [
                    Icon(Icons.quiz_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Personality Quiz'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'feedback',
                child: Row(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Give Feedback'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    final displayName = _displayName();
    final int userTripCount = _postedTrips.length;
    final avatarUrl = _userProfile?.avatarUrl?.trim() ?? '';
    final avatarBytes = _decodeDataUrlImage(avatarUrl);
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color.fromARGB(255, 244, 242, 242), width: 3)),
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
                    : Image.asset('assets/images/people/profile.png',
                        fit: BoxFit.cover)),
          ),
        ).animate().scale(delay: 100.ms).fadeIn(),
        const SizedBox(height: 12),
        Text(displayName,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 20)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const editprofile())),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit Profile',
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4675B8),
            side: const BorderSide(color: Color(0xFF4675B8)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStat('Trips', userTripCount.toString(), () {}),
            const SizedBox(width: 40),
            _buildStat('Followers', (_userProfile?.followers ?? 0).toString(),
                _showFollowersList),
            const SizedBox(width: 40),
            _buildStat('Following', (_userProfile?.following ?? 0).toString(),
                _showFollowingList),
          ],
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey.shade400)),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        ]));
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _tabs.map((tab) {
          final isActive = tab == _activeTab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(tab,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          color:
                              isActive ? Colors.black : Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  Container(
                      height: 2,
                      width: 80,
                      color: isActive ? Colors.black : Colors.transparent),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_activeTab == 'Liked Trips') return _buildLikedGrid();

    if (_isLoadingPostedTrips) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_postedTripsError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('Error: $_postedTripsError')),
      );
    }

    if (_postedTrips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No posted trips yet',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _postedTrips
            .map((trip) => _buildTripTile(trip, allowDelete: true)
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(delay: 100.ms))
            .toList(),
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip, {bool allowDelete = false}) {
    final title = (trip['title'] ?? 'Untitled Trip').toString();
    final destination =
        (trip['destination'] ?? trip['location'] ?? 'Trip').toString();
    final imageUrl = (trip['image_url'] ?? '').toString();
    final createdAt = _createdAtLabel(trip['created_at']);

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildTripImage(imageUrl),
                if (allowDelete &&
                    (trip['created_by'] ?? '').toString() == _userProfile?.id)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _confirmDeleteTrip(trip),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ],
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    const Icon(Icons.location_on,
                        size: 10, color: Color(0xFF4675B8)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(destination,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9E9E9E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis))
                  ]),
                  Text(createdAt,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripImage(String imageUrl) {
    final imageBytes = _decodeDataUrlImage(imageUrl);
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        height: 110,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    if (imageUrl.isNotEmpty) {
      final isNetwork =
          imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
      return isNetwork
          ? Image.network(
              imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildTripImageFallback(),
            )
          : Image.asset(
              imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildTripImageFallback(),
            );
    }

    return _buildTripImageFallback();
  }

  Widget _buildTripImageFallback() {
    return Container(
      height: 110,
      width: double.infinity,
      color: const Color(0xFFE9EEF7),
      child: Icon(
        Icons.travel_explore,
        color: const Color(0xFF4675B8).withValues(alpha: 0.7),
        size: 28,
      ),
    );
  }

  String _createdAtLabel(dynamic rawCreatedAt) {
    final createdAt = DateTime.tryParse(rawCreatedAt?.toString() ?? '');
    if (createdAt == null) return 'Recently';
    return _getTimeAgo(createdAt.toLocal());
  }

  Widget _buildLikedGrid() {
    if (_isLoadingLikedTrips) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_likedTripsError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('Error: $_likedTripsError')),
      );
    }

    if (_likedTrips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No liked trips yet',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _likedTrips.asMap().entries.map((entry) {
          final trip = entry.value;
          return _buildLikedTripTile(trip, entry.key)
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(delay: 50.ms);
        }).toList(),
      ),
    );
  }

  Widget _buildLikedTripTile(Map<String, dynamic> trip, int index) {
    final tripId = (trip['id'] ?? '').toString();

    return Stack(
      children: [
        _buildTripTile(trip),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: tripId.isEmpty
                ? null
                : () async {
                    try {
                      await _feedService.unlikeTrip(tripId);
                      if (!mounted) return;
                      setState(() {
                        _likedTrips.removeAt(index);
                      });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              e.toString().replaceFirst('Exception: ', '')),
                        ),
                      );
                    }
                  },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite,
                  size: 18, color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return const AppBottomNav(currentTab: AppNavTab.profile);
  }

  Widget _buildFollowersModal() {
    return _buildUserListModal(
        "Followers", _followersData, _isLoadingFollowers);
  }

  Widget _buildFollowingModal() {
    return _buildUserListModal(
        "Following", _followingData, _isLoadingFollowing);
  }

  Widget _buildUserListModal(
    String title,
    List<Map<String, dynamic>> users,
    bool isLoading,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(
                        child: Text(
                          title == 'Followers'
                              ? 'No followers yet'
                              : 'Not following anyone yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final name =
                              (user['name'] ?? 'TripBond User').toString();
                          final avatarUrl =
                              (user['avatar_url'] ?? '').toString();
                          final avatarBytes = _decodeDataUrlImage(avatarUrl);
                          final userId = (user['id'] ?? '').toString();
                          final hasAvatar = avatarUrl.isNotEmpty;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: hasAvatar
                                  ? Colors.transparent
                                  : const Color(0xFF4675B8),
                              backgroundImage: avatarBytes != null
                                  ? MemoryImage(avatarBytes)
                                  : (hasAvatar
                                      ? NetworkImage(avatarUrl)
                                      : null),
                              child: !hasAvatar
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    )
                                  : null,
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600)),
                            trailing: IconButton(
                              icon: const Icon(Icons.message_outlined,
                                  color: Colors.grey),
                              onPressed: userId.isEmpty
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ChatConversationScreen(
                                            otherUserId: userId,
                                            otherUserName: name,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
