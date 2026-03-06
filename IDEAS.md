# Footprint - Feature Ideas & Roadmap

## The Vision
Become the definitive travel tracking app: the deepest sub-national coverage, the smartest auto-import, and the most delightful visualization. No data loss, ever.

---

## Tier 1: Core Differentiators (next release)

### 1. Redesign App Icon
**Priority: HIGH** | iOS
The current icon has generic green blobs that don't read as real countries. Needs a redesign:
- **Option A — Globe with Real Continents**: A stylized globe (similar angle to current) but with recognizable simplified continent outlines. 3-4 visited countries highlighted in accent color with small pins. The rest in a muted tone. Clean, modern, Apple-esque.
- **Option B — US Map with States**: Close-up view of the US map with ~8 states filled in different warm colors (coral, amber, teal). A single pin on one state. Conveys "we track at the state level" immediately. More distinctive than generic globe icons.
- **Option C — Passport Stamp**: A stylized passport stamp circle with "FOOTPRINT" text, a small plane silhouette, and colorful geometric country shapes around it. Unique in the category.
- **Recommendation**: Option A with real continent silhouettes. The globe concept is right (travel = world), but the shapes must be instantly recognizable. Use a slightly tilted globe showing Europe/Africa/Americas. 3 pins in coral/amber/teal on highlighted countries. Subtle gradient on the ocean. Dark navy background like current. Consider hiring a designer on Fiverr/99designs for the final asset.

### 2. Coverage Percentage Per Country
**Priority: HIGH** | iOS, Backend
- When you visit states/provinces within a country, show "You've explored 23% of France"
- Heat map intensity based on coverage (light green = 1 state, dark green = 50%+)
- Progress rings on country detail view
- No competitor does this at depth

### 3. Head-to-Head Friend Comparison Map
**Priority: HIGH** | iOS
- Side-by-side or overlay map: green = only you, blue = only them, purple = both visited
- Tap a region to see who visited it and when
- One-tap share as Instagram Story-sized image
- Drives viral sharing

### 4. Travel Timeline Map Playback
**Priority: HIGH** | iOS
- Animate your map chronologically -- watch countries fill in over time
- Slider or play button to scrub through your travel history
- Screenshot any frame to share
- "Your first country was France in 2015"

---

## Tier 2: Social & Engagement

### 5. Digital Passport Stamps
**Priority: MEDIUM** | iOS
- When marking a new country, show animated passport stamp with flag + date
- Collectible passport view showing all stamps
- Stamps have regional styles (EU looks different from Asia)
- Shareable stamp grid image

### 6. Travel Challenges & Streaks
**Priority: MEDIUM** | iOS, Backend
- "Visit a new country this quarter"
- "Complete the Nordic countries"
- "Visit all 6 inhabited continents"
- Seasonal challenges (Summer: "Visit 3 coastal countries")
- Streak tracking: "You've visited a new place every month for 6 months"
- Challenge completion badges

### 7. "On This Day" Travel Memories
**Priority: MEDIUM** | iOS
- Daily notification: "3 years ago today, you were in Tokyo"
- Surface photos from that trip
- Drives daily re-engagement without feeling spammy

### 8. Group Trips
**Priority: MEDIUM** | iOS, Backend
- Create a shared trip with friends
- Everyone contributes photos, check-ins, notes
- Shared trip timeline and map
- Trip recap/summary at the end

### 9. Travel Milestones with Push
**Priority: LOW** | iOS, Backend
- "You've visited your 25th country!"
- "You've now explored more than 90% of Footprint users"
- Milestone moments drive sharing and retention

---

## Tier 3: Data & Visualization

### 10. UNESCO World Heritage Sites
**Priority: MEDIUM** | iOS, Backend | Issue #46
- 1,199 sites with map overlay
- Check them off as visited
- Statistics: "You've visited 47 of 1,199 UNESCO sites"
- Filter by type (cultural, natural, mixed)
- Country detail view shows UNESCO sites in that country

### 11. National Parks Tracking
**Priority: MEDIUM** | iOS, Backend | Issue #40
- US National Parks (63 parks) as Phase 1
- Dedicated map layer with park boundaries
- Park-specific badges and stats
- Expand to international parks later

### 12. Cities & Landmarks
**Priority: MEDIUM** | iOS, Backend | Issue #18
- Major cities (capital cities + top 500 by population)
- Famous landmarks as trackable pins
- Auto-detect from photo GPS data
- "You've visited 12 capital cities"

### 13. Rich Statistics Dashboard
**Priority: MEDIUM** | iOS
- Furthest north/south/east/west points visited
- Days spent abroad per year chart
- Most visited country heat map
- Average trip duration trends
- Distance traveled estimation
- Hemisphere completion (N/S, E/W)

### 14. Carbon Footprint Estimation
**Priority: LOW** | iOS
- Estimate travel carbon based on trip distances
- Assume flight for international, car for domestic
- Show cumulative and per-trip stats
- 2026 sustainability trend -- differentiator

---

## Tier 4: Import & Integrations

### 15. Google Maps Timeline Import
**Priority: HIGH** | iOS
- Import from Google Takeout KML/JSON export
- Maps Timeline has precise travel history
- One-time import fills in years of travel history
- Massive friction reducer for new users

### 16. Instagram Location Import
**Priority: LOW** | iOS
- Parse Instagram data export for location tags
- "You posted from 23 countries on Instagram"

### 17. Siri Shortcuts
**Priority: LOW** | iOS | Issue #47
- "Hey Siri, add France to my visited countries"
- "How many countries have I visited?"
- Quick action from Lock Screen

### 18. Apple Watch Companion
**Priority: LOW** | iOS | Issue #43
- Complication showing country count
- Quick-add from wrist when traveling
- Travel stats glance

---

## Tier 5: Platform & Growth

### 19. More Sub-National Regions
**Priority: MEDIUM** | iOS, Backend
Countries to add state/province tracking for:
- China (34 provinces)
- India (28 states)
- Japan (47 prefectures)
- Turkey (81 provinces)
- South Korea (17 provinces)
- Indonesia (38 provinces)
- Norway, Sweden, Finland (regions)
- Poland, Czech Republic (regions)
This expands the completionist appeal massively.

### 20. Visa & Entry Requirements
**Priority: LOW** | iOS, Backend
- Set your passport country in settings
- Bucket list countries show visa requirements
- "Visa-free", "Visa on arrival", "eVisa", "Embassy required"
- Use Sherpa/IATA Timatic API

### 21. "Explore Nearby" Suggestions
**Priority: LOW** | iOS
- "You've been to 3 of 8 provinces near you"
- Suggest unvisited regions within driving distance
- Weekend trip inspiration

### 22. Printable Travel Map Poster
**Priority: MEDIUM** | iOS
- Generate a high-res world map with your visited countries
- Print-ready PDF (A2/A3 sizes)
- Choose color scheme, include name and stats
- Visited app charges for this -- opportunity to include free or in Pro tier

### 23. Android Feature Parity
**Priority: HIGH** | Android
- Currently ~20% scaffolding
- Needs full feature implementation
- Doubles addressable market

### 24. Lock Screen Widgets
**Priority: MEDIUM** | iOS
- Country count
- Next bucket list destination
- Random travel memory photo
- Travel streak counter

### 25. Monetization: Footprint Pro
**Priority: HIGH** | iOS, Backend
- Free tier: 195 countries + US states, basic map, manual entry, 3 badges, 1 widget
- Pro ($19.99/year or $2.99/month, $49.99 lifetime):
  - All sub-national tracking
  - Photo auto-import
  - Year in Review
  - All badges and challenges
  - All widget styles
  - UNESCO + National Parks
  - Friend comparison maps
  - Export/print maps
  - Carbon footprint
- Lifetime option is critical for this category

---

## Completed Features (for reference)
- Interactive world map (195 countries)
- US states (50 + DC) and Canadian provinces (13)
- Sub-national tracking for 8 more countries (RU, UK, FR, IT, ES, NL, BE, AR)
- Apple Photos GPS import with trip clustering
- Sign in with Apple + Google auth
- Offline-first with cloud sync
- iOS widgets
- Background location tracking
- Push notifications for new location detection
- Badges & achievements (21 badges)
- Travel timeline with visit dates
- Transit vs visited distinction
- Continent + timezone statistics
- Friends leaderboard
- Bucket list mode
- Year in Review (Spotify Wrapped style)
- Photos & Memories tab
- Data export as shareable images
- 11 language localizations
- Animated splash screen
- Accessibility (VoiceOver, Dynamic Type)
- Marketing website (footprintmaps.com)
- Feedback system
