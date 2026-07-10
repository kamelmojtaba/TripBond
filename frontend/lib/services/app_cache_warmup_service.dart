import '../core/api_config.dart';
import '../core/api_service.dart';
import 'city_service.dart';
import 'poi_service.dart';

class AppCacheWarmupService {
  static final AppCacheWarmupService _instance =
      AppCacheWarmupService._internal();
  factory AppCacheWarmupService() => _instance;
  AppCacheWarmupService._internal();

  final _api = ApiService();
  final _cityService = CityService();
  final _poiService = POIService();

  Future<void>? _inFlight;

  Future<void> warmDestinationData({bool forceRefresh = false}) {
    if (!forceRefresh && _inFlight != null) return _inFlight!;

    _inFlight = _warmDestinationData().whenComplete(() {
      _inFlight = null;
    });
    return _inFlight!;
  }

  Future<void> _warmDestinationData() async {
    try {
      final response = await _api.get(
        '${ApiConfig.placesPath}/bootstrap',
        queryParams: {'places_per_city': '200'},
      );
      if (response is! Map) {
        await _cityService.listCities();
        return;
      }

      final cities = response['cities'];
      if (cities is List) {
        await _cityService.hydrateFromJson(cities);
      }

      final placesByCity = response['places_by_city'];
      if (placesByCity is Map) {
        for (final entry in placesByCity.entries) {
          final city = entry.key.toString();
          final places = entry.value;
          if (places is List) {
            await _poiService.hydrateCityPlacesFromJson(city, places);
          }
        }
      }
    } catch (_) {
      // If bootstrap fails, keep the app usable by at least warming city cache.
      try {
        await _cityService.listCities();
      } catch (_) {}
    }
  }
}
