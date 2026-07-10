import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

enum AuthStatus { unauthenticated, authenticated, loading }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.unauthenticated;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _errorMessage;

  AuthStatus get status => _status;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // Check authentication status on app start
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();

      if (isAuth) {
        _userId = await _authService.getUserId();
        _userEmail = await _authService.getUserEmail();
        _userName = await _authService.getUserName();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      // Backend returns {access_token, user, message} on success
      if (response['user'] != null) {
        final user = response['user'] as Map<String, dynamic>;
        _userId = user['id'] as String;
        _userEmail = user['email'] as String;
        _userName =
            user['full_name'] as String? ?? user['name'] as String? ?? '';
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = response['message'] as String? ?? 'Login failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dob,
    required String gender,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        dob: dob,
        gender: gender,
      );

      // Backend returns {access_token, user, message} on success
      if (response['user'] != null) {
        final user = response['user'] as Map<String, dynamic>;
        _userId = user['id'] as String?;
        _userEmail = user['email'] as String?;
        _userName =
            user['full_name'] as String? ?? user['name'] as String? ?? name;

        final emailVerified = user['email_verified'] as bool? ?? false;

        if (emailVerified) {
          // Fully registered and email verified
          _status = AuthStatus.authenticated;
        } else {
          // Registered but email verification required
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'email_verification_required';
        }
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = response['message'] as String? ?? 'Registration failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    final previousStatus = _status;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.logout();
      _userId = null;
      _userEmail = null;
      _userName = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _status = previousStatus;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  // Send 6-digit email verification code
  Future<void> sendVerificationCode(String email) async {
    try {
      await _authService.sendVerificationCode(email);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  // Verify 6-digit email code — returns true on success
  Future<bool> verifyEmailCode(String email, String code) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _authService.verifyEmailCode(email, code);
      if (!success) {
        _errorMessage = 'Invalid verification code. Please try again.';
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Set the authenticated status without changing stored user data.
  ///
  /// Useful after completing an email verification flow where login state
  /// should transition to authenticated.
  void setAuthenticatedStatus() {
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
