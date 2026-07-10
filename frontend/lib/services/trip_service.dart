import '../core/api_service.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  // Get my trips
  Future<List<Map<String, dynamic>>> getMyTrips() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/me',
        token: token,
      );

      // Response can be a list or a map containing a list
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get trips: ${e.toString()}');
    }
  }

  // Get trips by user ID
  Future<List<Map<String, dynamic>>> getTripsByUser(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/user/$userId',
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get user trips: ${e.toString()}');
    }
  }

  // Create trip
  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> tripData) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/',
        tripData,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to create trip: ${e.toString()}');
    }
  }

  // Get trip details
  Future<Map<String, dynamic>> getTripDetails(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get trip details: ${e.toString()}');
    }
  }

  // Update trip
  Future<Map<String, dynamic>> updateTrip(
      String tripId, Map<String, dynamic> updates) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.put(
        '${ApiConfig.tripsPath}/$tripId',
        updates,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update trip: ${e.toString()}');
    }
  }

  // Delete trip
  Future<void> deleteTrip(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _apiService.delete(
        '${ApiConfig.tripsPath}/$tripId',
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to delete trip: ${e.toString()}');
    }
  }

  // Get trip members
  Future<List<Map<String, dynamic>>> getTripMembers(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/members',
        token: token,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('members')) {
        final members = response['members'];
        if (members is List) {
          return members.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get trip members: ${e.toString()}');
    }
  }

  // Add trip member
  Future<Map<String, dynamic>> addTripMember(
      String tripId, String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/members',
        {'user_id': userId},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to add trip member: ${e.toString()}');
    }
  }

  // Remove trip member
  Future<void> removeTripMember(String tripId, String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _apiService.delete(
        '${ApiConfig.tripsPath}/$tripId/members/$userId',
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to remove trip member: ${e.toString()}');
    }
  }

  // Generate itinerary
  Future<Map<String, dynamic>> generateItinerary(
      String tripId, Map<String, dynamic> preferences) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/generate-itinerary',
        {
          'preferences': preferences,
        },
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to generate itinerary: ${e.toString()}');
    }
  }

  // Get latest itinerary
  Future<Map<String, dynamic>> getLatestItinerary(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/itinerary',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get itinerary: ${e.toString()}');
    }
  }

  // Get POI recommendations
  Future<List<Map<String, dynamic>>> getRecommendations(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/recommendations',
        token: token,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('recommendations')) {
        final recommendations = response['recommendations'];
        if (recommendations is List) {
          return recommendations.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get recommendations: ${e.toString()}');
    }
  }

  // Generate a non-final starter plan used before place voting
  Future<Map<String, dynamic>> getStarterPlan(
    String tripId, {
    int limit = 24,
    String pace = 'moderate',
  }) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/starter-plan',
        queryParams: {
          'limit': limit.toString(),
          'pace': pace,
        },
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return {};
    } catch (e) {
      throw Exception('Failed to get starter plan: ${e.toString()}');
    }
  }

  // Submit selected recommendations
  Future<Map<String, dynamic>> submitSelectedRecommendations(
      String tripId, List<String> selectedRecommendationIds) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/recommendations/selected',
        {'selected_recommendation_ids': selectedRecommendationIds},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception(
          'Failed to submit selected recommendations: ${e.toString()}');
    }
  }

  // Get trip summary
  Future<Map<String, dynamic>> getTripSummary(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/summary',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get trip summary: ${e.toString()}');
    }
  }

  // Get public trip details
  Future<Map<String, dynamic>> getPublicTripDetails(String tripId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/public/$tripId',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get public trip details: ${e.toString()}');
    }
  }

  // Get public itinerary
  Future<Map<String, dynamic>> getPublicItinerary(String tripId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/public/$tripId/itinerary',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get public itinerary: ${e.toString()}');
    }
  }

  // Get pending trip members
  Future<List<Map<String, dynamic>>> getPendingMembers(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/members/pending',
        token: token,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('members')) {
        final members = response['members'];
        if (members is List) {
          return members.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get pending members: ${e.toString()}');
    }
  }

  // Get all trip members
  Future<List<Map<String, dynamic>>> getAllMembers(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/$tripId/members/all',
        token: token,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('members')) {
        final members = response['members'];
        if (members is List) {
          return members.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get all members: ${e.toString()}');
    }
  }

  // Leave trip
  Future<void> leaveTrip(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/leave',
        {},
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to leave trip: ${e.toString()}');
    }
  }

  // Get trip invites
  Future<List<Map<String, dynamic>>> getInvites() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.tripsPath}/invites',
        token: token,
      );

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('invites')) {
        final invites = response['invites'];
        if (invites is List) {
          return invites.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get invites: ${e.toString()}');
    }
  }

  // Accept trip invite
  Future<Map<String, dynamic>> acceptInvite(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/invites/accept',
        {},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to accept invite: ${e.toString()}');
    }
  }

  // Decline trip invite
  Future<void> declineInvite(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/invites/decline',
        {},
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to decline invite: ${e.toString()}');
    }
  }

  // Update itinerary item
  Future<Map<String, dynamic>> updateItineraryItem(
      String tripId, String itemId, Map<String, dynamic> updates) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.put(
        '${ApiConfig.tripsPath}/$tripId/itinerary/items/$itemId',
        updates,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update itinerary item: ${e.toString()}');
    }
  }

  // Add itinerary item
  Future<Map<String, dynamic>> addItineraryItem(
      String tripId, int day, Map<String, dynamic> itemData) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/itinerary/items?day=$day',
        itemData,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to add itinerary item: ${e.toString()}');
    }
  }

  // Delete itinerary item
  Future<void> deleteItineraryItem(String tripId, String itemId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _apiService.delete(
        '${ApiConfig.tripsPath}/$tripId/itinerary/items/$itemId',
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to delete itinerary item: ${e.toString()}');
    }
  }

  // Recalculate itinerary
  Future<Map<String, dynamic>> recalculateItinerary(String tripId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.put(
        '${ApiConfig.tripsPath}/$tripId/recalculate',
        {},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to recalculate itinerary: ${e.toString()}');
    }
  }

  // List all places added to a trip
  Future<List<Map<String, dynamic>>> listTripPlaces(String tripId) async {
    final token = await _authService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    final response = await _apiService.get(
      '${ApiConfig.tripsPath}/$tripId/places',
      token: token,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Get the current gated trip flow status
  Future<Map<String, dynamic>> getTripFlowStatus(String tripId) async {
    final token = await _authService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    final response = await _apiService.get(
      '${ApiConfig.tripsPath}/$tripId/flow-status',
      token: token,
    );
    return response;
  }

  Future<Map<String, dynamic>> markPlacesComplete(String tripId) async {
    final token = await _authService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return await _apiService.post(
      '${ApiConfig.tripsPath}/$tripId/flow/places-complete',
      {},
      token: token,
    );
  }

  Future<Map<String, dynamic>> reopenPlaces(String tripId) async {
    final token = await _authService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return await _apiService.delete(
      '${ApiConfig.tripsPath}/$tripId/flow/places-complete',
      token: token,
    );
  }

  Future<Map<String, dynamic>> markVotingComplete(String tripId) async {
    final token = await _authService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return await _apiService.post(
      '${ApiConfig.tripsPath}/$tripId/flow/voting-complete',
      {},
      token: token,
    );
  }

  Future<Map<String, dynamic>> reopenVoting(String tripId) async {
    final token = await _authService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return await _apiService.delete(
      '${ApiConfig.tripsPath}/$tripId/flow/voting-complete',
      token: token,
    );
  }

  // Check if a place already exists in the trip
  Future<Map<String, dynamic>> checkPlaceDuplicate(
    String tripId,
    Map<String, dynamic> placeData,
  ) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/places/check-duplicate',
        placeData,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to check place duplicate: ${e.toString()}');
    }
  }

  // Add a place to the trip (with duplicate detection)
  Future<Map<String, dynamic>> addPlaceToTrip(
    String tripId,
    Map<String, dynamic> placeData,
  ) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.tripsPath}/$tripId/places/add',
        placeData,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to add place to trip: ${e.toString()}');
    }
  }

  // Suggest a place for the trip (adds to Bonders Suggestions)
  Future<Map<String, dynamic>> suggestPlaceForTrip(
    String tripId,
    Map<String, dynamic> placeData,
  ) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.suggestionsPath}/$tripId/suggest-place',
        placeData,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to suggest place: ${e.toString()}');
    }
  }

  // Get Bonders Suggestions for a trip
  Future<List<Map<String, dynamic>>> getPlaceSuggestions(
    String tripId, {
    String? status, // pending, approved
  }) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      String url = '${ApiConfig.suggestionsPath}/$tripId/list';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await _apiService.get(
        url,
        token: token,
      );

      return List<Map<String, dynamic>>.from(response['suggestions'] ?? []);
    } catch (e) {
      throw Exception('Failed to get suggestions: ${e.toString()}');
    }
  }
}
