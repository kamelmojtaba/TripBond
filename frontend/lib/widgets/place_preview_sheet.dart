import 'package:flutter/material.dart';

import '../utils/place_navigation.dart';
import 'place_image_carousel.dart';

Future<void> showPlacePreviewSheet(
  BuildContext context, {
  required PlacePreviewData data,
  String? tripId,
  List<Widget>? extraActions,
  VoidCallback? onViewFullDetails,
}) {
  final images = placeImagesFromMap(data.sourceMap);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final timeRange = _formatTimeRange(data.startTime, data.endTime);

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      data.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PlaceImageCarousel(
                    images: images,
                    height: 160,
                    showAttribution: images.isNotEmpty,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (data.location.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.location,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              if (data.rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFC8A858)),
                    const SizedBox(width: 6),
                    Text(
                      '${data.rating!.toStringAsFixed(1)} rating',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
              if (timeRange != null) ...[
                const SizedBox(height: 8),
                Text(
                  timeRange,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
              if (data.notes != null && data.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  data.notes!,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onViewFullDetails,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View full details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4675B8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (extraActions != null) ...[
                const SizedBox(height: 10),
                ...extraActions,
              ],
            ],
          ),
        ),
      );
    },
  );
}

String? _formatTimeRange(String? start, String? end) {
  if (start == null || start.isEmpty) return null;
  if (end == null || end.isEmpty) return start;
  return '$start - $end';
}
