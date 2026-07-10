import 'package:flutter_test/flutter_test.dart';
import 'package:tripbond_app/widgets/place_image_carousel.dart';

void main() {
  test('placeImagesFromMap prefers ordered gallery and keeps fallback image', () {
    final images = placeImagesFromMap({
      'image_url': 'https://example.com/fallback.jpg',
      'images': [
        {
          'url': 'https://example.com/first.jpg',
          'attributions': ['<a href="https://example.com">Author</a>'],
        },
        {
          'url': 'https://example.com/second.jpg',
          'attributions': ['Second'],
        },
      ],
    });

    expect(images, hasLength(3));
    expect(images[0].url, 'https://example.com/first.jpg');
    expect(images[1].url, 'https://example.com/second.jpg');
    expect(images[2].url, 'https://example.com/fallback.jpg');
    expect(cleanPlaceAttribution(images[0].attributions.first), 'Author');
  });

  test('placeImagesFromMap handles a single legacy image url', () {
    final images = placeImagesFromMap({
      'image_url': 'https://example.com/legacy.jpg',
    });

    expect(images, hasLength(1));
    expect(images.single.url, 'https://example.com/legacy.jpg');
  });

  test('placeImagesFromMap includes bundled image_asset', () {
    final images = placeImagesFromMap({
      'image_asset': 'assets/images/places/dammam_corniche.jpg',
    });

    expect(images, hasLength(1));
    expect(images.single.url, 'assets/images/places/dammam_corniche.jpg');
    expect(isBundledPlaceImageUrl(images.single.url), isTrue);
  });
}
