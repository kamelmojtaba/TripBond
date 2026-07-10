import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_model.dart';
import '../services/places_service.dart';
import '../services/trip_service.dart';
import '../services/auth_service.dart';
import '../widgets/place_image_carousel.dart';

class PlaceDetailsPage extends StatefulWidget {
  final String? placeId; // External place ID from Geoapify
  final double? latitude;
  final double? longitude;
  final String? name;
  final String? tripId; // Trip context for duplicate checking

  const PlaceDetailsPage({
    super.key,
    this.placeId,
    this.latitude,
    this.longitude,
    this.name,
    this.tripId,
  });

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage>
    with SingleTickerProviderStateMixin {
  final _placesService = PlacesService();
  final _tripService = TripService();
  final _authService = AuthService();

  late TabController _tabController;
  PlaceDetailsResponse? _placeDetails;
  bool _isLoading = true;
  String? _error;
  bool? _alreadyExists;
  String? _existenceMessage;
  bool _isAddingToPlan = false;
  bool _usingFallbackData = false; // Track if using saved card data
  Map<String, dynamic> _savedCardData = {}; // Original card data for fallback

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Store original card data for fallback display
    _savedCardData = {
      'name': widget.name,
      'latitude': widget.latitude,
      'longitude': widget.longitude,
    };

    _loadPlaceDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaceDetails() async {
    print('[PlaceDetailsPage] Loading place details with fallback strategy');
    print('[PlaceDetailsPage] PRIMARY: placeId=${widget.placeId}');
    print('[PlaceDetailsPage] FALLBACK: name=${widget.name}, '
        'lat=${widget.latitude}, lng=${widget.longitude}');

    setState(() {
      _isLoading = true;
      _error = null;
      _usingFallbackData = false;
    });

    try {
      PlaceDetailsResponse details;

      // STAGE 1: Use external place ID if available
      if (widget.placeId != null && widget.placeId!.isNotEmpty) {
        print('[PlaceDetailsPage] STAGE 1: Using external_place_id');
        details = await _placesService.getPlaceDetailsWithFallback(
          placeId: widget.placeId!,
          latitude: widget.latitude,
          longitude: widget.longitude,
          fallbackName: widget.name,
          country: 'SA', // Saudi Arabia
        );
      }
      // STAGE 2: Fallback to name-based search with coordinates
      else if (widget.name != null && widget.name!.isNotEmpty) {
        print(
            '[PlaceDetailsPage] STAGE 2: Using name-based search with coordinates');
        details = await _placesService.getPlaceDetailsWithFallback(
          placeId: widget.name!,
          latitude: widget.latitude,
          longitude: widget.longitude,
          fallbackName: widget.name,
          country: 'SA',
        );
      }
      // STAGE 3: No identifier available
      else {
        throw Exception('No place identifier provided');
      }

      // VALIDATION: Check if result makes sense
      if (details.result == null) {
        throw Exception('No result returned from API');
      }

      // DISTANCE VALIDATION: Ensure result is near expected location
      bool isResultAccurate = _validateResultAccuracy(
        details.result!.geometry?.lat,
        details.result!.geometry?.lng,
        details.result!.name,
      );

      if (!isResultAccurate) {
        print(
            '[PlaceDetailsPage] WARNING: Result does not match expected location');
        print('[PlaceDetailsPage] Expected: ${widget.name} at '
            '${widget.latitude}, ${widget.longitude}');
        print('[PlaceDetailsPage] Got: ${details.result?.name} at '
            '${details.result?.geometry?.lat}, ${details.result?.geometry?.lng}');
        throw Exception('Result location validation failed');
      }

      print('[PlaceDetailsPage] Loaded details: ${details.result?.name}');

      // Check for duplicates if tripId is provided
      if (widget.tripId != null && widget.tripId!.isNotEmpty) {
        await _checkDuplicate(details);
      }

      if (!mounted) return;
      setState(() {
        _placeDetails = details;
        _isLoading = false;
        _usingFallbackData = false;
      });
    } catch (e) {
      print('[PlaceDetailsPage] ERROR: ${e.toString()}');
      print('[PlaceDetailsPage] FALLBACK: Using saved card data');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not fetch exact match. Showing saved information.';
        _usingFallbackData = true;
      });
    }
  }

  /// Validate that API result is close to expected location
  bool _validateResultAccuracy(
      double? resultLat, double? resultLng, String? resultName) {
    // If no expected location, accept any result
    if (widget.latitude == null || widget.longitude == null) {
      return true;
    }

    // If no result location, reject
    if (resultLat == null || resultLng == null) {
      return false;
    }

    // Calculate distance using simple lat/lng difference (~111km per degree)
    final latDiff = (widget.latitude! - resultLat).abs();
    final lngDiff = (widget.longitude! - resultLng).abs();
    const maxAcceptableDiff = 0.5; // ~55km radius

    if (latDiff > maxAcceptableDiff || lngDiff > maxAcceptableDiff) {
      print('[PlaceDetailsPage] Location too far: '
          'latDiff=$latDiff, lngDiff=$lngDiff');
      return false;
    }

    // If name provided, check for name similarity
    if (widget.name != null && resultName != null) {
      final inputLower = widget.name!.toLowerCase();
      final resultLower = resultName.toLowerCase();

      // Accept exact match or if result name contains input
      if (!(inputLower == resultLower ||
          resultLower.contains(inputLower) ||
          inputLower.contains(resultLower))) {
        print('[PlaceDetailsPage] Name mismatch: '
            'expected="${widget.name}", got="$resultName"');
        return false;
      }
    }

    return true;
  }

  Future<void> _checkDuplicate(PlaceDetailsResponse details) async {
    try {
      print('[PlaceDetailsPage] Checking for duplicate...');
      final token = await _authService.getAuthToken();
      if (token == null) {
        print('[PlaceDetailsPage] No auth token');
        return;
      }

      final result = details.result;
      if (result == null) return;

      // Create payload for duplicate check
      final payload = {
        'external_place_id': result.placeId,
        'name': result.name,
        'latitude': result.geometry?.lat,
        'longitude': result.geometry?.lng,
        'trip_id': widget.tripId,
      };

      final response = await _tripService.checkPlaceDuplicate(
        widget.tripId!,
        payload,
      );

      print('[PlaceDetailsPage] Duplicate check response: $response');

      if (!mounted) return;
      setState(() {
        _alreadyExists = response['already_exists'] ?? false;
        _existenceMessage = response['message'];
      });
    } catch (e) {
      print('[PlaceDetailsPage] Error checking duplicate: $e');
      // Continue without duplicate check
    }
  }

  Future<void> _addToPlan() async {
    print('[PlaceDetailsPage] _addToPlan called');
    print('[PlaceDetailsPage] tripId: ${widget.tripId}');
    print('[PlaceDetailsPage] _placeDetails: ${_placeDetails}');
    print('[PlaceDetailsPage] _alreadyExists: $_alreadyExists');

    if (widget.tripId == null || widget.tripId!.isEmpty) {
      print('[PlaceDetailsPage] ERROR: No trip selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trip selected')),
      );
      return;
    }

    if (_placeDetails?.result == null) {
      print('[PlaceDetailsPage] ERROR: Place details not available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place details not available')),
      );
      return;
    }

    setState(() => _isAddingToPlan = true);

    try {
      final result = _placeDetails!.result!;
      print('[PlaceDetailsPage] Got place result: ${result.name}');

      final token = await _authService.getAuthToken();
      print('[PlaceDetailsPage] Token: ${token != null ? 'YES' : 'NO'}');
      if (token == null) throw Exception('Not authenticated');

      final payload = {
        'external_place_id': result.placeId,
        'name': result.name,
        'latitude': result.geometry?.lat,
        'longitude': result.geometry?.lng,
        'address': result.formattedAddress ?? '',
        'rating': result.rating,
        'user_ratings_total': result.userRatingsTotal,
        'types': result.types,
        'image_url': result.imageUrl,
        'photo_url': result.imageUrl,
        'images': result.images.map((image) => image.toJson()).toList(),
      };

      print('[PlaceDetailsPage] Payload: $payload');
      print(
          '[PlaceDetailsPage] Calling addPlaceToTrip with tripId: ${widget.tripId}');

      final response = await _tripService.addPlaceToTrip(
        widget.tripId!,
        payload,
      );

      print('[PlaceDetailsPage] Response received: $response');

      if (!mounted) return;

      // Check response
      if (response['already_exists'] == true) {
        print('[PlaceDetailsPage] Place already exists');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                response['message'] ?? 'This place is already in your trip'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _alreadyExists = true);
      } else if (response['success'] == true || response['id'] != null) {
        print('[PlaceDetailsPage] Place added successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Added to your trip!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _alreadyExists = true);

        // Navigate back after a short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        print('[PlaceDetailsPage] Unexpected response: $response');
        throw Exception(response['message'] ?? 'Failed to add place');
      }
    } catch (e) {
      print('[PlaceDetailsPage] Error adding to plan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToPlan = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildDetailsView(),
    );
  }

  Widget _buildErrorView() {
    // If using fallback data, show it with a notice
    if (_usingFallbackData && _savedCardData.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            // Top AppBar
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Place Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Warning message
            if (_error != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            // Place details from saved card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _savedCardData['name'] ?? 'Unknown Place',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_savedCardData['latitude'] != null)
                    Text(
                      'Location: '
                      '${(_savedCardData['latitude'] as double?)?.toStringAsFixed(4) ?? "?"}, '
                      '${(_savedCardData['longitude'] as double?)?.toStringAsFixed(4) ?? "?"}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✓ Shown from your saved place card data. '
                      'Detailed information could not be retrieved at this moment.',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Standard error view
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsView() {
    if (_placeDetails?.result == null) {
      return const Center(child: Text('No place data available'));
    }

    final place = _placeDetails!.result;

    return CustomScrollView(
      slivers: [
        // Header with image
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeaderImage(place),
          ),
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        // Details section
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and rating
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2),
                    const SizedBox(height: 8),
                    _buildRatingRow(place),
                    const SizedBox(height: 12),
                    if (place.formattedAddress != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.formattedAddress!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
              ),
              // Status message
              if (_alreadyExists == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _existenceMessage ??
                                'This place is already in your trip',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4675B8),
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Photos'),
                  Tab(text: 'Map'),
                ],
              ),
            ],
          ),
        ),
        // Tab content
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAboutTab(place),
              _buildReviewsTab(place),
              _buildPhotosTab(place),
              _buildMapTab(place),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImage(PlaceDetailsResult place) {
    final images = _detailsImages(place);
    return PlaceImageCarousel(
      images: images,
      height: 280,
      autoPlay: images.length > 1,
      showAttribution: images.isNotEmpty,
    );
  }

  List<PlaceImageData> _detailsImages(PlaceDetailsResult place) {
    final images = place.images
        .where((image) => image.url.isNotEmpty)
        .map(
          (image) => PlaceImageData(
            url: image.url,
            attributions: image.attributions,
          ),
        )
        .toList();

    for (final photo in place.photos) {
      final url = photo.imageUrl ?? photo.photoReference;
      if (url.isNotEmpty && !images.any((image) => image.url == url)) {
        images.add(
          PlaceImageData(
            url: url,
            attributions: photo.htmlAttributions,
          ),
        );
      }
    }

    if (place.imageUrl != null &&
        place.imageUrl!.isNotEmpty &&
        !images.any((image) => image.url == place.imageUrl)) {
      images.insert(0, PlaceImageData(url: place.imageUrl!));
    }

    return images;
  }

  Future<void> _openExternalUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildLinkButton({
    required IconData icon,
    required String label,
    required String? url,
  }) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openExternalUrl(url),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildRatingRow(PlaceDetailsResult place) {
    return Row(
      children: [
        if (place.rating != null) ...[
          ...List.generate(
            5,
            (i) => Icon(
              i < place.rating!.toInt() ? Icons.star : Icons.star_outline,
              color: Colors.amber,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${place.rating?.toStringAsFixed(1)} (${place.userRatingsTotal ?? 0})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ] else
          Text(
            'No ratings',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        const Spacer(),
      ],
    );
  }

  Widget _buildAboutTab(PlaceDetailsResult place) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('Address', place.formattedAddress),
          const SizedBox(height: 24),
          if (place.editorialSummary != null &&
              place.editorialSummary!.isNotEmpty) ...[
            _buildInfoSection('Description', place.editorialSummary),
            const SizedBox(height: 24),
          ],
          if (place.types.isNotEmpty) ...[
            _buildInfoSection(
              'Categories',
              place.types.join(', '),
            ),
            const SizedBox(height: 24),
          ],
          if (place.priceLevel != null) ...[
            _buildInfoSection(
              'Price Level',
              '💰' * (place.priceLevel ?? 0),
            ),
            const SizedBox(height: 24),
          ],
          _buildLinkButton(
            icon: Icons.map_outlined,
            label: 'Open in Google Maps',
            url: place.url,
          ),
          if (place.url != null && place.url!.isNotEmpty)
            const SizedBox(height: 8),
          _buildLinkButton(
            icon: Icons.language,
            label: 'Open Website',
            url: place.website,
          ),
          if ((place.url != null && place.url!.isNotEmpty) ||
              (place.website != null && place.website!.isNotEmpty))
            const SizedBox(height: 24),
          // Add to plan button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAddingToPlan ? null : _addToPlan,
              icon: _isAddingToPlan
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Icon(
                      _alreadyExists == true
                          ? Icons.check_circle
                          : Icons.add_circle,
                      color: Colors.white),
              label: Text(
                _alreadyExists == true ? 'Already Added' : 'Add to Plan',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _alreadyExists == true
                    ? Colors.grey[400]
                    : const Color(0xFF4675B8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String? content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content ?? 'N/A',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildReviewsTab(PlaceDetailsResult place) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No reviews available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosTab(PlaceDetailsResult place) {
    final images = _detailsImages(place);
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No photos available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return PlaceImageCarousel(
          images: [images[index]],
          height: 160,
          borderRadius: BorderRadius.circular(12),
          showAttribution: true,
        );
      },
    );
  }

  Widget _buildMapTab(PlaceDetailsResult place) {
    if (place.geometry == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Location: ${place.geometry?.lat}, ${place.geometry?.lng}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '(Map integration coming soon)',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Location coordinates:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Latitude: ${place.geometry!.lat.toStringAsFixed(4)}\nLongitude: ${place.geometry!.lng.toStringAsFixed(4)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          if (place.url != null && place.url!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openExternalUrl(place.url),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in Google Maps'),
            ),
          ],
        ],
      ),
    );
  }
}
