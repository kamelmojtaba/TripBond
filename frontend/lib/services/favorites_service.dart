import '../core/api_service.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  // Get user's favorites
  Future<List<Map<String, dynamic>>> getMyFavorites() async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      final response = await _apiService.get(
        '${ApiConfig.favoritesPath}/$userId',
        token: token,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('favorites')) {
        final favorites = response['favorites'];
        if (favorites is List) {
          return favorites.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get favorites: ${e.toString()}');
    }
  }

  // Add to favorites
  Future<Map<String, dynamic>> addFavorite({
    String? tripId,
    String? destinationName,
    String? destinationType,
    String? poiId,
  }) async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      // The database constraint requires at least one entity to be non-null:
      // trip_id (must reference existing trip), destination_name, or poi_id
      // For destination favorites, only send destination_name and destination_type
      // For trip favorites, send tripId
      if ((tripId == null || tripId.isEmpty) &&
          (destinationName == null || destinationName.isEmpty) &&
          (poiId == null || poiId.isEmpty)) {
        throw Exception('Provide a trip ID, destination name, or POI ID');
      }

      final response = await _apiService.post(
        '${ApiConfig.favoritesPath}/$userId',
        {
          if (tripId != null && tripId.isNotEmpty) 'trip_id': tripId,
          if (destinationName != null && destinationName.isNotEmpty)
            'destination_name': destinationName,
          if (destinationType != null && destinationType.isNotEmpty)
            'destination_type': destinationType,
          if (poiId != null && poiId.isNotEmpty) 'poi_id': poiId,
        },
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to add favorite: ${e.toString()}');
    }
  }

  // Remove from favorites
  Future<void> removeFavorite(String favoriteId) async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      await _apiService.delete(
        '${ApiConfig.favoritesPath}/$userId/$favoriteId',
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to remove favorite: ${e.toString()}');
    }
  }

  // Check if entity is favorited
  Future<bool> isFavorited({
    String? tripId,
    String? destinationName,
    String? poiId,
  }) async {
    try {
      final favorites = await getMyFavorites();
      return favorites.any((favorite) {
        if (tripId != null && tripId.isNotEmpty) {
          return favorite['trip_id']?.toString() == tripId;
        }
        if (poiId != null && poiId.isNotEmpty) {
          return favorite['poi_id']?.toString() == poiId;
        }
        if (destinationName != null && destinationName.isNotEmpty) {
          return favorite['destination_name']?.toString() == destinationName;
        }
        return false;
      });
    } catch (e) {
      return false;
    }
  }
}
