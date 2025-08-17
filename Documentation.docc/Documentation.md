# ``Apple_Maps_Demo``

A comprehensive iOS/CarPlay location-based audio tour application with hybrid offline/online AI capabilities.

## Overview

The Apple Maps Demo is a sophisticated audio tour application that provides immersive, location-aware experiences with intelligent content generation, seamless offline/online switching, and full CarPlay integration. The app automatically triggers audio content when users enter predefined geographic regions and adapts to different tour types.

### Key Features

- **📍 Location-Based Audio Triggers**: Automatic audio playback when entering POI geofences
- **🎵 Professional Audio Engine**: Background playback, crossfading, speed control
- **🚗 Full CarPlay Integration**: Native CarPlay templates for safe driving experience
- **🤖 AI-Powered Content**: Dynamic content generation using OpenAI
- **📱 Hybrid Mode**: Seamless offline/online content switching
- **🗺️ Interactive Maps**: Tour visualization with POI markers and routes
- **⚙️ Smart Adaptability**: Speed-based behavior for walking vs driving tours

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:Architecture>
- <doc:Configuration>

### Core Components

- <doc:Models>
- <doc:Managers>
- <doc:Services>

### Features

- <doc:LocationTracking>
- <doc:AudioPlayback>
- <doc:AIIntegration>
- <doc:CarPlayIntegration>

### Development

- <doc:Testing>
- <doc:Deployment>
- <doc:Contributing>

### User Guide

- <doc:UserManual>
- <doc:Troubleshooting>

## System Requirements

- **iOS**: 17.0+
- **Xcode**: 15.0+
- **Swift**: 6.0+
- **Device**: iPhone/iPad with location services

## Quick Start

1. Clone the repository and open in Xcode
2. Configure signing and capabilities
3. Add OpenAI API key in app settings
4. Build and run on device for full functionality

```bash
git clone <repository-url>
cd "Apple Maps Demo"
open "Apple Maps Demo.xcodeproj"
```

## Architecture Overview

The application follows a modern MVVM architecture with Swift 6 concurrency:

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

## License

This project is licensed under the MIT License.