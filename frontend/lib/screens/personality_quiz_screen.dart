import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../services/personality_service.dart';
import '../services/auth_service.dart';

class PersonalityQuizScreen extends StatefulWidget {
  const PersonalityQuizScreen({super.key});

  @override
  State<PersonalityQuizScreen> createState() => _PersonalityQuizScreenState();
}

class _PersonalityQuizScreenState extends State<PersonalityQuizScreen> {
  final _personalityService = PersonalityService();
  final _authService = AuthService();

  List<Map<String, dynamic>> questions = [];
  Map<int, int> answers = {}; // question id -> rating (1-5)
  bool isLoading = true;
  String errorMessage = '';
  int currentQuestion = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() => isLoading = true);
      final qs = await _personalityService.getQuizQuestions();
      setState(() {
        questions = qs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _submitQuiz() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please sign in again.');
      }

      final userId = await _authService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('User session expired. Please sign in again.');
      }

      if (answers.length < questions.length) {
        throw Exception('Please answer all questions before submitting.');
      }

      final submissionAnswers = answers.entries
          .map((e) => {
                'question_id': e.key,
                'answer': _ratingToAnswer(e.value),
              })
          .toList();

      await _personalityService.submitQuizSubmission(
        userId: userId,
        answers: submissionAnswers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Travel Personality Quiz'),
        backgroundColor: const Color(0xFF4675B8),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadQuestions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : questions.isEmpty
                  ? const Center(child: Text('No questions available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Question ${currentQuestion + 1} of ${questions.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${((currentQuestion + 1) / questions.length * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4675B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (currentQuestion + 1) / questions.length,
                              minHeight: 6,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF4675B8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Question
                          Text(
                            _questionText(questions[currentQuestion]),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Rating options (1-5)
                          Column(
                            children: List.generate(5, (index) {
                              final rating = index + 1;
                              final questionId =
                                  _questionId(questions[currentQuestion]);
                              final isSelected = answers[questionId] == rating;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      answers[questionId] = rating;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4675B8)
                                            : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      color: isSelected
                                          ? const Color(0xFF4675B8)
                                              .withOpacity(0.1)
                                          : Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _getRatingLabel(rating),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isSelected
                                                  ? const Color(0xFF4675B8)
                                                  : Colors.black,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF4675B8),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 32),
                          // Navigation buttons
                          Row(
                            children: [
                              if (currentQuestion > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() => currentQuestion--);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF4675B8),
                                      ),
                                    ),
                                    child: const Text('Previous'),
                                  ),
                                ),
                              if (currentQuestion > 0)
                                const SizedBox(width: 12),
                              Expanded(
                                child: answers.containsKey(
                                        _questionId(
                                            questions[currentQuestion]))
                                    ? ElevatedButton(
                                        onPressed: currentQuestion <
                                                questions.length - 1
                                            ? () {
                                                setState(
                                                    () => currentQuestion++);
                                              }
                                            : _submitQuiz,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF4675B8),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              Colors.grey[300],
                                          disabledForegroundColor:
                                              Colors.grey[600],
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: Text(
                                          currentQuestion < questions.length - 1
                                              ? 'Next'
                                              : 'Submit',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[300],
                                          foregroundColor: Colors.grey[600],
                                          disabledBackgroundColor:
                                              Colors.grey[300],
                                          disabledForegroundColor:
                                              Colors.grey[600],
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: const Text(
                                          'Select an option',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Strongly Disagree';
      case 2:
        return 'Disagree';
      case 3:
        return 'Neutral';
      case 4:
        return 'Agree';
      case 5:
        return 'Strongly Agree';
      default:
        return '';
    }
  }

  String _questionText(Map<String, dynamic> question) {
    return (question['text'] ?? question['question'] ?? '').toString();
  }

  int _questionId(Map<String, dynamic> question) {
    final id = question['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return currentQuestion + 1;
  }

  String _ratingToAnswer(int rating) {
    if (rating <= 2) return 'disagree';
    if (rating == 3) return 'neutral';
    return 'agree';
  }
}
