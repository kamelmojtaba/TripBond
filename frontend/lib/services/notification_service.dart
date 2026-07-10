import '../core/api_config.dart';
import '../core/api_service.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _api = ApiService();
  final _auth = AuthService();

  Future<String> _token() async {
    final token = await _auth.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> list({bool onlyUnread = false, int limit = 50}) async {
    final token = await _token();
    final response = await _api.get(
      '${ApiConfig.notificationsPath}/',
      queryParams: {
        'only_unread': onlyUnread.toString(),
        'limit': limit.toString(),
      },
      token: token,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<int> unreadCount() async {
    final token = await _token();
    final response = await _api.get(
      '${ApiConfig.notificationsPath}/unread-count',
      token: token,
    );
    if (response is Map && response['count'] is num) {
      return (response['count'] as num).toInt();
    }
    return 0;
  }

  Future<void> markRead(String id) async {
    final token = await _token();
    await _api.post('${ApiConfig.notificationsPath}/$id/read', {}, token: token);
  }

  Future<void> markAllRead() async {
    final token = await _token();
    await _api.post('${ApiConfig.notificationsPath}/read-all', {}, token: token);
  }
}
