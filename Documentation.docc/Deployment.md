# Deployment Guide

Complete guide for building, testing, and deploying the Apple Maps Demo application.

## Overview

This guide covers the entire deployment pipeline from development build to App Store submission, including code signing, testing, performance optimization, and CarPlay certification.

## Development Deployment

### Local Development Setup

#### Prerequisites

- **macOS 14.0+** (for Xcode 15)
- **Xcode 15.0+** with iOS 17.0+ SDK
- **Apple Developer Account** (required for device testing)
- **Git** for version control
- **OpenAI API Key** (optional, for AI features)

#### Initial Setup

```bash
# Clone repository
git clone <repository-url>
cd "Apple Maps Demo"

# Open in Xcode
open "Apple Maps Demo.xcodeproj"
```

#### Code Signing Configuration

1. **Select Project** in Xcode Navigator
2. **Choose Target**: "Apple Maps Demo"
3. **Signing & Capabilities**:
   - Set **Team** to your developer account
   - Update **Bundle Identifier** to unique value
   - Enable **Automatically manage signing**

#### Required Capabilities

Ensure these capabilities are enabled:
- **Location Services**: Always and When In Use
- **Background Modes**:
  - Audio, AirPlay, and Picture in Picture
  - Location updates
  - Background fetch
- **CarPlay** (optional, requires Apple approval)

### Building for Development

#### Simulator Build

```bash
# Build for iPhone Simulator
xcodebuild -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    build

# Build and run
xcodebuild -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    run
```

#### Device Build

```bash
# Build for physical device
xcodebuild -scheme "Apple Maps Demo" \
    -destination "platform=iOS,name=Your Device Name" \
    build

# Archive for distribution
xcodebuild -scheme "Apple Maps Demo" \
    -archivePath "Build/Apple Maps Demo.xcarchive" \
    archive
```

#### Clean Build (Troubleshooting)

```bash
# Clean build folder
xcodebuild clean -scheme "Apple Maps Demo"

# Reset package dependencies
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## Testing Before Deployment

### Comprehensive Test Suite

```bash
# Run all tests with coverage
xcodebuild test -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -enableCodeCoverage YES

# Generate test report
xcodebuild test -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -resultBundlePath TestResults.xcresult
```

### Critical Test Categories

#### 1. Unit Tests (Required: 95%+ Coverage)
```bash
# Run unit tests only
xcodebuild test -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:Apple_Maps_DemoTests
```

#### 2. Integration Tests
```bash
# Test location-audio integration
xcodebuild test -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:Apple_Maps_DemoTests/LocationAudioIntegrationTests
```

#### 3. UI Tests
```bash
# Test user workflows
xcodebuild test -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:Apple_Maps_DemoUITests
```

#### 4. Performance Tests
```bash
# Memory leak detection
xcodebuild test -scheme "Apple Maps Demo" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:Apple_Maps_DemoTests/PerformanceTests
```

### Manual Testing Checklist

#### Location Features (Physical Device Required)
- [ ] Location permission granted (Always/When In Use)
- [ ] GPS accuracy appropriate for tour type
- [ ] Geofence entry/exit triggers audio
- [ ] Background location works correctly
- [ ] Battery optimization active

#### Audio System
- [ ] Audio plays through device speakers
- [ ] Background audio continues when app backgrounded
- [ ] Audio session handles interruptions (calls)
- [ ] Volume and playback speed controls work
- [ ] Crossfading between POI content smooth

#### CarPlay Integration (If Enabled)
- [ ] CarPlay interface appears when connected
- [ ] Map template shows tour route
- [ ] Now Playing controls functional
- [ ] Audio continues in CarPlay
- [ ] Voice commands work

#### Network Conditions
- [ ] Offline mode works without network
- [ ] Online mode generates AI content
- [ ] Hybrid mode switches smoothly
- [ ] Poor network conditions handled gracefully

## Production Deployment

### Build Configuration

#### Release Build Settings

1. **Build Configuration**: Release
2. **Code Optimization**: Optimize for Speed
3. **Swift Compilation Mode**: Optimize for Speed
4. **Debug Information**: Include in separate file
5. **Strip Debug Symbols**: Yes

#### Performance Optimizations

```swift
// Ensure release optimizations are enabled
#if DEBUG
    print("Debug mode - performance optimizations disabled")
#else
    // Production code optimizations
#endif
```

### Archive Creation

#### Using Xcode

1. **Product** → **Archive**
2. Wait for archive completion
3. **Window** → **Organizer** → **Archives**
4. Select archive → **Distribute App**

#### Using Command Line

```bash
# Create archive
xcodebuild -scheme "Apple Maps Demo" \
    -configuration Release \
    -archivePath "Builds/Apple Maps Demo.xcarchive" \
    archive

# Export for App Store
xcodebuild -exportArchive \
    -archivePath "Builds/Apple Maps Demo.xcarchive" \
    -exportPath "Builds/Export" \
    -exportOptionsPlist ExportOptions.plist
```

#### ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
```

## App Store Submission

### Pre-Submission Checklist

#### App Store Guidelines Compliance

- [ ] **Privacy Policy**: Location and API usage disclosed
- [ ] **Terms of Service**: User agreement provided
- [ ] **Content Guidelines**: No inappropriate content
- [ ] **Performance**: Meets App Store performance standards
- [ ] **Accessibility**: VoiceOver and Dynamic Type support

#### Metadata Preparation

##### App Information
- **App Name**: "Apple Maps Demo" (or final name)
- **Subtitle**: "AI-Powered Audio Tours"
- **Category**: Navigation
- **Age Rating**: 4+ (All Ages)

##### Description Template
```
Discover the world through intelligent audio tours that adapt to your journey.

KEY FEATURES:
• Location-based audio triggers automatically play content when you arrive
• AI-powered content generation creates personalized tour experiences  
• Full CarPlay integration for safe driving tours
• Offline mode works without internet connection
• Professional audio with crossfading between locations

TOUR TYPES:
• Walking tours with high GPS accuracy
• Driving tours optimized for vehicle speeds
• Mixed tours that adapt to your movement

ADVANCED FEATURES:
• Background audio continues when app is minimized
• Battery optimization adjusts accuracy to preserve power
• Smart caching downloads content for offline use
• Accessibility support with VoiceOver and Dynamic Type

Perfect for exploring cities, historical sites, nature trails, and cultural destinations with rich, contextual audio content that enhances your journey.
```

##### Keywords
```
audio tour, travel, navigation, GPS, CarPlay, AI, tour guide, location, walking tour, driving tour, offline maps
```

#### Visual Assets

##### App Icons
- **1024x1024**: App Store icon
- **180x180**: iPhone app icon  
- **120x120**: iPhone notification icon
- **76x76**: iPad app icon

##### Screenshots
- **iPhone 6.7"**: 1290x2796 (iPhone 15 Pro Max)
- **iPhone 6.5"**: 1242x2688 (iPhone 15 Plus)
- **iPhone 5.5"**: 1242x2208 (iPhone 8 Plus)

Required screenshots:
1. Tour list with available tours
2. Map view with POI markers
3. Audio player with controls
4. Settings screen
5. CarPlay interface (if applicable)

##### App Preview Videos (Optional)
- **30 seconds maximum**
- **Landscape orientation for CarPlay**
- **No audio narration needed**

### Submission Process

#### Using App Store Connect

1. **Create App Record**:
   - Log into App Store Connect
   - My Apps → "+" → New App
   - Enter app information and bundle ID

2. **Upload Build**:
   - Use Xcode Organizer or Application Loader
   - Upload archive to App Store Connect
   - Wait for processing (15-30 minutes)

3. **Complete Metadata**:
   - Add description, keywords, screenshots
   - Set pricing and availability
   - Configure App Store features

4. **Submit for Review**:
   - Click "Submit for Review"
   - Answer review questions
   - Wait for Apple review (24-48 hours typical)

#### Using Command Line Tools

```bash
# Upload build using altool
xcrun altool --upload-app \
    --type ios \
    --file "Builds/Export/Apple Maps Demo.ipa" \
    --username "your-apple-id@example.com" \
    --password "app-specific-password"
```

## CarPlay Certification

### CarPlay Entitlement Request

CarPlay functionality requires special entitlement from Apple:

1. **Developer Portal**:
   - Certificates, Identifiers & Profiles
   - App IDs → Select your app
   - Capabilities → CarPlay
   - Request entitlement

2. **Justification Letter**:
   ```
   Subject: CarPlay Entitlement Request - Audio Tour Application
   
   Dear Apple CarPlay Team,
   
   We are requesting CarPlay entitlement for our audio tour application "Apple Maps Demo".
   
   Our app provides location-based audio tours that are specifically designed for safe driving experiences:
   
   • Voice-first interaction minimizes driver distraction
   • Large touch targets meet CarPlay design guidelines  
   • Audio content automatically plays based on location
   • Now Playing controls integrate with vehicle systems
   • Map template shows tour route safely
   
   The CarPlay integration enhances driver safety by:
   1. Reducing phone interaction while driving
   2. Providing hands-free audio tour experience
   3. Integrating with vehicle's built-in controls
   4. Following CarPlay Human Interface Guidelines
   
   We have thoroughly tested the CarPlay interface and ensure it meets all safety requirements.
   
   Thank you for your consideration.
   ```

3. **Review Process**:
   - Apple reviews CarPlay justification
   - Typically takes 2-4 weeks
   - May request additional information

### CarPlay Testing

#### CarPlay Simulator Testing
```bash
# Enable CarPlay in iOS Simulator
Device → CarPlay → Connect to CarPlay
```

#### Physical CarPlay Testing
- Test with actual CarPlay-enabled vehicle
- Verify all templates work correctly
- Test voice commands and physical controls
- Validate safety compliance

## Continuous Integration/Continuous Deployment

### GitHub Actions Setup

#### `.github/workflows/test.yml`
```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode Version
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
    
    - name: Install Dependencies
      run: xcodebuild -resolvePackageDependencies
    
    - name: Run Tests
      run: |
        xcodebuild test \
          -scheme "Apple Maps Demo" \
          -destination "platform=iOS Simulator,name=iPhone 16" \
          -enableCodeCoverage YES \
          -resultBundlePath TestResults.xcresult
    
    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        xcode: true
        xcode_archive_path: TestResults.xcresult
```

#### `.github/workflows/deploy.yml`
```yaml
name: Deploy to App Store
on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build and Archive
      run: |
        xcodebuild -scheme "Apple Maps Demo" \
          -configuration Release \
          -archivePath "Apple Maps Demo.xcarchive" \
          archive
    
    - name: Export for App Store
      run: |
        xcodebuild -exportArchive \
          -archivePath "Apple Maps Demo.xcarchive" \
          -exportPath "Export" \
          -exportOptionsPlist ExportOptions.plist
    
    - name: Upload to App Store
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
      run: |
        xcrun altool --upload-app \
          --type ios \
          --file "Export/Apple Maps Demo.ipa" \
          --username "$APPLE_ID" \
          --password "$APPLE_PASSWORD"
```

### Fastlane Integration

#### `Fastfile`
```ruby
default_platform(:ios)

platform :ios do
  desc "Run all tests"
  lane :test do
    run_tests(
      scheme: "Apple Maps Demo",
      devices: ["iPhone 16"]
    )
  end
  
  desc "Build and upload to App Store"
  lane :release do
    # Run tests first
    test
    
    # Build archive
    build_app(
      scheme: "Apple Maps Demo",
      configuration: "Release"
    )
    
    # Upload to App Store
    upload_to_app_store(
      skip_waiting_for_build_processing: true
    )
  end
end
```

## Post-Deployment Monitoring

### Crash Reporting

Enable crash reporting to monitor app stability:

```swift
// In AppDelegate or App struct
import CrashReporter // Or your preferred crash reporting service

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Configure crash reporting
    CrashReporter.start()
    return true
}
```

### Analytics Integration

Monitor user behavior and performance:

```swift
// Track key user actions
Analytics.track("tour_started", properties: [
    "tour_name": tour.name,
    "tour_type": tour.tourType.rawValue
])

Analytics.track("audio_played", properties: [
    "poi_name": poi.name,
    "content_type": "ai_generated"
])
```

### Performance Monitoring

Track app performance metrics:

- Launch time
- Memory usage
- Battery consumption
- Network performance
- Location accuracy

## Troubleshooting Deployment Issues

### Common Build Errors

#### Code Signing Issues
```bash
# Reset development certificates
security delete-keychain ios_distribution.keychain
# Re-download certificates from Developer Portal
```

#### Package Dependency Issues
```bash
# Reset package cache
rm -rf ~/Library/Developer/Xcode/DerivedData
# Re-resolve packages
xcodebuild -resolvePackageDependencies
```

#### Archive Issues
```bash
# Clean build folder
xcodebuild clean
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### App Store Rejection Handling

#### Common Rejection Reasons
1. **Location Usage**: Ensure usage descriptions are clear
2. **Background Usage**: Justify background location usage
3. **Performance**: Address memory leaks or crashes
4. **Privacy**: Update privacy policy for location/API usage

#### Resolution Process
1. Address specific reviewer feedback
2. Update binary if code changes needed
3. Respond to reviewer notes if clarification sufficient
4. Resubmit for review

This comprehensive deployment guide ensures successful building, testing, and release of the Apple Maps Demo application across all target platforms and distribution channels.