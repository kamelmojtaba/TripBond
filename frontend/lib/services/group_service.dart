import '../core/api_service.dart';
import '../core/api_config.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final _apiService = ApiService();

  // Aggregate group preferences
  Future<Map<String, dynamic>> aggregateGroupPreferences(
    String tripId, {
    required String strategy,
    List<String>? userIds,
    Map<String, double>? weights,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'strategy': strategy,
      };

      if (userIds != null) {
        requestBody['user_ids'] = userIds;
      }

      if (weights != null) {
        requestBody['weights'] = weights;
      }

      final response = await _apiService.post(
        '${ApiConfig.groupPath}/$tripId/aggregate',
        requestBody,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to aggregate preferences: ${e.toString()}');
    }
  }

  // Optimize group recommendations using Genetic Algorithm
  Future<Map<String, dynamic>> optimizeGroupRecommendations(
    String tripId, {
    int? populationSize,
    int? generations,
    double? mutationRate,
    int? topK,
  }) async {
    try {
      final requestBody = <String, dynamic>{};

      if (populationSize != null) {
        requestBody['population_size'] = populationSize;
      }
      if (generations != null) {
        requestBody['generations'] = generations;
      }
      if (mutationRate != null) {
        requestBody['mutation_rate'] = mutationRate;
      }
      if (topK != null) {
        requestBody['top_k'] = topK;
      }

      final response = await _apiService.post(
        '${ApiConfig.groupPath}/$tripId/optimize',
        requestBody,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to optimize recommendations: ${e.toString()}');
    }
  }
}
