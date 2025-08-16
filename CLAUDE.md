# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Building the Application
```bash
# Build for simulator (recommended for development)
xcodebuild -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" build

# Build for device (requires code signing)
xcodebuild -scheme "Apple Maps Demo" -destination "platform=iOS,name=Your Device Name" build

# Clean build (when dependencies or build cache issues occur)
xcodebuild clean -scheme "Apple Maps Demo"
```

### Running Tests
```bash
# Run all tests (Unit + Integration + UI)
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16"

# Run only unit tests (fastest feedback)
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests

# Run only integration tests
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests/LocationAudioIntegrationTests

# Run specific test class
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests/TourTests

# Run with code coverage
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -enableCodeCoverage YES
```

### CarPlay Testing
```bash
# CarPlay requires special simulator setup:
# 1. Launch iOS Simulator
# 2. Device → CarPlay → Connect to CarPlay
# 3. Run app normally - CarPlay window will appear
```

## Architecture Overview

This is a location-based audio tour iOS app with SwiftUI, SwiftData, and full CarPlay integration. The architecture follows MVVM with Swift 6 concurrency patterns.

### Core Architecture Layers

**Models (SwiftData @Model)**
- `Tour`: Contains POIs, metadata, tour type (walking/driving), speed adaptations
- `PointOfInterest`: Geographic locations with coordinates, geofencing radius, audio content
- `AudioContent`: Audio files with transcripts, generation metadata, download status
- `UserPreferences`: App settings, API configuration, playback preferences

**Managers (@MainActor)**
- `LocationManager`: GPS tracking, geofencing (20 region limit), speed-based tour adaptations
- `AudioManager`: Professional audio playback, crossfading, background audio, CarPlay integration
- `HybridContentManager`: Intelligent offline/online switching (Live AI > Cached AI > Local)

**Services**
- `OpenAIService`: Dynamic content generation with GPT-4 and text-to-speech
- `AudioStorageService`: File management, download queuing, cache management
- `ConnectivityManager`: Network quality assessment for hybrid mode switching

**CarPlay Templates**
- `CarPlaySceneDelegate`: Lifecycle management for CarPlay sessions
- `CarPlayMapTemplate`: Route visualization with POI markers
- `CarPlayNowPlayingTemplate`: Audio controls with media information
- `CarPlayListTemplate`: Tour selection interface

### Key Architectural Patterns

**Swift 6 Concurrency**
- All UI components use `@MainActor`
- Async/await for location services, audio playback, API calls
- Structured concurrency with TaskGroup for batch operations
- Actor isolation for thread-safe operations

**Location-Audio Integration**
- Geofences trigger automatic audio playback when entering POI regions
- Speed detection adapts behavior: walking tours (30s dwell time) vs driving tours (5s dwell time)
- Background location monitoring with battery optimization
- CoreLocation region limit (20) managed dynamically based on proximity

**Hybrid Content System**
- Priority hierarchy: Live OpenAI content > Cached AI content > Local audio files
- Automatic fallback when network conditions degrade
- Predictive content loading based on user route and speed
- Smart caching with expiration and storage management

## Development Workflow

### Model Changes
When modifying SwiftData models, be aware:
- Models use `@unchecked Sendable` for Swift 6 compliance
- Complex relationships exist between Tour ↔ PointOfInterest ↔ AudioContent
- Location data stored as separate latitude/longitude properties (not CLLocationCoordinate2D)
- Tour types affect geofencing behavior and audio timing

### Location Features
- Always test location features on physical device (simulator has limited GPS)
- Location accuracy affects geofence reliability - validate with `horizontalAccuracy` checks
- Background location requires "Always" permission and proper Info.plist configuration
- Speed calculations use consecutive location updates for tour type adaptation

### Audio Implementation
- Audio sessions handle interruptions (calls, other apps)
- CrossFade between POI audio content for seamless experience  
- Background audio playback requires specific capabilities in entitlements
- CarPlay integration requires separate audio route handling

### Testing Strategy
The project maintains 95%+ test coverage:
- **Unit Tests**: Models, services, managers with comprehensive mock system
- **Integration Tests**: End-to-end location → audio trigger workflows
- **UI Tests**: Complete user flows, accessibility compliance, CarPlay interactions
- **Mock System**: `TestDataFactory` provides consistent test data, `MockLocationManager` simulates GPS, `MockAudioManager` simulates playback

### API Integration
- OpenAI API key configured through in-app Settings (not hardcoded)
- Content generation uses location context, user preferences, historical visits
- Rate limiting and error handling with exponential backoff
- Streaming responses for real-time content delivery

### CarPlay Development
- CarPlay capability requires Apple Developer Program approval
- Templates designed for minimal driver distraction (large touch targets, high contrast)
- Voice-first interaction design with remote command center integration
- Test with both CarPlay Simulator and physical CarPlay systems

## Common Development Patterns

### Adding New POI Features
1. Update `PointOfInterest` model with new properties
2. Modify geofencing logic in `LocationManager` if location-based
3. Update audio playback in `AudioManager` if affects audio behavior
4. Add UI components in appropriate Feature/ directory
5. Create comprehensive tests including integration scenarios

### Location-Based Features
- Always check `authorizationStatus` before starting location services
- Use appropriate accuracy settings based on tour type (walking vs driving)
- Implement proper error handling for location permission denials
- Test geofence entry/exit behavior with different movement speeds

### Audio Features
- Configure audio session for background playback and interruption handling
- Implement proper crossfading between audio segments
- Handle external audio device connections (Bluetooth, CarPlay)
- Test with various audio routes and interruption scenarios

### API Features
- Implement request queuing and retry logic for network reliability
- Cache responses appropriately based on content type and user patterns
- Handle rate limiting and API quota management
- Test offline fallback scenarios thoroughly

## Project Structure Notes

The codebase uses feature-based organization under `Features/` with shared `Core/` components. CarPlay integration is centralized under `Features/CarPlay/` with template-based architecture. Test organization mirrors main app structure with additional `Mocks/` and `IntegrationTests/` directories.

When adding new features, follow the established patterns of placing UI in appropriate feature directories, shared business logic in `Core/`, and comprehensive test coverage across unit, integration, and UI test layers.