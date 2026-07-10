from app.services import place_image_assets


def test_lookup_bundled_asset_for_dammam_corniche():
    asset = place_image_assets.lookup_bundled_asset("Dammam Corniche", "Dammam")
    assert asset == "assets/images/places/dammam_corniche.jpg"


def test_lookup_bundled_asset_for_jeddah_fountain():
    asset = place_image_assets.lookup_bundled_asset("King Fahd Fountain", "Jeddah")
    assert asset == "assets/images/places/king_fahd_fountain.jpg"


def test_lookup_returns_none_for_non_priority_city():
    assert place_image_assets.lookup_bundled_asset("Some Place", "Abha") is None


def test_lookup_uses_city_default_for_arabic_only_names():
    asset = place_image_assets.lookup_bundled_asset("سينما العرب", "Jeddah")
    assert asset == "assets/images/cities/jeddah.png"


def test_apply_bundled_images_sets_gallery():
    place = {"name": "Marina Mall Dammam", "city": "Dammam", "images": []}
    merged = place_image_assets.apply_bundled_images(place)
    assert merged["image_asset"] == "assets/images/places/marina_mall_dammam.jpg"
    assert merged["image_url"] == merged["image_asset"]
    assert merged["images"][0]["source"] == "bundled"


def test_apply_bundled_images_skips_when_google_image_exists():
    place = {
        "name": "Marina Mall Dammam",
        "city": "Dammam",
        "image_url": "https://example.com/photo.jpg",
    }
    merged = place_image_assets.apply_bundled_images(place)
    assert "image_asset" not in merged
    assert merged["image_url"] == "https://example.com/photo.jpg"
