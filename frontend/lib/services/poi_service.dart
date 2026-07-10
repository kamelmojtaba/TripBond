import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_service.dart';
import '../core/api_config.dart';

class POIService {
  static final POIService _instance = POIService._internal();
  factory POIService() => _instance;
  POIService._internal();

  static const _cityPlacesCachePrefix = 'tripbond.city_places.v1.';
  static const _cityPlacesTimestampPrefix =
      'tripbond.city_places.cached_at.v1.';

  final _apiService = ApiService();
  final Map<String, List<Map<String, dynamic>>> _cityPlacesCache = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _cityPlacesInFlight =
      {};

  /// Search and filter Points of Interest
  ///
  /// Parameters:
  /// - location: Filter by location (optional)
  /// - type: Filter by type - 'attraction', 'restaurant', 'hotel', etc. (optional)
  /// - minRating: Minimum rating (0-5) (optional)
  /// - maxPriceLevel: Maximum price level (1-4) (optional)
  /// - tags: Comma-separated tags to filter by (optional)
  /// - limit: Maximum number of results (default: 50, max: 100)
  Future<List<Map<String, dynamic>>> searchPOIs({
    String? location,
    String? type,
    double? minRating,
    int? maxPriceLevel,
    String? tags,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final canUseCityCache = location != null &&
        location.trim().isNotEmpty &&
        type == null &&
        minRating == null &&
        maxPriceLevel == null &&
        tags == null;

    if (canUseCityCache && !forceRefresh) {
      final cached = await _cachedCityPlaces(location);
      if (cached != null && cached.isNotEmpty) {
        _refreshCityPlacesInBackground(location, limit);
        return cached.take(limit).toList();
      }

      final cityKey = _normaliseCityKey(location);
      final inFlight = _cityPlacesInFlight[cityKey];
      if (inFlight != null) {
        final places = await inFlight;
        return places.take(limit).toList();
      }
    }

    try {
      if (canUseCityCache && location != null) {
        final places = await _fetchCityPlaces(location, limit);
        return places.take(limit).toList();
      }

      return await _fetchPOIs(
        location: location,
        type: type,
        minRating: minRating,
        maxPriceLevel: maxPriceLevel,
        tags: tags,
        limit: limit,
      );
    } catch (e) {
      throw Exception('Failed to search POIs: ${e.toString()}');
    }
  }

  Future<void> hydrateCityPlacesFromJson(
    String location,
    List<dynamic> jsonList,
  ) async {
    final places = _normalisePlaces(jsonList);
    final cityKey = _normaliseCityKey(location);
    _cityPlacesCache[cityKey] = places;
    await _writeCityPlacesCache(cityKey, places);
  }

  Future<List<Map<String, dynamic>>> _fetchCityPlaces(
    String location,
    int limit,
  ) {
    final cityKey = _normaliseCityKey(location);
    final inFlight = _cityPlacesInFlight[cityKey];
    if (inFlight != null) return inFlight;

    final future =
        _fetchPOIs(location: location, limit: limit).then((places) async {
      _cityPlacesCache[cityKey] = places;
      await _writeCityPlacesCache(cityKey, places);
      return places;
    });
    _cityPlacesInFlight[cityKey] = future;
    future.whenComplete(() => _cityPlacesInFlight.remove(cityKey));
    return future;
  }

  Future<List<Map<String, dynamic>>> _fetchPOIs({
    String? location,
    String? type,
    double? minRating,
    int? maxPriceLevel,
    String? tags,
    int limit = 50,
  }) async {
    final params = <String, String>{};
    if (location != null) params['location'] = location;
    if (type != null) params['type'] = type;
    if (minRating != null) params['min_rating'] = minRating.toString();
    if (maxPriceLevel != null)
      params['max_price_level'] = maxPriceLevel.toString();
    if (tags != null) params['tags'] = tags;
    params['limit'] = limit.toString();

    final response = await _apiService.get(
      ApiConfig.poisPath,
      queryParams: params,
    );

    if (response is List) {
      return _normalisePlaces(response);
    } else if (response is Map && response.containsKey('pois')) {
      final pois = response['pois'];
      if (pois is List) {
        return _normalisePlaces(pois);
      }
    }

    return [];
  }

  Future<List<Map<String, dynamic>>?> _cachedCityPlaces(String location) async {
    final cityKey = _normaliseCityKey(location);
    final memory = _cityPlacesCache[cityKey];
    if (memory != null) return memory;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cityPlacesCachePrefix$cityKey');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final places = _normalisePlaces(decoded);
      _cityPlacesCache[cityKey] = places;
      return places;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCityPlacesCache(
    String cityKey,
    List<Map<String, dynamic>> places,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cityPlacesCachePrefix$cityKey',
        jsonEncode(places),
      );
      await prefs.setInt(
        '$_cityPlacesTimestampPrefix$cityKey',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Cache writes are a performance optimization only.
    }
  }

  void _refreshCityPlacesInBackground(String location, int limit) {
    final cityKey = _normaliseCityKey(location);
    if (_cityPlacesInFlight.containsKey(cityKey)) return;

    final future =
        _fetchPOIs(location: location, limit: limit).then((places) async {
      _cityPlacesCache[cityKey] = places;
      await _writeCityPlacesCache(cityKey, places);
      return places;
    });
    _cityPlacesInFlight[cityKey] = future;
    future
        .catchError(
            (_) => _cityPlacesCache[cityKey] ?? <Map<String, dynamic>>[])
        .whenComplete(() => _cityPlacesInFlight.remove(cityKey));
  }

  List<Map<String, dynamic>> _normalisePlaces(List<dynamic> values) {
    return values
        .whereType<Map>()
        .map((place) => Map<String, dynamic>.from(place))
        .toList();
  }

  String _normaliseCityKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  /// Get detailed information about a specific POI
  Future<Map<String, dynamic>> getPOIDetail(String poiId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.poisPath}/$poiId',
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to get POI details: ${e.toString()}');
    }
  }

  /// Get top-rated POIs by category
  Future<List<Map<String, dynamic>>> getTopRatedPOIs({
    String? category,
    int limit = 10,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (category != null) params['type'] = category;

      final response = await _apiService.get(
        ApiConfig.poisPath,
        queryParams: params,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('pois')) {
        final pois = response['pois'];
        if (pois is List) {
          return pois.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get top-rated POIs: ${e.toString()}');
    }
  }

  /// Get POIs by tags
  Future<List<Map<String, dynamic>>> getPOIsByTags(List<String> tags) async {
    try {
      final tagsString = tags.join(',');
      final response = await _apiService.get(
        ApiConfig.poisPath,
        queryParams: {'tags': tagsString},
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('pois')) {
        final pois = response['pois'];
        if (pois is List) {
          return pois.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get POIs by tags: ${e.toString()}');
    }
  }
}
