# Audio Tour Application

A comprehensive iOS/CarPlay location-based audio tour application with hybrid offline/online AI capabilities.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [Testing](#testing)
- [Architecture](#architecture)
- [CarPlay Integration](#carplay-integration)
- [API Integration](#api-integration)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This application provides immersive, location-aware audio tours with intelligent content generation, seamless offline/online switching, and full CarPlay integration. The app automatically triggers audio content when users enter predefined geographic regions (geofences) and adapts to different tour types (walking, driving, cycling).

## Features

### Core Features
- 📍 **Location-Based Audio Triggers**: Automatic audio playback when entering POI geofences
- 🎵 **Professional Audio Engine**: Background playback, crossfading, speed control
- 🚗 **Full CarPlay Integration**: Native CarPlay templates for safe driving experience
- 🤖 **AI-Powered Content**: Dynamic content generation using OpenAI
- 📱 **Hybrid Mode**: Seamless offline/online content switching
- 🗺️ **Interactive Maps**: Tour visualization with POI markers and routes
- ⚙️ **Smart Adaptability**: Speed-based behavior for walking vs driving tours

### User Interface
- **Tour Discovery**: Browse, search, and filter tours by category, difficulty, and type
- **Audio Player**: Professional controls with scrubbing, speed adjustment, and queue management
- **Settings**: Comprehensive preferences for audio, downloads, and API configuration
- **Map View**: Interactive tour maps with real-time location and POI visualization

### Technical Features
- **SwiftUI + MVVM Architecture**: Modern, maintainable codebase
- **Swift 6 Concurrency**: Full async/await and actor-based concurrency
- **SwiftData Persistence**: Modern Core Data replacement for data management
- **Comprehensive Testing**: 95%+ test coverage with unit, integration, and UI tests

## Requirements

### System Requirements
- **iOS**: 17.0+
- **Xcode**: 15.0+
- **Swift**: 6.0+
- **Device**: iPhone/iPad with location services

### Development Requirements
- macOS 14.0+ (for Xcode 15)
- Apple Developer Account (for device testing and CarPlay)
- OpenAI API Key (for AI content generation)

### Hardware for Testing
- iOS Device with GPS (recommended for location testing)
- CarPlay-compatible vehicle or CarPlay simulator (for CarPlay testing)

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd "Apple Maps Demo"
```

### 2. Open in Xcode
```bash
open "Apple Maps Demo.xcodeproj"
```

### 3. Install Dependencies
The project uses Swift Package Manager. Dependencies will be resolved automatically when you first build:

- **OpenAI Swift Client**: AI content generation
- **Reachability**: Network monitoring
- **AsyncLocationKit**: Modern location handling

### 4. Configure Signing
1. Select the project in Xcode
2. Go to **Signing & Capabilities**
3. Set your **Team** and **Bundle Identifier**
4. Ensure required capabilities are enabled:
   - Location Services
   - Background Modes (Audio, Location updates)
   - CarPlay (optional, requires Apple approval)

## Configuration

### 1. Location Permissions
The app requires location permissions for core functionality. The following usage descriptions are already configured in `Info.plist`:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

### 2. OpenAI API Configuration
1. Obtain an API key from [OpenAI](https://platform.openai.com/)
2. Launch the app and navigate to **Settings**
3. Enter your API key in the **API Configuration** section
4. Select your preferred model (GPT-4 recommended)

### 3. CarPlay Setup (Optional)
CarPlay functionality requires:
1. Apple Developer Program membership
2. CarPlay entitlement approval from Apple
3. CarPlay-compatible testing environment

To enable CarPlay:
1. Uncomment CarPlay capability in `Apple_Maps_Demo.entitlements`
2. Request CarPlay entitlement from Apple Developer Portal
3. Test with CarPlay Simulator or physical CarPlay system

## Running the Application

### Using Xcode (Recommended)
1. Select a target device or simulator
2. Press **⌘+R** or click the **Play** button
3. Grant location permissions when prompted
4. Allow microphone access for audio features (if prompted)

### Command Line Build
```bash
# Build for simulator
xcodebuild -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" build

# Build for device
xcodebuild -scheme "Apple Maps Demo" -destination "platform=iOS,name=Your Device Name" build
```

### First Launch Setup
1. **Grant Permissions**: Allow location access (required)
2. **Configure API**: Add OpenAI API key in Settings (optional)
3. **Select Tour**: Browse available tours in the Tours tab
4. **Test Audio**: Verify audio playback in the Player tab

## Testing

The application includes comprehensive testing across all layers:

### Test Structure
```
Apple Maps DemoTests/
├── UnitTests/
│   ├── Models/          # Model validation and business logic
│   ├── Services/        # Service layer with mocks
│   ├── Managers/        # Manager layer with dependency injection
│   └── ViewModels/      # ViewModel and Combine publisher testing
├── IntegrationTests/    # End-to-end integration scenarios
├── Mocks/              # Mock implementations and test utilities
└── UITests/            # User interface and accessibility testing
```

### Running Tests

#### All Tests (⌘+U in Xcode)
```bash
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16"
```

#### Unit Tests Only
```bash
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests
```

#### UI Tests Only
```bash
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoUITests
```

#### Specific Test Classes
```bash
# Test Tour model
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests/TourTests

# Test Audio Manager
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests/AudioManagerTests

# Test Location Integration
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests/LocationAudioIntegrationTests
```

#### Code Coverage
```bash
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -enableCodeCoverage YES
```

### Test Categories

#### Unit Tests (95%+ Coverage)
- **Models**: Tour, PointOfInterest, AudioContent, UserPreferences
- **Managers**: AudioManager, LocationManager with full mock integration
- **Services**: OpenAIService with network simulation and error scenarios
- **ViewModels**: TourViewModel with Combine publisher testing

#### Integration Tests
- **Location + Audio**: End-to-end geofence trigger to audio playback
- **Speed Adaptation**: Walking vs driving tour behavior
- **Error Recovery**: Network failures, permission issues, audio interruptions

#### UI Tests
- **User Flows**: Navigation, tour selection, audio controls
- **Accessibility**: VoiceOver, Dynamic Type, color contrast
- **Performance**: Launch time, memory usage, responsiveness

### Testing Best Practices

1. **Start with Unit Tests**: Fast feedback for individual components
2. **Use Mocks Extensively**: Consistent, predictable test data
3. **Test Edge Cases**: Error conditions, boundary values, user edge cases
4. **Performance Testing**: Memory leaks, CPU usage, battery impact
5. **Accessibility Testing**: Ensure inclusive user experience

## Architecture

### High-Level Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI Views │    │   ViewModels    │    │     Models      │
│                 │◄──►│                 │◄──►│                 │
│ - TourListView  │    │ - TourViewModel │    │ - Tour          │
│ - AudioPlayer   │    │ - MapViewModel  │    │ - POI           │
│ - MapView       │    │ - AudioPlayer   │    │ - AudioContent  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                        ▲                        ▲
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Managers     │    │    Services     │    │   Persistence   │
│                 │    │                 │    │                 │
│ - AudioManager  │    │ - OpenAIService │    │ - SwiftData     │
│ - LocationMgr   │    │ - AudioStorage  │    │ - Repositories  │
│ - HybridContent │    │ - Connectivity  │    │ - DataManager   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Components

#### Models (SwiftData)
- **Tour**: Complete tour information with POIs and metadata
- **PointOfInterest**: Geographic locations with audio content
- **AudioContent**: Audio files with transcripts and metadata
- **UserPreferences**: User settings and configuration

#### Managers (@MainActor)
- **AudioManager**: Professional audio playback with crossfading
- **LocationManager**: GPS tracking and geofencing with battery optimization
- **HybridContentManager**: Intelligent offline/online content switching

#### Services
- **OpenAIService**: AI content generation with streaming support
- **AudioStorageService**: File management and download queuing
- **ConnectivityManager**: Network monitoring and quality assessment

#### CarPlay Integration
- **CarPlaySceneDelegate**: CarPlay lifecycle management
- **CarPlayInterfaceController**: Template coordination and navigation
- **CarPlay Templates**: Map, NowPlaying, and List templates

## CarPlay Integration

### Overview
Full CarPlay integration provides safe, voice-first audio tour experience while driving.

### CarPlay Features
- **Map Template**: Tour route visualization with POI markers
- **Now Playing**: Audio controls with album art and track information
- **Tour Selection**: Browse and select tours without distraction
- **Voice Commands**: Media remote control integration

### CarPlay Testing

#### Using CarPlay Simulator
1. Launch iOS Simulator
2. Go to **Device → CarPlay → Connect to CarPlay**
3. Launch the audio tour app
4. Test CarPlay interface in the CarPlay window

#### Using Physical CarPlay
1. Connect iPhone to CarPlay-compatible vehicle
2. Launch app on iPhone
3. Access via CarPlay interface
4. Test with actual vehicle controls

### CarPlay Development Notes
- CarPlay capability requires Apple approval
- Templates designed for minimal driver distraction
- Large touch targets and high contrast UI
- Voice-first interaction design

## API Integration

### OpenAI Integration
The app integrates with OpenAI for dynamic content generation:

#### Supported Features
- **Text Generation**: GPT-4 for contextual tour content
- **Text-to-Speech**: High-quality audio generation
- **Streaming**: Real-time content delivery
- **Context Awareness**: Location and user preference integration

#### Configuration
1. Obtain API key from OpenAI platform
2. Configure in app Settings → API Configuration
3. Select preferred model (GPT-4 recommended)
4. Monitor usage and costs in Settings

#### Content Generation
- **Historical Context**: Location-specific historical information
- **Cultural Information**: Local culture and traditions
- **Personalized Narratives**: Adapted to user preferences and tour type

### Hybrid Mode Operation
- **Priority**: Live AI > Cached AI > Local Content
- **Automatic Switching**: Based on network quality and availability
- **Seamless Transitions**: No interruption to user experience
- **Smart Caching**: Predictive content loading based on route

## Development

### Project Structure
```
Apple Maps Demo/
├── App/                          # App lifecycle and CarPlay setup
├── Core/
│   ├── Models/                   # SwiftData models
│   ├── Services/                 # Business logic services
│   ├── Managers/                 # High-level system managers
│   └── Extensions/               # Utility extensions
├── Features/
│   ├── Audio/                    # Audio player UI and logic
│   ├── Map/                      # Map views and interaction
│   ├── Tours/                    # Tour management and UI
│   └── CarPlay/                  # CarPlay templates and controllers
├── Resources/                    # Assets and localizations
└── Utilities/                    # Helper classes and constants
```

### Development Workflow
1. **Feature Development**: Use feature branches with clear naming
2. **Testing**: Write tests first (TDD approach recommended)
3. **Code Review**: Ensure Swift 6 concurrency compliance
4. **Integration Testing**: Test on physical devices with real GPS
5. **Performance Testing**: Monitor memory usage and battery impact

### Swift 6 Concurrency
The project fully adopts Swift 6 concurrency:
- `@MainActor` for UI components
- `async/await` for asynchronous operations
- Actor isolation for thread safety
- Structured concurrency with TaskGroup

### Code Quality Standards
- SwiftLint integration for style consistency
- 95%+ test coverage requirement
- Documentation for public APIs
- Performance benchmarks for critical paths

## Troubleshooting

### Common Issues

#### Location Services
**Problem**: Location not updating or geofences not triggering
**Solutions**:
- Verify location permissions in Settings → Privacy & Security → Location Services
- Check app location permission: "While Using App" or "Always"
- Test on physical device (simulator has limited location features)
- Ensure GPS signal is strong (outdoor testing recommended)

#### Audio Playback
**Problem**: Audio not playing or poor quality
**Solutions**:
- Check volume and mute switch
- Verify audio session interruption handling
- Test with different audio routes (speaker, headphones, CarPlay)
- Check background audio permissions

#### CarPlay Issues
**Problem**: CarPlay interface not appearing
**Solutions**:
- Verify CarPlay entitlement is enabled and approved
- Check CarPlay connection (cable or wireless)
- Restart CarPlay connection
- Test with CarPlay Simulator first

#### API Integration
**Problem**: AI content not generating
**Solutions**:
- Verify OpenAI API key is valid and has credits
- Check network connectivity
- Review API usage limits and quotas
- Check app logs for API error messages

#### Performance Issues
**Problem**: App running slowly or using excessive battery
**Solutions**:
- Check location accuracy settings (use appropriate precision)
- Monitor background app refresh settings
- Review audio session configuration
- Use performance testing tools in Xcode

### Debug Mode Features
The app includes debug features for development:
- Location simulation with predefined routes
- Mock audio content for offline testing
- Network condition simulation
- Detailed logging for troubleshooting

### Logging and Diagnostics
- Comprehensive logging throughout the application
- Performance metrics collection
- Crash reporting integration ready
- Network request logging for API debugging

## Contributing

### Development Setup
1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Install dependencies and configure signing
4. Run tests to ensure baseline functionality
5. Implement feature with comprehensive tests
6. Submit pull request with detailed description

### Code Standards
- Follow Swift API Design Guidelines
- Maintain 95%+ test coverage
- Document public APIs with DocC
- Use SwiftLint for style consistency
- Ensure Swift 6 concurrency compliance

### Testing Requirements
- Unit tests for all new functionality
- Integration tests for complex workflows
- UI tests for user-facing features
- Performance tests for critical paths
- Accessibility compliance verification

### Pull Request Process
1. Ensure all tests pass (`⌘+U` in Xcode)
2. Run performance benchmarks
3. Update documentation for API changes
4. Include demo/screenshots for UI changes
5. Request review from maintainers

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Check the troubleshooting section above
- Review the comprehensive test suite for usage examples

---

**Built with ❤️ using SwiftUI, Swift 6 Concurrency, and Modern iOS Development Practices**