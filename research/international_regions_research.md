# International Regions Research - Cities & Provinces Expansion

Research and implementation for GitHub issues #17 (States/provinces for other countries) and #18 (Cities & Landmarks tracking).

## Overview

Expanding Footprint to support tracking subnational regions (states/provinces) for countries beyond US and Canada, plus laying groundwork for cities and landmarks.

## Target Countries - Phase 1 (Subnational Regions)

### ✅ High Priority (Implemented)
1. **Australia** - 8 regions (6 states + 2 territories)
2. **Mexico** - 32 regions (31 states + 1 federal district)

### 🔄 High Priority (Next)
3. **Brazil** - 27 regions (26 states + 1 federal district)
4. **Germany** - 16 regions (16 Länder)

### 📋 Medium Priority (Future)
5. **India** - 36 regions (28 states + 8 union territories)
6. **China** - 34 regions (22 provinces + 5 autonomous regions + 4 municipalities + 2 SARs)

## Implementation Progress

### ✅ Phase 1: Schema & Models (COMPLETED)
- [x] Extended `RegionType` enum with 6 new international region types
- [x] Created `SubnationalRegion` base model with country-specific subclasses
- [x] Updated `visited_place.py` with classification helper functions
- [x] Comprehensive test coverage (13 tests, 100% passing)

### ✅ Phase 2: Data Infrastructure (COMPLETED)
- [x] Created `fetch_international_regions.py` script
- [x] Generated sample data for Australia (8 regions) and Mexico (5 regions)
- [x] Established data structure and ISO 3166-2 code standards

### 📋 Phase 3: Backend API (NEXT STEPS)
- [ ] Update places API endpoints with extended region type support
- [ ] Add international region statistics calculations
- [ ] Update sync services for new region types
- [ ] Integration testing with real API calls

### 📋 Phase 4: Frontend Integration
- [ ] Update iOS SwiftUI models for new region types
- [ ] Add region selection UI components
- [ ] Update map display logic for international regions
- [ ] Statistics view enhancements

### 📋 Phase 5: Production Data
- [ ] Download Natural Earth Admin 1 boundaries
- [ ] Process real geographic data for all countries
- [ ] Generate optimized boundary files for mobile
- [ ] Performance testing with full datasets

## Technical Implementation Details

### Database Schema
```python
class RegionType(str, Enum):
    # Existing
    COUNTRY = "country"
    US_STATE = "us_state"
    CANADIAN_PROVINCE = "canadian_province"

    # New international regions (Phase 1)
    AUSTRALIAN_STATE = "australian_state"      # 8 regions
    MEXICAN_STATE = "mexican_state"            # 32 regions
    BRAZILIAN_STATE = "brazilian_state"        # 27 regions
    GERMAN_STATE = "german_state"              # 16 regions
    INDIAN_STATE = "indian_state"              # 36 regions
    CHINESE_PROVINCE = "chinese_province"      # 34 regions

    # Future Phase 2 (Cities & Landmarks)
    CITY = "city"
    UNESCO_SITE = "unesco_site"
    NATIONAL_PARK = "national_park"
```

### Sample Data Generated
- `data/international_regions/au_regions.json` - 8 Australian states/territories
- `data/international_regions/mx_regions.json` - 5 sample Mexican states

### Helper Functions
- `is_international_region()` - Classification helper
- `is_subnational_region()` - General subnational check
- `get_parent_country_code()` - Country lookup from region
- `get_region_total()` - Statistics calculations

## Testing Status

**✅ 13/13 tests passing**
- Region type classification (3 tests)
- Model validation (4 tests)
- Helper functions (4 tests)
- Data structure validation (2 tests)

## Data Sources & Quality

### Primary: Natural Earth Admin 1
- **URL**: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/
- **License**: Public Domain
- **Coverage**: Global states/provinces with consistent quality
- **Format**: Shapefile → GeoJSON conversion

### Standards
- **Codes**: ISO 3166-2 subdivision codes
- **Naming**: Local names with English alternatives
- **Boundaries**: Simplified for mobile performance

## Issue Status

### GitHub Issue #17: States/provinces for other countries
**Status**: 🔄 IN PROGRESS - Phase 1 Complete
- ✅ Schema design and implementation
- ✅ Data models and validation
- ✅ Sample data generation
- 🔄 Backend API integration (next)
- 📋 Frontend integration (planned)

### GitHub Issue #18: Cities & Landmarks tracking
**Status**: 📋 PLANNED - Phase 2
- 📋 Research city data sources (GeoNames, OpenStreetMap)
- 📋 UNESCO World Heritage Sites integration
- 📋 National Parks data (existing script foundation)
- 📋 Point-of-interest tracking models

## Performance Considerations

### Mobile Optimization
- Boundary simplification by zoom level
- Lazy loading of detailed geometries
- Efficient spatial indexing
- Memory usage monitoring

### Data Volume Estimates
- Full boundary data: ~50MB compressed
- Simplified mobile boundaries: ~5MB
- Metadata only: <1MB

## Next Immediate Steps

1. **Update Backend API** (This Sprint)
   - Extend places API routes with international region support
   - Update statistics calculations
   - Add filtering and search capabilities

2. **Generate Real Data** (Next Sprint)
   - Download Natural Earth data
   - Process all 6 country boundaries
   - Validate against official sources

3. **Frontend Integration** (Following Sprint)
   - iOS model updates
   - Map display enhancements
   - User interface improvements

## Success Metrics

- **Coverage**: 6 new countries with 153 total regions added
- **Performance**: <2s load time for region data
- **Quality**: 100% ISO 3166-2 code compliance
- **Testing**: >90% code coverage maintained
