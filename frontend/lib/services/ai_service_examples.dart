import 'package:flutter/material.dart';
import '../services/ai_service.dart';

/// Example 1: Get Group Recommendations
/// Display AI-powered POI recommendations for a group
class GroupRecommendationsExample extends StatefulWidget {
  final String tripId;
  final List<String> userIds;

  const GroupRecommendationsExample({
    Key? key,
    required this.tripId,
    required this.userIds,
  }) : super(key: key);

  @override
  State<GroupRecommendationsExample> createState() =>
      _GroupRecommendationsExampleState();
}

class _GroupRecommendationsExampleState
    extends State<GroupRecommendationsExample> {
  final _aiService = AIService();
  late Future<GroupRecommendationsResponse> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _loadRecommendations() {
    _recommendationsFuture = _aiService.getGroupRecommendations(
      tripId: widget.tripId,
      userIds: widget.userIds,
      topK: 10,
      aggregationStrategy: 'average',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupRecommendationsResponse>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No recommendations available'));
        }

        final response = snapshot.data!;

        return ListView.builder(
          itemCount: response.recommendations.length,
          itemBuilder: (context, index) {
            final rec = response.recommendations[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(rec.name),
                subtitle: Text('${rec.category} • Rating: ${rec.rating}/5'),
                trailing: Chip(
                  label: Text('${(rec.score * 100).toStringAsFixed(0)}%'),
                  backgroundColor: Colors.blue[100],
                ),
                onTap: () {
                  // Navigate to POI details
                  // Navigator.push(...);
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Example 2: Optimize Itinerary with Genetic Algorithm
/// Create an optimized multi-day itinerary
class ItineraryOptimizationExample extends StatefulWidget {
  final String tripId;
  final List<String> userIds;
  final List<Map<String, dynamic>> pois;

  const ItineraryOptimizationExample({
    Key? key,
    required this.tripId,
    required this.userIds,
    required this.pois,
  }) : super(key: key);

  @override
  State<ItineraryOptimizationExample> createState() =>
      _ItineraryOptimizationExampleState();
}

class _ItineraryOptimizationExampleState
    extends State<ItineraryOptimizationExample> {
  final _aiService = AIService();
  late Future<OptimizedItinerary> _itineraryFuture;
  bool _useGeneticAlgorithm = true;
  int _numDays = 2;
  String _pace = 'moderate';

  @override
  void initState() {
    super.initState();
    _optimizeItinerary();
  }

  void _optimizeItinerary() {
    _itineraryFuture = _aiService.optimizeGroupItinerary(
      tripId: widget.tripId,
      userIds: widget.userIds,
      pois: widget.pois,
      useGa: _useGeneticAlgorithm,
      numDays: _numDays,
      pace: _pace,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Days: $_numDays'),
                  ),
                  Slider(
                    value: _numDays.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    onChanged: (value) {
                      setState(() {
                        _numDays = value.toInt();
                        _optimizeItinerary();
                      });
                    },
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _pace,
                onChanged: (value) {
                  setState(() {
                    _pace = value ?? 'moderate';
                    _optimizeItinerary();
                  });
                },
                items: const [
                  DropdownMenuItem(value: 'slow', child: Text('Slow Pace')),
                  DropdownMenuItem(
                      value: 'moderate', child: Text('Moderate Pace')),
                  DropdownMenuItem(value: 'fast', child: Text('Fast Pace')),
                ],
              ),
              SwitchListTile(
                title: const Text('Use Genetic Algorithm'),
                value: _useGeneticAlgorithm,
                onChanged: (value) {
                  setState(() {
                    _useGeneticAlgorithm = value;
                    _optimizeItinerary();
                  });
                },
              ),
            ],
          ),
        ),
        // Itinerary Display
        Expanded(
          child: FutureBuilder<OptimizedItinerary>(
            future: _itineraryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: Text('No itinerary available'));
              }

              final itinerary = snapshot.data!;

              return ListView.builder(
                itemCount: itinerary.itinerary.length,
                itemBuilder: (context, dayIndex) {
                  final day = itinerary.itinerary[dayIndex];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: Colors.blue,
                          padding: const EdgeInsets.all(8.0),
                          width: double.infinity,
                          child: Text(
                            'Day ${day.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...day.activities.map((activity) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${activity.startTime} - ${activity.endTime}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Duration: ${activity.durationMinutes}m, Travel: ${activity.travelToMinutes}m',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Summary Footer
        FutureBuilder<OptimizedItinerary>(
          future: _itineraryFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final itinerary = snapshot.data!;
              return Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Cost'),
                        Text(
                          '\$${itinerary.totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Travel Time'),
                        Text(
                          '${itinerary.totalTravelTime}m',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Quality Score'),
                        Text(
                          '${(itinerary.fitnessScore * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// Example 3: Get User Recommendations
/// Show personalized recommendations for a single user
class UserRecommendationsExample extends StatefulWidget {
  final String userId;
  final String? tripId;

  const UserRecommendationsExample({
    Key? key,
    required this.userId,
    this.tripId,
  }) : super(key: key);

  @override
  State<UserRecommendationsExample> createState() =>
      _UserRecommendationsExampleState();
}

class _UserRecommendationsExampleState
    extends State<UserRecommendationsExample> {
  final _aiService = AIService();
  late Future<List<AIRecommendation>> _recommendationsFuture;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _loadRecommendations() {
    _recommendationsFuture = _aiService.getUserRecommendations(
      userId: widget.userId,
      tripId: widget.tripId,
      topK: 20,
      category: _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category Filter
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String?>(
            hint: const Text('Filter by category'),
            value: _selectedCategory,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _loadRecommendations();
              });
            },
            items: const [
              DropdownMenuItem(value: null, child: Text('All Categories')),
              DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
              DropdownMenuItem(value: 'attraction', child: Text('Attraction')),
              DropdownMenuItem(value: 'hotel', child: Text('Hotel')),
              DropdownMenuItem(value: 'shopping', child: Text('Shopping')),
            ],
          ),
        ),
        // Recommendations Grid
        Expanded(
          child: FutureBuilder<List<AIRecommendation>>(
            future: _recommendationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No recommendations'));
              }

              final recommendations = snapshot.data!;

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                ),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final rec = recommendations[index];
                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: Colors.grey[300],
                          height: 100,
                          width: double.infinity,
                          child: const Icon(Icons.image, size: 50),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                rec.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 12, color: Colors.amber),
                                      Text(
                                        '${rec.rating}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(rec.score * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Example 4: Submit Itinerary Feedback
/// Allow users to rate and comment on their itinerary
class FeedbackFormExample extends StatefulWidget {
  final String itineraryId;

  const FeedbackFormExample({
    Key? key,
    required this.itineraryId,
  }) : super(key: key);

  @override
  State<FeedbackFormExample> createState() => _FeedbackFormExampleState();
}

class _FeedbackFormExampleState extends State<FeedbackFormExample> {
  final _aiService = AIService();
  double _score = 3.0;
  late TextEditingController _notesController;
  final List<String> _improvements = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_score < 1 || _score > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a score between 1-5')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _aiService.submitItineraryFeedback(
        itineraryId: widget.itineraryId,
        feedbackScore: _score,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        improvements: _improvements.isNotEmpty ? _improvements : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Experience',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _score = (index + 1).toDouble()),
                  child: Icon(
                    Icons.star,
                    size: 40,
                    color: index < _score.toInt()
                        ? Colors.amber
                        : Colors.grey[300],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Your Comments',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What did you enjoy? What could be improved?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Suggestions for Improvement',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              InputChip(
                label: const Text('More restaurants'),
                onPressed: () => setState(() {
                  if (_improvements.contains('More restaurants')) {
                    _improvements.remove('More restaurants');
                  } else {
                    _improvements.add('More restaurants');
                  }
                }),
                selected: _improvements.contains('More restaurants'),
              ),
              InputChip(
                label: const Text('Less walking'),
                onPressed: () => setState(() {
                  if (_improvements.contains('Less walking')) {
                    _improvements.remove('Less walking');
                  } else {
                    _improvements.add('Less walking');
                  }
                }),
                selected: _improvements.contains('Less walking'),
              ),
              InputChip(
                label: const Text('More nightlife'),
                onPressed: () => setState(() {
                  if (_improvements.contains('More nightlife')) {
                    _improvements.remove('More nightlife');
                  } else {
                    _improvements.add('More nightlife');
                  }
                }),
                selected: _improvements.contains('More nightlife'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Feedback'),
            ),
          ),
        ],
      ),
    );
  }
}
