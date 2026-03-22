# Footprint Travel Tracker — Dev Diary

Cross-platform fix/feature tracker. Each item shows status across platforms.
Status: done | pending | n/a (not applicable) | backlog

---

## Feb 22, 2026

### Android App: Initial Kotlin + Jetpack Compose implementation
Full Android app scaffolding with Compose, Room, Hilt, Material 3. Matches iOS feature set structure.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | done | n/a | n/a |

---

## Feb 14, 2026

### Deployment skills for Claude agents
Added `/deploy-testflight` and `/deploy-backend` skill definitions for agent automation.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

---

## Feb 7, 2026

### Feature: Per-country state tracking settings (#100)
Configure which countries show state/province-level tracking. Integrated with map, country list, and Year in Review.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Account reset not clearing photo import and sync state
Reset account left stale photo import progress and sync metadata behind. Now clears all import-related state.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Photo import visitedDate not backfilled
Photos imported before visitedDate was added had nil dates. Added backfill logic during import.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Year in Review date logic errors
Places without visitedDate were excluded. Timezone and region counts were wrong. Total visited counts not shown.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Year in Review share sheet crash
Share sheet presented without guard. Dead animation state caused UI glitch. Counter animation was fragile.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Bug: Duplicate ShareSheetView name collision
`ShareSheetView` existed in both data export and Year in Review. Renamed to `ActivityShareSheet` in Year in Review.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: Year in Review — Spotify Wrapped-style summary (#96)
Animated annual travel summary with stats cards, country counts, continent progress, and shareable images.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Photos & Memories — attach photos to places (#95)
View trip photos grouped by trips instead of countries. Redesigned Memories tab.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Animated splash screen (#94)
App icon with globe sweep animation and smooth transition to content.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Data export — share travel maps (#93)
Export and share visited maps as images. Shareable travel statistics.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: macOS app via Mac Catalyst (#98)
Enable Mac Catalyst to run iOS app natively on macOS.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Accessibility improvements (#97)
VoiceOver labels, Dynamic Type support, high contrast mode across all views.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Reduce console logging spam (#99)
Removed excessive debug logging that cluttered device console in production builds.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Review fixes: accessibility labels, deduplicate code, fix sort menu
Code review cleanup pass — consolidated duplicate code, added missing a11y labels, fixed broken sort menu.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

---

## Feb 6, 2026

### Bug: Photo import performance — photoAssetIDs bloating cluster structs
`photoAssetIDs` array stored in cluster structs caused excessive memory use during import. Removed from struct, pre-load GeoJSON boundaries to avoid contention, added 10s geocoder timeout.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

---

## Feb 4, 2026

### Bug: Timezone stats — visiting Russia marks all timezones as visited (#91)
Multi-timezone countries (US, CA, RU, AU, MX, BR) showed ALL timezones as visited when any state was visited. Added state-level timezone mappings so only actually visited state timezones count.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Bug: iOS build not producing signed IPA for TestFlight (#89, #90)
Build workflow lacked `-allowProvisioningUpdates`, App Store Connect API auth, archive/export steps, and artifact upload. Fixed to produce proper IPA artifacts.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Security: Remove Google API key from repo
Moved Google API key to GitHub Secret instead of hardcoded in source.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | done | n/a | n/a |

### Google Calendar/Gmail import disabled
Hidden from UI — re-enable when Google OAuth consent screen is approved.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### v2.0.0 Release — App Store submission
Version bump, App Store metadata, screenshots, PolyForm Noncommercial license, support page.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | done | done |

---

## Feb 3, 2026

### Bug: Blank screen when selecting states in Russia and US
State code matching failed for GeoJSON files using short codes (e.g., "AL") vs full ISO codes (e.g., "RU-AL"). Added case-insensitive fallback and fallback UI for missing state info.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Swift 6 concurrency errors in ScreenshotTests
Strict concurrency checks broke screenshot tests. Fixed with `nonisolated(unsafe)` annotations.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: 15 new language localizations (20 total)
Added translations for DE, FR, JA, ES, IT, PT, ZH, KO, NL, SV, NO, DA, FI, PL, RU.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | backlog | n/a |

### Feature: States/provinces for 8 new countries
Added state-level tracking for Russia, UK, France, Italy, Spain, Netherlands, Belgium, Argentina. Updated FR, IT, GB subdivision data to match GeoJSON files.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Feature: Firebase analytics events and tracking granularity
Added analytics event tracking throughout the app with configurable granularity setting.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Public feedback endpoint for website
API endpoint for website visitors to submit feedback without auth.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | done | done |

### Feature: Automated App Store release with Claude release notes
Fastlane pipeline generates release notes via Claude, uploads to App Store Connect.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

---

## Feb 2, 2026

### Bug: TestFlight code signing — 15+ iterations to get it right
Extensive iteration through manual certs, automatic signing, Fastlane sigh, App Store Connect API, personal dev account. Final fix: use `-allowProvisioningUpdates` with ASC API auth.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Bug: Pulumi installation in deploy workflow
Deploy workflow failed because Pulumi wasn't installed. Made workflow self-contained.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | n/a | done |

---

## Jan 31, 2026

### Feature: Domain registration workflow (Route53)
Added and then removed automated domain registration workflow — domain owned in a different AWS account. Fixed Route53 validation records to allow overwrite.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | done | done |

### Bug: Pulumi using wrong virtual environment (#82)
Pulumi wasn't using the uv-managed virtual environment, causing missing dependencies.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | n/a | done |

### Bug: Pulumi backend URL wrong S3 bucket (#81)
Infrastructure pointed to incorrect S3 bucket for Pulumi state.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | n/a | done |

### Bug: Google login broken (#79)
Google Sign-In flow was not working. Fixed alongside Route53 domain configuration.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

---

## Jan 30, 2026

### Feature: Firebase Analytics and Crashlytics integration
Added Firebase SDK, dSYM upload build phase, analytics events throughout the app.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Swift 6 concurrency issues in tests
Strict concurrency mode broke test compilation. Fixed with proper isolation annotations.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: Internationalization support (5 languages)
Added i18n infrastructure with initial 5 language translations. Regenerated Xcode project to include resources.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | backlog | n/a |

### Feature: International regions — cities & provinces expansion (#76)
Expanded state/province tracking beyond US/CA to international countries.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### iOS workflow migration to shared ios-infra
Migrated build and TestFlight workflows to shared infrastructure pattern with macos-26 runner fallback.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

---

## Jan 29, 2026

### Bug: Onboarding location permission uses wrong method (#72)
LocationManager called incorrect method for requesting permission during onboarding.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Bucket list feature broken + missing onboarding (#71)
Bucket list mode had bugs preventing proper use. Added onboarding tutorial to explain the feature.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Photo import geocoding too slow (#70)
Increased geocoding concurrency 10x with detailed logging for debugging.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: PhotoLocationStore concurrency crash (#69)
`PhotoLocationStore` not marked as `@MainActor`, causing data races.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: Apple Photos import — resume and coastal detection (#60)
Added incremental scanning (only new photos), resume from saved progress, GeoJSON boundary fallback for coastal photos that geocoding misses (500m tolerance, 8-direction check).
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: TestFlight build version numbers not passed (#67)
xcodebuild wasn't receiving version numbers, causing build rejection.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Bug: iOS build runner compatibility (#63-#66)
Multiple iterations to find working runner config: macos-15 with Xcode 16, private EnumerationResult type, Equatable conformance for ImportStatistics.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

---

## Jan 28, 2026

### Feature: Timeline, transit, continents, timezones, badges, leaderboard (#58)
Major feature batch: travel timeline with departure dates, transit vs visited distinction, continent breakdown, timezone coverage, 21 badge definitions, friends leaderboard. 205 backend tests.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Bug: SwiftData migration error on launch
New `status` field had no default value, breaking lightweight migration. Added default + graceful DatabaseErrorView with reset option.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: TestFlight crash on launch (#59)
Hardcoded `aps-environment=development` in entitlements caused push notification failure in TestFlight. Also: `fatalError` in ModelContainer init, force cast in background task, deprecated `keyWindow` access.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Cleanup: Close 10 issues, fix bugs, remove 219 lines (#57)
Closed 10 completed issues (auth, push, feedback, bucket list, etc.). Removed trivial/placeholder tests. Consolidated duplicate code.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | done |

---

## Jan 27, 2026

### Feature: Bucket list mode (#56)
Mark countries you want to visit. Separate tracking from visited places.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Feature: Comprehensive App Store asset pipeline
Fastlane deliver integration, metadata management, screenshots, app icon. Multiple fixes for App Store validation (emoji stripping, category casing, deprecated options).
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: TestFlight automated distribution (#55)
Automatic upload and distribution to internal testers on every main push. Export compliance, beta groups, JWT-based API auth.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Bug: iOS 26 SDK requirement (ITMS-90725)
App Store rejected build for not using iOS 26 SDK. Updated Xcode selection in workflows.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: Background photo monitoring and location tracking
Automatic detection of new locations via background location updates and photo library changes.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Local notifications for new location detection
Push notification when a new country/state is detected from background location or photos.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Sign in with Apple not working
Missing entitlements for Sign in with Apple. Fixed authentication flow.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Bug: Google Sign-In broken — wrong OAuth client type
Used web OAuth client instead of iOS client. Fixed with PKCE flow and proper branding.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Feature: Self-hosted runner support with GitHub-hosted fallback
iOS build workflows try self-hosted Mac runner first, fall back to GitHub-hosted macos-26 if unavailable.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Bug: Release build errors — DEBUG-only code not guarded
Code using debug-only APIs compiled in Release mode, causing build failures.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Infrastructure: Migrate to personal AWS account
Cross-account domain setup to bridge domain in default account with infrastructure in personal account.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | done | done |

---

## Jan 26, 2026

### Feature: Apple and Google Sign In authentication
Full authentication flow with both providers. Token persistence in Keychain.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Feature: Unified import UI with photo enhancements
Combined import sources into single flow. Updated bundle ID for new Apple Developer account.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

---

## Jan 24-25, 2026

### Feature: Apple Photos library import (#48)
Import visited countries from photo GPS data. Lambda timeout increased to 10 minutes for processing.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Feature: Marketing website with React/Vite (#49)
Landing page at footprintmaps.com with auto-deploy to S3/CloudFront.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | done | n/a |

### Feature: Feedback and feature request system (#10)
In-app feedback submission with backend storage.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | done | done |

### Bug: UserResponse model mismatch
iOS model didn't match actual API response shape, causing decode failures.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: API subdomain and website hosting infrastructure
Set up api.footprintmaps.com, Route53 DNS, S3 website hosting, CloudFront CDN.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | done | done |

---

## Jan 23, 2026

### Feature: Friends list and sharing (backend)
Social features: contacts integration, friend lists, sharing visited places.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Feature: iOS Widget preparation
App Group data sharing for widget extension. Widget shows visited count and recent places.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Live location tracking
Background location monitoring to auto-detect new countries/states visited.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Map tap-to-toggle, split territories, state visualization, accessibility (#8)
Tap country on map to toggle visited status. Split overseas territories. State-level map coloring. VoiceOver support for map.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### UI: Thinner US/CA country borders
Reduced border width from default to 1.5px for cleaner look.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

---

## Jan 20, 2026

### Rename: Skratch to Footprint
Full rename of app, bundle ID, and all code references.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | done |

### Feature: Country list grouped by continent (#7)
Collapsible continent sections in country list view.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Bug: Authentication button issues (#6)
Sign-in buttons not responding to taps. Fixed action handlers.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: MapKit country boundary visualization (#5)
Custom map overlays showing country boundaries with visited/unvisited coloring.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |

### Feature: Backend test suite
Comprehensive API route tests, service unit tests, pre-commit hooks.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| n/a | n/a | n/a | done |

### Feature: iOS unit tests for API client and data layer
XCTest coverage for networking and SwiftData operations.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | n/a | n/a | n/a |

### Feature: Settings screen and sync improvements
User preferences, sync status display, manual sync trigger.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | done |

### Bug: Map overlays rendering incorrectly
Fixed GeoJSON overlay rendering and improved country list UX.
| iOS | Android | Web | API |
|-----|---------|-----|-----|
| done | backlog | n/a | n/a |
