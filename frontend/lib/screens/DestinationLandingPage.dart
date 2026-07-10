import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'DatesPage.dart';
import 'Bonder.dart';
import 'profile.dart';
import 'places_search_screen.dart';
import 'nearby_places_screen.dart';
import 'AI_Plan.dart';
import 'plans_list.dart';
import 'chat_screen.dart';
import 'poi_explorer_screen.dart';
import 'TripHomeScreen.dart';
import 'trip_preview_screen.dart';
import '../services/favorites_service.dart';
import '../services/feed_service.dart';
import '../providers/trip_provider.dart';
import '../state/trip_creation_state.dart';
import '../widgets/app_bottom_nav.dart';

class Destination {
  final int id;
  final String name;
  final String image;
  final List<String> stars;
  final bool featured;
  const Destination(
      {required this.id,
      required this.name,
      required this.image,
      required this.stars,
      this.featured = false});
}

class Post {
  final String id;
  final String userName;
  final String location;
  final String image;
  final String title;
  int likes;
  String privacy;
  final DateTime timestamp; // to track actual posting time

  Post({
    String? id,
    required this.userName,
    required this.location,
    required this.image,
    required this.title,
    required this.likes,
    required this.privacy,
    required this.timestamp,
  }) : id = id ?? '${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}';
}

// --- GLOBAL LISTS ---

final List<Destination> destinations = [
  Destination(
      id: 1,
      name: 'Buraidah',
      image: 'assets/images/cities/Buraidah.png',
      stars: ['star', 'star', 'star']),
  Destination(
      id: 2,
      name: 'Khobar',
      image: 'assets/images/cities/Khobar.png',
      stars: ['star', 'star', 'star'],
      featured: true),
  Destination(
      id: 3,
      name: 'Jeddah',
      image: 'assets/images/cities/jeddah.png',
      stars: ['star', 'star', 'star']),
];

List<Post> posts = [
  Post(
      userName: 'Sarah Mohamed',
      location: 'Al Khobar',
      image: 'assets/images/cities/khobar2.png',
      title: 'Family Trip',
      likes: 8,
      privacy: 'Public',
      timestamp: DateTime.now().subtract(const Duration(hours: 2))),
  Post(
      userName: 'Ahmed Ali',
      location: 'Jeddah',
      image: 'assets/images/cities/jeddah.png',
      title: 'Weekend Gateway',
      likes: 12,
      privacy: 'Public',
      timestamp: DateTime.now().subtract(const Duration(days: 1))),
  Post(
      userName: 'Fatima Khan',
      location: 'Riyadh',
      image: 'assets/images/cities/Riyadh.png',
      title: 'Adventure Time',
      likes: 5,
      privacy: 'Public',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45))),
];

class DestinationLandingPage extends StatefulWidget {
  const DestinationLandingPage({super.key});
  @override
  State<DestinationLandingPage> createState() => _DestinationLandingPageState();
}

class _DestinationLandingPageState extends State<DestinationLandingPage> {
  final FavoritesService _favoritesService = FavoritesService();
  final FeedService _feedService = FeedService();
  final Map<String, Map<String, dynamic>> _favoriteByTitle = {};
  bool _isLoadingFavorites = true;
  List<Map<String, dynamic>> _feed = [];
  bool _isLoadingFeed = true;
  String? _feedError;

  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadFeed();
    Future.microtask(() {
      Provider.of<TripProvider>(context, listen: false).fetchMyTrips();
    });
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoadingFeed = true;
      _feedError = null;
    });
    try {
      final feed = await _feedService.fetchFeed();
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _isLoadingFeed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.toString();
        _isLoadingFeed = false;
      });
    }
  }

  void _openTripPreview(Map<String, dynamic> trip) {
    final tripId = trip['id']?.toString() ?? '';
    if (tripId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripPreviewScreen(
        tripId: tripId,
        initialTrip: trip,
        onTripChanged: (updatedTrip) {
          if (!mounted) return;
          setState(() {
            trip
              ..clear()
              ..addAll(updatedTrip);
          });
        },
      ),
    ));
  }

  Future<void> _loadFavorites() async {
    try {
      print('[DestinationLandingPage] Starting _loadFavorites');
      final favorites = await _favoritesService.getMyFavorites();
      print('[DestinationLandingPage] Loaded ${favorites.length} favorites');
      if (!mounted) return;
      setState(() {
        _favoriteByTitle
          ..clear()
          ..addEntries(favorites.map((favorite) {
            final title =
                (favorite['destination_name'] ?? '').toString().trim();
            return MapEntry(title, favorite);
          }).where((entry) => entry.key.isNotEmpty));
        _isLoadingFavorites = false;
      });
      print('[DestinationLandingPage] _loadFavorites completed successfully');
    } catch (e) {
      print('[DestinationLandingPage] Error loading favorites: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFavorites = false;
      });
    }
  }

  Future<void> _toggleFavorite(Post post) async {
    final favorite = _favoriteByTitle[post.title];
    try {
      if (favorite != null) {
        await _favoritesService
            .removeFavorite((favorite['id'] ?? '').toString());
        if (!mounted) return;
        setState(() {
          _favoriteByTitle.remove(post.title);
          if (post.likes > 0) {
            post.likes--;
          }
        });
      } else {
        final savedFavorite = await _favoritesService.addFavorite(
          destinationName: post.title,
          destinationType: post.location,
        );
        if (!mounted) return;
        setState(() {
          _favoriteByTitle[post.title] = savedFavorite;
          post.likes++;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showPickTripSheet() {
    String selectedPrivacy = 'Public';
    String selectedCategory = 'Future Plans';
    Map<String, dynamic>? selectedTrip;
    final TextEditingController titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final tripProvider = Provider.of<TripProvider>(context);
            final allTrips = tripProvider.myTrips;

            print(
                'DEBUG: TripProvider loading state: ${tripProvider.isLoading}');
            print('DEBUG: All trips count: ${allTrips.length}');
            print('DEBUG: All trips: $allTrips');

            List<Map<String, dynamic>> currentDisplayList =
                _filterTripsByCategory(allTrips, selectedCategory);

            print(
                'DEBUG: Filtered trips for category "$selectedCategory": ${currentDisplayList.length}');
            print('DEBUG: Filtered trips: $currentDisplayList');

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      left: 16,
                      right: 16,
                      top: 20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text("Create Post",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 22)),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCategory,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 20),
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: Colors.black),
                              items: [
                                'Past Plans',
                                'Current Plans',
                                'Future Plans'
                              ]
                                  .map((val) => DropdownMenuItem(
                                      value: val, child: Text(val)))
                                  .toList(),
                              onChanged: (val) => setModalState(() {
                                selectedCategory = val!;
                                selectedTrip = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const Text("Select a Trip Location to post:",
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      if (selectedTrip == null) ...[
                        if (currentDisplayList.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No trips found in this category',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ...currentDisplayList.map((trip) {
                            final tripName =
                                trip['title'] ?? trip['name'] ?? 'Trip';
                            final startDate = trip['start_date'] ?? '';
                            final endDate = trip['end_date'] ?? '';
                            final dateRange = '$startDate to $endDate';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.location_on,
                                    color: Color(0xFF4675B8)),
                                title: Text(tripName,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(dateRange,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600)),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 20),
                                onTap: () =>
                                    setModalState(() => selectedTrip = trip),
                              ),
                            );
                          }).toList(),
                      ] else ...[
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                color: const Color(0xFFF0F0F0),
                                child: selectedTrip!['image_url'] != null
                                    ? Image.network(
                                        selectedTrip!['image_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                          child:
                                              Icon(Icons.image_not_supported),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.image_not_supported),
                                      ),
                              ),
                            ),
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(15)),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.add_a_photo,
                                  color: Color(0xFF4675B8), size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: "Title your post...",
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade400, width: 2)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                    color: Color(0xFF4675B8), width: 2.5)),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4675B8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 80, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () {
                              if (titleController.text.isNotEmpty) {
                                setState(() {
                                  posts.insert(
                                      0,
                                      Post(
                                        userName: 'Sarah Mohamed',
                                        location: selectedTrip!['title'] ??
                                            selectedTrip!['name'] ??
                                            'Trip',
                                        image: selectedTrip!['image_url'] ??
                                            'assets/images/cities/jeddah.png',
                                        title: titleController.text,
                                        likes: 0,
                                        privacy: selectedPrivacy,
                                        timestamp: DateTime.now(),
                                      ));
                                });
                                Navigator.pop(context);
                              }
                            },
                            child: const Text("Post",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterTripsByCategory(
      List<Map<String, dynamic>> trips, String category) {
    final now = DateTime.now();

    return trips.where((trip) {
      final startDate = trip['start_date'] != null
          ? DateTime.tryParse(trip['start_date'])
          : null;
      final endDate =
          trip['end_date'] != null ? DateTime.tryParse(trip['end_date']) : null;

      if (startDate == null || endDate == null) {
        return category == 'Future Plans';
      }

      if (category == 'Past Plans') {
        return endDate.isBefore(now);
      } else if (category == 'Current Plans') {
        return startDate.isBefore(now) && endDate.isAfter(now);
      } else {
        // Future Plans
        return startDate.isAfter(now);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: _showPickTripSheet,
          backgroundColor: const Color(0xFF4675B8),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search for bonders...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey.shade400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Bonders(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoadingFeed)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_feedError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('Feed unavailable: $_feedError',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600])),
                        TextButton(
                          onPressed: _loadFeed,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_feed.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No public trips yet.')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100, top: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFeedTripCard(_feed[index])
                              .animate()
                              .fadeIn(delay: (450 + (index * 100)).ms)
                              .slideY(begin: 0.15, end: 0),
                        );
                      },
                      childCount: _feed.length,
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

  Widget _buildPostCard(Post post) {
    final isLiked = _favoriteByTitle.containsKey(post.title);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF4675B8)),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(post.userName,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(
                        "• ${_getTimeAgo(post.timestamp)}",
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (post.privacy == 'Private') ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.lock, size: 12, color: Colors.grey)
                      ]
                    ]),
                    Row(children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFF6F7789)),
                      const SizedBox(width: 4),
                      Text(post.location,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6F7789)))
                    ]),
                  ])),
              GestureDetector(
                onTap: _isLoadingFavorites
                    ? null
                    : () async => await _toggleFavorite(post),
                child: Row(
                  children: [
                    Text('${post.likes}',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLiked ? Colors.red : Colors.grey[600])),
                    const SizedBox(width: 4),
                    Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked ? Colors.red : Colors.grey[600]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(post.image,
                  width: double.infinity, height: 180, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Text(post.title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildFeedTripCard(Map<String, dynamic> trip) {
    final tripId = trip['id']?.toString() ?? '';
    final hasLiked = trip['has_liked'] == true;
    final likes = (trip['likes_count'] as int?) ?? 0;
    final memberCount = (trip['member_count'] as int?) ?? 1;
    final creator = (trip['creator'] as Map?) ?? {};
    final creatorName =
        (creator['full_name'] ?? creator['username'] ?? 'Traveler').toString();
    final destination = (trip['destination'] ?? '').toString();
    final title = (trip['title'] ?? 'Trip').toString();
    final imageUrl = (trip['image_url'] ?? '').toString();
    final pendingJoin = trip['has_pending_join_request'] == true;
    final canOpen = trip['is_creator'] == true || trip['is_member'] == true;

    DateTime? created;
    final rawCreated = trip['created_at'];
    if (rawCreated is String) {
      try {
        created = DateTime.parse(rawCreated).toLocal();
      } catch (_) {}
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openTripPreview(trip),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF4675B8),
                  backgroundImage: (creator['avatar_url'] != null &&
                          creator['avatar_url'].toString().isNotEmpty)
                      ? NetworkImage(creator['avatar_url'].toString())
                      : null,
                  child: (creator['avatar_url'] == null ||
                          creator['avatar_url'].toString().isEmpty)
                      ? Text(
                          creatorName.isNotEmpty
                              ? creatorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(creatorName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (created != null) ...[
                            const SizedBox(width: 8),
                            Text('• ${_getTimeAgo(created)}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                      if (destination.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Color(0xFF6F7789)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(destination,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF6F7789))),
                          ),
                        ]),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text('$likes',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hasLiked ? Colors.red : Colors.grey[600])),
                    const SizedBox(width: 4),
                    Icon(hasLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: hasLiked ? Colors.red : Colors.grey[600]),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: 180,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 180,
                      color: Colors.grey[200],
                      child: const Icon(Icons.airplanemode_active,
                          color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text('$memberCount members',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (pendingJoin && !canOpen) ...[
              const SizedBox(height: 4),
              const Text('Join request sent',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4675B8),
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openTripPreview(trip),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4675B8),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return const AppBottomNav(currentTab: AppNavTab.home);
  }
}

class _DestinationCard extends StatefulWidget {
  final Destination destination;
  final VoidCallback onTap;
  const _DestinationCard({required this.destination, required this.onTap});
  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: 150.ms);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onTap();
        },
        child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
                width: widget.destination.featured ? 170 : 150,
                height: widget.destination.featured ? 200 : 180,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset(widget.destination.image, fit: BoxFit.cover),
                      Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.center,
                                  colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent
                          ]))),
                      Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Text(widget.destination.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white)))
                    ])))));
  }
}

class DestinationSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) =>
      Center(child: Text('Searching for "$query"...'));
  @override
  Widget buildSuggestions(BuildContext context) {
    final list = destinations
        .where((city) => city.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) => ListTile(
            title: Text(list[i].name),
            onTap: () {
              query = list[i].name;
              showResults(context);
            }));
  }
}
