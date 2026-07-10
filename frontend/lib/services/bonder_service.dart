import '../core/api_config.dart';
import '../core/api_service.dart';
import 'auth_service.dart';

class BonderItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final String lastMsg;

  BonderItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.lastMsg = 'Say hello to start chatting',
  });

  factory BonderItem.fromJson(Map<String, dynamic> json) {
    return BonderItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'TripBond User').toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  BonderItem copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? lastMsg,
  }) {
    return BonderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMsg: lastMsg ?? this.lastMsg,
    );
  }
}

class BonderService {
  static final BonderService _instance = BonderService._internal();
  factory BonderService() => _instance;
  BonderService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  Future<List<BonderItem>> getFriends() async {
    return _fetchBonders('${ApiConfig.usersPath}/me/friends');
  }

  Future<List<BonderItem>> getAllBonders({int limit = 100}) async {
    return _fetchBonders(
      '${ApiConfig.usersPath}/bonders',
      queryParams: {'limit': '$limit'},
    );
  }

  Future<List<BonderItem>> getBonders({int limit = 50}) async {
    return getFriends();
  }

  Future<List<BonderItem>> _fetchBonders(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final token = await _authService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final currentUserId = await _authService.getUserId();
    final currentUserName =
        (await _authService.getUserName())?.trim().toLowerCase();

    final response =
        await _apiService.get(path, queryParams: queryParams, token: token);

    if (response is! List) {
      throw Exception('Invalid response format for bonders');
    }

    final items = response
        .whereType<Map<String, dynamic>>()
        .map(BonderItem.fromJson)
        .toList();

    final seenIds = <String>{};

    return items.where((item) {
      final id = item.id.trim();
      final normalizedName = item.name.trim().toLowerCase();

      // Ignore malformed records without IDs.
      if (id.isEmpty) {
        return false;
      }

      // Primary guard: current user should never appear in bonders.
      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          id == currentUserId) {
        return false;
      }

      // Fallback guard when auth user id is unavailable.
      if ((currentUserId == null || currentUserId.isEmpty) &&
          currentUserName != null &&
          currentUserName.isNotEmpty &&
          normalizedName == currentUserName) {
        return false;
      }

      // Keep first occurrence only.
      if (!seenIds.add(id)) {
        return false;
      }

      return true;
    }).toList();
  }
}
