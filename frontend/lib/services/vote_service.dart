import '../core/api_config.dart';
import '../core/api_service.dart';
import 'auth_service.dart';

class VoteService {
  static final VoteService _instance = VoteService._internal();
  factory VoteService() => _instance;
  VoteService._internal();

  final _api = ApiService();
  final _auth = AuthService();

  Future<String> _token() async {
    final token = await _auth.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> listTripVotes(String tripId) async {
    final token = await _token();
    final response = await _api.get(
      '${ApiConfig.votesPath}/trip/$tripId',
      token: token,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> castVote(String tripPlaceId, int value) async {
    final token = await _token();
    return await _api.post(
      '${ApiConfig.votesPath}/place/$tripPlaceId',
      {'value': value},
      token: token,
    );
  }

  Future<void> retractVote(String tripPlaceId) async {
    final token = await _token();
    await _api.delete(
      '${ApiConfig.votesPath}/place/$tripPlaceId',
      token: token,
    );
  }

  Future<Map<String, dynamic>> openVoting(String tripId) async {
    final token = await _token();
    return await _api.post(
      '${ApiConfig.votesPath}/trip/$tripId/voting/open',
      {},
      token: token,
    );
  }

  Future<Map<String, dynamic>> closeVoting(String tripId) async {
    final token = await _token();
    return await _api.post(
      '${ApiConfig.votesPath}/trip/$tripId/voting/close',
      {},
      token: token,
    );
  }
}
