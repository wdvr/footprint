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

## Data Sources Research

### Primary Source: Administrative Boundaries
**Natural Earth Data**
- URL: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/
- License: Public Domain
- Files: `ne_10m_admin_1_states_provinces_shp.zip`
- Coverage: Global states/provinces with consistent quality
- Format: Shapefile/GeoJSON

**Alternative: OpenStreetMap/Geofabrik**
- URL: https://download.geofabrik.de/
- License: ODbL
- Coverage: Country-specific extracts with admin boundaries
- Format: Shapefile/PBF

### Country-Specific Details

#### Australia (8 regions)
- **States (6)**: New South Wales, Victoria, Queensland, Western Australia, South Australia, Tasmania
- **Territories (2)**: Australian Capital Territory, Northern Territory
- **ISO 3166-2**: AU-NSW, AU-VIC, AU-QLD, AU-WA, AU-SA, AU-TAS, AU-ACT, AU-NT
- **Capital**: Each state has its own capital city
- **Data Source**: Australian Bureau of Statistics or Natural Earth

#### Mexico (32 regions)
- **States (31)**: Aguascalientes, Baja California, Baja California Sur, etc.
- **Federal District (1)**: Ciudad de México (Mexico City)
- **ISO 3166-2**: MX-AGU, MX-BCN, MX-BCS, etc.
- **Data Source**: INEGI (Mexican statistics office) or Natural Earth

#### Brazil (27 regions)
- **States (26)**: São Paulo, Rio de Janeiro, Minas Gerais, etc.
- **Federal District (1)**: Distrito Federal (Brasília)
- **ISO 3166-2**: BR-SP, BR-RJ, BR-MG, etc.
- **Data Source**: IBGE (Brazilian statistics office) or Natural Earth

#### Germany (16 regions)
- **States (16)**: Baden-Württemberg, Bayern, Berlin, Brandenburg, etc.
- **ISO 3166-2**: DE-BW, DE-BY, DE-BE, DE-BB, etc.
- **Data Source**: Federal Statistical Office of Germany or Natural Earth

#### India (36 regions)
- **States (28)**: Andhra Pradesh, Assam, Bihar, etc.
- **Union Territories (8)**: Delhi, Puducherry, Chandigarh, etc.
- **ISO 3166-2**: IN-AP, IN-AS, IN-BR, etc.
- **Data Source**: Survey of India or Natural Earth

#### China (34 regions)
- **Provinces (22)**: Anhui, Fujian, Gansu, etc.
- **Autonomous Regions (5)**: Guangxi, Inner Mongolia, Ningxia, Tibet, Xinjiang
- **Municipalities (4)**: Beijing, Chongqing, Shanghai, Tianjin
- **Special Administrative Regions (2)**: Hong Kong, Macao
- **Taiwan (1)**: Taiwan (disputed)
- **ISO 3166-2**: CN-AH, CN-FJ, CN-GS, etc.
- **Data Source**: National Bureau of Statistics of China or Natural Earth

## Implementation Strategy

### Phase 1: Schema Extension
1. Create new region type enums
2. Extend geographic models
3. Update database schema
4. Create migration scripts

### Phase 2: Data Acquisition
1. Download Natural Earth admin boundaries
2. Process and clean data for target countries
3. Extract region metadata (names, codes, capitals)
4. Generate optimized GeoJSON for each country

### Phase 3: Backend Integration
1. Update API models and endpoints
2. Add new region types to statistics calculation
3. Update sync services
4. Add comprehensive test coverage

### Phase 4: Frontend Integration
1. Update SwiftUI models
2. Add region selection UI
3. Update map display logic
4. Add statistics display

### Phase 5: Testing & Optimization
1. Performance testing with larger datasets
2. Memory optimization for mobile
3. Boundary simplification for zoom levels
4. Error handling and fallbacks

## Technical Considerations

### Database Schema
- Extend `RegionType` enum with new values
- Create base `SubnationalRegion` model
- Country-specific models inherit from base
- Consistent naming conventions (ISO 3166-2 codes)

### Performance
- Boundary data can be large (MB per country)
- Need simplified geometries for mobile
- Lazy loading of detailed boundaries
- Efficient spatial indexing

### Localization
- Region names in multiple languages
- Local vs English naming preferences
- Consistent display formatting

### Data Quality
- Verify ISO 3166-2 code consistency
- Handle disputed territories appropriately
- Regular data updates and validation

## Next Steps
1. Download and evaluate Natural Earth data
2. Create proof-of-concept for Australia (smallest dataset)
3. Design extensible schema for all countries
4. Implement data processing pipeline
5. Create comprehensive test suite
