import '../core/api_config.dart';
import '../core/api_service.dart';
import 'auth_service.dart';

class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  final _api = ApiService();
  final _auth = AuthService();

  Future<String> _token() async {
    final token = await _auth.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> fetchFeed(
      {int limit = 20, int offset = 0}) async {
    final token = await _token();
    final response = await _api.get(
      '${ApiConfig.feedPath}/',
      queryParams: {'limit': '$limit', 'offset': '$offset'},
      token: token,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyLikedTrips({
    int limit = 100,
    int offset = 0,
  }) async {
    final token = await _token();
    final response = await _api.get(
      '${ApiConfig.feedPath}/me/liked-trips',
      queryParams: {'limit': '$limit', 'offset': '$offset'},
      token: token,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> likeTrip(String tripId) async {
    final token = await _token();
    await _api.post('${ApiConfig.feedPath}/trips/$tripId/like', {},
        token: token);
  }

  Future<void> unlikeTrip(String tripId) async {
    final token = await _token();
    await _api.delete('${ApiConfig.feedPath}/trips/$tripId/like', token: token);
  }

  Future<Map<String, dynamic>> requestToJoin(String tripId,
      {String? message}) async {
    final token = await _token();
    return await _api.post(
      '${ApiConfig.feedPath}/trips/$tripId/join-requests',
      {'message': message},
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> listJoinRequests(String tripId) async {
    final token = await _token();
    final response = await _api.get(
      '${ApiConfig.feedPath}/trips/$tripId/join-requests',
      token: token,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> approveJoinRequest(String tripId, String requestId) async {
    final token = await _token();
    await _api.post(
      '${ApiConfig.feedPath}/trips/$tripId/join-requests/$requestId/approve',
      {},
      token: token,
    );
  }

  Future<void> rejectJoinRequest(String tripId, String requestId) async {
    final token = await _token();
    await _api.post(
      '${ApiConfig.feedPath}/trips/$tripId/join-requests/$requestId/reject',
      {},
      token: token,
    );
  }
}
