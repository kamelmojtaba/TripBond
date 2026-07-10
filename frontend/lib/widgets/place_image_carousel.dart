import 'dart:async';

import 'package:flutter/material.dart';

const String kPlaceImageLogoAsset = 'assets/images/icons/logo.png';

bool isBundledPlaceImageUrl(String url) {
  return url.startsWith('assets/');
}

class PlaceImageData {
  final String url;
  final List<String> attributions;

  const PlaceImageData({
    required this.url,
    this.attributions = const [],
  });

  factory PlaceImageData.fromJson(Map<String, dynamic> json) {
    return PlaceImageData(
      url: (json['url'] ?? json['image_url'] ?? '').toString(),
      attributions: (json['attributions'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

List<PlaceImageData> placeImagesFromMap(Map<String, dynamic> place) {
  final images = <PlaceImageData>[];
  final imageAsset = (place['image_asset'] ?? '').toString();
  if (imageAsset.isNotEmpty) {
    images.add(PlaceImageData(url: imageAsset));
  }
  final rawImages = place['images'];
  if (rawImages is List) {
    for (final raw in rawImages) {
      if (raw is Map<String, dynamic>) {
        final image = PlaceImageData.fromJson(raw);
        if (image.url.isNotEmpty) images.add(image);
      } else if (raw is Map) {
        final image = PlaceImageData.fromJson(Map<String, dynamic>.from(raw));
        if (image.url.isNotEmpty) images.add(image);
      } else if (raw is String && raw.isNotEmpty) {
        images.add(PlaceImageData(url: raw));
      }
    }
  }

  final fallback =
      (place['image_url'] ?? place['photo_url'] ?? place['photo'] ?? '')
          .toString();
  if (fallback.isNotEmpty && !images.any((image) => image.url == fallback)) {
    images.add(PlaceImageData(url: fallback));
  }
  return images;
}

Widget buildPlaceImage({
  required String url,
  required BoxFit fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  if (isBundledPlaceImageUrl(url)) {
    return Image.asset(
      url,
      fit: fit,
      errorBuilder: errorBuilder ??
          (_, __, ___) => Image.asset(
                kPlaceImageLogoAsset,
                fit: fit,
              ),
    );
  }
  return Image.network(
    url,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

Widget buildPlaceImagePlaceholder({
  double iconSize = 48,
  Color backgroundColor = const Color(0xFFF3F4F6),
}) {
  return Container(
    color: backgroundColor,
    alignment: Alignment.center,
    child: Image.asset(
      kPlaceImageLogoAsset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
    ),
  );
}

String cleanPlaceAttribution(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

class PlaceImageCarousel extends StatefulWidget {
  final List<PlaceImageData> images;
  final double height;
  final BorderRadius borderRadius;
  final bool autoPlay;
  final bool showAttribution;
  final IconData placeholderIcon;

  const PlaceImageCarousel({
    super.key,
    required this.images,
    required this.height,
    this.borderRadius = BorderRadius.zero,
    this.autoPlay = false,
    this.showAttribution = true,
    this.placeholderIcon = Icons.location_on,
  });

  @override
  State<PlaceImageCarousel> createState() => _PlaceImageCarouselState();
}

class _PlaceImageCarouselState extends State<PlaceImageCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PlaceImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length ||
        oldWidget.autoPlay != widget.autoPlay) {
      _timer?.cancel();
      if (_index >= widget.images.length) {
        _index = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.hasClients) {
            _controller.jumpToPage(0);
          }
        });
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!widget.autoPlay || widget.images.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.images.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _goToPage(int page) {
    if (!_controller.hasClients || widget.images.length < 2) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goToPrevious() {
    final previous = (_index - 1 + widget.images.length) % widget.images.length;
    _goToPage(previous);
  }

  void _goToNext() {
    final next = (_index + 1) % widget.images.length;
    _goToPage(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: buildPlaceImagePlaceholder(iconSize: 56),
        ),
      );
    }

    final current = widget.images[_index.clamp(0, widget.images.length - 1)];
    final attribution = current.attributions
        .map(cleanPlaceAttribution)
        .where((value) => value.isNotEmpty)
        .join(', ');

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                return buildPlaceImage(
                  url: widget.images[index].url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => buildPlaceImagePlaceholder(),
                );
              },
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.35),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CarouselArrowButton(
                    icon: Icons.chevron_left,
                    label: 'Previous image',
                    height: widget.height,
                    onPressed: _goToPrevious,
                  ),
                ),
              ),
            if (widget.images.length > 1)
              Positioned(
                right: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CarouselArrowButton(
                    icon: Icons.chevron_right,
                    label: 'Next image',
                    height: widget.height,
                    onPressed: _goToNext,
                  ),
                ),
              ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (index) {
                    final active = index == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: active ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ),
              ),
            if (widget.showAttribution)
              Positioned(
                left: 8,
                right: 8,
                bottom: widget.images.length > 1 ? 22 : 8,
                child: Text(
                  isBundledPlaceImageUrl(current.url)
                      ? 'TripBond'
                      : attribution.isEmpty
                          ? 'Google Maps'
                          : 'Google Maps: $attribution',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double height;
  final VoidCallback onPressed;

  const _CarouselArrowButton({
    required this.icon,
    required this.label,
    required this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = height <= 70
        ? 22.0
        : height < 90
            ? 26.0
            : 36.0;
    final iconSize = height <= 70
        ? 16.0
        : height < 90
            ? 18.0
            : 24.0;

    return Material(
      color: Colors.black.withOpacity(0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Semantics(
          button: true,
          label: label,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
