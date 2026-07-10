import 'package:flutter/material.dart';

import '../models/place_model.dart';
import '../screens/place_details_page.dart';
import '../widgets/place_preview_sheet.dart';

/// Normalized place data for previews and detail navigation.
class PlacePreviewData {
  final String name;
  final String location;
  final double? rating;
  final String? startTime;
  final String? endTime;
  final String? notes;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> sourceMap;

  const PlacePreviewData({
    required this.name,
    this.location = '',
    this.rating,
    this.startTime,
    this.endTime,
    this.notes,
    this.placeId,
    this.latitude,
    this.longitude,
    this.sourceMap = const {},
  });

  static String textFromMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String? idFromMap(Map<String, dynamic> map) {
    for (final key in [
      'external_place_id',
      'place_id',
      'poi_id',
      'fsq_id',
      'id',
    ]) {
      final value = map[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static double? latFromMap(Map<String, dynamic> map) {
    for (final key in ['latitude', 'lat']) {
      final value = map[key];
      if (value is num && value != 0) return value.toDouble();
    }
    return null;
  }

  static double? lngFromMap(Map<String, dynamic> map) {
    for (final key in ['longitude', 'lng', 'lon']) {
      final value = map[key];
      if (value is num && value != 0) return value.toDouble();
    }
    return null;
  }

  static double? ratingFromMap(Map<String, dynamic> map) {
    final value = map['rating'] ?? map['score'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  factory PlacePreviewData.fromMap(
    Map<String, dynamic> map, {
    String? fallbackLocation,
  }) {
    final start = textFromMap(map, ['start_time']);
    final end = textFromMap(map, ['end_time']);
    final notes = textFromMap(map, ['notes', 'category', 'ai_reason']);

    return PlacePreviewData(
      name: textFromMap(map, ['name', 'title']).isEmpty
          ? 'Place'
          : textFromMap(map, ['name', 'title']),
      location: textFromMap(map, [
        'address',
        'location',
        'formatted_address',
        'vicinity',
      ]).isEmpty
          ? (fallbackLocation ?? '')
          : textFromMap(map, [
              'address',
              'location',
              'formatted_address',
              'vicinity',
            ]),
      rating: ratingFromMap(map),
      startTime: start.isEmpty ? null : start,
      endTime: end.isEmpty ? null : end,
      notes: notes.isEmpty ? null : notes,
      placeId: idFromMap(map),
      latitude: latFromMap(map),
      longitude: lngFromMap(map),
      sourceMap: Map<String, dynamic>.from(map),
    );
  }

  factory PlacePreviewData.fromPlaceResult(PlaceResult place) {
    return PlacePreviewData(
      name: place.name,
      location: place.formattedAddress ?? place.vicinity ?? '',
      rating: place.rating,
      placeId: place.placeId.isEmpty ? null : place.placeId,
      latitude: place.geometry?.lat,
      longitude: place.geometry?.lng,
      sourceMap: {
        'name': place.name,
        'place_id': place.placeId,
        'formatted_address': place.formattedAddress,
        'latitude': place.geometry?.lat,
        'longitude': place.geometry?.lng,
        'rating': place.rating,
        'images': place.images.map((image) => image.toJson()).toList(),
        'image_url': place.imageUrl,
      },
    );
  }
}

Future<void> openPlacePreview(
  BuildContext context, {
  required PlacePreviewData data,
  String? tripId,
  List<Widget>? extraActions,
}) {
  return showPlacePreviewSheet(
    context,
    data: data,
    tripId: tripId,
    extraActions: extraActions,
    onViewFullDetails: () {
      Navigator.pop(context);
      openPlaceDetailsPage(
        context,
        data: data,
        tripId: tripId,
      );
    },
  );
}

Future<void> openPlacePreviewFromMap(
  BuildContext context,
  Map<String, dynamic> map, {
  String? tripId,
  String? fallbackLocation,
  List<Widget>? extraActions,
}) {
  return openPlacePreview(
    context,
    data: PlacePreviewData.fromMap(map, fallbackLocation: fallbackLocation),
    tripId: tripId,
    extraActions: extraActions,
  );
}

Future<void> openPlacePreviewFromResult(
  BuildContext context,
  PlaceResult place, {
  String? tripId,
  List<Widget>? extraActions,
}) {
  return openPlacePreview(
    context,
    data: PlacePreviewData.fromPlaceResult(place),
    tripId: tripId,
    extraActions: extraActions,
  );
}

void openPlaceDetailsPage(
  BuildContext context, {
  required PlacePreviewData data,
  String? tripId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlaceDetailsPage(
        placeId: data.placeId,
        latitude: data.latitude,
        longitude: data.longitude,
        name: data.name,
        tripId: tripId,
      ),
    ),
  );
}

/// Tappable place name styled as a link.
class PlaceNameLink extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color linkColor;

  const PlaceNameLink({
    super.key,
    required this.name,
    required this.onTap,
    this.style,
    this.maxLines,
    this.overflow,
    this.linkColor = const Color(0xFF4675B8),
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        name,
        maxLines: maxLines,
        overflow: overflow,
        style: baseStyle.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
