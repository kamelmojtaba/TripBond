import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/api_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _secureStorage = const FlutterSecureStorage();
  final _apiService = ApiService();

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';

  // Store authentication token securely
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  // Get authentication token
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  // Store refresh token
  Future<void> saveRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  // Save user data
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String name,
  }) async {
    await _secureStorage.write(key: _userIdKey, value: userId);
    await _secureStorage.write(key: _userEmailKey, value: email);
    await _secureStorage.write(key: _userNameKey, value: name);
  }

  // Get user email
  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: _userEmailKey);
  }

  // Get user name
  Future<String?> getUserName() async {
    return await _secureStorage.read(key: _userNameKey);
  }

  // Get user ID
  Future<String?> getUserId() async {
    return await _secureStorage.read(key: _userIdKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    // TODO: Add token expiration check
    // For now, just check if token exists
    return true;
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.authPath}/signin',
        {
          'email': email,
          'password': password,
        },
      );

      if (response['access_token'] != null) {
        // Save tokens and user data
        await saveAuthToken(response['access_token'] as String);

        final user = response['user'] as Map<String, dynamic>;
        await saveUserData(
          userId: user['id'] as String,
          email: user['email'] as String,
          name: user['full_name'] as String? ?? user['email'] as String,
        );

        return {
          'success': true,
          'token': response['access_token'],
          'user': user,
        };
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dob,
    required String gender,
  }) async {
    try {
      final requestBody = {
        'full_name': name,
        'email': email,
        'password': password,
        'phone_number': phone,
        'date_of_birth': dob,
        'gender': gender,
      };

      final response = await _apiService.post(
        '${ApiConfig.authPath}/signup',
        requestBody,
      );

      if (response['access_token'] != null) {
        // Only save if we have a token (email might need verification)
        if ((response['access_token'] as String).isNotEmpty) {
          await saveAuthToken(response['access_token'] as String);

          final user = response['user'] as Map<String, dynamic>;
          await saveUserData(
            userId: user['id'] as String,
            email: user['email'] as String,
            name: user['full_name'] as String? ?? name,
          );
        }

        return {
          'success': true,
          'message': response['message'] ?? 'Registration successful',
          'token': response['access_token'],
          'user': response['user'],
        };
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      // Print detailed error for debugging
      print('Registration error: $e');
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    // Clear secure storage
    await _secureStorage.deleteAll();

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    // Keep onboarding_complete flag
    final hasCompletedOnboarding =
        prefs.getBool('onboarding_complete') ?? false;
    await prefs.clear();
    if (hasCompletedOnboarding) {
      await prefs.setBool('onboarding_complete', true);
    }
  }

  // Send password reset code
  Future<void> sendPasswordResetCode(String email) async {
    try {
      await _apiService.post(
        '${ApiConfig.authPath}/reset-password',
        {'email': email},
      );
    } catch (e) {
      throw Exception('Failed to send reset code: ${e.toString()}');
    }
  }

  // Verify reset code
  Future<bool> verifyResetCode(String email, String code) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.authPath}/verify-reset-code',
        {
          'email': email,
          'code': code,
        },
      );
      return response['valid'] == true;
    } catch (e) {
      throw Exception('Failed to verify code: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    try {
      await _apiService.post(
        '${ApiConfig.authPath}/update-password-with-code',
        {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }

  // Verify email
  Future<void> verifyEmail(String token) async {
    try {
      await _apiService.post(
        '${ApiConfig.authPath}/verify-email',
        {'token': token},
      );
    } catch (e) {
      throw Exception('Failed to verify email: ${e.toString()}');
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _apiService.post(
        '${ApiConfig.authPath}/resend-verification',
        {'email': email},
      );
    } catch (e) {
      throw Exception('Failed to resend verification: ${e.toString()}');
    }
  }

  // Send 6-digit email verification code
  Future<void> sendVerificationCode(String email) async {
    try {
      await _apiService.post(
        '${ApiConfig.authPath}/send-verification-code',
        {'email': email},
      );
    } catch (e) {
      throw Exception('Failed to send verification code: ${e.toString()}');
    }
  }

  // Verify the 6-digit email code — returns true on success
  Future<bool> verifyEmailCode(String email, String code) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.authPath}/verify-email-code',
        {'email': email, 'code': code},
      );

      // Backend returns {message, email, access_token, user} on success
      if (response['access_token'] != null) {
        // Save the new token with email_verified: true
        await saveAuthToken(response['access_token'] as String);

        // Update user data
        if (response['user'] != null) {
          final user = response['user'] as Map<String, dynamic>;
          await saveUserData(
            userId: user['id'] as String,
            email: user['email'] as String,
            name: user['full_name'] as String,
          );
        }
        return true;
      }

      return response['email'] != null || response['message'] != null;
    } catch (e) {
      throw Exception('Email verification failed: ${e.toString()}');
    }
  }
}
