# Architecture Overview

Comprehensive guide to the Apple Maps Demo application architecture, design patterns, and code organization.

## Overview

The Apple Maps Demo follows a modern iOS architecture combining MVVM pattern with Swift 6 concurrency, SwiftData persistence, and feature-based organization. The design emphasizes separation of concerns, testability, and performance optimization.

## High-Level Architecture

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

## Core Design Patterns

### MVVM (Model-View-ViewModel)

**Views**: SwiftUI views that focus purely on UI rendering
- Declarative UI with data binding
- Minimal business logic
- State management through `@StateObject` and `@ObservedObject`

**ViewModels**: Presentation logic and state management
- `@MainActor` for UI thread safety
- Combine publishers for reactive updates
- Coordinate between views and business logic

**Models**: Data entities and business rules
- SwiftData models for persistence
- Value types for data transfer
- Business logic encapsulation

### Repository Pattern

Abstraction layer for data access:

```swift
protocol TourRepository {
    func fetchTours() async throws -> [Tour]
    func saveTour(_ tour: Tour) async throws
    func deleteTour(id: UUID) async throws
}
```

Benefits:
- Testable with mock implementations
- Consistent data access patterns
- Separation of persistence concerns

### Manager Pattern

High-level coordination of complex subsystems:

- **AudioManager**: Audio session, playback, crossfading
- **LocationManager**: GPS, geofencing, battery optimization
- **HybridContentManager**: Content mode switching, caching

## Project Structure

```
Apple Maps Demo/
├── App/                          # App lifecycle and setup
│   ├── Apple_Maps_DemoApp.swift  # App entry point
│   └── CarPlaySceneDelegate.swift # CarPlay lifecycle
├── Core/                         # Shared business logic
│   ├── Models/                   # Data models (SwiftData)
│   ├── Services/                 # Business services
│   ├── Managers/                 # System managers
│   └── Extensions/               # Utility extensions
├── Features/                     # Feature modules
│   ├── Audio/                    # Audio player functionality
│   ├── Map/                      # Map and location features
│   ├── Tours/                    # Tour management
│   └── CarPlay/                  # CarPlay integration
├── Resources/                    # Assets and localizations
└── Utilities/                    # Helper classes and constants
```

### Feature-Based Organization

Each feature module contains:
- **Views/**: SwiftUI views for the feature
- **ViewModels/**: Presentation logic
- **Models/** (if feature-specific): Local data structures

Benefits:
- Clear module boundaries
- Easier team collaboration
- Simplified testing scope

## Concurrency Architecture

### Swift 6 Adoption

The application fully embraces Swift 6 concurrency:

```swift
@MainActor
class AudioManager: ObservableObject {
    @Published var isPlaying = false
    
    func playAudio(_ content: AudioContent) async {
        // Safe main actor execution
    }
}
```

**Key Patterns:**
- `@MainActor` for UI-related classes
- `async/await` for asynchronous operations
- Actor isolation for thread safety
- Structured concurrency with TaskGroup

### Actor Design

```swift
actor AudioStorageService {
    private var downloadQueue: [DownloadTask] = []
    
    func enqueueDownload(_ task: DownloadTask) {
        downloadQueue.append(task)
    }
}
```

Benefits:
- Data race elimination
- Compile-time safety
- Performance optimization

## Data Flow Architecture

### Unidirectional Data Flow

1. **User Action** → View triggers action
2. **ViewModel** → Processes action, updates state
3. **Manager/Service** → Executes business logic
4. **Repository** → Persists or retrieves data
5. **Publisher** → Notifies subscribers of changes
6. **View** → Updates UI based on new state

### Example Flow: Playing Audio

```
User taps POI marker → MapView → MapViewModel → AudioManager
                                      ↓
AudioContent ← Repository ← DataManager ← AudioStorageService
                                      ↓
AudioManager plays content → Publishes state → MapViewModel → MapView updates
```

## Location Architecture

### Geofencing System

```swift
// Dynamic geofence management
class LocationManager {
    private let maxRegions = 20 // iOS limit
    
    func updateGeofences(for tour: Tour, userLocation: CLLocation) {
        // Intelligent region selection based on proximity
        let nearbyPOIs = selectNearbyPOIs(tour.pois, from: userLocation)
        registerRegions(for: nearbyPOIs)
    }
}
```

**Features:**
- Dynamic region registration based on proximity
- Battery optimization with accuracy tuning
- Speed-based behavior adaptation

### Tour Type Adaptation

```swift
enum TourType {
    case walking    // High accuracy, 30s dwell time
    case driving    // Medium accuracy, 5s dwell time
    case mixed      // Adaptive accuracy
}
```

## Audio Architecture

### Professional Audio Pipeline

```swift
class AudioManager {
    private var primaryPlayer: AVAudioPlayer?
    private var crossfadePlayer: AVAudioPlayer?
    
    func crossfadeTo(_ newContent: AudioContent) async {
        // Smooth transition between audio content
    }
}
```

**Features:**
- Crossfading between POI content
- Background audio continuation
- CarPlay integration
- Audio session interruption handling

## AI Integration Architecture

### Hybrid Content System

```swift
class HybridContentManager {
    func getContent(for poi: PointOfInterest) async -> AudioContent {
        // Priority: Live AI > Cached AI > Local
        switch connectivityManager.currentMode {
        case .online: return await generateLiveContent(poi)
        case .offline: return getCachedContent(poi)
        case .hybrid: return await intelligentSelection(poi)
        }
    }
}
```

**Content Hierarchy:**
1. **Live AI Generation**: Real-time OpenAI content
2. **Cached AI Content**: Previously generated AI content
3. **Local Content**: Pre-recorded audio files

## CarPlay Architecture

### Template-Based Design

```swift
class CarPlayInterfaceController {
    func setupMapTemplate() -> CPMapTemplate {
        let template = CPMapTemplate()
        // Configure for driving safety
        return template
    }
}
```

**Safety-First Design:**
- Large touch targets
- Voice-first interaction
- Minimal driver distraction
- High contrast UI

## Performance Architecture

### Memory Management

```swift
class ImageCacheManager {
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache: DiskImageCache
    
    func handleMemoryPressure() {
        memoryCache.removeAllObjects()
    }
}
```

**Optimization Strategies:**
- Two-tier caching (memory + disk)
- Memory pressure response
- Battery-aware location accuracy
- Network request batching

### Battery Optimization

```swift
class LocationManager {
    func adaptToBattery(level: Float) {
        switch level {
        case 0.0...0.2: setAccuracy(.reduced)
        case 0.2...0.5: setAccuracy(.balanced)
        default: setAccuracy(.full)
        }
    }
}
```

## Testing Architecture

### Three-Tier Testing Strategy

1. **Unit Tests**: Individual component testing
2. **Integration Tests**: End-to-end workflows
3. **UI Tests**: User interaction testing

```swift
class MockLocationManager: LocationManagerProtocol {
    var mockLocation: CLLocation?
    
    func simulateLocationUpdate(_ location: CLLocation) {
        mockLocation = location
        // Trigger location update
    }
}
```

**Testing Benefits:**
- 95%+ code coverage
- Predictable test data
- Isolated component testing
- Integration scenario validation

## Security Architecture

### API Key Management

```swift
// Secure storage pattern
class UserPreferences {
    @Published var apiKey: String {
        get { KeychainService.shared.getAPIKey() ?? "" }
        set { KeychainService.shared.setAPIKey(newValue) }
    }
}
```

**Security Practices:**
- No hardcoded API keys
- Keychain storage for sensitive data
- Network request validation
- Privacy-compliant location usage

## Extensibility

### Protocol-Oriented Design

```swift
protocol ContentGenerator {
    func generateContent(for poi: PointOfInterest) async throws -> String
}

class OpenAIContentGenerator: ContentGenerator {
    // OpenAI implementation
}

class LocalContentGenerator: ContentGenerator {
    // Local content implementation
}
```

Benefits:
- Easy feature addition
- Technology swapping
- Enhanced testability
- Clear contracts

This architecture enables maintainable, testable, and performant code while supporting complex location-based audio tour functionality.