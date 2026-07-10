import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/user_service.dart';

class editprofile extends StatefulWidget {
  const editprofile({super.key});

  @override
  State<editprofile> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<editprofile> {
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _gender = 'Female';
  bool _isLoading = true;
  bool _isSaving = false;
  String _avatarUrl = '';
  String? _selectedAvatarDataUrl;
  Uint8List? _selectedAvatarBytes;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _userService.getMyProfile();
      if (!mounted) return;

      _fullNameController.text = (profile['full_name'] ?? '').toString();
      _dobController.text = _formatDobForDisplay(
        (profile['date_of_birth'] ?? '').toString(),
      );
      _emailController.text = (profile['email'] ?? '').toString();
      _phoneController.text = (profile['phone_number'] ?? '').toString();
      _avatarUrl = (profile['avatar_url'] ?? '').toString();

      final gender = (profile['gender'] ?? '').toString();
      if (gender.toLowerCase() == 'male') {
        _gender = 'Male';
      } else if (gender.toLowerCase() == 'female') {
        _gender = 'Female';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    if (_newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New password and confirmation do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final updates = <String, dynamic>{
      'full_name': _fullNameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'gender': _gender.toLowerCase(),
    };

    if (_removeAvatar) {
      updates['avatar_url'] = '';
    } else if (_selectedAvatarDataUrl != null &&
        _selectedAvatarDataUrl!.isNotEmpty) {
      updates['avatar_url'] = _selectedAvatarDataUrl;
    }

    final dobForApi = _normalizeDobForApi(_dobController.text.trim());
    if (dobForApi != null && dobForApi.isNotEmpty) {
      updates['date_of_birth'] = dobForApi;
    }

    setState(() => _isSaving = true);
    try {
      await _userService.updateProfile(updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF4675B8),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      final originalBytes = await picked.readAsBytes();
      if (originalBytes.isEmpty) return;

      final processedBytes = _cropAndCompressImage(originalBytes);
      if (processedBytes.isEmpty) return;

      final dataUrl = 'data:image/jpeg;base64,${base64Encode(processedBytes)}';

      if (!mounted) return;
      setState(() {
        _selectedAvatarBytes = processedBytes;
        _selectedAvatarDataUrl = dataUrl;
        _removeAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Uint8List _cropAndCompressImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final shortest = decoded.width < decoded.height
          ? decoded.width
          : decoded.height;
      final x = (decoded.width - shortest) ~/ 2;
      final y = (decoded.height - shortest) ~/ 2;

      final cropped = img.copyCrop(
        decoded,
        x: x,
        y: y,
        width: shortest,
        height: shortest,
      );
      final resized = img.copyResize(
        cropped,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      final encoded = img.encodeJpg(resized, quality: 78);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedAvatarBytes = null;
      _selectedAvatarDataUrl = null;
      _avatarUrl = '';
      _removeAvatar = true;
    });
  }

  Uint8List? _decodeDataUrlImage(String value) {
    if (!value.startsWith('data:image')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex < 0 || commaIndex >= value.length - 1) return null;
    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatar() {
    ImageProvider? imageProvider;

    if (_selectedAvatarBytes != null) {
      imageProvider = MemoryImage(_selectedAvatarBytes!);
    } else if (_avatarUrl.trim().isNotEmpty) {
      final decoded = _decodeDataUrlImage(_avatarUrl.trim());
      if (decoded != null) {
        imageProvider = MemoryImage(decoded);
      } else {
        imageProvider = NetworkImage(_avatarUrl.trim());
      }
    }

    final hasAvatar =
        !_removeAvatar && (imageProvider != null || _avatarUrl.trim().isNotEmpty);

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                backgroundImage: _removeAvatar ? null : imageProvider,
                child: (_removeAvatar || imageProvider == null)
                    ? const Icon(
                        Icons.person,
                        size: 52,
                        color: Color(0xFF4675B8),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickAvatar,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4675B8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasAvatar)
            TextButton.icon(
              onPressed: _removePhoto,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Remove Photo',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDobForDisplay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final parts = value.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]} - ${parts[1]} - ${parts[0]}';
    }
    return value;
  }

  String? _normalizeDobForApi(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final isoParts = value.split('-').map((e) => e.trim()).toList();
    if (isoParts.length == 3 && isoParts[0].length == 4) {
      return '${isoParts[0]}-${isoParts[1].padLeft(2, '0')}-${isoParts[2].padLeft(2, '0')}';
    }

    final displayParts = value
        .split(RegExp(r'\s*-\s*'))
        .map((e) => e.trim())
        .toList();
    if (displayParts.length == 3 && displayParts[2].length == 4) {
      final day = displayParts[0].padLeft(2, '0');
      final month = displayParts[1].padLeft(2, '0');
      final year = displayParts[2];
      return '$year-$month-$day';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF1E1E1E)),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 24),
              _buildAvatar(),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Tap camera icon to change photo',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Personal Information:', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
              const SizedBox(height: 16),
              _buildField('Full name', _fullNameController, Icons.person_outline),
              _buildField('Date of Birth', _dobController, Icons.calendar_today_outlined),
              _buildField('E-Mail', _emailController, Icons.email_outlined),
              _buildField('Phone number', _phoneController, Icons.phone_android),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.white,
                ),
                child: Row(
                  children: ['Female', 'Male'].map((g) {
                    final selected = _gender == g;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _gender = g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF4675B8) : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            g,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: selected ? Colors.white : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Password:', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
              const SizedBox(height: 16),
              _buildPasswordField('Current Password', '********************', readOnly: true, icon: Icons.visibility_off_outlined),
              _buildPasswordField('New Password', '', controller: _newPasswordController),
              _buildPasswordField('Confirm New Password', '', controller: _confirmPasswordController),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4675B8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey.shade400)),
                TextField(
                  controller: controller,
                  readOnly: label == 'E-Mail',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
          Icon(icon, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, String initial, {bool readOnly = false, IconData? icon, TextEditingController? controller}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey.shade400)),
                TextField(
                  controller: controller ?? TextEditingController(text: initial),
                  readOnly: readOnly,
                  obscureText: true,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
          Icon(icon ?? Icons.lock_outline, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
