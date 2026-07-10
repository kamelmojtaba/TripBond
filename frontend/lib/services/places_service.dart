import '../core/api_service.dart';
import '../core/api_config.dart';
import '../models/place_model.dart';

class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  final _apiService = ApiService();

  // Search places by text query
  Future<PlacesSearchResponse> searchPlaces({
    required String query,
    String language = 'en',
    String? nextPageToken,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'language': language,
      };

      if (nextPageToken != null) {
        queryParams['next_page_token'] = nextPageToken;
      }

      final response = await _apiService.get(
        '${ApiConfig.placesPath}/search',
        queryParams: queryParams,
      );

      return PlacesSearchResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search places: ${e.toString()}');
    }
  }

  // Get place details
  Future<PlaceDetailsResponse> getPlaceDetails(String placeId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.placesPath}/details/$placeId',
      );

      return PlaceDetailsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get place details: ${e.toString()}');
    }
  }

  // Get place details from TripBond's saved enrichment cache only.
  Future<PlaceDetailsResponse> getCachedPlaceDetails(String placeId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.placesPath}/cached/$placeId',
      );

      return PlaceDetailsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get cached place details: ${e.toString()}');
    }
  }

  // Get place details with intelligent fallback
  // Supports lat/lng/country context to find the correct location
  // This prevents "Ithra" from returning "Ithra Tower" in wrong country
  Future<PlaceDetailsResponse> getPlaceDetailsWithFallback({
    required String placeId,
    double? latitude,
    double? longitude,
    String? fallbackName,
    String? country,
  }) async {
    try {
      return await getCachedPlaceDetails(placeId);
    } catch (_) {
      // Keep the legacy live details path as a fallback for search results that
      // have not been processed by the scheduled cache job yet.
    }

    try {
      final queryParams = {
        'language': 'en',
      };

      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (fallbackName != null) queryParams['fallback_name'] = fallbackName;
      if (country != null) queryParams['country'] = country;

      final response = await _apiService.get(
        '${ApiConfig.placesPath}/details/$placeId',
        queryParams: queryParams,
      );

      return PlaceDetailsResponse.fromJson(response);
    } catch (e) {
      throw Exception(
          'Failed to get place details with fallback: ${e.toString()}');
    }
  }

  // Get POIs (Points of Interest)
  Future<List<Map<String, dynamic>>> getPOIs({
    String? destination,
    String? category,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (destination != null) queryParams['destination'] = destination;
      if (category != null) queryParams['category'] = category;
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _apiService.get(
        ApiConfig.poisPath,
        queryParams: queryParams,
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
      throw Exception('Failed to get POIs: ${e.toString()}');
    }
  }

  // Get POI details
  Future<Map<String, dynamic>> getPOIDetails(String poiId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.poisPath}/$poiId',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get POI details: ${e.toString()}');
    }
  }

  // Get nearby places
  Future<PlacesSearchResponse> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radius = 5000,
    String? type,
    String language = 'en',
  }) async {
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radius.toString(),
        'language': language,
      };

      if (type != null) queryParams['type'] = type;

      final response = await _apiService.get(
        '${ApiConfig.placesPath}/nearby',
        queryParams: queryParams,
      );

      return PlacesSearchResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get nearby places: ${e.toString()}');
    }
  }
}
