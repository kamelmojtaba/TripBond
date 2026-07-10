import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/animations/animation_constants.dart';
import '../providers/trip_provider.dart';
import '../providers/user_provider.dart';
import '../services/city_service.dart';
import '../state/trip_creation_state.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/place_image_carousel.dart';
import 'AI_Plan.dart';
import 'bonder.dart';
import 'DatesPage.dart';
import 'DestinationLandingPage.dart';
import 'profile.dart';
import 'TripHomeScreen.dart';
import 'trip_flow_screen.dart';

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

class PlanItem {
  final String name;
  final String image;
  final String dateRange;
  final List<String> avatarInitials;

  const PlanItem({
    required this.name,
    required this.image,
    required this.dateRange,
    this.avatarInitials = const [],
  });
}

const List<Color> _avatarColors = [
  Color(0xFF4675B8),
  Color(0xFFC4A44A),
  Color(0xFFE87C5D),
];

class PlansList extends StatefulWidget {
  final String source; // 'home' or 'generatedPlan'
  const PlansList({super.key, this.source = 'home'});

  @override
  State<PlansList> createState() => _PlansListState();
}

class _PlansListState extends State<PlansList> {
  bool currentOpen = true;
  bool futureOpen = true;
  bool pastOpen = true;

  final _cityService = CityService();
  List<CityInfo> _cities = [];
  bool _loadingCities = true;
  String? _citiesError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<TripProvider>(context, listen: false).fetchMyTrips();
      Provider.of<UserProvider>(context, listen: false).fetchMyProfile();
    });
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await _cityService.listCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _citiesError = e.toString();
        _loadingCities = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterTripsByDate(
      List<Map<String, dynamic>> trips, bool isCurrent) {
    final now = DateTime.now();
    return trips.where((trip) {
      final startDate = trip['start_date'] != null
          ? DateTime.tryParse(trip['start_date'])
          : null;
      final endDate =
          trip['end_date'] != null ? DateTime.tryParse(trip['end_date']) : null;

      if (startDate == null || endDate == null) {
        return !isCurrent; // Put trips without dates in future
      }

      if (isCurrent) {
        // Current: ongoing trips (started but not ended)
        return startDate.isBefore(now) && endDate.isAfter(now);
      } else {
        // Future: trips that haven't started yet
        return startDate.isAfter(now);
      }
    }).toList();
  }

  List<Map<String, dynamic>> _filterPastTrips(
      List<Map<String, dynamic>> trips) {
    final now = DateTime.now();
    return trips.where((trip) {
      final endDate =
          trip['end_date'] != null ? DateTime.tryParse(trip['end_date']) : null;

      if (endDate == null) {
        return false;
      }

      // Past: trips that have already ended
      return endDate.isBefore(now);
    }).toList();
  }

  //the user must not be able to create a plan without setting the date (a safety net for edge cases like corrupted backend data.)
  String _formatDateRange(Map<String, dynamic> trip) {
    if (trip['start_date'] != null && trip['end_date'] != null) {
      try {
        final start = DateTime.parse(trip['start_date']);
        final end = DateTime.parse(trip['end_date']);
        return '${start.day} - ${end.day} ${_getMonthName(end.month)} ${end.year}';
      } catch (e) {
        return 'Invalid date'; // fallback for corrupted data only
      }
    }
    // This should never happen — backend must enforce date requirement
    return 'Invalid date';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          final currentTrips = _filterTripsByDate(tripProvider.myTrips, true);
          final futureTrips = _filterTripsByDate(tripProvider.myTrips, false);
          final realPastTrips = _filterPastTrips(tripProvider.myTrips);

          return Stack(
            children: [
              Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 4),
                        _buildDestinationCards(context),
                        const SizedBox(height: 16),
                        _buildPeopleBanner(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  Expanded(
                    child: tripProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 90),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  _buildSection('Current Plans', currentOpen,
                                      () {
                                    setState(() => currentOpen = !currentOpen);
                                  }, currentTrips),
                                  const SizedBox(height: 16),
                                  _buildSection('Future Plans', futureOpen, () {
                                    setState(() => futureOpen = !futureOpen);
                                  }, futureTrips),
                                  const SizedBox(height: 16),
                                  _buildSection('Past Plans', pastOpen, () {
                                    setState(() => pastOpen = !pastOpen);
                                  }, realPastTrips),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              _buildBottomNav(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final userName = userProvider.currentProfile?['first_name'] ??
              userProvider.currentProfile?['full_name'] ??
              'User';
          return Row(
            children: [
              const SizedBox(width: 24),
              const Spacer(),
              Text(
                "$userName's Plans",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 24),
            ],
          );
        },
      ),
    )
        .animate()
        .fadeIn(
          duration: Duration(milliseconds: AnimationConstants.normal),
          curve: AnimationConstants.cubicEaseOut,
        )
        .slideY(
          begin: -0.1,
          end: 0,
          duration: Duration(milliseconds: AnimationConstants.normal),
          curve: AnimationConstants.cubicEaseOut,
        );
  }

  Widget _buildSection(
      String title, bool isOpen, VoidCallback onToggle, List<dynamic> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Icon(
                isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.black,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isOpen) ...plans.map((plan) => _buildPlanCard(plan)),
      ],
    );
  }

  Widget _buildPlanCard(dynamic plan) {
    // Handle both PlanItem and Map<String, dynamic>
    final String name =
        plan is PlanItem ? plan.name : (plan['title'] ?? 'Untitled');
    final String image =
        plan is PlanItem ? plan.image : (plan['image_url'] ?? '');
    final String dateRange =
        plan is PlanItem ? plan.dateRange : _formatDateRange(plan);
    final List<String> avatarInitials =
        plan is PlanItem ? plan.avatarInitials : [];
    final String? tripId = plan is PlanItem ? null : (plan['id']?.toString());
    final String destination =
        plan is PlanItem ? plan.name : (plan['destination'] ?? name).toString();

    return GestureDetector(
      onTap: () {
        if (widget.source == 'generatedPlan' && tripId != null) {
          // From generated plan - navigate to AI_Plan for that trip
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AI_Plan(
                tripId: tripId,
                destination: destination,
                tripTitle: name,
              ),
            ),
          );
        } else if (tripId != null) {
          // From home/search - resume the gated trip flow.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TripFlowScreen(
                tripId: tripId,
                tripTitle: name,
                destination: destination,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TripHomeScreen(
                tripId: tripId,
                tripTitle: name,
                destination: destination,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image.startsWith('http')
                  ? Image.network(
                      image,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultTripImage(),
                    )
                  : image.isNotEmpty
                      ? Image.asset(
                          image,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultTripImage(),
                        )
                      : _defaultTripImage(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Color(0xFF666666)),
                      const SizedBox(width: 6),
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  if (avatarInitials.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 24,
                      child: Stack(
                        children: List.generate(avatarInitials.length, (i) {
                          return Positioned(
                            left: i * 18.0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _avatarColors[i % _avatarColors.length],
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                avatarInitials[i],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultTripImage() {
    return SizedBox(
      width: 90,
      height: 90,
      child: buildPlaceImagePlaceholder(iconSize: 40),
    );
  }

  String _getMonthName(int month) {
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
    return months[month];
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Where We Bonding?',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 22)),
          IconButton(
              onPressed: () => showSearch(
                  context: context,
                  delegate: DestinationSearchDelegate(initialCities: _cities)),
              icon: const Icon(Icons.search, size: 28)),
        ],
      ),
    );
  }

  Widget _buildDestinationCards(BuildContext context) {
    if (_loadingCities) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_citiesError != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load destinations',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _loadingCities = true;
                      _citiesError = null;
                    });
                    _loadCities();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_cities.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No destinations available.')),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final city = _cities[index];
          return _CityCard(
            city: city,
            onTap: () {
              selectedCityForTrip = city.name;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DatesPage(destination: city.name),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPeopleBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
            color: const Color(0xFF4675B8),
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
                width: 70,
                child: Stack(
                    children: List.generate(
                        3,
                        (i) => Positioned(
                            left: i * 20.0,
                            child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF4675B8),
                                        width: 2)),
                                child: const Icon(Icons.person,
                                    size: 16, color: Color(0xFF4675B8))))))),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('+8 people like this destination',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return const AppBottomNav(currentTab: AppNavTab.search);
  }
}

class _CityCard extends StatefulWidget {
  final CityInfo city;
  final VoidCallback onTap;
  const _CityCard({required this.city, required this.onTap});

  @override
  State<_CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<_CityCard>
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
    final featured = widget.city.isFeatured;
    final asset = widget.city.imageAsset;
    final imageUrl = widget.city.imageUrl ??
        (widget.city.images.isNotEmpty
            ? widget.city.images.first['url']?.toString()
            : null);
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapCancel: () => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: featured ? 170 : 150,
          height: featured ? 200 : 180,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (asset != null)
                  Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                else if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                else
                  _placeholder(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 8,
                  right: 8,
                  child: Column(
                    children: [
                      Text(
                        widget.city.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${widget.city.count} places',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return buildPlaceImagePlaceholder(iconSize: 48);
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
  final _cityService = CityService();
  final List<CityInfo>? initialCities;
  late final Future<List<CityInfo>> _citiesFuture;

  DestinationSearchDelegate({this.initialCities}) {
    _citiesFuture = initialCities != null && initialCities!.isNotEmpty
        ? Future.value(initialCities)
        : _cityService.listCities();
  }

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _build(context);

  @override
  Widget buildSuggestions(BuildContext context) => _build(context);

  Widget _build(BuildContext context) {
    return FutureBuilder<List<CityInfo>>(
      future: _citiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final cities = snapshot.data ?? const <CityInfo>[];
        final q = query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? cities
            : cities
                .where((c) =>
                    c.name.toLowerCase().contains(q) ||
                    c.province.toLowerCase().contains(q))
                .toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No cities match your search.'));
        }
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final city = filtered[i];
            return ListTile(
              leading: const Icon(Icons.location_city),
              title: Text(city.name),
              subtitle: Text(
                  '${city.province.isNotEmpty ? '${city.province} · ' : ''}${city.count} places'),
              onTap: () {
                selectedCityForTrip = city.name;
                close(context, null);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DatesPage(destination: city.name),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
