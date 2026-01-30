# International Regions Research

Research for expanding Footprint to support states/provinces for additional countries beyond US and Canada.

## Target Countries (Priority Order)

### High Priority
1. **Australia** - States and territories (8 regions)
2. **Mexico** - States (31 states + 1 federal district)
3. **Brazil** - States (26 states + 1 federal district)
4. **Germany** - Länder (16 states)

### Medium Priority
5. **India** - States and union territories (28 states + 8 union territories)
6. **China** - Provinces, autonomous regions, municipalities (34 divisions)

## Implementation Progress

### ✅ Completed
- [x] Extended RegionType enum with 6 new international region types
- [x] Created SubnationalRegion base model and country-specific models
- [x] Updated visited_place.py with classification helper functions
- [x] Created comprehensive test suite (13 tests, all passing)
- [x] Generated sample data for Australia (8 regions) and Mexico (5 sample regions)
- [x] Created data fetching script framework

### 🔄 In Progress
- [ ] Update backend API endpoints to support new region types
- [ ] Create comprehensive data processing pipeline
- [ ] Add real geographic boundary data

### 📋 Next Steps
1. **Backend API Integration**
   - Update places API with extended statistics
   - Add filtering support for international regions
   - Update sync services

2. **Data Acquisition**
   - Download Natural Earth Admin 1 boundaries
   - Process real geographic data for all 6 countries
   - Generate optimized boundary files

3. **Frontend Integration**
   - Update iOS models and UI
   - Add region selection interface
   - Update statistics display

## Technical Implementation

### Database Schema Extensions
```python
class RegionType(str, Enum):
    # Existing
    COUNTRY = "country"
    US_STATE = "us_state"
    CANADIAN_PROVINCE = "canadian_province"

    # New international regions
    AUSTRALIAN_STATE = "australian_state"
    MEXICAN_STATE = "mexican_state"
    BRAZILIAN_STATE = "brazilian_state"
    GERMAN_STATE = "german_state"
    INDIAN_STATE = "indian_state"
    CHINESE_PROVINCE = "chinese_province"
```

### Region Totals
- Australia: 8 regions (6 states + 2 territories)
- Mexico: 32 regions (31 states + 1 federal district)
- Brazil: 27 regions (26 states + 1 federal district)
- Germany: 16 regions (16 Länder)
- India: 36 regions (28 states + 8 union territories)
- China: 34 regions (22 provinces + 5 autonomous regions + 4 municipalities + 2 SARs + 1 disputed)

### Data Sources
- **Primary**: Natural Earth Admin 1 (Public Domain)
- **Format**: GeoJSON with ISO 3166-2 codes
- **Quality**: Consistent global coverage, appropriate for mobile apps

## Sample Data Generated
- `/data/international_regions/au_regions.json` - Australian states/territories
- `/data/international_regions/mx_regions.json` - Mexican states (sample)

## Testing
All functionality is covered by comprehensive tests:
- Region type classification (3 test methods)
- Model validation (4 test methods)
- Helper functions (4 test methods)
- Data structure validation (2 test methods)

**Test Status**: ✅ 13/13 tests passing
