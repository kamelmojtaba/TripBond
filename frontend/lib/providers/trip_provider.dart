import 'package:flutter/foundation.dart';
import '../services/trip_service.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();

  List<Map<String, dynamic>> _myTrips = [];
  Map<String, dynamic>? _currentTrip;
  List<Map<String, dynamic>> _tripMembers = [];
  Map<String, dynamic>? _currentItinerary;
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get myTrips => _myTrips;
  Map<String, dynamic>? get currentTrip => _currentTrip;
  List<Map<String, dynamic>> get tripMembers => _tripMembers;
  Map<String, dynamic>? get currentItinerary => _currentItinerary;
  List<Map<String, dynamic>> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch my trips
  Future<void> fetchMyTrips() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myTrips = await _tripService.getMyTrips();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new trip
  Future<bool> createTrip(Map<String, dynamic> tripData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newTrip = await _tripService.createTrip(tripData);
      _myTrips.insert(0, newTrip);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get trip details
  Future<void> fetchTripDetails(String tripId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentTrip = await _tripService.getTripDetails(tripId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update trip
  Future<bool> updateTrip(String tripId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedTrip = await _tripService.updateTrip(tripId, updates);
      _currentTrip = updatedTrip;

      // Update in my trips list
      final index = _myTrips.indexWhere((trip) => trip['id'] == tripId);
      if (index != -1) {
        _myTrips[index] = updatedTrip;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete trip
  Future<bool> deleteTrip(String tripId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _tripService.deleteTrip(tripId);
      _myTrips.removeWhere((trip) => trip['id'] == tripId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch trip members
  Future<void> fetchTripMembers(String tripId) async {
    try {
      _tripMembers = await _tripService.getTripMembers(tripId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Add trip member
  Future<bool> addTripMember(String tripId, String userId) async {
    try {
      await _tripService.addTripMember(tripId, userId);
      await fetchTripMembers(tripId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Generate itinerary
  Future<bool> generateItinerary(
      String tripId, Map<String, dynamic> preferences) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentItinerary =
          await _tripService.generateItinerary(tripId, preferences);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get latest itinerary
  Future<void> fetchLatestItinerary(String tripId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentItinerary = await _tripService.getLatestItinerary(tripId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get recommendations
  Future<void> fetchRecommendations(String tripId) async {
    try {
      _recommendations = await _tripService.getRecommendations(tripId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all data (on logout)
  void clearData() {
    _myTrips = [];
    _currentTrip = null;
    _tripMembers = [];
    _currentItinerary = null;
    _recommendations = [];
    _errorMessage = null;
    notifyListeners();
  }
}
