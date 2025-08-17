# User Manual

Complete guide for end users of the Apple Maps Demo audio tour application.

## Overview

The Apple Maps Demo is an intelligent audio tour application that provides immersive, location-based experiences. The app automatically plays audio content when you arrive at points of interest and adapts to your movement type (walking, driving, or cycling).

## Getting Started

### First Launch Setup

#### 1. Grant Location Permission

When you first open the app, you'll be prompted for location access:

- **"Allow While Using App"**: Basic functionality
- **"Allow Always"** (Recommended): Full background features

> **Tip**: You can change this later in iOS Settings → Privacy & Security → Location Services

#### 2. Configure Audio Settings

Navigate to **Settings** to configure:
- **Voice Speed**: Adjust playback speed (0.5x to 2.0x)
- **Auto-play**: Enable automatic audio when entering POI areas
- **Background Audio**: Continue playing when app is minimized

#### 3. Optional: Add OpenAI API Key

For AI-generated content:
1. Go to **Settings** → **API Configuration**
2. Enter your OpenAI API key
3. Select your preferred model (GPT-4 recommended)

## Main Interface

### Tab Navigation

The app has four main sections:

#### 🗺️ Map Tab
- **Interactive map** showing your location
- **POI markers** for points of interest
- **Tour routes** displayed as colored lines
- **Current position** with heading indicator

#### 🎯 Tours Tab
- **Browse available tours** by category
- **Search tours** by name or location
- **Filter tours** by difficulty, duration, or type
- **Download tours** for offline use

#### 🎵 Player Tab
- **Audio player controls** (play, pause, skip)
- **Volume and speed controls**
- **Current POI information**
- **Playback queue** showing upcoming content

#### ⚙️ Settings Tab
- **General preferences** (language, units)
- **Audio settings** (voice, quality)
- **Content settings** (downloads, cache)
- **API configuration** (OpenAI key)

## Using Tours

### Discovering Tours

#### Browse by Category
- **Historical**: Museums, monuments, historic districts
- **Cultural**: Art galleries, cultural sites, local traditions
- **Nature**: Parks, trails, scenic viewpoints
- **Culinary**: Food tours, markets, restaurant districts
- **Architecture**: Buildings, urban design, landmarks

#### Search and Filter
- **Search bar**: Enter tour name or location
- **Difficulty filter**: Easy, Moderate, Challenging
- **Duration filter**: Under 1 hour, 1-3 hours, 3+ hours
- **Tour type**: Walking, Driving, Mixed

### Starting a Tour

#### 1. Select Your Tour
1. Tap on a tour in the Tours tab
2. Review tour information and map
3. Check estimated duration and difficulty
4. Tap **"Start Tour"**

#### 2. Tour Begins
- Map switches to show tour route
- Your location appears as blue dot
- POI markers show as numbered pins
- Audio queue loads with tour content

#### 3. Move to First POI
- Navigate toward first POI marker
- Audio automatically starts when you enter the area
- Follow route suggestions or explore freely

### During the Tour

#### Automatic Audio Playback
- **Geofence Entry**: Audio starts when you enter POI area
- **Walking Tours**: ~30 second delay for listening time
- **Driving Tours**: ~5 second delay for quick access
- **Mixed Tours**: Adapts based on your detected speed

#### Manual Controls
- **Play/Pause**: Tap center button
- **Skip Forward**: Tap +30s button
- **Skip Backward**: Tap -30s button
- **Volume**: Use device volume or in-app slider
- **Speed**: Adjust in player settings (0.5x to 2.0x)

#### Map Interaction
- **Zoom**: Pinch to zoom in/out
- **Pan**: Drag to explore area
- **POI Info**: Tap markers for details
- **Your Location**: Tap location button to recenter

## Audio Player Features

### Player Controls

#### Basic Controls
- **Play/Pause**: Center button
- **Previous**: Skip to previous POI
- **Next**: Skip to next POI
- **Progress Bar**: Drag to seek within current audio

#### Advanced Controls
- **Speed Control**: 0.5x, 0.75x, 1x, 1.25x, 1.5x, 2x
- **Volume**: Independent from device volume
- **Crossfade**: Smooth transitions between POI content
- **Queue Management**: Reorder or skip upcoming content

### Now Playing Information
- **POI Name**: Current point of interest
- **Tour Progress**: X of Y POIs completed
- **Time Remaining**: For current audio
- **Total Duration**: Estimated tour completion time

### Background Playback
- Audio continues when you minimize the app
- Control from iOS Control Center
- CarPlay integration (if available)
- Lock screen controls available

## Offline Features

### Downloading Tours

#### Automatic Downloads
- **Smart Caching**: Frequently visited tours cached automatically
- **Predictive Loading**: Upcoming POI content pre-downloaded
- **Background Downloads**: Content downloads when on WiFi

#### Manual Downloads
1. Go to **Tours** tab
2. Tap tour you want to download
3. Tap **"Download for Offline"**
4. Choose quality level:
   - **High**: Best quality, larger files
   - **Medium**: Balanced quality/size
   - **Low**: Smaller files for limited storage

### Using Offline Mode
- Tours work completely offline once downloaded
- GPS still functions without internet
- Map tiles cached for offline viewing
- No AI-generated content (uses pre-recorded audio)

### Managing Storage
Go to **Settings** → **Content Settings**:
- **Storage Usage**: See how much space tours use
- **Clear Cache**: Free up space
- **Auto-cleanup**: Automatically remove old content
- **Download Quality**: Change default quality

## CarPlay Integration

### Setup
1. Connect iPhone to CarPlay-enabled vehicle
2. Launch app on iPhone
3. CarPlay interface appears automatically
4. Use vehicle's touchscreen or controls

### CarPlay Features

#### Map Template
- **Tour route** displayed on vehicle screen
- **POI markers** with distance information
- **Turn-by-turn guidance** (if enabled)
- **Large touch targets** for safety

#### Now Playing Template
- **Track information** showing current POI
- **Album art** using POI images
- **Media controls** integrated with vehicle
- **Voice commands** support

#### Tour Selection
- **Browse tours** from vehicle screen
- **Start tours** without touching phone
- **Quick actions** for favorite tours

### Safety Features
- **Voice-first design** minimizes distraction
- **Large buttons** easy to use while driving
- **Audio-focused** interface
- **Automatic transitions** require no interaction

## Accessibility Features

### VoiceOver Support
- **Full VoiceOver** compatibility
- **Descriptive labels** for all buttons
- **Audio descriptions** for visual elements
- **Navigation hints** for complex interfaces

### Dynamic Type
- **Text scaling** from small to accessibility sizes
- **Layout adaptation** maintains usability
- **Bold text** support for better visibility

### Motor Accessibility
- **Large touch targets** throughout app
- **Switch Control** compatibility
- **Voice Control** integration
- **Reduced motion** options

### Visual Accessibility
- **High contrast** mode support
- **Color blind** friendly design
- **Smart Invert** compatibility
- **Reduce transparency** support

## Troubleshooting

### Location Issues

#### "Location Not Available"
1. Check iOS Settings → Privacy & Security → Location Services
2. Ensure Location Services enabled for app
3. Try moving outdoors for better GPS signal
4. Restart app if location seems stuck

#### "Geofences Not Triggering"
1. Ensure "Always" location permission granted
2. Check that you're within POI radius (shown on map)
3. Walk slowly around POI area
4. Verify tour is active and POI is next in sequence

### Audio Issues

#### "No Audio Playing"
1. Check device volume and mute switch
2. Verify audio is playing in player tab
3. Try different audio route (speaker, headphones)
4. Check if other apps are using audio

#### "Audio Cutting Out"
1. Disable Low Power Mode
2. Close other audio apps
3. Check for iOS updates
4. Restart app if problem persists

### Download Issues

#### "Downloads Failing"
1. Check internet connection
2. Ensure sufficient storage space
3. Try downloading on WiFi
4. Clear app cache and retry

#### "Offline Mode Not Working"
1. Verify tour was fully downloaded
2. Check download status in Tours tab
3. Ensure location services still enabled
4. Try re-downloading problematic tour

### Performance Issues

#### "App Running Slowly"
1. Close other running apps
2. Restart device
3. Clear app cache in Settings
4. Update to latest app version

#### "Battery Draining Fast"
1. Enable battery optimization in Settings
2. Use lower location accuracy for longer tours
3. Download tours on WiFi to reduce cellular usage
4. Consider using Low Power Mode for long tours

## Privacy and Data

### Location Data
- **Location used only** for tour functionality
- **No location tracking** when app not in use
- **Data stays on device** unless you enable cloud sync
- **History automatic deletion** after 30 days

### API Usage
- **OpenAI API calls** only when generating content
- **No personal data** sent to AI services
- **Content cached locally** to minimize API usage
- **API key stored securely** in device keychain

### Analytics
- **Usage analytics** help improve app experience
- **No personal information** collected
- **Opt-out available** in Settings
- **Data anonymized** before collection

## Advanced Features

### Custom Tour Creation
(Future feature - coming soon)
- Create your own audio tours
- Add custom POI locations
- Record or generate audio content
- Share tours with friends

### Group Tours
(Future feature - coming soon)
- Tour with friends simultaneously
- Synchronized audio playback
- Group chat during tours
- Shared photo albums

### AR Integration
(Future feature - coming soon)
- Augmented reality POI information
- Historical overlay views
- Interactive 3D models
- Enhanced visual experience

## Getting Help

### In-App Help
- **Settings** → **Help & Support**
- **FAQ** section for common questions
- **Contact form** for specific issues
- **Video tutorials** for key features

### Community Support
- **User forums** for tour recommendations
- **Local guides** sharing insights
- **Tour reviews** and ratings
- **Social sharing** of experiences

### Technical Support
- **App Store reviews** for general feedback
- **Email support** for technical issues
- **Bug reporting** through app
- **Feature requests** welcome

Enjoy exploring the world with intelligent, location-aware audio tours!