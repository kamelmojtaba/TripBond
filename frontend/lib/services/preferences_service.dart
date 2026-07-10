import '../core/api_service.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  // Get travel questionnaire
  Future<Map<String, dynamic>> getQuestionnaire() async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.preferencesPath}/questionnaire',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get questionnaire: ${e.toString()}');
    }
  }

  // Submit trip preferences
  Future<Map<String, dynamic>> submitTripPreferences(
      String tripId, String userId, Map<String, dynamic> preferences) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.preferencesPath}/trip/submit',
        {
          'trip_id': tripId,
          'user_id': userId,
          ...preferences,
        },
      );

      return response;
    } catch (e) {
      throw Exception('Failed to submit preferences: ${e.toString()}');
    }
  }

  // Get trip preferences for a user
  Future<Map<String, dynamic>> getTripPreferences(
      String tripId, String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.preferencesPath}/trip/$tripId/$userId',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get trip preferences: ${e.toString()}');
    }
  }

  // Get all trip preferences (for group)
  Future<List<Map<String, dynamic>>> getAllTripPreferences(
      String tripId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.preferencesPath}/trip/$tripId',
      );

      if (response.containsKey('preferences') &&
          response['preferences'] is List) {
        return (response['preferences'] as List).cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get all trip preferences: ${e.toString()}');
    }
  }

  // Update trip preferences
  Future<Map<String, dynamic>> updateTripPreferences(
      String tripId, String userId, Map<String, dynamic> preferences) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.preferencesPath}/trip/$tripId/$userId',
        preferences,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update preferences: ${e.toString()}');
    }
  }

  // Delete trip preferences
  Future<void> deleteTripPreferences(String tripId, String userId) async {
    try {
      await _apiService.delete(
        '${ApiConfig.preferencesPath}/trip/$tripId/$userId',
      );
    } catch (e) {
      throw Exception('Failed to delete preferences: ${e.toString()}');
    }
  }

  // Update user general preferences
  Future<Map<String, dynamic>> updateUserGeneralPreferences(
      Map<String, dynamic> preferences) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.preferencesPath}/user/general',
        preferences,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update general preferences: ${e.toString()}');
    }
  }

  // Get user general preferences
  Future<Map<String, dynamic>> getUserGeneralPreferences(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.preferencesPath}/user/general/$userId',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get general preferences: ${e.toString()}');
    }
  }
}
