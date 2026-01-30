# Footprint iOS App - Internationalization Guide

## Overview
This guide describes the internationalization (i18n) implementation for the Footprint travel tracker iOS app, supporting 20+ languages to make the app accessible worldwide.

## Supported Languages (Initial 5 + Planned 15)

### Phase 1 - Implemented (5 languages)
- **English (en)** - Base language
- **Spanish (es)** - 500M+ speakers
- **French (fr)** - 280M+ speakers  
- **German (de)** - 130M+ speakers
- **Japanese (ja)** - 125M+ speakers

### Phase 2 - Planned (15 additional languages)
- **Mandarin Chinese (zh-CN)** - 918M+ speakers
- **Portuguese (pt)** - 260M+ speakers
- **Russian (ru)** - 258M+ speakers
- **Italian (it)** - 65M+ speakers
- **Korean (ko)** - 77M+ speakers
- **Dutch (nl)** - 24M+ speakers
- **Polish (pl)** - 45M+ speakers
- **Turkish (tr)** - 79M+ speakers
- **Arabic (ar)** - 422M+ speakers
- **Hebrew (he)** - 9M+ speakers
- **Thai (th)** - 60M+ speakers
- **Vietnamese (vi)** - 76M+ speakers
- **Swedish (sv)** - 10M+ speakers
- **Norwegian (no)** - 5M+ speakers
- **Danish (da)** - 6M+ speakers

## File Structure
```
ios/Footprint/Resources/
├── en.lproj/
│   └── Localizable.strings     # English (base)
├── es.lproj/
│   └── Localizable.strings     # Spanish
├── fr.lproj/
│   └── Localizable.strings     # French
├── de.lproj/
│   └── Localizable.strings     # German
├── ja.lproj/
│   └── Localizable.strings     # Japanese
└── INTERNATIONALIZATION_GUIDE.md  # This file
```

## Localization System

### 1. String Categories
All user-facing strings are organized into logical categories:

- **Tab Bar**: Navigation tab titles
- **Authentication**: Sign-in/out, offline mode
- **Sync**: Synchronization status and messages  
- **Location & Permissions**: Location tracking settings
- **Import**: Photo and data import features
- **Data Management**: Backup, restore, delete operations
- **App Information**: Version, build info
- **Countries & Places**: Geographic content
- **Stats**: Travel statistics and achievements
- **Onboarding**: First-time user experience
- **Map & UI Controls**: Interactive map elements
- **Common Actions**: Cancel, OK, Done, etc.
- **Accessibility**: Screen reader labels
- **Error Messages**: User-friendly error text
- **Geographic Terms**: Continent, country, state names

### 2. Usage Patterns

#### Type-Safe Localization (Recommended)
Use the L10n enum for compile-time safety:
```swift
Text(L10n.Tab.map)                    // "Map" / "Mapa" / "Carte"
Text(L10n.Auth.signedIn)             // "Signed In" / "Sesión iniciada"
Text(L10n.Onboarding.Welcome.title)  // "Welcome to Footprint"
```

#### String Parameters
For dynamic content with parameters:
```swift
Text(L10n.Auth.signedInWith("Google"))  // "Signed in with Google"
Text(L10n.Data.clearAllConfirmation(visitedPlaces.count))  // "This will remove all 42 visited places."
```

#### Simple Localization Extension
For basic strings:
```swift
Text("tab.map".localized)           // Uses NSLocalizedString
Text("error.unknown".localized)     // Fallback to key if missing
```

### 3. Best Practices

#### String Key Naming
- Use hierarchical dot notation: `"category.subcategory.item"`
- Keep keys descriptive: `"onboarding.location.benefit.battery"`
- Use consistent prefixes: `tab.`, `auth.`, `sync.`, `stats.`

#### Handling Plurals
For languages with complex plural rules:
```swift
// English: "1 country" vs "5 countries"  
// Use .stringsdict files for proper pluralization
let format = NSLocalizedString("stats.countries_count", comment: "Countries count")
Text(String.localizedStringWithFormat(format, count))
```

#### Text Expansion
Account for text length variations:
- German text can be 35% longer than English
- Chinese/Japanese can be 30% shorter  
- Arabic/Hebrew require RTL layout support

#### Cultural Considerations
- Date/time formatting per locale using `DateFormatter`
- Number formatting using `NumberFormatter`
- Currency display for travel expenses
- Cultural color associations (red = luck in China, danger in West)

## Implementation Details

### 1. Xcode Configuration
1. **Project Settings**: Ensure all target languages are enabled in Xcode
2. **Info.plist**: Set `CFBundleDevelopmentRegion` and `CFBundleLocalizations`
3. **Storyboard Localization**: Not used (SwiftUI-only app)

### 2. Testing Different Languages
```bash
# Test in iOS Simulator
# Settings > General > Language & Region > iPhone Language

# Test with different locale in code
override func setUp() {
    UserDefaults.standard.set(["es"], forKey: "AppleLanguages")
    UserDefaults.standard.synchronize()
}
```

### 3. Accessibility Integration
All localized strings include accessibility labels:
```swift
.accessibilityLabel(L10n.Accessibility.visitedStatus(country.name, 
                    isVisited ? L10n.Accessibility.visited : L10n.Accessibility.notVisited))
```

### 4. Dynamic Type Support
Ensure UI adapts to text size changes:
```swift
Text(localizedString)
    .font(.body)
    .lineLimit(nil)  // Allow text wrapping
    .minimumScaleFactor(0.8)  // Scale down if needed
```

## Adding New Languages

### Step 1: Create Language Directory
```bash
mkdir -p ios/Footprint/Resources/[language].lproj
```

### Step 2: Copy and Translate Strings
1. Copy `en.lproj/Localizable.strings` to new directory
2. Translate all string values (keep keys unchanged)
3. Ensure proper encoding (UTF-8) for special characters

### Step 3: Update Xcode Project
1. Add new .lproj folder to Xcode project
2. Update project localizations list
3. Test with new language selected in simulator

### Step 4: Quality Assurance
- [ ] Test all major user flows in new language
- [ ] Verify UI layout handles text expansion/contraction  
- [ ] Check special characters render correctly
- [ ] Test accessibility with VoiceOver in new language
- [ ] Verify number/date formatting

## RTL Language Support (Arabic, Hebrew)

### Layout Considerations
```swift
HStack {
    // Automatically flips for RTL
    Image(systemName: "chevron.right")
    Text(localizedString)
}
.environment(\.layoutDirection, .rightToLeft) // Force RTL for testing
```

### Text Alignment
```swift
Text(localizedString)
    .multilineTextAlignment(.leading)  // Automatically adapts to RTL
    .frame(maxWidth: .infinity, alignment: .leading)
```

## Performance Considerations

### 1. Lazy Loading
Strings are loaded on-demand by iOS, not all at app launch.

### 2. Bundle Size
Each language adds ~50KB to app bundle. Consider on-demand language downloads for lesser-used languages.

### 3. Memory Usage
NSLocalizedString caches frequently used strings automatically.

## Maintenance Workflow

### Adding New Strings
1. Add string to base `en.lproj/Localizable.strings`
2. Update `Localizable.swift` enum with type-safe accessor
3. Translate to all supported languages
4. Test in multiple languages

### String Auditing
```bash
# Find untranslated strings
genstrings -o . **/*.swift
diff en.lproj/Localizable.strings Localizable.strings
```

### Automated Translation Validation
Consider integrating tools like:
- Crowdin for community translations
- Google Translate API for initial drafts
- Professional translation services for final review

## Common Issues and Solutions

### 1. Missing Translations
- Fallback: iOS displays the string key if translation missing
- Solution: Use base language fallback in code

### 2. Text Truncation
- Problem: UI elements too small for translated text
- Solution: Use flexible layouts and test with longest text

### 3. Incorrect String Formatting
- Problem: Parameter order differs in some languages
- Solution: Use positional parameters: `%1$@ visited %2$d countries`

### 4. Context Ambiguity  
- Problem: Same English word has different translations based on context
- Solution: Use descriptive keys and comments

## Future Enhancements

### 1. On-Demand Language Downloads
Download language packs as needed to reduce initial app size.

### 2. Machine Learning Translation
Use Core ML to provide basic translations for unsupported languages.

### 3. User-Contributed Translations
Allow users to suggest improvements to translations through in-app feedback.

### 4. Regional Variants
Support regional differences (e.g., `en-US` vs `en-GB`, `es-ES` vs `es-MX`).

---

## Testing Checklist

Before releasing with new language support:

- [ ] All strings translated and contextually appropriate
- [ ] UI layouts handle text length variations
- [ ] Number, date, currency formatting correct for locale
- [ ] Accessibility labels work with local screen readers
- [ ] App Store metadata translated (title, description, keywords)
- [ ] Customer support prepared for new languages
- [ ] Marketing materials localized for target regions

---

*This guide should be updated whenever new strings are added or languages are supported.*
