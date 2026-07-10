import '../core/api_service.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  // Get current user's profile
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/me',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get profile: ${e.toString()}');
    }
  }

  // Get user profile by ID
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.usersPath}/$userId/profile',
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Get current user's followers
  Future<List<Map<String, dynamic>>> getMyFollowers() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/me/followers',
        token: token,
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get followers: ${e.toString()}');
    }
  }

  // Get current user's following list
  Future<List<Map<String, dynamic>>> getMyFollowing() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/me/following',
        token: token,
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get following: ${e.toString()}');
    }
  }

  // Get current user's accepted bonders/friends
  Future<List<Map<String, dynamic>>> getMyFriends() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/me/friends',
        token: token,
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get friends: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getBondRequests({
    String direction = 'incoming',
  }) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/me/bond-requests',
        queryParams: {'direction': direction},
        token: token,
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get bond requests: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getRelationship(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/$userId/relationship',
        token: token,
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to get relationship: ${e.toString()}');
    }
  }

  // Get discoverable TripBond users for inviting/connecting
  Future<List<Map<String, dynamic>>> getBonders({int limit = 100}) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/bonders',
        queryParams: {'limit': limit.toString()},
        token: token,
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get bonders: ${e.toString()}');
    }
  }

  // Update profile
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      final response = await _apiService.put(
        '${ApiConfig.usersPath}/$userId/profile',
        updates,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Get user settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      final response = await _apiService.get(
        '${ApiConfig.usersPath}/$userId/settings',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to get settings: ${e.toString()}');
    }
  }

  // Update settings
  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> settings) async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      final response = await _apiService.put(
        '${ApiConfig.usersPath}/$userId/settings',
        settings,
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to update settings: ${e.toString()}');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final token = await _authService.getAuthToken();
      final userId = await _authService.getUserId();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      await _apiService.delete(
        '${ApiConfig.usersPath}/$userId',
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // Upload profile picture
  Future<Map<String, dynamic>> uploadProfilePicture(
      String userId, String filePath) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // TODO: Implement multipart file upload
      // This will require multipart/form-data upload
      throw UnimplementedError('Profile picture upload not yet implemented');
    } catch (e) {
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  // Follow a user
  Future<Map<String, dynamic>> followUser(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.usersPath}/$userId/follow',
        {},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to follow user: ${e.toString()}');
    }
  }

  // Unfollow a user
  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.delete(
        '${ApiConfig.usersPath}/$userId/follow',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to unfollow user: ${e.toString()}');
    }
  }

  // Send bond request
  Future<Map<String, dynamic>> sendBondRequest(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.usersPath}/$userId/bond-request',
        {},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to send bond request: ${e.toString()}');
    }
  }

  // Cancel bond request
  Future<Map<String, dynamic>> cancelBondRequest(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.delete(
        '${ApiConfig.usersPath}/$userId/bond-request',
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to cancel bond request: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> acceptBondRequest(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.usersPath}/$userId/bond-request/accept',
        {},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to accept bond request: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> rejectBondRequest(String userId) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _apiService.post(
        '${ApiConfig.usersPath}/$userId/bond-request/reject',
        {},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to reject bond request: ${e.toString()}');
    }
  }
}
