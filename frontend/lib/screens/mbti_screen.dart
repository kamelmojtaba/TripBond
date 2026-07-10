import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/animations/page_transitions.dart';
import '../core/animations/animation_constants.dart';
import '../core/constants/constants.dart';
import '../services/personality_service.dart';
import '../services/auth_service.dart';
import 'DestinationLandingPage.dart';

class MbtiScreen extends StatefulWidget {
  const MbtiScreen({super.key});

  @override
  State<MbtiScreen> createState() => _MbtiScreenState();
}

class _MbtiScreenState extends State<MbtiScreen> {
  int _currentScreen = 0;
  final Map<int, String> _answers = {};
  final PersonalityService _personalityService = PersonalityService();

  final List<Map<String, String>> _questionMeta = [
    {
      'illustration': 'assets/images/icons/mtbi2.png',
      'dimension': 'E',
    },
    {
      'illustration': 'assets/images/icons/mtbi3.png',
      'dimension': 'N',
    },
    {
      'illustration': 'assets/images/icons/mtbi4.png',
      'dimension': 'J',
    },
    {
      'illustration': 'assets/images/icons/mtbi5.png',
      'dimension': 'J',
    },
    {
      'illustration': 'assets/images/icons/mtbi6.png',
      'dimension': 'E',
    },
    {
      'illustration': 'assets/images/icons/mtbi7.png',
      'dimension': 'E',
    },
    {
      'illustration': 'assets/images/icons/mtbi8.png',
      'dimension': 'F',
    },
    {
      'illustration': 'assets/images/icons/mtbi9.png',
      'dimension': 'I',
    },
    {
      'illustration': 'assets/images/icons/mtbi10.png',
      'dimension': 'S',
    },
    {
      'illustration': 'assets/images/icons/mtbi11.png',
      'dimension': 'T',
    },
  ];

  bool _isLoadingQuestions = true;
  bool _isSubmitting = false;
  String? _loadError;
  List<Map<String, dynamic>> _quizQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadQuizQuestions();
  }

  Future<void> _loadQuizQuestions() async {
    try {
      final response = await _personalityService.getQuizQuestions();
      final questions = response;
      if (!mounted) return;
      setState(() {
        _quizQuestions = questions;
        _isLoadingQuestions = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingQuestions = false;
      });
    }
  }

  void _handleAnswer(String answer) {
    setState(() {
      _answers[_currentScreen] = answer;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_currentScreen < _quizQuestions.length) {
        setState(() {
          _currentScreen++;
        });
      } else {
        _completeAssessment();
      }
    });
  }

  void _handleNext() {
    if (_currentScreen < _quizQuestions.length) {
      setState(() {
        _currentScreen++;
      });
    } else {
      _completeAssessment();
    }
  }

  Future<void> _completeAssessment() async {
    if (_isSubmitting) return;

    try {
      setState(() {
        _isSubmitting = true;
      });

      // Get user ID
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final answersForApi = <Map<String, dynamic>>[];
      _answers.forEach((index, answer) {
        final questionIndex = index - 1;
        if (questionIndex >= 0 && questionIndex < _quizQuestions.length) {
          final question = _quizQuestions[questionIndex];
          answersForApi.add({
            'question_id': question['id'],
            'answer': answer.toLowerCase(),
          });
        }
      });

      // Submit to backend
      final scores = await _personalityService.submitQuizSubmission(
        userId: userId,
        answers: answersForApi,
      );

      // Calculate MBTI type from scores
      final mbtiType = _calculateMbtiTypeFromScores(scores);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mbti_type', mbtiType);
      await prefs.setBool('mbti_completed', true);

      if (!mounted) return;

      // Navigate to destination landing page
      Navigator.of(context).pushReplacement(
        SharedAxisPageRoute(page: const DestinationLandingPage()),
      );
    } catch (e) {
      // Handle error
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save assessment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      // Still navigate but with local calculation
      final mbtiType = _calculateMbtiType();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mbti_type', mbtiType);
      await prefs.setBool('mbti_completed', true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        SharedAxisPageRoute(page: const DestinationLandingPage()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _calculateMbtiTypeFromScores(Map<String, dynamic> scores) {
    // Extract Big Five scores and convert to MBTI type
    final extraversion = scores['extraversion'] ?? 0.5;
    final openness = scores['openness'] ?? 0.5;
    final agreeableness = scores['agreeableness'] ?? 0.5;
    final conscientiousness = scores['conscientiousness'] ?? 0.5;

    String type = '';
    type += extraversion > 0.5 ? 'E' : 'I';
    type += openness > 0.5 ? 'N' : 'S';
    type += agreeableness > 0.5 ? 'F' : 'T';
    type += conscientiousness > 0.5 ? 'J' : 'P';

    return type;
  }

  String _calculateMbtiType() {
    // TODO: Implement proper MBTI calculation logic
    // This is a simplified version
    final scores = <String, int>{
      'E': 0,
      'I': 0,
      'S': 0,
      'N': 0,
      'T': 0,
      'F': 0,
      'J': 0,
      'P': 0,
    };

    _answers.forEach((index, answer) {
      final questionIndex = index - 1;
      if (questionIndex >= 0 && questionIndex < _questionMeta.length) {
        final dimension = _questionMeta[questionIndex]['dimension'] as String;
        if (answer == AppStrings.agree) {
          scores[dimension] = (scores[dimension] ?? 0) + 1;
        }
      }
    });

    // Determine type (simplified)
    return 'ENFP'; // Default for now
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuestions) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadQuizQuestions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isIntro = _currentScreen == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            if (!isIntro) _buildProgressIndicator(),

            // Main content
            Expanded(
              child: isIntro ? _buildIntroScreen() : _buildQuestionScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalQuestions = _quizQuestions.length;
    final progress =
        totalQuestions <= 1 ? 0.0 : _currentScreen / totalQuestions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$_currentScreen/${_quizQuestions.length}',
                style: AppTextStyles.label,
              ),
            ],
          ),
          AppDimensions.sizedBoxH12,
          ClipRRect(
            borderRadius: AppDimensions.borderRadiusSmall,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: const Duration(milliseconds: AnimationConstants.fast),
          curve: AnimationConstants.smoothEaseOut,
        );
  }

  Widget _buildIntroScreen() {
    return SizedBox.expand(
      child: Stack(
        children: [
          Padding(
            padding: AppDimensions.paddingH32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDimensions.sizedBoxH60,

                // Title
                Text(
                  AppStrings.mbtiIntroTitle,
                  style: AppTextStyles.headline1,
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(
                          milliseconds: AnimationConstants.medium),
                      curve: AnimationConstants.cubicEaseOut,
                    )
                    .slideY(
                      begin: 0.3,
                      end: 0,
                      duration: const Duration(
                          milliseconds: AnimationConstants.medium),
                      curve: AnimationConstants.cubicEaseOut,
                    ),
                AppDimensions.sizedBoxH80,

                // Illustration - centered
                Center(
                  child: Image.asset(
                    'assets/images/icons/mtbi1.png',
                    height: 280,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 280,
                        width: 200,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: AppDimensions.borderRadiusXLarge,
                        ),
                        child: const Icon(
                          Icons.group,
                          size: 100,
                          color: AppColors.textHint,
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(
                        delay: const Duration(
                            milliseconds: AnimationConstants.fast),
                        duration: const Duration(
                            milliseconds: AnimationConstants.medium),
                        curve: AnimationConstants.cubicEaseOut,
                      )
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        delay: const Duration(
                            milliseconds: AnimationConstants.fast),
                        duration: const Duration(
                            milliseconds: AnimationConstants.medium),
                        curve: AnimationConstants.cubicEaseOut,
                      ),
                ),
              ],
            ),
          ),

          // Continue button - bottom right
          Positioned(
            bottom: 32,
            right: 32,
            child: SizedBox(
              width: AppDimensions.fabSize,
              height: AppDimensions.fabSize,
              child: FloatingActionButton(
                onPressed: _handleNext,
                backgroundColor: AppColors.primary,
                elevation: AppDimensions.elevationLow,
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.textLight,
                  size: AppDimensions.fabIconSize,
                ),
              ),
            )
                .animate()
                .fadeIn(
                  delay:
                      const Duration(milliseconds: AnimationConstants.medium),
                  duration:
                      const Duration(milliseconds: AnimationConstants.normal),
                  curve: AnimationConstants.cubicEaseOut,
                )
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  delay:
                      const Duration(milliseconds: AnimationConstants.medium),
                  duration:
                      const Duration(milliseconds: AnimationConstants.normal),
                  curve: AnimationConstants.cubicEaseOut,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final questionIndex = _currentScreen - 1;
    final currentQuestion = _quizQuestions[questionIndex];
    final currentAnswer = _answers[_currentScreen];
    final meta = _questionMeta[questionIndex];

    return SizedBox.expand(
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: AppDimensions.paddingH32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppDimensions.sizedBoxH24,

                  // Question text
                  AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: AnimationConstants.normal),
                    switchInCurve: AnimationConstants.cubicEaseOut,
                    switchOutCurve: AnimationConstants.cubicEaseIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      currentQuestion['text'] as String,
                      key: ValueKey<int>(_currentScreen),
                      style: AppTextStyles.headline3,
                    ),
                  ),
                  AppDimensions.sizedBoxH48,

                  // Answer buttons
                  _buildAnswerButton(
                      AppStrings.agree, currentAnswer == AppStrings.agree, 0),
                  AppDimensions.sizedBoxH16,
                  _buildAnswerButton(AppStrings.neutral,
                      currentAnswer == AppStrings.neutral, 1),
                  AppDimensions.sizedBoxH16,
                  _buildAnswerButton(AppStrings.disagree,
                      currentAnswer == AppStrings.disagree, 2),
                  AppDimensions.sizedBoxH48,

                  // Illustration
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(
                          milliseconds: AnimationConstants.medium),
                      switchInCurve: AnimationConstants.cubicEaseOut,
                      switchOutCurve: AnimationConstants.cubicEaseIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.85, end: 1.0)
                                .animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Image.asset(
                        meta['illustration'] as String,
                        key: ValueKey<int>(_currentScreen),
                        height: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 180,
                            width: 150,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppDimensions.borderRadiusLarge,
                            ),
                            child: const Icon(
                              Icons.people,
                              size: 80,
                              color: AppColors.textHint,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          // Next button - bottom right
          Positioned(
            bottom: 32,
            right: 32,
            child: SizedBox(
              width: AppDimensions.fabSize,
              height: AppDimensions.fabSize,
              child: FloatingActionButton(
                onPressed: _currentScreen < _quizQuestions.length
                    ? _handleNext
                    : _completeAssessment,
                backgroundColor: AppColors.primary,
                elevation: AppDimensions.elevationLow,
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.textLight,
                  size: AppDimensions.fabIconSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(String text, bool isSelected, int index) {
    return Center(
      child: SizedBox(
        width: AppDimensions.buttonWidthMedium,
        height: AppDimensions.buttonHeightLarge,
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: AnimationConstants.ultraFast),
          curve: AnimationConstants.cubicEaseOut,
          child: ElevatedButton(
            onPressed: () => _handleAnswer(text),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSelected ? AppColors.primaryLight : AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: AppDimensions.borderRadiusMedium,
              ),
              elevation: isSelected
                  ? AppDimensions.elevationMedium
                  : AppDimensions.elevationNone,
              shadowColor: AppColors.primaryWithOpacity(0.4),
            ),
            child: Text(
              text,
              style: AppTextStyles.buttonLarge,
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(
                milliseconds: AnimationConstants.ultraFast * index + 100),
            duration: const Duration(milliseconds: AnimationConstants.normal),
            curve: AnimationConstants.cubicEaseOut,
          )
          .slideX(
            begin: 0.2,
            end: 0,
            delay: Duration(
                milliseconds: AnimationConstants.ultraFast * index + 100),
            duration: const Duration(milliseconds: AnimationConstants.normal),
            curve: AnimationConstants.cubicEaseOut,
          ),
    );
  }
}
