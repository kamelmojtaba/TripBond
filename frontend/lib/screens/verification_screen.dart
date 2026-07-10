import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'new_password_screen.dart';
import 'widgets/custom_loading_spinner.dart';
import '../core/animations/page_transitions.dart';
import '../services/auth_service.dart';

class VerificationScreen extends StatefulWidget {
  final String email;

  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _remainingSeconds = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Add listener to first field for paste support
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final isValid = await _authService.verifyResetCode(widget.email, code);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or expired code.')),
      );
      return;
    }

    Navigator.push(
      context,
      SharedAxisPageRoute(
          page: NewPasswordScreen(email: widget.email, code: code)),
    );
  }

  Future<void> _resendCode() async {
    if (_remainingSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait $_remainingSeconds seconds before requesting a new code',
            style: GoogleFonts.mulish(),
          ),
          backgroundColor: const Color(0xFF4675B8),
        ),
      );
      return;
    }

    try {
      await _authService.sendPasswordResetCode(widget.email);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
      return;
    }

    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reset code has been resent to ${widget.email}',
          style: GoogleFonts.mulish(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  List<TextSpan> _buildEmailText(String email) {
    final parts = email.split('@');
    if (parts.length != 2) {
      return [
        TextSpan(
            text:
                'Please enter the 6-digit code sent to your email $email for verification.')
      ];
    }

    return [
      const TextSpan(
          text: 'Please enter the 6-digit code sent to\nyour email '),
      TextSpan(
        text: parts[0],
        style: GoogleFonts.mulish(color: Colors.black54),
      ),
      TextSpan(
        text: '@${parts[1]}',
        style: GoogleFonts.mulish(
          color: const Color(0xFF4675B8),
          fontWeight: FontWeight.w600,
        ),
      ),
      const TextSpan(text: ' for verification.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Back button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4675B8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Almost there',
                            style: GoogleFonts.mulish(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.mulish(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                              children: _buildEmailText(widget.email),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // 6-digit code input
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 45,
                          height: 50,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: GoogleFonts.mulish(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Colors.grey, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF4675B8), width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              // Handle paste - check if multiple digits
                              if (value.length > 1) {
                                // Extract digits and distribute across fields
                                final digits = value.split('');
                                for (int i = 0;
                                    i < digits.length && (index + i) < 6;
                                    i++) {
                                  _controllers[index + i].text = digits[i];
                                  if (index + i < 5) {
                                    _focusNodes[index + i + 1].requestFocus();
                                  }
                                }
                              } else if (value.isNotEmpty && index < 5) {
                                // Single digit - move to next field
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                // Backspace - move to previous field
                                _focusNodes[index - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4675B8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          disabledBackgroundColor:
                              const Color(0xFF4675B8).withValues(alpha: 0.6),
                        ),
                        child: _isLoading
                            ? const CustomLoadingSpinner(
                                fontSize: 14,
                                dotSize: 8,
                                textColor: Colors.white,
                                dotColors: [
                                  Colors.white,
                                  Colors.white70,
                                  Colors.white54
                                ],
                              )
                            : Text(
                                'Verify',
                                style: GoogleFonts.mulish(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend code
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Didn't receive any code?",
                            style: GoogleFonts.mulish(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          TextButton(
                            onPressed: _resendCode,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Resend Again',
                              style: GoogleFonts.mulish(
                                fontSize: 13,
                                color: const Color(0xFF4675B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _remainingSeconds > 0
                                ? 'Request new code in ${_formatTime(_remainingSeconds)}'
                                : 'You can request a new code now',
                            style: GoogleFonts.mulish(
                              fontSize: 12,
                              color: _remainingSeconds > 0
                                  ? Colors.black38
                                  : const Color(0xFF4675B8),
                              fontWeight: _remainingSeconds > 0
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
