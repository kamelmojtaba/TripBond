import 'package:flutter/material.dart';
import '../services/feedback_service.dart';
import '../services/trip_service.dart';

class FeedbackScreen extends StatefulWidget {
  final String? tripId;

  const FeedbackScreen({this.tripId, super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackService = FeedbackService();
  final _tripService = TripService();

  List<Map<String, dynamic>> trips = [];
  bool isLoading = true;
  String? selectedTripId;

  @override
  void initState() {
    super.initState();
    selectedTripId = widget.tripId;
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      setState(() => isLoading = true);
      final myTrips = await _tripService.getMyTrips();
      setState(() {
        trips = myTrips;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Trip Feedback'),
        backgroundColor: const Color(0xFF4675B8),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trip_origin,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No trips available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : selectedTripId == null
                  ? _buildTripSelection()
                  : _buildFeedbackForm(),
    );
  }

  Widget _buildTripSelection() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(trip['title'] ?? 'Untitled Trip'),
            subtitle: Text(trip['destination'] ?? 'Unknown destination'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              setState(() => selectedTripId = trip['id']);
            },
          ),
        );
      },
    );
  }

  Widget _buildFeedbackForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _TripFeedbackForm(
        tripId: selectedTripId!,
        feedbackService: _feedbackService,
        onSubmitSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback submitted successfully!')),
          );
          Navigator.pop(context);
        },
        onBack: () {
          setState(() => selectedTripId = null);
        },
      ),
    );
  }
}

class _TripFeedbackForm extends StatefulWidget {
  final String tripId;
  final FeedbackService feedbackService;
  final VoidCallback onSubmitSuccess;
  final VoidCallback onBack;

  const _TripFeedbackForm({
    required this.tripId,
    required this.feedbackService,
    required this.onSubmitSuccess,
    required this.onBack,
  });

  @override
  State<_TripFeedbackForm> createState() => _TripFeedbackFormState();
}

class _TripFeedbackFormState extends State<_TripFeedbackForm> {
  int rating = 0;
  final _feedbackController = TextEditingController();
  List<String> selectedTags = [];
  bool isSubmitting = false;

  final List<String> availableTags = [
    'Amazing',
    'Good',
    'Worth it',
    'Expensive',
    'Crowded',
    'Peaceful',
    'Adventure',
    'Relaxing',
  ];

  Future<void> _submitFeedback() async {
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    try {
      setState(() => isSubmitting = true);
      await widget.feedbackService.rateTrip(
        tripId: widget.tripId,
        rating: rating,
        feedback: _feedbackController.text,
        tags: selectedTags,
      );
      if (mounted) {
        widget.onSubmitSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
            const Text(
              'How was your trip?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 24),
        // Star rating
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => rating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        index < rating ? Icons.star : Icons.star_outline,
                        size: 40,
                        color: const Color(0xFF4675B8),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                rating == 0 ? 'Tap to rate' : _getRatingLabel(rating),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4675B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Tags
        const Text(
          'How would you describe it?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableTags.map((tag) {
            final isSelected = selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedTags.add(tag);
                  } else {
                    selectedTags.remove(tag);
                  }
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF4675B8).withOpacity(0.3),
              side: BorderSide(
                color: isSelected ? const Color(0xFF4675B8) : Colors.grey[300]!,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        // Feedback text field
        const Text(
          'Additional comments (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feedbackController,
          decoration: InputDecoration(
            hintText: 'Share details about your experience...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 32),
        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4675B8),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Submit Feedback',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Okay';
      case 2:
        return 'Good';
      case 3:
        return 'Great';
      case 4:
        return 'Excellent';
      case 5:
        return 'Unforgettable';
      default:
        return '';
    }
  }
}
