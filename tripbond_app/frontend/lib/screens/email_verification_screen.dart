import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../frontend/lib/providers/auth_provider.dart';
import '../../../../frontend/lib/core/animations/page_transitions.dart';
import '../../../../frontend/lib/screens/mbti_screen.dart';
import '../../../../frontend/lib/screens/widgets/custom_loading_spinner.dart';

/// Shown right after a user registers.
/// The user enters the 6-digit code that was emailed to them.
/// On success, the email is confirmed and the user proceeds to MBTI assessment.
class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _remainingSeconds = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _remainingSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _handleVerify() async {
    final code = _currentCode;
    if (code.length != 6) {
      _showSnack('Please enter all 6 digits', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.verifyEmailCode(widget.email, code);

      if (!mounted) return;

      if (success) {
        // Email verified! User is now authenticated
        authProvider.setAuthenticatedStatus();

        _showSnack(
          'Email verified successfully!',
          isError: false,
          duration: const Duration(seconds: 2),
        );

        // Navigate to MBTI screen (onboarding continues)
        Navigator.of(context).pushAndRemoveUntil(
          FadePageRoute(page: const MbtiScreen()),
          (route) => false,
        );
      } else {
        setState(() => _isLoading = false);
        _showSnack(
          authProvider.errorMessage ?? 'Invalid code. Please try again.',
          isError: true,
        );
        // Clear the fields so user can re-enter
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        authProvider.clearError();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Verification failed. Please try again.', isError: true);
    }
  }

  Future<void> _handleResend() async {
    if (_remainingSeconds > 0) {
      _showSnack(
        'Please wait ${_formatTime(_remainingSeconds)} before requesting a new code.',
        isError: false,
      );
      return;
    }

    setState(() => _isResending = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendVerificationCode(widget.email);

      if (!mounted) return;
      _showSnack(
        'A new verification code has been sent to your email.',
        isError: false,
      );
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Failed to resend code. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showSnack(
    String message, {
    required bool isError,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mulish()),
        backgroundColor: isError ? Colors.red : const Color(0xFF4675B8),
        duration: duration,
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  List<TextSpan> _buildSubtitleSpans() {
    final parts = widget.email.split('@');
    if (parts.length != 2) {
      return [TextSpan(text: 'Code sent to ${widget.email}')];
    }
    return [
      const TextSpan(text: 'Please enter the 6-digit code sent to\n'),
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
                    // ── back button ───────────────────────────────────────
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4675B8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── title ────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Verify your email',
                            style: GoogleFonts.mulish(
                              fontSize: 26,
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
                                height: 1.6,
                              ),
                              children: _buildSubtitleSpans(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── 6-digit input ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 44,
                          height: 52,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: GoogleFonts.mulish(
                              fontSize: 22,
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
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4675B8),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              // Support paste — distribute digits across fields
                              if (value.length > 1) {
                                final digits = value.split('');
                                for (
                                  int j = 0;
                                  j < digits.length && (i + j) < 6;
                                  j++
                                ) {
                                  _controllers[i + j].text = digits[j];
                                  if (i + j < 5) {
                                    _focusNodes[i + j + 1].requestFocus();
                                  }
                                }
                              } else if (value.isNotEmpty && i < 5) {
                                _focusNodes[i + 1].requestFocus();
                              } else if (value.isEmpty && i > 0) {
                                _focusNodes[i - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 36),

                    // ── verify button ────────────────────────────────────
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
                          disabledBackgroundColor: const Color(
                            0xFF4675B8,
                          ).withValues(alpha: 0.6),
                        ),
                        child: _isLoading
                            ? const CustomLoadingSpinner(
                                fontSize: 14,
                                dotSize: 8,
                                textColor: Colors.white,
                                dotColors: [
                                  Colors.white,
                                  Colors.white70,
                                  Colors.white54,
                                ],
                              )
                            : Text(
                                'Confirm Email',
                                style: GoogleFonts.mulish(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── resend section ───────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Didn't receive the code?",
                            style: GoogleFonts.mulish(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _isResending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4675B8),
                                  ),
                                )
                              : TextButton(
                                  onPressed: _remainingSeconds > 0
                                      ? null
                                      : _handleResend,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: const Color(0xFF4675B8),
                                    disabledForegroundColor:
                                        Colors.grey.shade400,
                                  ),
                                  child: Text(
                                    'Resend Code',
                                    style: GoogleFonts.mulish(
                                      fontSize: 13,
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
