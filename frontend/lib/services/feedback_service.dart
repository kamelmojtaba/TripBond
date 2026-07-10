import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api_service.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  // Rate a completed trip
  Future<Map<String, dynamic>> rateTrip({
    required String tripId,
    required int rating,
    required String feedback,
    required List<String> tags,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.feedbackPath}/trips/$tripId/rate',
        {
          'rating': rating,
          'feedback': feedback,
          'tags': tags,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to rate trip: ${e.toString()}');
    }
  }

  // Rate a specific activity within a trip
  Future<Map<String, dynamic>> rateActivity({
    required String tripId,
    required String activityId,
    required int rating,
    required String feedback,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.feedbackPath}/activities/rate',
        {
          'trip_id': tripId,
          'activity_id': activityId,
          'rating': rating,
          'feedback': feedback,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to rate activity: ${e.toString()}');
    }
  }

  // Submit feedback on a recommendation
  Future<Map<String, dynamic>> submitRecommendationFeedback({
    required String recommendationId,
    required String tripId,
    required bool wasHelpful,
    required String feedback,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.feedbackPath}/recommendations/feedback',
        {
          'recommendation_id': recommendationId,
          'trip_id': tripId,
          'was_helpful': wasHelpful,
          'feedback': feedback,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception(
          'Failed to submit recommendation feedback: ${e.toString()}');
    }
  }

  // Get user's feedback stats
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.feedbackPath}/stats',
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to get feedback stats: ${e.toString()}');
    }
  }

  // Get feedback for a specific trip
  Future<Map<String, dynamic>> getTripFeedback(String tripId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.feedbackPath}/trips/$tripId',
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to get trip feedback: ${e.toString()}');
    }
  }
}
