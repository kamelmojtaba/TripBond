import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/user_provider.dart';
import '../services/user_service.dart';
import 'login_screen.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<Settings> {
  final _userService = UserService();
  bool _notificationsOn = true;
  bool _securityEnabled = true;
  String _privacyMode = 'public';
  bool _isLoading = true;
  bool _isSigningOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _userService.getSettings();
      if (!mounted) return;
      setState(() {
        _notificationsOn = settings['notifications_enabled'] ?? true;
        _securityEnabled = settings['security_enabled'] ?? true;
        _privacyMode = settings['privacy_mode'] ?? 'public';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to load settings: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateNotifications(bool value) async {
    setState(() => _notificationsOn = value);
    try {
      await _userService.updateSettings({
        'notifications_enabled': value,
      });
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() {
        _notificationsOn = !value;
        _errorMessage =
            'Failed to update notifications: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _updateSecurity(bool value) async {
    setState(() => _securityEnabled = value);
    try {
      await _userService.updateSettings({
        'security_enabled': value,
      });
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() {
        _securityEnabled = !value;
        _errorMessage =
            'Failed to update security settings: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _updatePrivacyMode(String mode) async {
    setState(() => _privacyMode = mode);
    try {
      await _userService.updateSettings({
        'privacy_mode': mode,
      });
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to update privacy settings: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to log in again to use TripBond.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;

    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;

      context.read<UserProvider>().clearProfile();
      context.read<TripProvider>().clearData();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _errorMessage =
            'Failed to sign out: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back,
                    size: 24, color: Color(0xFF1E1E1E)),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      border: Border.all(color: const Color(0xFFEF5350)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFEF5350), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFFEF5350),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _errorMessage = null),
                          child: const Icon(Icons.close,
                              color: Color(0xFFEF5350), size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              _buildSectionTitle('Account'),
              _buildToggleItem(Icons.lock_outline, 'Security', _securityEnabled,
                  _updateSecurity),
              _buildToggleItem(Icons.notifications_outlined, 'Notifications'),
              _buildPrivacyModeItem(),
              const SizedBox(height: 24),
              _buildSectionTitle('Support & About'),
              _buildArrowItem(Icons.inventory_2_outlined, 'My Subscribtion'),
              _buildArrowItem(Icons.help_outline, 'Help & Support'),
              _buildArrowItem(Icons.info_outline, 'Terms and Policies'),
              const SizedBox(height: 24),
              _buildSectionTitle('Cache & cellular'),
              _buildArrowItem(Icons.inventory_2_outlined, 'Free up space'),
              _buildArrowItem(Icons.speed, 'Data Saver'),
              const SizedBox(height: 24),
              _buildSignOutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5)))),
      margin: const EdgeInsets.only(bottom: 4),
      child: Text(title,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.black)),
    );
  }

  Widget _buildArrowItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E1E1E)),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Colors.black))),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF999999)),
        ],
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, String label,
      [bool? value, Function(bool)? onChanged]) {
    value ??= _notificationsOn;
    onChanged ??= _updateNotifications;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E1E1E)),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Colors.black))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4675B8),
            thumbColor: const MaterialStatePropertyAll(Color(0xFF4675B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyModeItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined,
              size: 20, color: Color(0xFF1E1E1E)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Privacy',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Colors.black)),
                Text(_privacyMode,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF999999))),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _updatePrivacyMode,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'public',
                child: Text('Public'),
              ),
              const PopupMenuItem(
                value: 'friends',
                child: Text('Friends Only'),
              ),
              const PopupMenuItem(
                value: 'private',
                child: Text('Private'),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSigningOut ? null : _handleSignOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF5350),
          side: const BorderSide(color: Color(0xFFEF5350)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFEF5350),
                ),
              )
            : const Icon(Icons.logout, size: 20),
        label: Text(
          _isSigningOut ? AppStrings.processing : AppStrings.logout,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
