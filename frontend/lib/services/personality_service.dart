import '../core/api_service.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

class PersonalityService {
  static final PersonalityService _instance = PersonalityService._internal();
  factory PersonalityService() => _instance;
  PersonalityService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  // Get personality quiz questions
  Future<List<Map<String, dynamic>>> getQuizQuestions() async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.personalityPath}/questions',
      );

      return _normalizeQuizQuestions(response);
    } catch (e) {
      throw Exception('Failed to get quiz questions: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> _normalizeQuizQuestions(dynamic response) {
    final List<dynamic> raw;
    if (response is List) {
      raw = response;
    } else if (response is Map && response['questions'] is List) {
      raw = response['questions'] as List;
    } else {
      return [];
    }

    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final text = (map['text'] ?? map['question'] ?? '').toString();
      map['text'] = text;
      map['question'] = text;
      return map;
    }).toList();
  }

  // Submit quiz answers (requires authentication).
  Future<Map<String, dynamic>> submitQuiz(
      String userId, List<Map<String, dynamic>> answers) async {
    return submitQuizSubmission(userId: userId, answers: answers);
  }

  // Submit quiz answers in the backend schema format.
  Future<Map<String, dynamic>> submitQuizSubmission({
    required String userId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final token = await _authService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please sign in again.');
    }

    try {
      final response = await _apiService.post(
        '${ApiConfig.personalityPath}/submit',
        {
          'user_id': userId,
          'answers': answers,
        },
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('Failed to submit quiz: ${e.toString()}');
    }
  }

  // Get personality scores
  Future<Map<String, dynamic>> getPersonalityScores(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.personalityPath}/scores/$userId',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get personality scores: ${e.toString()}');
    }
  }

  // Update personality scores
  Future<Map<String, dynamic>> updatePersonalityScores(
      String userId, Map<String, dynamic> scores) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.put(
        '${ApiConfig.personalityPath}/$userId',
        scores,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update personality scores: ${e.toString()}');
    }
  }
}
