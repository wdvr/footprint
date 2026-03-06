# Footprint - Known Bugs & Issues

## Open Bugs

### BUG-001: Google Calendar/Gmail import disabled but code still present
**Severity**: Low (UX debt, not user-facing)
**Component**: iOS (ImportSourcesView.swift lines 18-98), Backend
**Description**: The entire Google import UI is commented out in ImportSourcesView.swift. Backend endpoints (`/api/import/google`) still exist and are deployed. Should either re-enable (after Google OAuth consent screen approval) or remove dead code.
**Workaround**: N/A -- feature is hidden from users.

### BUG-002: Outdated TODO comment about account deletion
**Severity**: Trivial
**Component**: iOS (ContentView.swift line 619)
**Description**: Comment says "TODO: Implement account deletion through backend API" but account deletion IS implemented. Dead comment.

### BUG-003: iPad screenshot tests fail
**Severity**: Low
**Component**: iOS (FootprintUITests/ScreenshotTests.swift) | Issue #88
**Description**: Screenshot tests use element identifiers that don't exist on iPad layout. Need device detection and iPad-specific queries. Also need to update Snapfile for iPad Pro sizes.

### BUG-004: Performance not benchmarked with large datasets
**Severity**: Medium
**Component**: iOS, Backend | Issue #23
**Description**: No performance testing has been done. Map rendering, sync speed, and photo import with large photo libraries (50k+ photos) are untested. Could be slow for power users.

### BUG-005: Production AWS environment not deployed
**Severity**: HIGH
**Component**: Infrastructure | Issue #16
**Description**: Only dev environment exists. Production deployment needed before real App Store launch. Includes separate DynamoDB tables, Lambda functions, API Gateway stage, and monitoring.

### BUG-006: Photo import can be slow for large libraries
**Severity**: Medium
**Component**: iOS (PhotoImportManager)
**Description**: Photo import scans entire library sequentially with geocoding. For large libraries (30k+ photos), this can take 10+ minutes. Incremental scan helps on re-runs but first import is slow. Consider batch geocoding or background processing improvements.

### BUG-007: macOS Catalyst build untested
**Severity**: Low
**Component**: iOS
**Description**: Mac Catalyst was enabled (DIARY.md mentions it, Issue #19 was closed) but there's no evidence of testing or optimization for macOS. Menu bar, window sizing, keyboard shortcuts likely need work.

---

## Recently Fixed (for reference)

| Bug | Fixed In | Description |
|-----|----------|-------------|
| Timezone stats showing all timezones for Russia | v2.0.1 | Multi-timezone countries now only count timezones for actually visited states |
| Year in Review date logic errors | v2.0.1 | Places without visitedDate excluded; timezone and region counts wrong |
| Year in Review share sheet crash | v2.0.1 | Share sheet presented without guard, dead animation state |
| Photo import photoAssetIDs bloating memory | v2.0.0 | Removed from cluster structs, pre-load GeoJSON, 10s geocoder timeout |
| Blank screen selecting states in Russia/US | v2.0.0 | State code matching failed for short vs full ISO codes |
| TestFlight crash on launch | v1.x | Hardcoded aps-environment=development in entitlements |
| SwiftData migration error | v1.x | New status field had no default value |
| Photo import geocoding too slow | v1.x | Increased concurrency 10x |
| Onboarding location permission wrong method | v1.x | Called incorrect method for requesting permission |
