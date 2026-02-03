# Cities and Landmarks Research for Footprint

**Date:** February 2026
**Status:** Research only - not yet implemented

## Executive Summary

The Footprint app already has cities and landmarks data integrated. This document researches additional data sources and potential enhancements for the Cities & Landmarks tracking feature (GitHub Issue #18).

---

## Current Implementation Status

### Existing Data Files

The app already includes cities and landmarks data in `/ios/Footprint/Resources/GeoData/`:

| File | Size | Content |
|------|------|---------|
| `world_cities.json` | 175 KB | 2,222 cities across 153 countries |
| `world_landmarks.json` | 348 KB | 3,943 landmarks across 227 countries |
| `world_states.json` | 437 KB | States/provinces for multiple countries |

### Cities Data Analysis

Current cities data (population >= 250,000):
- **Total cities:** 2,222
- **Countries covered:** 153
- **Population breakdown:**
  - 1M+: 533 cities (24%)
  - 500K-1M: 570 cities (26%)
  - 250K-500K: 1,119 cities (50%)

Top countries by city count:
- China: 282 cities
- India: 162 cities
- Brazil: 112 cities
- Japan: 96 cities
- United States: 92 cities

### Landmarks Data Analysis

Current landmarks breakdown by type:
- **National Parks:** 2,893
- **UNESCO World Heritage Sites:** 1,050
- **Total:** 3,943 landmarks

### Data Generation Scripts

Existing scripts in `/scripts/`:
- `fetch_geographic_data.py` - Fetches cities, states, and country metadata
- `fetch_landmarks.py` - Fetches UNESCO sites, national parks, and popular landmarks

---

## Cities Data Sources

### 1. GeoNames (Current Source)

**Website:** https://www.geonames.org/
**Download:** https://download.geonames.org/export/dump/
**License:** Creative Commons Attribution 4.0

**Available Downloads:**
| File | Description | Size |
|------|-------------|------|
| `cities500.zip` | Cities with pop > 500 | 12 MB |
| `cities1000.zip` | Cities with pop > 1,000 | 9.6 MB |
| `cities5000.zip` | Cities with pop > 5,000 | 4.9 MB |
| `cities15000.zip` | Cities with pop > 15,000 | 2.9 MB |

**Data Fields:**
- geonameid, name, asciiname, alternatenames
- latitude, longitude (WGS84)
- feature class, feature code
- country code (ISO-3166)
- population, elevation, timezone

**Pros:**
- Comprehensive global coverage (11M+ placenames)
- Daily updates
- Free and well-documented
- Population data included

**Cons:**
- No "significance" ranking beyond population
- No tourism relevance scoring

### 2. Natural Earth Populated Places

**Website:** https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-populated-places/
**License:** Public Domain

**Available Scales:**
- 1:10m (detailed) - ~7,500 places
- 1:50m (medium) - ~1,200 places
- 1:110m (coarse) - ~250 places

**Data Fields:**
- Name, country, admin region
- Latitude, longitude
- Population estimates (LandScan derived, 90% coverage)
- Scale ranking (for map display filtering)
- Feature class (national capital, admin capital, populated place)

**Pros:**
- Curated for cartographic display
- Scale rankings help with zoom-level filtering
- Includes admin capitals (important for travel tracking)
- Public domain

**Cons:**
- Fewer cities than GeoNames
- Less frequent updates

### 3. dr5hn/countries-states-cities-database (Alternative Source)

**GitHub:** https://github.com/dr5hn/countries-states-cities-database
**License:** ODbL 1.0

**Content:**
- 153,765 cities worldwide
- 5,299 states/provinces across 250 countries
- Country metadata

**Pros:**
- Single JSON file download
- Well-maintained GitHub repo
- State/province linkage

**Cons:**
- No population data
- Less verification than GeoNames

---

## Landmarks Data Sources

### 1. UNESCO World Heritage Sites

**Official API:** https://data.unesco.org/explore/dataset/whc001/api/
**Alternative:** https://github.com/eprendergast/unesco-api
**License:** Public Domain

**Current Implementation:**
- Using Igor-Vladyka/realplanet GitHub dataset
- 1,050 sites (as of current data)
- Includes cultural, natural, and mixed sites

**Official UNESCO Data:**
- 1,248 properties total
- 972 cultural sites
- 235 natural sites
- 41 mixed sites
- 170 countries

### 2. National Parks

**Current Source:** openshift-roadshow/nationalparks-js (GeoNames data)
**Alternative:** Protected Planet WDPA database

**Current Implementation:**
- 2,893 national parks
- 161 countries covered

**Protected Planet (WDPA) Alternative:**
- Website: https://www.protectedplanet.net/
- Most comprehensive protected areas database
- Includes nature reserves, national parks, marine protected areas
- ~295,000 protected areas globally

### 3. Wikidata (SPARQL Queries)

**Endpoint:** https://query.wikidata.org/
**License:** CC0 (Public Domain)

**Queryable Landmark Types:**
- Q33506 - Museum
- Q23413 - Castle
- Q570116 - Tourist attraction
- Q839954 - Archaeological site
- Q15206070 - Historic site
- Q4989906 - Monument

**Pros:**
- Massive dataset (100M+ items)
- Multilingual labels
- Links to Wikipedia
- Geographic coordinates
- Constantly updated

**Cons:**
- SPARQL queries can be slow/timeout
- Rate limited (2000 requests/minute)
- Data quality varies
- Complex query language

### 4. OpenStreetMap (Overpass API)

**Endpoint:** https://overpass-api.de/api/interpreter
**Interactive Tool:** https://overpass-turbo.eu/
**License:** ODbL

**Tourism Tags:**
- `tourism=attraction`
- `tourism=museum`
- `tourism=viewpoint`
- `historic=monument`
- `historic=memorial`
- `historic=castle`
- `historic=archaeological_site`

**Pros:**
- Community-maintained, constantly updated
- Highly detailed for popular areas
- Free to use
- Geographic queries supported

**Cons:**
- Rate limits (10,000 queries/day recommended)
- Query timeouts (180 seconds)
- Uneven coverage globally
- Large data volumes

### 5. Wikimedia Commons Monuments Database

**Website:** https://commons.wikimedia.org/wiki/Commons:Monuments_database
**License:** CC0

**Content:**
- Cultural heritage monuments from various countries
- Linked to Wikipedia/Wikidata
- Images available

### 6. Commercial APIs (for reference)

**Google Places API:**
- Comprehensive but expensive at scale
- Not suitable for bulk download

**TripAdvisor API:**
- Requires partnership agreement
- Good for rankings/reviews

**HERE Geocoder API:**
- Landmark search within radius
- Free tier available

---

## Recommended Population Thresholds

Based on analysis of current data and app use cases:

| Tier | Population | Est. Count | Use Case |
|------|------------|------------|----------|
| Major | >= 1M | ~500 | Global capitals, major metros |
| Large | >= 500K | ~1,100 | Regional hubs |
| Medium | >= 250K | ~2,200 | Current implementation |
| Small | >= 100K | ~5,000 | Detailed tracking |
| All | >= 50K | ~10,000 | Comprehensive |

**Recommendation:** Keep current 250K threshold for initial release. Consider offering tiered downloads:
- Default: 250K+ (2,200 cities)
- Extended: 100K+ (downloadable pack)

---

## Recommended Landmark Categories

For travel tracking, prioritize:

1. **Must Have (currently implemented):**
   - UNESCO World Heritage Sites
   - National Parks

2. **High Priority (to add):**
   - National/state capitals
   - Famous monuments (Eiffel Tower, Statue of Liberty, etc.)
   - Major museums (Louvre, British Museum, Smithsonian)
   - Famous religious sites (Notre Dame, Vatican, Angkor Wat)

3. **Medium Priority:**
   - Castles and palaces
   - Archaeological sites
   - Famous bridges
   - Iconic viewpoints

4. **Lower Priority:**
   - Regional museums
   - Local monuments
   - Minor historic sites

---

## Data Format Recommendations

### Cities JSON Schema

```json
{
  "US": [
    {
      "name": "New York City",
      "lat": 40.7128,
      "lng": -74.0060,
      "pop": 8804190,
      "state": "NY",
      "capital": false,
      "admin_capital": false
    }
  ]
}
```

### Landmarks JSON Schema

```json
{
  "FR": [
    {
      "name": "Eiffel Tower",
      "type": "monument",
      "category": "landmark",
      "lat": 48.8584,
      "lng": 2.2945,
      "unesco": false,
      "wikidata": "Q243"
    }
  ]
}
```

---

## Implementation Recommendations

### Phase 1: Enhance Current Data
1. Add capital city flags to cities data
2. Add more landmark types from Wikidata (monuments, museums)
3. Create unified landmark JSON with consistent schema

### Phase 2: iOS App Integration
1. Create City model similar to VisitedPlace
2. Add city tracking UI
3. Implement landmark discovery (nearby landmarks when visiting a country)
4. Add achievement badges for landmark visits

### Phase 3: Advanced Features
1. City autocomplete search
2. "Major cities visited" statistics
3. UNESCO site completion tracker
4. National park visited map overlay

---

## File Size Considerations

For iOS app bundle:

| Data Set | Current | With 100K cities | Notes |
|----------|---------|------------------|-------|
| Cities | 175 KB | ~400 KB | Acceptable |
| Landmarks | 348 KB | ~500 KB | With added monuments |
| Total | ~1 MB | ~1.5 MB | Well within limits |

Consider lazy-loading detailed city data per country to reduce initial bundle size.

---

## Data Licensing Summary

All recommended data sources use permissive licenses:

| Source | License | Attribution Required |
|--------|---------|---------------------|
| GeoNames | CC-BY 4.0 | Yes |
| Natural Earth | Public Domain | No |
| UNESCO | Public Domain | No |
| Wikidata | CC0 | No |
| OpenStreetMap | ODbL | Yes, if redistributing |

**Recommendation:** Include attribution in app's About/Credits screen.

---

## Next Steps

1. [ ] Review this research with stakeholder
2. [ ] Decide on city population threshold
3. [ ] Select additional landmark categories to add
4. [ ] Update data fetching scripts
5. [ ] Design iOS data models for cities/landmarks
6. [ ] Create GitHub issue for implementation tasks

---

## References

- [GeoNames](https://www.geonames.org/)
- [Natural Earth](https://www.naturalearthdata.com/)
- [UNESCO World Heritage List](https://whc.unesco.org/en/list/)
- [Wikidata SPARQL Examples](https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service/queries/examples)
- [OpenStreetMap Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API)
- [Protected Planet WDPA](https://www.protectedplanet.net/)
