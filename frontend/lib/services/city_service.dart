import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/api_service.dart';

class CityInfo {
  final String name;
  final String province;
  final String country;
  final int count;
  final double? lat;
  final double? lng;
  final String? imageAsset;
  final String? imageUrl;
  final List<Map<String, dynamic>> images;
  final String? description;
  final String? googleMapsUrl;
  final List<dynamic> photoAttributions;
  final bool isFeatured;

  const CityInfo({
    required this.name,
    required this.province,
    required this.country,
    required this.count,
    required this.lat,
    required this.lng,
    required this.imageAsset,
    required this.imageUrl,
    this.images = const [],
    this.description,
    this.googleMapsUrl,
    this.photoAttributions = const [],
    required this.isFeatured,
  });

  factory CityInfo.fromJson(Map<String, dynamic> json) {
    return CityInfo(
      name: (json['name'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      imageAsset: (json['image_asset'] is String &&
              (json['image_asset'] as String).isNotEmpty)
          ? json['image_asset'] as String
          : null,
      imageUrl: (json['image_url'] is String &&
              (json['image_url'] as String).isNotEmpty)
          ? json['image_url'] as String
          : null,
      images: (json['images'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
      description: json['description']?.toString(),
      googleMapsUrl: (json['google_maps_url'] ?? json['url'])?.toString(),
      photoAttributions:
          json['photo_attributions'] as List<dynamic>? ?? const [],
      isFeatured: json['is_featured'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'province': province,
        'country': country,
        'count': count,
        'lat': lat,
        'lng': lng,
        'image_asset': imageAsset,
        'image_url': imageUrl,
        'images': images,
        'description': description,
        'google_maps_url': googleMapsUrl,
        'photo_attributions': photoAttributions,
        'is_featured': isFeatured,
      };
}

class CityService {
  static final CityService _instance = CityService._internal();
  factory CityService() => _instance;
  CityService._internal();

  static const _cacheKey = 'tripbond.destination_cities.v1';
  static const _cacheTimestampKey = 'tripbond.destination_cities.cached_at.v1';

  final _api = ApiService();
  List<CityInfo>? _cache;
  Future<List<CityInfo>>? _inFlight;

  List<CityInfo>? get cachedCities => _cache;

  Future<List<CityInfo>> listCities({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    if (!forceRefresh) {
      final cached = await _readDiskCache();
      if (cached != null) {
        _cache = cached;
        _refreshFromNetworkInBackground();
        return cached;
      }
      if (_inFlight != null) return _inFlight!;
    }

    _inFlight = _fetchCitiesFromNetwork();
    try {
      return await _inFlight!;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> hydrateFromJson(List<dynamic> jsonList) async {
    final cities = jsonList
        .whereType<Map<String, dynamic>>()
        .map(CityInfo.fromJson)
        .toList();
    _cache = cities;
    await _writeDiskCache(cities);
  }

  Future<List<CityInfo>> _fetchCitiesFromNetwork() async {
    final response = await _api.get('${ApiConfig.placesPath}/cities');
    final cities = _parseCities(response);
    _cache = cities;
    await _writeDiskCache(cities);
    return cities;
  }

  List<CityInfo> _parseCities(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(CityInfo.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<CityInfo>?> _readDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CityInfo.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(List<CityInfo> cities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(cities.map((city) => city.toJson()).toList()),
      );
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Cache writes should never block destination loading.
    }
  }

  void _refreshFromNetworkInBackground() {
    if (_inFlight != null) return;
    _inFlight = _fetchCitiesFromNetwork();
    _inFlight!.catchError((_) => _cache ?? <CityInfo>[]).whenComplete(() {
      _inFlight = null;
    });
  }
}
