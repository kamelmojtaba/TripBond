/// Place model representing location data from the Geoapify Places API
class PlaceGeometry {
  final double lat;
  final double lng;

  PlaceGeometry({required this.lat, required this.lng});

  factory PlaceGeometry.fromJson(Map<String, dynamic> json) {
    return PlaceGeometry(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
      };
}

class PlacePhoto {
  final String photoReference;
  final int height;
  final int width;
  final List<String> htmlAttributions;
  final String? imageUrl;

  PlacePhoto({
    required this.photoReference,
    required this.height,
    required this.width,
    this.htmlAttributions = const [],
    this.imageUrl,
  });

  factory PlacePhoto.fromJson(Map<String, dynamic> json) {
    return PlacePhoto(
      photoReference: json['photo_reference'] ?? '',
      height: json['height'] ?? 0,
      width: json['width'] ?? 0,
      htmlAttributions: (json['html_attributions'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'photo_reference': photoReference,
        'height': height,
        'width': width,
        'html_attributions': htmlAttributions,
        'image_url': imageUrl,
      };
}

class CachedPlaceImage {
  final String url;
  final int? height;
  final int? width;
  final String source;
  final List<String> attributions;
  final String? expiresAt;
  final int sortOrder;

  CachedPlaceImage({
    required this.url,
    this.height,
    this.width,
    this.source = 'google_places',
    this.attributions = const [],
    this.expiresAt,
    this.sortOrder = 0,
  });

  factory CachedPlaceImage.fromJson(Map<String, dynamic> json) {
    return CachedPlaceImage(
      url: (json['url'] ?? '').toString(),
      height: (json['height'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      source: (json['source'] ?? 'google_places').toString(),
      attributions: (json['attributions'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
      expiresAt: json['expires_at']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'height': height,
        'width': width,
        'source': source,
        'attributions': attributions,
        'expires_at': expiresAt,
        'sort_order': sortOrder,
      };
}

class PlaceOpeningHours {
  final bool? openNow;

  PlaceOpeningHours({this.openNow});

  factory PlaceOpeningHours.fromJson(Map<String, dynamic> json) {
    return PlaceOpeningHours(
      openNow: json['open_now'],
    );
  }

  Map<String, dynamic> toJson() => {
        'open_now': openNow,
      };
}

class PlaceResult {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final String? vicinity;
  final PlaceGeometry? geometry;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final List<String> types;
  final PlaceOpeningHours? openingHours;
  final List<PlacePhoto> photos;
  final List<CachedPlaceImage> images;
  final String? imageUrl;
  final String? icon;
  final String? businessStatus;

  PlaceResult({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    this.vicinity,
    this.geometry,
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.types = const [],
    this.openingHours,
    this.photos = const [],
    this.images = const [],
    this.imageUrl,
    this.icon,
    this.businessStatus,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'],
      vicinity: json['vicinity'],
      geometry: json['geometry'] != null
          ? PlaceGeometry.fromJson(json['geometry'])
          : null,
      rating:
          json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      userRatingsTotal: json['user_ratings_total'],
      priceLevel: json['price_level'],
      types: List<String>.from(json['types'] ?? []),
      openingHours: json['opening_hours'] != null
          ? PlaceOpeningHours.fromJson(json['opening_hours'])
          : null,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((p) => PlacePhoto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((p) => CachedPlaceImage.fromJson(p as Map<String, dynamic>))
              .where((image) => image.url.isNotEmpty)
              .toList() ??
          [],
      imageUrl: json['image_url'],
      icon: json['icon'],
      businessStatus: json['business_status'],
    );
  }

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'name': name,
        'formatted_address': formattedAddress,
        'vicinity': vicinity,
        'geometry': geometry?.toJson(),
        'rating': rating,
        'user_ratings_total': userRatingsTotal,
        'price_level': priceLevel,
        'types': types,
        'opening_hours': openingHours?.toJson(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'images': images.map((p) => p.toJson()).toList(),
        'image_url': imageUrl,
        'icon': icon,
        'business_status': businessStatus,
      };
}

class PlacesSearchResponse {
  final List<PlaceResult> results;
  final String? nextPageToken;
  final String status;

  PlacesSearchResponse({
    required this.results,
    this.nextPageToken,
    required this.status,
  });

  factory PlacesSearchResponse.fromJson(Map<String, dynamic> json) {
    return PlacesSearchResponse(
      results: (json['results'] as List<dynamic>?)
              ?.map((r) => PlaceResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      nextPageToken: json['next_page_token'],
      status: json['status'] ?? 'OK',
    );
  }

  Map<String, dynamic> toJson() => {
        'results': results.map((r) => r.toJson()).toList(),
        'next_page_token': nextPageToken,
        'status': status,
      };
}

class PlaceDetailsResult {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final String? formattedPhoneNumber;
  final String? internationalPhoneNumber;
  final String? website;
  final PlaceGeometry? geometry;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final List<String> types;
  final dynamic openingHours;
  final List<PlacePhoto> photos;
  final List<CachedPlaceImage> images;
  final String? imageUrl;
  final String? url;
  final String? editorialSummary;

  PlaceDetailsResult({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    this.formattedPhoneNumber,
    this.internationalPhoneNumber,
    this.website,
    this.geometry,
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.types = const [],
    this.openingHours,
    this.photos = const [],
    this.images = const [],
    this.imageUrl,
    this.url,
    this.editorialSummary,
  });

  factory PlaceDetailsResult.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsResult(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'],
      formattedPhoneNumber: json['formatted_phone_number'],
      internationalPhoneNumber: json['international_phone_number'],
      website: json['website'],
      geometry: json['geometry'] != null
          ? PlaceGeometry.fromJson(json['geometry'])
          : null,
      rating:
          json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      userRatingsTotal: json['user_ratings_total'],
      priceLevel: json['price_level'],
      types: List<String>.from(json['types'] ?? []),
      openingHours: json['opening_hours'],
      photos: (json['photos'] as List<dynamic>?)
              ?.map((p) => PlacePhoto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((p) => CachedPlaceImage.fromJson(p as Map<String, dynamic>))
              .where((image) => image.url.isNotEmpty)
              .toList() ??
          [],
      imageUrl: json['image_url'],
      url: json['url'],
      editorialSummary: json['editorial_summary'],
    );
  }

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'name': name,
        'formatted_address': formattedAddress,
        'formatted_phone_number': formattedPhoneNumber,
        'international_phone_number': internationalPhoneNumber,
        'website': website,
        'geometry': geometry?.toJson(),
        'rating': rating,
        'user_ratings_total': userRatingsTotal,
        'price_level': priceLevel,
        'types': types,
        'opening_hours': openingHours,
        'photos': photos.map((p) => p.toJson()).toList(),
        'images': images.map((p) => p.toJson()).toList(),
        'image_url': imageUrl,
        'url': url,
        'editorial_summary': editorialSummary,
      };
}

class PlaceDetailsResponse {
  final PlaceDetailsResult result;
  final String status;

  PlaceDetailsResponse({required this.result, required this.status});

  factory PlaceDetailsResponse.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsResponse(
      result: PlaceDetailsResult.fromJson(json['result']),
      status: json['status'] ?? 'OK',
    );
  }

  Map<String, dynamic> toJson() => {
        'result': result.toJson(),
        'status': status,
      };
}
