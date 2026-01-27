# App Store Preview Video Plan for Footprint

## Video Specifications

**Duration**: 30 seconds (maximum)
**Format**: MP4, H.264 encoding
**Resolution**:
- iPhone: 1080x1920 (9:16 aspect ratio)
- iPad: 1200x1600 (3:4 aspect ratio)
**Frame Rate**: 30 fps
**Audio**: None (App Store videos autoplay muted)
**File Size**: Under 500 MB

## Video Script & Storyboard (30 seconds)

### Scene 1: App Launch & Authentication (0-4 seconds)
**Visual**: App icon animation → Login screen → "Continue without account"
**Text Overlay**: "Track your travels beautifully"
**Action**: Quick tap on "Continue without account"

### Scene 2: World Map Overview (4-12 seconds)
**Visual**: Zoom out to show full world map with visited countries highlighted
**Text Overlay**: "Mark countries you've visited"
**Action**:
- Pan across map showing green visited countries
- Zoom focus on different continents (Europe, Asia, Americas)
- Show country count: "23 countries visited"

### Scene 3: Adding a New Country (12-18 seconds)
**Visual**: Tap on an unvisited country (e.g., Japan)
**Text Overlay**: "Just tap to mark as visited"
**Action**:
- Finger tap animation on Japan
- Country highlights in green
- Small celebration animation
- Counter updates: "24 countries visited"

### Scene 4: Statistics View (18-24 seconds)
**Visual**: Swipe to Stats tab showing progress bars
**Text Overlay**: "See your travel progress"
**Action**:
- Show animated progress bars filling up
- Countries: 24/195
- US States: 7/50
- Canadian Provinces: 3/13

### Scene 5: Import Feature Preview (24-28 seconds)
**Visual**: Quick glimpse of Settings → Import Sources
**Text Overlay**: "Import from photos & Gmail"
**Action**:
- Show import options briefly
- Photos, Gmail, Calendar icons visible

### Scene 6: Call to Action (28-30 seconds)
**Visual**: Return to map view with full footprint
**Text Overlay**: "Start your journey today"
**Action**:
- Final pan across beautiful world map
- App icon appears in corner

## Text Overlays & Timing

| Time | Text | Duration | Position |
|------|------|----------|----------|
| 0-4s | "Track your travels beautifully" | 4s | Top center |
| 4-12s | "Mark countries you've visited" | 8s | Top center |
| 12-18s | "Just tap to mark as visited" | 6s | Bottom center |
| 18-24s | "See your travel progress" | 6s | Top center |
| 24-28s | "Import from photos & Gmail" | 4s | Top center |
| 28-30s | "Start your journey today" | 2s | Center |

## Recording Instructions

### Device Setup
```bash
# Use iPhone 17 Pro Max for recording
# Simulator: iPhone 17 Pro Max (iOS 17)
# Recording: QuickTime Player screen recording at 30fps

# Launch with sample data for attractive visuals
xcrun simctl launch booted com.footprint.app -SampleDataMode YES -DisableAnimations YES
```

### Screen Recording Steps

#### Pre-Recording Setup
1. **Clean simulator state**:
   - Reset simulator: Device → Erase All Content and Settings
   - Launch with sample data: `-SampleDataMode YES`
   - Disable animations: `-DisableAnimations YES`
   - Set time to 9:41 AM (classic iOS demo time)

2. **QuickTime setup**:
   - File → New Screen Recording
   - Select iPhone simulator
   - Set to record at 30fps
   - Ensure simulator is at 100% scale

#### Recording Sequence
1. **Start recording before app launch**
2. **Scene 1 (0-4s)**: Launch app, quickly tap "Continue without account"
3. **Scene 2 (4-12s)**: Let map load, slow pan across continents
4. **Scene 3 (12-18s)**: Tap Japan to mark as visited, brief pause for animation
5. **Scene 4 (18-24s)**: Tap Stats tab, let progress bars animate
6. **Scene 5 (24-28s)**: Quick Settings → Import Sources → back
7. **Scene 6 (28-30s)**: Return to Map tab, final overview

#### Timing Tips
- Practice the sequence multiple times before recording
- Use deliberate, slow movements for clarity
- Allow 1-2 second pauses after major actions
- Keep finger touches visible but brief

## Post-Production Checklist

### Video Editing
- [ ] Trim to exactly 30 seconds
- [ ] Add text overlays with timing from table above
- [ ] Ensure smooth transitions between scenes
- [ ] Remove any UI glitches or loading states
- [ ] Add subtle fade-in/fade-out effects

### Text Overlay Style
- **Font**: San Francisco (iOS system font)
- **Size**: 28pt for main text, 24pt for secondary
- **Color**: White with 20% black shadow for readability
- **Animation**: Fade in over 0.5s, hold, fade out over 0.5s
- **Position**: Safe area aware, never cover important UI

### Quality Control
- [ ] Verify video plays smoothly on all Apple devices
- [ ] Test with sound off (App Store default)
- [ ] Check text is readable on small screens
- [ ] Ensure no copyrighted content visible
- [ ] Verify sample data looks realistic

## Alternative Video Concepts

### Concept B: Journey Story
- Start with empty map
- Show rapid progression of countries being added
- Timeline of adventures unfolding
- End with fully populated travel map

### Concept C: Feature Focus
- Split screen: before/after import
- Show photos being analyzed for GPS data
- Email confirmations being processed
- Map automatically populating

### Concept D: Comparison Style
- Side-by-side: old travel journal vs Footprint
- Show ease of digital tracking
- Highlight visual benefits

## Technical Implementation

### Automated Recording Script
```bash
#!/bin/bash
# record_preview_video.sh

echo "🎬 Recording App Store Preview Video"

# Setup simulator
xcrun simctl shutdown all
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl launch booted com.footprint.app -SampleDataMode YES -DisableAnimations YES

# Wait for app to load
sleep 3

echo "📱 Ready to record!"
echo "1. Open QuickTime Player"
echo "2. File → New Screen Recording"
echo "3. Select iPhone simulator"
echo "4. Follow the 30-second script"
echo "5. Save as 'Footprint_Preview_Video_Raw.mov'"

read -p "Press Enter when recording is complete..."

echo "✅ Recording complete!"
echo "📝 Next steps:"
echo "1. Edit video in iMovie or Final Cut Pro"
echo "2. Add text overlays according to timing table"
echo "3. Export as MP4, H.264, 1080x1920, 30fps"
echo "4. Upload to App Store Connect"
```

### Video Export Settings
```
Format: MP4
Codec: H.264
Resolution: 1080x1920 (Portrait)
Frame Rate: 30fps
Bitrate: 8-10 Mbps (high quality)
Audio: None (remove audio track)
Color Space: Rec. 709
```

## App Store Upload Requirements

### Video Files Needed
- **iPhone 6.9"** (1080x1920): Primary video
- **iPhone 6.3"** (1080x1920): Same video, different preview
- **iPad 12.9"** (1200x1600): Landscape version if needed

### Upload Process
1. **App Store Connect** → Your App → App Store tab
2. **App Previews** section
3. **Upload video for each device size**
4. **Add captions if needed** (recommended for accessibility)
5. **Preview on device** before submitting

## Accessibility Considerations

### Captions/Subtitles
Since the video has no audio narration, captions should describe the visual action:
- "User taps on Japan to mark as visited"
- "World map shows visited countries in green"
- "Statistics display travel progress"

### Visual Clarity
- High contrast text overlays
- Large, readable fonts
- Clear finger tap indicators
- Smooth, non-jarring transitions

## Success Metrics

### App Store Performance
- **Video Play Rate**: Target 60%+ of page visitors
- **Conversion Rate**: Compare with/without video
- **Engagement**: Full video completion rate

### Video Quality Indicators
- No dropped frames or stuttering
- Clear, readable text on small screens
- Compelling visual flow that tells a story
- Professional polish matching app quality

## Timeline

### Production Schedule
- **Day 1**: Record raw footage (multiple takes)
- **Day 2**: Edit and add text overlays
- **Day 3**: Review, refinements, export
- **Day 4**: Upload to App Store Connect
- **Day 5**: Test and finalize for submission

This comprehensive video plan ensures a professional, engaging App Store preview that showcases Footprint's key features and visual appeal within the 30-second limit.