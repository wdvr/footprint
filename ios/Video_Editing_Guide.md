# Video Editing Guide for Footprint App Store Preview

This guide provides step-by-step instructions for editing the recorded footage into a polished App Store preview video.

## Software Options

### Recommended: Final Cut Pro
- Professional features and precision
- Excellent text overlay capabilities
- Perfect for iOS video specifications

### Alternative: iMovie (Free)
- Simpler interface, good for basic editing
- Built-in templates work well for app videos
- Sufficient for our needs

### Alternative: DaVinci Resolve (Free)
- Professional-grade, completely free
- Advanced color grading and effects
- Steeper learning curve

## Video Editing Steps

### 1. Project Setup

#### Final Cut Pro Setup:
1. **New Project**:
   - Resolution: 1080x1920 (Portrait)
   - Frame Rate: 30fps
   - Color Space: Rec. 709

#### iMovie Setup:
1. **Create New Project**: Movie
2. **Import Media**: Drag your recorded .mov file
3. **Aspect Ratio**: We'll crop to portrait later

### 2. Basic Editing

#### Trim to Exactly 30 Seconds
```
Timeline markers:
0:00 - Start (app launch)
0:04 - Authentication bypass
0:12 - Map overview complete
0:18 - Country selection complete
0:24 - Stats view complete
0:28 - Import preview complete
0:30 - End (final map view)
```

#### Smooth Transitions
- Use 0.2-second crossfades between major scene changes
- No abrupt cuts within the same view
- Maintain visual flow throughout

### 3. Text Overlays

#### Typography Specifications
- **Font**: San Francisco (iOS system font) or Helvetica Neue
- **Weight**: Medium for headlines, Regular for secondary
- **Size**: 32pt for main text (scales with video resolution)
- **Color**: Pure white (#FFFFFF)
- **Shadow**: 20% black, 2px offset, 4px blur
- **Position**: Center-aligned, safe area aware

#### Text Animation Timing
```
Animation template:
- Fade In: 0.3 seconds
- Hold: [varies per scene]
- Fade Out: 0.3 seconds
- Overlap: 0.1 seconds between consecutive texts
```

### 4. Specific Text Overlays

#### Scene 1: App Launch (0-4 seconds)
```
Text: "Track your travels beautifully"
Timing: 0s → 4s
Position: Top third, centered
Font Size: 32pt
Animation: Fade in 0s-0.3s, Hold 0.3s-3.7s, Fade out 3.7s-4s
```

#### Scene 2: Map Overview (4-12 seconds)
```
Text: "Mark countries you've visited"
Timing: 4s → 12s
Position: Top third, centered
Font Size: 32pt
Animation: Fade in 4s-4.3s, Hold 4.3s-11.7s, Fade out 11.7s-12s
```

#### Scene 3: Interaction (12-18 seconds)
```
Text: "Just tap to mark as visited"
Timing: 12s → 18s
Position: Bottom third, centered (avoid covering map)
Font Size: 28pt
Animation: Fade in 12s-12.3s, Hold 12.3s-17.7s, Fade out 17.7s-18s
```

#### Scene 4: Statistics (18-24 seconds)
```
Text: "See your travel progress"
Timing: 18s → 24s
Position: Top third, centered
Font Size: 32pt
Animation: Fade in 18s-18.3s, Hold 18.3s-23.7s, Fade out 23.7s-24s
```

#### Scene 5: Import Features (24-28 seconds)
```
Text: "Import from photos & Gmail"
Timing: 24s → 28s
Position: Top third, centered
Font Size: 28pt
Animation: Fade in 24s-24.3s, Hold 24.3s-27.7s, Fade out 27.7s-28s
```

#### Scene 6: Call to Action (28-30 seconds)
```
Text: "Start your journey today"
Timing: 28s → 30s
Position: Center, centered
Font Size: 34pt, Bold
Animation: Fade in 28s-28.3s, Hold 28.3s-29.7s, Fade out 29.7s-30s
```

## Final Cut Pro Specific Instructions

### Text Setup
1. **Add Title**: Generators → Titles → "Custom"
2. **Position**: Use Transform tools, not keyframes initially
3. **Font Settings**: Inspector → Title tab → Text style
4. **Drop Shadow**: Inspector → Title tab → Face style → Drop Shadow

### Text Animation
1. **Opacity Keyframes**:
   - Set first keyframe at 0% opacity
   - Set second keyframe at 100% opacity (0.3s later)
   - Set third keyframe at 100% opacity (before fade out)
   - Set fourth keyframe at 0% opacity (0.3s later)

2. **Position Animation** (subtle):
   - Start 10px lower than final position
   - Animate to final position during fade in
   - Use "Ease In" transition

### Color Correction
1. **Brightness/Contrast**: Slightly boost contrast for crisp visuals
2. **Saturation**: Subtle boost to make map colors pop
3. **Color Balance**: Ensure neutral whites for text readability

## iMovie Specific Instructions

### Adding Text
1. **Titles**: Click "Titles" in the content library
2. **Choose Style**: "Lower Third" or "Centered" work best
3. **Drag to Timeline**: Position over video at correct timecode
4. **Edit Text**: Double-click in preview to edit

### Text Customization
1. **Font**: Click text in preview → Show Fonts
2. **Size**: Use slider in title controls
3. **Position**: Drag text in preview window
4. **Animation**: Choose "Fade In and Out" from dropdown

### Exporting from iMovie
1. **File** → **Share** → **File**
2. **Resolution**: High (1080p)
3. **Quality**: High
4. **Compress**: Better Quality
5. **Format**: MP4

## Export Specifications

### Final Output Settings
```
Format: MP4 (MPEG-4)
Video Codec: H.264
Resolution: 1080 x 1920 (Portrait)
Frame Rate: 30 fps
Bitrate: 8-10 Mbps (VBR)
Audio: None (remove audio track entirely)
Color Profile: Rec. 709
File Size: Under 500MB (typically 50-100MB)
```

### Quality Control Checklist
- [ ] Video is exactly 30.00 seconds
- [ ] Resolution is 1080x1920 (portrait)
- [ ] No audio track present
- [ ] All text is readable on small screens
- [ ] Text doesn't cover important UI elements
- [ ] Animations are smooth and professional
- [ ] File size is under 500MB
- [ ] Video plays correctly on iOS devices

### Export Commands

#### Final Cut Pro:
```
File → Share → Master File
- Video: H.264, 1080x1920
- Audio: None
- Color Space: Rec. 709
```

#### FFmpeg (Command Line):
```bash
ffmpeg -i input_video.mov -vf "scale=1080:1920" -c:v libx264 -b:v 8M -r 30 -an -pix_fmt yuv420p output_video.mp4
```

## Advanced Techniques

### Subtle Effects
1. **Zoom Animation**: Very slight (102% to 100%) during key moments
2. **Color Highlights**: Brief saturation boost when countries are marked
3. **Glow Effect**: Subtle glow on "visited" countries during animation

### Professional Polish
1. **Consistent Pacing**: Each scene should feel intentional, not rushed
2. **Visual Hierarchy**: Most important elements should be most prominent
3. **Brand Consistency**: Colors and fonts should match app design
4. **Accessibility**: High contrast text, readable on all devices

### Testing the Final Video
1. **Preview on iPhone**: AirDrop to device and play full-screen
2. **Test on iPad**: Ensure video scales appropriately
3. **Silent Viewing**: Ensure story is clear without audio
4. **Multiple Viewers**: Get feedback from others unfamiliar with the app

## Troubleshooting Common Issues

### Text Not Readable
- Increase font size
- Add stronger drop shadow
- Choose higher contrast background moments

### Video Too Fast/Slow
- Adjust speed in 0.1x increments
- Ensure critical actions are visible for at least 1 second
- Don't rush through complex UI

### Export Issues
- Check aspect ratio settings
- Verify no audio track is included
- Ensure H.264 codec is selected
- Test file plays on iOS devices

### File Size Too Large
- Reduce bitrate slightly (7-8 Mbps)
- Check for unnecessary high-motion scenes
- Ensure video is exactly 30 seconds

This comprehensive editing guide ensures your App Store preview video meets professional standards and effectively showcases Footprint's key features within the required constraints.