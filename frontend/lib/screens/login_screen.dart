import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'DestinationLandingPage.dart';
import 'widgets/custom_loading_spinner.dart';
import '../core/animations/page_transitions.dart';
import '../core/animations/animation_constants.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Navigate and remove all auth screens from stack
      Navigator.of(context).pushAndRemoveUntil(
        SharedAxisPageRoute(page: const DestinationLandingPage()),
        (route) => false,
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Illustration with animation
                    Center(
                      child: Image.asset(
                        'assets/images/icons/authcon.png',
                        height: 180,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.login,
                            size: 180,
                            color: Color(0xFF4675B8),
                          );
                        },
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: const Duration(
                              milliseconds: AnimationConstants.medium),
                          curve: AnimationConstants.cubicEaseOut,
                        )
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          duration: const Duration(
                              milliseconds: AnimationConstants.medium),
                          curve: AnimationConstants.cubicEaseOut,
                        ),
                    const SizedBox(height: 32),

                    // Welcome text with animation
                    Text(
                      'Welcome back',
                      style: GoogleFonts.mulish(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: const Duration(milliseconds: 200),
                          duration: const Duration(
                              milliseconds: AnimationConstants.normal),
                          curve: AnimationConstants.cubicEaseOut,
                        )
                        .slideY(
                          begin: 0.1,
                          delay: const Duration(milliseconds: 200),
                          duration: const Duration(
                              milliseconds: AnimationConstants.normal),
                          curve: AnimationConstants.cubicEaseOut,
                        ),
                    const SizedBox(height: 4),
                    Text(
                      'sign in to access your account',
                      style: GoogleFonts.mulish(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(
                              milliseconds: AnimationConstants.normal),
                          curve: AnimationConstants.cubicEaseOut,
                        )
                        .slideY(
                          begin: 0.1,
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(
                              milliseconds: AnimationConstants.normal),
                          curve: AnimationConstants.cubicEaseOut,
                        ),
                    const SizedBox(height: 40),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.mulish(fontSize: 15),
                      validator: Validators.validateEmail,
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        hintStyle: GoogleFonts.mulish(
                          color: Colors.grey[400],
                          fontSize: 15,
                        ),
                        suffixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: GoogleFonts.mulish(fontSize: 15),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: GoogleFonts.mulish(
                          color: Colors.grey[400],
                          fontSize: 15,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.lock_open_outlined
                                : Icons.lock_outline,
                            color: Colors.grey[400],
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remember me and Forgot password
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF4675B8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: BorderSide(
                              color: Colors.grey[400]!,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password ?',
                            style: GoogleFonts.mulish(
                              fontSize: 14,
                              color: const Color(0xFF4675B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Next button
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final isLoading = authProvider.isLoading;

                        return SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4675B8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: const Color(0xFF4675B8)
                                  .withValues(alpha: 0.6),
                            ),
                            child: isLoading
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
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Next',
                                        style: GoogleFonts.mulish(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 20),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Register now
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New Member? ',
                            style: GoogleFonts.mulish(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                SharedAxisPageRoute(
                                    page: const RegisterScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Register now',
                              style: GoogleFonts.mulish(
                                fontSize: 14,
                                color: const Color(0xFF4675B8),
                                fontWeight: FontWeight.w600,
                              ),
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
