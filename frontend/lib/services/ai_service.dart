import '../core/api_service.dart';
import '../core/api_config.dart';

class AIRecommendation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double score;
  final List<double> userPreferences;
  final String category;
  final double rating;
  final double fairnessIndex;

  AIRecommendation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.score,
    required this.userPreferences,
    required this.category,
    required this.rating,
    required this.fairnessIndex,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      score: (json['score'] ?? 0.0).toDouble(),
      userPreferences: List<double>.from(
        (json['user_preferences'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble()) ??
            [],
      ),
      category: json['category'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      fairnessIndex: (json['fairness_index'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'score': score,
        'user_preferences': userPreferences,
        'category': category,
        'rating': rating,
        'fairness_index': fairnessIndex,
      };
}

class GroupRecommendationsResponse {
  final String tripId;
  final List<String> userIds;
  final String strategy;
  final List<AIRecommendation> recommendations;
  final double fairnessScore;
  final DateTime timestamp;

  GroupRecommendationsResponse({
    required this.tripId,
    required this.userIds,
    required this.strategy,
    required this.recommendations,
    required this.fairnessScore,
    required this.timestamp,
  });

  factory GroupRecommendationsResponse.fromJson(Map<String, dynamic> json) {
    return GroupRecommendationsResponse(
      tripId: json['trip_id'] ?? '',
      userIds: List<String>.from(json['user_ids'] ?? []),
      strategy: json['strategy'] ?? '',
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => AIRecommendation.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      fairnessScore: (json['fairness_score'] ?? 0.0).toDouble(),
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'user_ids': userIds,
        'strategy': strategy,
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'fairness_score': fairnessScore,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ItineraryActivity {
  final String poiId;
  final String name;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final int travelToMinutes;

  ItineraryActivity({
    required this.poiId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.travelToMinutes,
  });

  factory ItineraryActivity.fromJson(Map<String, dynamic> json) {
    return ItineraryActivity(
      poiId: json['poi_id'] ?? '',
      name: json['name'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      travelToMinutes: json['travel_to_minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'poi_id': poiId,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'duration_minutes': durationMinutes,
        'travel_to_minutes': travelToMinutes,
      };
}

class DayItinerary {
  final int day;
  final List<ItineraryActivity> activities;

  DayItinerary({
    required this.day,
    required this.activities,
  });

  factory DayItinerary.fromJson(Map<String, dynamic> json) {
    return DayItinerary(
      day: json['day'] ?? 0,
      activities: (json['activities'] as List<dynamic>?)
              ?.map(
                  (a) => ItineraryActivity.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'activities': activities.map((a) => a.toJson()).toList(),
      };
}

class OptimizedItinerary {
  final String tripId;
  final List<String> userIds;
  final String optimizationMethod;
  final int numDays;
  final List<DayItinerary> itinerary;
  final double totalCost;
  final int totalTravelTime;
  final double fitnessScore;
  final DateTime timestamp;

  OptimizedItinerary({
    required this.tripId,
    required this.userIds,
    required this.optimizationMethod,
    required this.numDays,
    required this.itinerary,
    required this.totalCost,
    required this.totalTravelTime,
    required this.fitnessScore,
    required this.timestamp,
  });

  factory OptimizedItinerary.fromJson(Map<String, dynamic> json) {
    return OptimizedItinerary(
      tripId: json['trip_id'] ?? '',
      userIds: List<String>.from(json['user_ids'] ?? []),
      optimizationMethod: json['optimization_method'] ?? '',
      numDays: json['num_days'] ?? 0,
      itinerary: (json['itinerary'] as List<dynamic>?)
              ?.map((d) => DayItinerary.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
      totalTravelTime: json['total_travel_time'] ?? 0,
      fitnessScore: (json['fitness_score'] ?? 0.0).toDouble(),
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'user_ids': userIds,
        'optimization_method': optimizationMethod,
        'num_days': numDays,
        'itinerary': itinerary.map((d) => d.toJson()).toList(),
        'total_cost': totalCost,
        'total_travel_time': totalTravelTime,
        'fitness_score': fitnessScore,
        'timestamp': timestamp.toIso8601String(),
      };
}

class AIBackendStatus {
  final String status;
  final Map<String, dynamic> aiBackend;
  final DateTime timestamp;

  AIBackendStatus({
    required this.status,
    required this.aiBackend,
    required this.timestamp,
  });

  factory AIBackendStatus.fromJson(Map<String, dynamic> json) {
    return AIBackendStatus(
      status: json['status'] ?? 'unknown',
      aiBackend: json['ai_backend'] ?? {},
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'ai_backend': aiBackend,
        'timestamp': timestamp.toIso8601String(),
      };
}

class AIServiceConfig {
  final String aiBackendUrl;
  final Map<String, dynamic> endpoints;
  final Map<String, dynamic> features;
  final Map<String, dynamic> models;

  AIServiceConfig({
    required this.aiBackendUrl,
    required this.endpoints,
    required this.features,
    required this.models,
  });

  factory AIServiceConfig.fromJson(Map<String, dynamic> json) {
    return AIServiceConfig(
      aiBackendUrl: json['ai_backend_url'] ?? '',
      endpoints: json['endpoints'] ?? {},
      features: json['features'] ?? {},
      models: json['models'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'ai_backend_url': aiBackendUrl,
        'endpoints': endpoints,
        'features': features,
        'models': models,
      };
}

/// AI Service for interacting with AI backend endpoints
///
/// Handles:
/// - Group recommendations (POI prediction with fairness)
/// - Itinerary optimization (Genetic Algorithm based)
/// - User recommendations
/// - Feedback submission
/// - System status and configuration
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final _apiService = ApiService();

  /// Get AI system status
  ///
  /// Returns the health status of the AI backend
  /// including model loading status
  Future<AIBackendStatus> getAIStatus() async {
    try {
      final response = await _apiService.get('${ApiConfig.aiPath}/status');

      if (response is Map<String, dynamic>) {
        return AIBackendStatus.fromJson(response);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to get AI status: ${e.toString()}');
    }
  }

  /// Get AI-generated recommendations for a group
  ///
  /// Parameters:
  /// - tripId: Trip identifier
  /// - userIds: List of user IDs in the group
  /// - topK: Number of recommendations to return (default: 10)
  /// - aggregationStrategy: 'average', 'majority', or 'weighted' (default: 'average')
  ///
  /// Returns POI recommendations tailored to group preferences
  /// with fairness scoring to ensure all group members are satisfied
  Future<GroupRecommendationsResponse> getGroupRecommendations({
    required String tripId,
    required List<String> userIds,
    int topK = 10,
    String aggregationStrategy = 'average',
  }) async {
    try {
      final body = {
        'trip_id': tripId,
        'user_ids': userIds,
        'top_k': topK,
        'aggregation_strategy': aggregationStrategy,
      };

      final response = await _apiService.post(
        '${ApiConfig.aiPath}/recommendations/group',
        body,
      );

      if (response is Map<String, dynamic>) {
        return GroupRecommendationsResponse.fromJson(response);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to get group recommendations: ${e.toString()}');
    }
  }

  /// Optimize a group itinerary using Genetic Algorithm
  ///
  /// Parameters:
  /// - tripId: Trip identifier
  /// - userIds: List of user IDs
  /// - pois: List of points of interest with structure:
  ///   {id, name, latitude, longitude, category, rating}
  /// - useGa: Use Genetic Algorithm (true) or Greedy (false) (default: true)
  /// - numDays: Number of days for itinerary (default: 1)
  /// - maxBudget: Maximum budget in dollars (optional)
  /// - pace: 'slow', 'moderate', or 'fast' (default: 'moderate')
  ///
  /// Returns optimized itinerary with timing and travel recommendations
  Future<OptimizedItinerary> optimizeGroupItinerary({
    required String tripId,
    required List<String> userIds,
    required List<Map<String, dynamic>> pois,
    bool useGa = true,
    int numDays = 1,
    double? maxBudget,
    String pace = 'moderate',
  }) async {
    try {
      final body = {
        'trip_id': tripId,
        'user_ids': userIds,
        'pois': pois,
        'use_ga': useGa,
        'num_days': numDays,
        'pace': pace,
      };

      if (maxBudget != null) {
        body['max_budget'] = maxBudget;
      }

      final response = await _apiService.post(
        '${ApiConfig.aiPath}/itinerary/optimize',
        body,
      );

      if (response is Map<String, dynamic>) {
        return OptimizedItinerary.fromJson(response);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to optimize itinerary: ${e.toString()}');
    }
  }

  /// Get personalized recommendations for a specific user
  ///
  /// Parameters:
  /// - userId: User ID
  /// - tripId: Trip context (optional)
  /// - topK: Number of recommendations (default: 10)
  /// - category: POI category filter (optional)
  ///
  /// Returns user-specific POI recommendations
  Future<List<AIRecommendation>> getUserRecommendations({
    required String userId,
    String? tripId,
    int topK = 10,
    String? category,
  }) async {
    try {
      final params = <String, String>{
        'top_k': topK.toString(),
      };

      if (tripId != null) params['trip_id'] = tripId;
      if (category != null) params['category'] = category;

      final response = await _apiService.get(
        '${ApiConfig.aiPath}/recommendations/user/$userId',
        queryParams: params,
      );

      // Handle both list and object responses
      if (response is List) {
        return response
            .map((r) => AIRecommendation.fromJson(r as Map<String, dynamic>))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final recommendations = response['recommendations'] as List<dynamic>?;
        if (recommendations != null) {
          return recommendations
              .map((r) => AIRecommendation.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get user recommendations: ${e.toString()}');
    }
  }

  /// Submit feedback for an optimized itinerary
  ///
  /// Parameters:
  /// - itineraryId: ID of the itinerary being reviewed
  /// - feedbackScore: Rating from 1-5 (1=poor, 5=excellent)
  /// - notes: Detailed feedback comments (optional)
  /// - improvements: List of suggested improvements (optional)
  ///
  /// Returns feedback confirmation
  Future<Map<String, dynamic>> submitItineraryFeedback({
    required String itineraryId,
    required double feedbackScore,
    String? notes,
    List<String>? improvements,
  }) async {
    try {
      if (feedbackScore < 1 || feedbackScore > 5) {
        throw Exception('feedback_score must be between 1 and 5');
      }

      final body = <String, dynamic>{
        'feedback_score': feedbackScore,
      };

      if (notes != null) body['notes'] = notes;
      if (improvements != null) body['improvements'] = improvements;

      final response = await _apiService.post(
        '${ApiConfig.aiPath}/feedback/itinerary/$itineraryId',
        body,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to submit feedback: ${e.toString()}');
    }
  }

  /// Get AI system configuration
  ///
  /// Returns information about available AI features,
  /// endpoints, and loaded models
  Future<AIServiceConfig> getAIConfig() async {
    try {
      final response = await _apiService.get('${ApiConfig.aiPath}/config');

      if (response is Map<String, dynamic>) {
        return AIServiceConfig.fromJson(response);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to get AI config: ${e.toString()}');
    }
  }
}
