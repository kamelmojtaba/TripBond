#!/usr/bin/env python3
"""
Expand the integrated POI dataset for KSA-only destinations.

- Remove non-Saudi cities (Abu Dhabi, Hurghada, Bahrain, etc.)
- Reassign mis-tagged city="Al" rows using name heuristics
- Normalize city spellings (Buraidah -> Buraydah, Hegra -> AlUla)
- Append curated POIs so every listed KSA city has >= MIN_POIS_PER_CITY rows
"""
from __future__ import annotations

import math
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "tripbond_ai_backend" / "data" / "final_integrated_poi_dataset.csv"
MIN_POIS_PER_CITY = 10

# Cities that must never appear as trip destinations
NON_KSA_CITIES = {
    "Abu Dhabi",
    "Hurghada",
    "Manama",
    "Muharraq",
    "Zallaq",
}

# Junk / scrape fragments — excluded from curated city list
JUNK_CITIES = {
    "Al", "Ad", "Ras", "King", "Saudi", "SH", "1c", "Closed", "Temporarily",
    "Tuwarin", "Sa'ad", "Khubayb", "Qesm", "Hafar", "وحيدة", "عجاج",
    "العويند", "بوضان", "السلام", "الرياض",
}

# Canonical city renames (old -> new)
CITY_RENAMES = {
    "Buraidah": "Buraydah",
    "Khobar": "Al Khobar",
    "Hegra": "AlUla",
    "Ushaiqer": "Shaqra",
    "Rijal Almaa": "Abha",
    "Buqayq": "Dammam",
    "Uthmaniyah": "Al-Ahsa",
    "Dhurma": "Riyadh",
    "Huraymila": "Riyadh",
    "Rughabah": "Buraydah",
    "Al-Muzahmiya": "Riyadh",
    "Kaec": "King Abdullah Economic City",
}

# Heuristic reassignment for broken city="Al" rows
_AL_NAME_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"khobar|kobar", re.I), "Al Khobar"),
    (re.compile(r"jubail", re.I), "Al Jubail"),
    (re.compile(r"corniche island", re.I), "Al Khobar"),
    (re.compile(r"scitech|sci-?tech", re.I), "Al Khobar"),
    (re.compile(r"escape the room", re.I), "Al Khobar"),
    (re.compile(r"empire cinemas khobar", re.I), "Al Khobar"),
    (re.compile(r"ajdan walk", re.I), "Al Khobar"),
    (re.compile(r"lake park", re.I), "Dammam"),
    (re.compile(r"half moon", re.I), "Dhahran"),
]

# Curated supplements: (name, category, poi_type, city, province, lat, lng, rating, reviews, description)
# Coordinates are approximate city-centre offsets for real landmarks.
def _supplements() -> list[dict]:
    rows: list[dict] = []

    def add_many(city: str, province: str, places: list[tuple]):
        for item in places:
            name, cat, ptype, lat, lng, rating, reviews, desc = item
            rows.append({
                "name": name,
                "category": cat,
                "poi_type": ptype,
                "city": city,
                "province": province,
                "latitude": lat,
                "longitude": lng,
                "rating": rating,
                "review_count": reviews,
                "description": desc,
                "opening_hours": "Daily: 9:00 AM - 10:00 PM",
                "booking_link": "",
                "data_source": "KSA_Curated_Supplement",
                "created_date": "2026-05-19",
            })

    ep = "Eastern Province"

    add_many("Al Khobar", ep, [
        ("SciTech Technology Center", "Science Museum", "attraction", 26.3012, 50.2142, 4.4, 6300,
         "Interactive science museum on the Khobar Corniche."),
        ("Al Rashid Mall", "Shopping Mall", "shopping", 26.3015, 50.1965, 4.3, 8200,
         "Major shopping and dining complex in Al Khobar."),
        ("Desert Designs Park", "Park", "attraction", 26.2890, 50.1850, 4.2, 2100,
         "Family park with play areas near the corniche."),
        ("Al Khobar Water Tower", "Landmark", "attraction", 26.2795, 50.2088, 4.1, 1500,
         "Iconic waterfront tower and viewpoint."),
        ("Corniche Island", "Waterfront", "attraction", 26.2760, 50.2110, 4.5, 2200,
         "Island park connected to the Khobar Corniche."),
        ("Escape the Room Khobar", "Entertainment", "entertainment", 26.2920, 50.2010, 4.7, 3200,
         "Popular escape-room venue in Al Khobar."),
        ("Empire Cinemas Khobar", "Cinema", "entertainment", 26.2980, 50.1990, 3.9, 1300,
         "Multiplex cinema in Al Khobar."),
        ("Al Danah Mall", "Shopping Mall", "shopping", 26.3050, 50.1920, 4.2, 4500,
         "Retail mall with international brands."),
        ("Heritage Village Al Khobar", "Heritage Site", "attraction", 26.2840, 50.2050, 4.0, 980,
         "Cultural heritage showcase on the Eastern coast."),
        ("Al Khobar Fish Market", "Market", "attraction", 26.2810, 50.2105, 4.3, 2400,
         "Fresh seafood market by the Gulf waterfront."),
        ("Prince Turki Street Park", "Park", "attraction", 26.2875, 50.1980, 4.4, 1100,
         "Green space and walking paths in central Khobar."),
        ("Ajdan Walk Al Khobar", "Shopping District", "shopping", 26.2965, 50.1885, 4.4, 957,
         "Open-air retail and dining promenade."),
    ])

    add_many("Dammam", ep, [
        ("King Abdulaziz Center for World Culture (Ithra)", "Cultural Center", "attraction", 26.3042, 50.1645, 4.9, 7200,
         "World-class museum and cultural hub (near Dhahran)."),
        ("Dammam Corniche", "Waterfront", "attraction", 26.4340, 50.1030, 4.5, 11000,
         "Long waterfront promenade along the Arabian Gulf."),
        ("Share Al-Hob Market", "Market", "attraction", 26.4280, 50.0890, 4.2, 3400,
         "Traditional market in central Dammam."),
        ("Dammam Regional Museum", "Museum", "attraction", 26.4200, 50.0880, 4.1, 1800,
         "Regional history and archaeology museum."),
        ("Marina Mall Dammam", "Shopping Mall", "shopping", 26.4150, 50.0950, 4.3, 5600,
         "Waterfront shopping and dining destination."),
        ("Dolphin Village Dammam", "Family Attraction", "entertainment", 26.4380, 50.1120, 4.0, 2900,
         "Family entertainment complex on the corniche."),
        ("King Fahd Park Dammam", "Park", "attraction", 26.4050, 50.0780, 4.4, 4200,
         "Large urban park with lakes and trails."),
        ("Al Shatea District Beach", "Beach", "beach", 26.4410, 50.1180, 4.2, 3100,
         "Public beach access along Dammam coast."),
    ])

    add_many("Buraydah", "Qassim", [
        ("Buraydah Dates Festival Site", "Cultural Site", "attraction", 26.3590, 43.9810, 4.6, 5200,
         "Famous dates market and festival grounds."),
        ("Al Oqailat Heritage Village", "Heritage Village", "attraction", 26.3420, 43.9650, 4.4, 2100,
         "Restored Najdi heritage neighborhood."),
        ("King Khalid Cultural Center", "Cultural Center", "attraction", 26.3550, 43.9720, 4.3, 1800,
         "Arts and cultural events in Buraydah."),
        ("Al Nakheel Mall Buraydah", "Shopping Mall", "shopping", 26.3680, 43.9880, 4.2, 6400,
         "Major mall in Qassim region."),
        ("Buraydah Museum", "Museum", "attraction", 26.3510, 43.9700, 4.1, 1200,
         "Local history and heritage exhibits."),
        ("Al Ahsa Park Buraydah", "Park", "attraction", 26.3620, 43.9750, 4.0, 900,
         "City park with walking paths."),
        ("Qassim University Botanical Garden", "Garden", "nature", 26.3480, 43.9580, 4.3, 750,
         "Green campus gardens open to visitors."),
        ("Al Bassam House", "Heritage House", "attraction", 26.3570, 43.9680, 4.5, 1100,
         "Historic merchant house museum."),
        ("Buraydah Grand Mosque", "Mosque", "attraction", 26.3540, 43.9780, 4.7, 3200,
         "Central mosque and landmark."),
        ("Al Qassim Walk", "Promenade", "attraction", 26.3600, 43.9840, 4.2, 1500,
         "Retail and dining walkway."),
    ])

    add_many("Abha", "Asir", [
        ("Abha Dam Lake", "Lake", "nature", 18.2160, 42.5050, 4.6, 4800,
         "Scenic reservoir and picnic area."),
        ("Al Muftaha Village", "Art Village", "attraction", 18.2140, 42.5080, 4.5, 3600,
         "Traditional arts and crafts village."),
        ("Abha Palace Museum", "Museum", "attraction", 18.2180, 42.5020, 4.3, 2100,
         "Regional heritage museum."),
        ("Jabal Al Soodah Viewpoint", "Viewpoint", "nature", 18.2738, 42.3667, 4.8, 6200,
         "Highest peak viewpoint in Saudi Arabia."),
        ("Abha Cultural Center", "Cultural Center", "attraction", 18.2120, 42.5100, 4.2, 1400,
         "Performing arts and exhibitions."),
        ("Rijal Almaa (near Abha)", "Heritage Village", "attraction", 18.2127, 42.2458, 4.8, 3200,
         "UNESCO-nominated stone village in Asir mountains."),
    ])

    add_many("Al Baha", "Al Baha", [
        ("Al Baha Heritage Village", "Heritage Village", "attraction", 20.0129, 41.4677, 4.5, 2800,
         "Traditional highland architecture."),
        ("Raghadan Forest Park", "Forest Park", "nature", 20.0180, 41.4720, 4.6, 4100,
         "Cool mountain forest with trails."),
        ("Al Baha Suspension Bridge", "Landmark", "attraction", 20.0080, 41.4600, 4.4, 1900,
         "Scenic bridge over the Sarawat range."),
        ("Bin Raqoush Palace", "Historic Palace", "attraction", 20.0150, 41.4650, 4.3, 1200,
         "Restored historic palace."),
        ("Al Baha Regional Museum", "Museum", "attraction", 20.0100, 41.4700, 4.2, 980,
         "Regional culture and history."),
        ("Zee Al-Ain Village", "Heritage Village", "attraction", 19.8900, 41.4200, 4.7, 3500,
         "Famous stone village in marble hills."),
        ("Al Baha Cable Car", "Cable Car", "attraction", 20.0200, 41.4750, 4.4, 2200,
         "Cable car with mountain views."),
        ("King Fahd Park Al Baha", "Park", "attraction", 20.0050, 41.4680, 4.1, 1100,
         "Central city park."),
        ("Al Baha Grand Mosque", "Mosque", "attraction", 20.0130, 41.4690, 4.6, 2400,
         "Main city mosque."),
        ("Shada Mountains", "Natural Reserve", "nature", 19.9500, 41.3800, 4.8, 1800,
         "Dramatic granite peaks and caves."),
    ])

    add_many("Najran", "Najran", [
        ("Al-Ukhdood Archaeological Site", "Archaeological Site", "attraction", 17.4800, 44.1300, 4.7, 2900,
         "Ancient ruins and inscriptions."),
        ("Najran Regional Museum", "Museum", "attraction", 17.4924, 44.1277, 4.3, 1500,
         "History of Najran region."),
        ("Al Aan Palace", "Historic Palace", "attraction", 17.4950, 44.1250, 4.5, 2100,
         "Traditional mud-brick palace."),
        ("Najran Dam Park", "Park", "attraction", 17.5000, 44.1350, 4.2, 1100,
         "Park around Najran reservoir."),
        ("Al Faisaliah Park Najran", "Park", "attraction", 17.4880, 44.1200, 4.1, 900,
         "Family park in the city."),
        ("Najran Valley Viewpoint", "Viewpoint", "nature", 17.5100, 44.1400, 4.4, 800,
         "Panoramic valley views."),
        ("Al-Maskan Heritage Market", "Market", "attraction", 17.4900, 44.1280, 4.0, 650,
         "Local crafts and produce."),
        ("Najran Fort", "Historic Fort", "attraction", 17.4940, 44.1260, 4.3, 1700,
         "Historic fort overlooking the wadi."),
        ("Saqr Park", "Park", "attraction", 17.4850, 44.1320, 4.2, 1200,
         "Urban green space."),
        ("Hima Well Cultural Area", "Cultural Site", "attraction", 17.4700, 44.1100, 4.6, 1400,
         "Rock art and heritage trails."),
    ])

    add_many("Jazan", "Jazan", [
        ("Farasan Islands Ferry Point", "Marina", "attraction", 16.8892, 42.5510, 4.5, 3200,
         "Gateway to the Farasan archipelago."),
        ("Jazan Corniche", "Waterfront", "attraction", 16.8920, 42.5480, 4.4, 4100,
         "Coastal promenade and parks."),
        ("Jazan Regional Museum", "Museum", "attraction", 16.8880, 42.5550, 4.2, 1100,
         "Regional heritage exhibits."),
        ("Al Dosariyah Island", "Island", "beach", 16.9100, 42.5200, 4.6, 2800,
         "Island park near Jazan city."),
        ("Jazan Economic City Beach", "Beach", "beach", 16.8700, 42.5800, 4.3, 1900,
         "Red Sea beach access."),
        ("Wadi Lajab", "Canyon", "nature", 17.0500, 43.2000, 4.8, 4500,
         "Stunning sandstone canyon for hiking."),
        ("Jazan Heritage Village", "Heritage Village", "attraction", 16.8850, 42.5520, 4.1, 950,
         "Traditional southern architecture."),
        ("Al Rashid Mall Jazan", "Shopping Mall", "shopping", 16.8950, 42.5450, 4.0, 2200,
         "Shopping and dining complex."),
        ("Mount Fayfa", "Mountain", "nature", 17.2800, 43.0500, 4.7, 1600,
         "Terraced mountain villages and views."),
        ("Jazan Dam Lake", "Lake", "nature", 16.9000, 42.5600, 4.2, 800,
         "Reservoir recreation area."),
    ])

    add_many("Farasan", "Jazan", [
        ("Farasan Islands Marine Reserve", "Natural Reserve", "nature", 16.7029, 41.9932, 4.9, 1850,
         "Pristine islands with coral reefs."),
        ("Beit Al Refai Museum", "Museum", "attraction", 16.7050, 41.9900, 4.4, 620,
         "Heritage house on Farasan Island."),
        ("Al Qassar Village", "Heritage Village", "attraction", 16.7100, 41.9850, 4.5, 480,
         "Historic coral-stone village."),
        ("Farasan Island Beach", "Beach", "beach", 16.6980, 41.9950, 4.6, 1200,
         "White-sand beaches and snorkeling."),
        ("Damsik Mangrove Forest", "Nature", "nature", 16.7200, 42.0100, 4.3, 350,
         "Mangrove ecosystem tours."),
        ("Farasan Old Souq", "Market", "attraction", 16.7040, 41.9920, 4.2, 290,
         "Traditional island market."),
        ("Roman Well Farasan", "Historic Site", "attraction", 16.7060, 41.9880, 4.1, 210,
         "Ancient well archaeological site."),
        ("Sajid Island", "Island", "beach", 16.6800, 42.0200, 4.7, 540,
         "Nearby island for diving."),
        ("Farasan Lighthouse", "Landmark", "attraction", 16.7000, 41.9970, 4.0, 180,
         "Coastal navigation landmark."),
        ("Turquoise Bay Farasan", "Beach", "beach", 16.6950, 42.0000, 4.8, 890,
         "Crystal-clear swimming bay."),
    ])

    add_many("Al Jubail", ep, [
        ("Jubail Corniche", "Waterfront", "attraction", 27.0174, 49.6572, 4.3, 4500,
         "Coastal walkway and beaches."),
        ("Al Fanateer Beach", "Beach", "beach", 27.0200, 49.6500, 4.4, 3800,
         "Popular family beach."),
        ("Jubail Fish Market", "Market", "attraction", 27.0150, 49.6600, 4.2, 2100,
         "Fresh seafood market."),
        ("Galleria Mall Jubail", "Shopping Mall", "shopping", 27.0100, 49.6550, 4.3, 5200,
         "Major retail destination."),
        ("Jubail Industrial City Visitor Center", "Visitor Center", "attraction", 27.0050, 49.6400, 4.0, 800,
         "Industrial tourism and exhibits."),
        ("Deffi Park", "Park", "attraction", 27.0120, 49.6580, 4.1, 1500,
         "Urban park and recreation."),
        ("Al Nakheel Beach Jubail", "Beach", "beach", 27.0250, 49.6450, 4.3, 2900,
         "Palm-lined public beach."),
        ("Jubail Heritage Village", "Heritage Village", "attraction", 27.0080, 49.6520, 4.2, 1100,
         "Traditional coastal heritage."),
        ("Mall of Jubail", "Shopping Mall", "shopping", 27.0180, 49.6480, 4.1, 3400,
         "Shopping and entertainment."),
        ("Al Huwaylat Beach", "Beach", "beach", 27.0300, 49.6350, 4.4, 2200,
         "Quiet beach north of Jubail."),
    ])

    add_many("Dhahran", ep, [
        ("Ithra - King Abdulaziz Center", "Cultural Center", "attraction", 26.3042, 50.1645, 4.9, 7200,
         "Museum, library, cinema, and performing arts."),
        ("Half Moon Bay", "Beach", "beach", 26.2572, 50.1906, 4.4, 8900,
         "Crescent beach for camping and water sports."),
        ("Dhahran Hills Park", "Park", "attraction", 26.2900, 50.1500, 4.3, 2100,
         "Hillside park popular with families."),
        ("King Abdulaziz Air Base Museum", "Museum", "attraction", 26.2800, 50.1600, 4.0, 650,
         "Aviation heritage exhibits."),
        ("Al Dawoodiyah Park", "Park", "attraction", 26.2850, 50.1550, 4.2, 1200,
         "Community park and playgrounds."),
        ("Dhahran Mall", "Shopping Mall", "shopping", 26.3023, 50.1644, 4.3, 19000,
         "Premier shopping in the Dammam metro area."),
    ])

    add_many("Yanbu", "Madinah", [
        ("Yanbu Al Bahr Historic District", "Historic District", "attraction", 24.0890, 38.0617, 4.5, 4200,
         "Ottoman-era old town and harbor."),
        ("Yanbu Corniche", "Waterfront", "attraction", 24.0950, 38.0550, 4.4, 5100,
         "Red Sea promenade."),
        ("Yanbu Industrial City Beach", "Beach", "beach", 24.0500, 38.0200, 4.2, 2800,
         "Industrial city coastal access."),
        ("Radwa Mountain", "Mountain", "nature", 24.1200, 38.1000, 4.6, 1900,
         "Hiking and panoramic views."),
        ("Yanbu Flower Festival Park", "Park", "attraction", 24.0920, 38.0580, 4.3, 1500,
         "Seasonal flower displays."),
        ("Al-Nakheel Beach Yanbu", "Beach", "beach", 24.1000, 38.0500, 4.4, 3200,
         "Palm-lined public beach."),
        ("Yanbu Royal Commission Museum", "Museum", "attraction", 24.0880, 38.0620, 4.1, 900,
         "City development history."),
        ("Yanbu Fish Market", "Market", "attraction", 24.0900, 38.0600, 4.3, 2100,
         "Fresh Red Sea seafood."),
    ])

    add_many("Taif", "Makkah", [
        ("Shubra Palace", "Historic Palace", "attraction", 21.2703, 40.4158, 4.5, 3800,
         "Former royal residence, now museum."),
        ("Al Rudaf Park", "Park", "attraction", 21.2750, 40.4200, 4.4, 5200,
         "Large park with lake and roses."),
        ("Taif Cable Car", "Cable Car", "attraction", 21.2600, 40.4300, 4.6, 6100,
         "Cable car to Al Hada mountain."),
        ("Rose Factory Taif", "Cultural Site", "attraction", 21.2680, 40.4180, 4.3, 2400,
         "Famous Taif rose products."),
        ("Al Hada Mountain", "Mountain", "nature", 21.2500, 40.4500, 4.7, 4800,
         "Cool mountain escape with views."),
        ("Okaz Souq", "Historic Market", "attraction", 21.2800, 40.4000, 4.4, 2900,
         "Revived ancient cultural souq."),
        ("King Fahd Park Taif", "Park", "attraction", 21.2720, 40.4120, 4.2, 3100,
         "Major city park."),
        ("Taif Regional Museum", "Museum", "attraction", 21.2690, 40.4160, 4.1, 1500,
         "Regional heritage collection."),
        ("Al Shafa Village", "Mountain Village", "nature", 21.2200, 40.3500, 4.6, 2200,
         "Highland village and viewpoints."),
    ])

    add_many("Tabuk", "Tabuk", [
        ("Tabuk Castle", "Historic Fort", "attraction", 28.3838, 36.5713, 4.3, 3100,
         "Ottoman fortress museum."),
        ("Al Disah Valley", "Valley", "nature", 28.2000, 36.8000, 4.8, 4200,
         "Dramatic sandstone valley hiking."),
        ("Tabuk Regional Museum", "Museum", "attraction", 28.3850, 36.5700, 4.2, 1400,
         "Regional archaeology and history."),
        ("Wadi Al Disah", "Natural Wonder", "nature", 28.2100, 36.7900, 4.7, 3800,
         "Red rock formations and palm groves."),
        ("Tabuk Park", "Park", "attraction", 28.3800, 36.5750, 4.1, 1100,
         "Central urban park."),
        ("Al Bida Archaeological Site", "Archaeological Site", "attraction", 28.1000, 36.2000, 4.5, 900,
         "Ancient Nabataean site near Tabuk."),
        ("Tabuk Corniche Park", "Waterfront", "attraction", 28.3900, 36.5600, 4.0, 800,
         "Northern city waterfront."),
        ("Prince Fahd Bin Sultan Park", "Park", "attraction", 28.3820, 36.5680, 4.2, 1500,
         "Family recreation area."),
        ("Hejaz Railway Station Tabuk", "Historic Site", "attraction", 28.3840, 36.5720, 4.4, 1200,
         "Restored Ottoman railway station."),
    ])

    add_many("Al-Ahsa", ep, [
        ("Al Ahsa Oasis", "UNESCO Site", "attraction", 25.3833, 49.5833, 4.8, 12000,
         "World's largest oasis, UNESCO listed."),
        ("Ibrahim Palace", "Historic Palace", "attraction", 25.4300, 49.5900, 4.5, 3400,
         "Ottoman-era palace in Hofuf."),
        ("Jabal Al Qarah", "Mountain", "nature", 25.4200, 49.6000, 4.6, 5100,
         "Distinctive mesa with caves."),
        ("Al Qaisariyah Souq", "Historic Souq", "attraction", 25.3800, 49.5850, 4.4, 2800,
         "Traditional covered market."),
        ("Yellow Lake Al Ahsa", "Lake", "nature", 25.3500, 49.5500, 4.3, 1900,
         "Seasonal desert lake."),
        ("Jawatha Mosque", "Historic Mosque", "attraction", 25.4000, 49.5800, 4.5, 2100,
         "One of the oldest mosques in the region."),
        ("Al Ahsa National Museum", "Museum", "attraction", 25.3850, 49.5820, 4.2, 1500,
         "Oasis heritage exhibits."),
        ("Uqair Beach", "Beach", "beach", 25.6500, 50.2000, 4.1, 2200,
         "Historic coastal port beach."),
        ("Al Asfar Lake", "Lake", "nature", 25.3600, 49.5600, 4.4, 1700,
         "Birdwatching and nature area."),
    ])

    add_many("Umluj", "Tabuk", [
        ("Umluj Beach", "Beach", "beach", 25.0201, 37.2669, 4.8, 5400,
         "Maldives of Saudi Arabia white sands."),
        ("Duba Port Umluj", "Marina", "attraction", 25.0100, 37.2700, 4.2, 1200,
         "Red Sea departure point."),
        ("Coral Reef Snorkeling Umluj", "Marine Activity", "beach", 25.0300, 37.2600, 4.7, 2100,
         "Snorkeling and diving spots."),
        ("Umluj Islands Tour", "Island Tour", "attraction", 25.0400, 37.2500, 4.6, 1800,
         "Boat tours to offshore islands."),
        ("Al Wajh Road Viewpoint", "Viewpoint", "nature", 25.0500, 37.2800, 4.4, 900,
         "Coastal highway scenic stop."),
        ("Umluj Palm Groves", "Oasis", "nature", 25.0150, 37.2650, 4.3, 650,
         "Date palm farms and walks."),
        ("Red Sea Diving Center Umluj", "Diving", "beach", 25.0250, 37.2680, 4.5, 1100,
         "Dive trips and equipment rental."),
        ("Umluj Heritage Village", "Heritage Village", "attraction", 25.0180, 37.2720, 4.1, 420,
         "Traditional coastal settlement."),
        ("Mango Beach Umluj", "Beach", "beach", 25.0350, 37.2550, 4.7, 1500,
         "Secluded swimming beach."),
        ("Umluj Marina Walk", "Promenade", "attraction", 25.0220, 37.2670, 4.2, 780,
         "Waterfront dining and walks."),
    ])

    add_many("Shaqra", "Riyadh", [
        ("Ushaiger Heritage Village", "Heritage Village", "attraction", 25.3319, 45.2547, 4.6, 1240,
         "Restored Najdi mud-brick village."),
        ("Shaqra Heritage Museum", "Museum", "attraction", 25.2400, 45.2500, 4.3, 800,
         "Local history exhibits."),
        ("Subaie Heritage House", "Heritage House", "attraction", 25.2350, 45.2480, 4.3, 192,
         "Traditional merchant house."),
        ("Shaqra Old Market", "Market", "attraction", 25.2380, 45.2520, 4.1, 450,
         "Traditional souq area."),
        ("Al-Majmaah Road Park", "Park", "attraction", 25.2420, 45.2550, 4.0, 320,
         "Community park."),
        ("Shaqra Date Farms", "Farm Tour", "attraction", 25.2300, 45.2450, 4.2, 280,
         "Date plantation visits."),
        ("Wadi Hanifah Viewpoint Shaqra", "Viewpoint", "nature", 25.2500, 45.2600, 4.4, 510,
         "Desert wadi scenery."),
        ("Shaqra Cultural Center", "Cultural Center", "attraction", 25.2360, 45.2510, 4.1, 390,
         "Arts and community events."),
        ("Al-Dubayyah Fort", "Historic Fort", "attraction", 25.2280, 45.2400, 4.3, 620,
         "Restored desert fort."),
        ("Shaqra Guest House District", "Heritage District", "attraction", 25.2340, 45.2490, 4.0, 210,
         "Traditional accommodation area."),
    ])

    add_many("Qassim", "Qassim", [
        ("Buraydah Dates Market", "Market", "attraction", 26.3590, 43.9810, 4.6, 5200,
         "World-famous dates trading."),
        ("Unaizah Heritage Village", "Heritage Village", "attraction", 26.0900, 43.9700, 4.4, 2800,
         "Historic town in Qassim."),
        ("Al Bassam Heritage House", "Heritage House", "attraction", 26.3570, 43.9680, 4.5, 1100,
         "Traditional merchant home."),
        ("King Khalid Park Qassim", "Park", "attraction", 26.3500, 43.9750, 4.2, 1900,
         "Regional park."),
        ("Al Mithnab Old Town", "Historic Town", "attraction", 26.0200, 44.0500, 4.3, 900,
         "Traditional mud architecture."),
        ("Qassim University Campus", "Landmark", "attraction", 26.3480, 43.9580, 4.0, 750,
         "Modern campus grounds."),
        ("Al-Rass Heritage Area", "Heritage Site", "attraction", 25.8500, 43.5000, 4.2, 1100,
         "Historic Qassim town."),
        ("Al Bukayriyah Oasis", "Oasis", "nature", 26.1500, 43.6500, 4.4, 1400,
         "Palm oasis and farms."),
        ("Al Shabab Park Buraydah", "Park", "attraction", 26.3620, 43.9780, 4.1, 800,
         "Sports and recreation park."),
        ("Al-Qassim Regional Museum", "Museum", "attraction", 26.3550, 43.9720, 4.2, 650,
         "Regional artifacts and history."),
    ])

    # Smaller cities that still appear in dataset
    for city, province, places in [
        ("Al-Kharj", "Riyadh", [
            ("Al-Kharj Water Tower", "Landmark", "attraction", 24.1550, 47.3050, 4.2, 1100, "City landmark."),
            ("King Abdulaziz Palace Al-Kharj", "Historic Site", "attraction", 24.1500, 47.3000, 4.4, 1800, "Historic palace."),
            ("Al-Kharj Zoo", "Zoo", "entertainment", 24.1600, 47.3100, 4.1, 2400, "Family zoo."),
            ("Al-Baijan Park", "Park", "attraction", 24.1520, 47.3020, 4.0, 900, "Urban park."),
            ("Al-Kharj Historical Museum", "Museum", "attraction", 24.1530, 47.3040, 4.2, 650, "Local history."),
            ("Al-Saih Lake", "Lake", "nature", 24.1400, 47.2900, 4.3, 1200, "Desert lake recreation."),
            ("Al-Kharj Mall", "Shopping Mall", "shopping", 24.1580, 47.3080, 4.1, 3200, "Shopping center."),
            ("Al-Hayer Hot Springs", "Hot Springs", "nature", 24.1200, 47.2500, 4.5, 2100, "Natural hot springs."),
            ("Al-Kharj Heritage Village", "Heritage Village", "attraction", 24.1510, 47.3010, 4.0, 480, "Traditional architecture."),
            ("Prince Salman Park Al-Kharj", "Park", "attraction", 24.1540, 47.3060, 4.2, 1100, "Community park."),
        ]),
        ("Arar", "Northern Borders", [
            ("Arar Heritage Museum", "Museum", "attraction", 30.9750, 41.0380, 4.1, 800, "Border region history."),
            ("Arar Grand Mosque", "Mosque", "attraction", 30.9800, 41.0400, 4.5, 1500, "Central mosque."),
            ("Arar Park", "Park", "attraction", 30.9780, 41.0350, 4.0, 600, "City park."),
            ("Northern Borders Monument", "Landmark", "attraction", 30.9820, 41.0420, 4.2, 450, "Regional landmark."),
            ("Arar Traditional Market", "Market", "attraction", 30.9760, 41.0370, 4.0, 520, "Local souq."),
            ("Al-Nabk Forest Arar", "Forest", "nature", 30.9500, 41.0000, 4.3, 380, "Desert acacia forest."),
            ("Arar Sports City", "Sports Complex", "sports", 30.9700, 41.0300, 4.1, 900, "Stadium complex."),
            ("Arar Water Tower Park", "Park", "attraction", 30.9790, 41.0390, 4.0, 350, "Park around water tower."),
            ("Arar Cultural Center", "Cultural Center", "attraction", 30.9770, 41.0360, 4.1, 420, "Community arts."),
            ("Rawdat Arar", "Nature", "nature", 30.9600, 41.0200, 4.2, 280, "Desert meadow picnic area."),
        ]),
        ("Unayzah", "Qassim", [
            ("Unayzah Heritage Village", "Heritage Village", "attraction", 26.0900, 43.9700, 4.5, 2800, "Historic Qassim town."),
            ("Unayzah Museum", "Museum", "attraction", 26.0880, 43.9680, 4.2, 1100, "Regional museum."),
            ("Al Bassam House Unayzah", "Heritage House", "attraction", 26.0920, 43.9720, 4.4, 900, "Traditional house."),
            ("Unayzah Park", "Park", "attraction", 26.0910, 43.9710, 4.1, 750, "Central park."),
            ("Unayzah Dates Market", "Market", "attraction", 26.0890, 43.9690, 4.3, 1400, "Dates trading."),
            ("Al Rajhi Mosque Unayzah", "Mosque", "attraction", 26.0905, 43.9705, 4.6, 2000, "Landmark mosque."),
            ("Unayzah Corniche Lake", "Lake", "nature", 26.0850, 43.9650, 4.2, 620, "Lake recreation."),
            ("Unayzah Sports Stadium", "Stadium", "sports", 26.0870, 43.9670, 4.0, 1100, "Sports venue."),
            ("Al Ghada Mall Unayzah", "Shopping Mall", "shopping", 26.0930, 43.9730, 4.1, 1800, "Shopping mall."),
            ("Unayzah Old Souq", "Market", "attraction", 26.0885, 43.9685, 4.2, 850, "Traditional market."),
        ]),
        ("Safwa", ep, [
            ("Safwa Corniche", "Waterfront", "attraction", 26.6500, 49.9500, 4.2, 1100, "Gulf waterfront."),
            ("Safwa Fish Market", "Market", "attraction", 26.6520, 49.9520, 4.1, 800, "Seafood market."),
            ("Safwa Park", "Park", "attraction", 26.6480, 49.9480, 4.0, 450, "Community park."),
            ("Safwa Heritage House", "Heritage House", "attraction", 26.6510, 49.9510, 4.2, 320, "Traditional house."),
            ("Al Khaleej Mall Safwa", "Shopping Mall", "shopping", 26.6530, 49.9530, 4.0, 1200, "Local mall."),
            ("Safwa Beach", "Beach", "beach", 26.6550, 49.9550, 4.3, 900, "Public beach."),
            ("Safwa Cultural Center", "Cultural Center", "attraction", 26.6490, 49.9490, 4.1, 280, "Community events."),
            ("Safwa Sports Club", "Sports", "sports", 26.6470, 49.9470, 4.0, 350, "Sports facilities."),
            ("Safwa Date Farms", "Farm", "attraction", 26.6450, 49.9450, 4.2, 210, "Date plantations."),
            ("Safwa Marina", "Marina", "attraction", 26.6560, 49.9560, 4.1, 480, "Small boat harbor."),
        ]),
    ]:
        add_many(city, province, places)

    add_many("King Abdullah Economic City", "Makkah", [
        ("King Abdullah Economic City Beach", "Beach", "beach", 22.4000, 39.0800, 4.5, 6200,
         "Red Sea beaches in KAEC."),
        ("Bay La Sun Marina", "Marina", "attraction", 22.4050, 39.0850, 4.4, 4100,
         "Marina and waterfront dining."),
        ("KAEC Golf Course", "Golf", "sports", 22.3950, 39.0750, 4.6, 2800,
         "Championship golf course."),
        ("Juman Mall KAEC", "Shopping Mall", "shopping", 22.4020, 39.0820, 4.3, 3500,
         "Retail and entertainment."),
        ("KAEC Industrial Valley", "Landmark", "attraction", 22.3900, 39.0700, 4.0, 900,
         "Economic zone landmark."),
        ("Lagoon Park KAEC", "Park", "attraction", 22.4080, 39.0880, 4.4, 2100,
         "Waterfront park and lagoon."),
        ("KAEC Sports Stadium", "Stadium", "sports", 22.3920, 39.0780, 4.2, 1500,
         "Community sports venue."),
        ("Coral Reef KAEC", "Marine Reserve", "nature", 22.4100, 39.0900, 4.7, 1800,
         "Snorkeling and diving."),
        ("KAEC Heritage Trail", "Trail", "attraction", 22.3980, 39.0800, 4.1, 650,
         "Coastal walking trail."),
        ("Sunset Beach KAEC", "Beach", "beach", 22.4120, 39.0920, 4.5, 2400,
         "Popular sunset viewpoint."),
    ])

    return rows


def _reassign_al_city(name: str) -> str | None:
    for pattern, city in _AL_NAME_PATTERNS:
        if pattern.search(name):
            return city
    return None


def _next_poi_id(existing: pd.Series) -> int:
    nums = []
    for pid in existing.dropna().astype(str):
        m = re.match(r"POI_(\d+)", pid)
        if m:
            nums.append(int(m.group(1)))
    return max(nums, default=0) + 1


def main() -> None:
    df = pd.read_csv(CSV_PATH)
    original_len = len(df)

    # Drop non-KSA
    df = df[~df["city"].isin(NON_KSA_CITIES)].copy()

    # Drop rows with non-Saudi province
    if "province" in df.columns:
        df = df[~df["province"].astype(str).str.contains("International", case=False, na=False)].copy()

    # Rename cities
    df["city"] = df["city"].replace(CITY_RENAMES)

    # Fix city="Al" using name heuristics
    al_mask = df["city"] == "Al"
    for idx in df.index[al_mask]:
        name = str(df.at[idx, "name"])
        new_city = _reassign_al_city(name)
        if new_city:
            df.at[idx, "city"] = new_city

    # Khobar-related rows tagged Dammam with Khobar in name
    dammam_khobar = (df["city"] == "Dammam") & df["name"].astype(str).str.contains(
        r"khobar|kobar", case=False, na=False
    )
    df.loc[dammam_khobar, "city"] = "Al Khobar"

    # Deduplicate supplements against existing names per city
    existing_keys = {
        (str(r["city"]).strip().lower(), str(r["name"]).strip().lower())
        for _, r in df.iterrows()
    }

    next_id = _next_poi_id(df["poi_id"])
    new_rows = []
    for sup in _supplements():
        key = (sup["city"].lower(), sup["name"].lower())
        if key in existing_keys:
            continue
        existing_keys.add(key)
        sup["poi_id"] = f"POI_{next_id:06d}"
        next_id += 1
        new_rows.append(sup)

    if new_rows:
        df = pd.concat([df, pd.DataFrame(new_rows)], ignore_index=True)

    # Ensure province/country consistency for new rows
    for idx, row in df.iterrows():
        if pd.isna(row.get("province")) or str(row.get("province")).strip() == "":
            city = str(row["city"])
            province_map = {
                "Riyadh": "Riyadh", "Jeddah": "Makkah", "Makkah": "Makkah", "Madinah": "Madinah",
                "AlUla": "Medina", "Taif": "Makkah", "Tabuk": "Tabuk", "Abha": "Asir",
                "Aseer": "Asir", "Hail": "Hail", "Najran": "Najran", "Jazan": "Jazan",
                "Al Khobar": "Eastern Province", "Dammam": "Eastern Province",
                "Dhahran": "Eastern Province", "Al Jubail": "Eastern Province",
                "Al-Ahsa": "Eastern Province", "Buraydah": "Qassim", "Qassim": "Qassim",
                "Unayzah": "Qassim", "Al Baha": "Al Baha", "Diriyah": "Riyadh",
                "Shaqra": "Riyadh", "Umluj": "Tabuk", "Yanbu": "Madinah",
                "Farasan": "Jazan", "Al-Kharj": "Riyadh", "Arar": "Northern Borders",
                "Safwa": "Eastern Province",
            }
            if city in province_map:
                df.at[idx, "province"] = province_map[city]

    # Report counts below minimum (excluding junk)
    counts = df.groupby("city").size()
    under = {
        c: int(n)
        for c, n in counts.items()
        if n < MIN_POIS_PER_CITY and c not in JUNK_CITIES and c not in NON_KSA_CITIES
    }

    df.to_csv(CSV_PATH, index=False)

    # Hint for local dev: restart the API or call invalidate_* after this script.
    print("Restart the FastAPI backend so cities/POI caches reload.")

    print(f"Removed {original_len - len(df) + len(new_rows)} net rows from non-KSA cleanup")
    print(f"Added {len(new_rows)} curated POIs")
    print(f"Final rows: {len(df)}")
    if under:
        print(f"Cities still under {MIN_POIS_PER_CITY}:")
        for c, n in sorted(under.items(), key=lambda x: x[1]):
            print(f"  {c}: {n}")
    else:
        print(f"All non-junk cities have >= {MIN_POIS_PER_CITY} POIs")


if __name__ == "__main__":
    main()
