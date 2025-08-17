# Testing Guide

Comprehensive testing strategy and implementation guide for the Apple Maps Demo application.

## Overview

The application maintains 95%+ test coverage through a three-tier testing strategy: Unit Tests, Integration Tests, and UI Tests. This approach ensures reliability, performance, and user experience quality across all features.

## Test Architecture

### Testing Pyramid Structure

```
                    ┌─────────────────┐
                    │    UI Tests     │  ← User flows, accessibility
                    │   (Slower)      │
                ┌───┴─────────────────┴───┐
                │  Integration Tests      │  ← End-to-end workflows
                │    (Medium)             │
            ┌───┴─────────────────────────┴───┐
            │       Unit Tests                │  ← Individual components
            │      (Fastest)                  │
            └─────────────────────────────────┘
```

### Test Organization

```
Apple Maps DemoTests/
├── UnitTests/                   # Fast, isolated component tests
│   ├── Models/                  # Data model validation
│   ├── Services/               # Business logic with mocks
│   ├── Managers/               # Manager layer coordination
│   └── ViewModels/             # Presentation logic
├── IntegrationTests/           # End-to-end workflows
│   └── LocationAudioIntegrationTests.swift
├── Mocks/                      # Test doubles and utilities
│   ├── MockAudioManager.swift
│   ├── MockLocationManager.swift
│   ├── MockOpenAIService.swift
│   └── TestDataFactory.swift
└── UITests/                    # User interface testing
    ├── Apple_Maps_DemoUITests.swift
    └── Apple_Maps_DemoUITestsLaunchTests.swift
```

## Unit Testing

### Model Tests

Model tests verify data integrity, validation rules, and business logic:

```swift
class TourTests: XCTestCase {
    func testTourCreation() {
        // Given
        let poi = TestDataFactory.createPOI()
        
        // When
        let tour = Tour(
            name: "Test Tour",
            description: "A test tour",
            pointsOfInterest: [poi],
            tourType: .walking
        )
        
        // Then
        XCTAssertEqual(tour.name, "Test Tour")
        XCTAssertEqual(tour.tourType, .walking)
        XCTAssertEqual(tour.pointsOfInterest.count, 1)
    }
    
    func testTourDurationCalculation() {
        // Tests estimated duration calculation based on POIs
    }
    
    func testTourTypeValidation() {
        // Tests speed validation for different tour types
    }
}
```

### Service Tests with Mocks

Service tests use dependency injection and mocks for predictable behavior:

```swift
class OpenAIServiceTests: XCTestCase {
    var service: OpenAIService!
    var mockNetworkSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockNetworkSession = MockURLSession()
        service = OpenAIService(session: mockNetworkSession)
    }
    
    func testContentGeneration() async throws {
        // Given
        let expectedResponse = TestDataFactory.createOpenAIResponse()
        mockNetworkSession.mockResponse = expectedResponse
        
        // When
        let content = try await service.generateContent(for: TestDataFactory.createPOI())
        
        // Then
        XCTAssertNotNil(content)
        XCTAssertFalse(content.text.isEmpty)
    }
    
    func testErrorHandling() async {
        // Tests retry logic and fallback mechanisms
    }
}
```

### Manager Tests with Dependency Injection

Manager tests verify coordination logic with injected dependencies:

```swift
class AudioManagerTests: XCTestCase {
    var audioManager: AudioManager!
    var mockAudioStorage: MockAudioStorageService!
    var mockDataService: MockDataService!
    
    override func setUp() {
        super.setUp()
        mockAudioStorage = MockAudioStorageService()
        mockDataService = MockDataService()
        
        audioManager = AudioManager(
            audioStorageService: mockAudioStorage,
            dataService: mockDataService
        )
    }
    
    func testPlaybackStart() {
        // Given
        let poi = TestDataFactory.createPOI()
        mockAudioStorage.stubbedAudioFile = TestDataFactory.createAudioURL()
        
        // When
        audioManager.playPOI(poi)
        
        // Then
        XCTAssertTrue(audioManager.isPlaying)
        XCTAssertEqual(audioManager.currentPOI?.id, poi.id)
    }
}
```

## Integration Testing

Integration tests verify end-to-end workflows across multiple components:

```swift
class LocationAudioIntegrationTests: XCTestCase {
    var locationManager: MockLocationManager!
    var audioManager: MockAudioManager!
    var tourViewModel: TourViewModel!
    
    override func setUp() {
        super.setUp()
        locationManager = MockLocationManager()
        audioManager = MockAudioManager()
        tourViewModel = TourViewModel(
            locationManager: locationManager,
            audioManager: audioManager
        )
    }
    
    func testGeofenceToAudioTrigger() async {
        // Given: User approaches POI
        let tour = TestDataFactory.createTour()
        let poi = tour.pointsOfInterest[0]
        
        tourViewModel.startTour(tour)
        
        // When: User enters geofence
        let poiLocation = CLLocation(
            latitude: poi.latitude,
            longitude: poi.longitude
        )
        locationManager.simulateLocationUpdate(poiLocation)
        
        // Then: Audio should start playing
        await fulfillment(of: [
            XCTExpectation { self.audioManager.isPlaying }
        ], timeout: 2.0)
        
        XCTAssertEqual(audioManager.currentPOI?.id, poi.id)
    }
    
    func testSpeedBasedBehavior() async {
        // Tests walking vs driving tour adaptations
    }
    
    func testOfflineOnlineSwitching() async {
        // Tests hybrid mode transitions
    }
}
```

## UI Testing

UI tests verify user workflows and accessibility compliance:

```swift
class Apple_Maps_DemoUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testTourSelectionFlow() {
        // Navigate to tours
        app.tabBars.buttons["Tours"].tap()
        
        // Select a tour
        let firstTour = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstTour.exists)
        firstTour.tap()
        
        // Verify tour detail appears
        XCTAssertTrue(app.navigationBars["Tour Detail"].exists)
        
        // Start tour
        app.buttons["Start Tour"].tap()
        
        // Verify map view
        XCTAssertTrue(app.maps.firstMatch.exists)
    }
    
    func testAudioPlayerControls() {
        // Test play/pause, skip, volume controls
    }
    
    func testAccessibility() {
        // Verify VoiceOver labels and hints
        XCTAssertTrue(app.isVoiceOverRunning)
        
        // Test Dynamic Type support
        app.buttons["Increase Text Size"].tap()
        // Verify UI adapts appropriately
    }
}
```

## Mock System

### TestDataFactory

Provides consistent test data across all test suites:

```swift
enum TestDataFactory {
    static func createTour(
        name: String = "Test Tour",
        type: TourType = .walking,
        poiCount: Int = 3
    ) -> Tour {
        let pois = (0..<poiCount).map { createPOI(index: $0) }
        return Tour(
            name: name,
            description: "Test tour description",
            pointsOfInterest: pois,
            tourType: type
        )
    }
    
    static func createPOI(index: Int = 0) -> PointOfInterest {
        return PointOfInterest(
            name: "Test POI \(index)",
            latitude: 37.7749 + Double(index) * 0.001,
            longitude: -122.4194 + Double(index) * 0.001,
            radius: 100.0,
            category: .landmark
        )
    }
    
    static func createAudioContent() -> AudioContent {
        return AudioContent(
            transcript: "Test audio transcript",
            duration: 60.0,
            language: "en"
        )
    }
}
```

### Mock Implementations

Mock classes provide predictable behavior for testing:

```swift
class MockLocationManager: LocationManagerProtocol {
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    func simulateLocationUpdate(_ location: CLLocation) {
        currentLocation = location
        locationUpdateHandler?(location)
    }
    
    func simulateGeofenceEntry(region: CLRegion) {
        NotificationCenter.default.post(
            name: .didEnterRegion,
            object: nil,
            userInfo: ["regionId": region.identifier]
        )
    }
}

class MockAudioManager: AudioManagerProtocol {
    var isPlaying = false
    var currentPOI: PointOfInterest?
    var playbackHistory: [PlaybackRecord] = []
    
    func playPOI(_ poi: PointOfInterest) {
        currentPOI = poi
        isPlaying = true
        playbackHistory.append(PlaybackRecord(poi: poi, timestamp: Date()))
    }
    
    func reset() {
        isPlaying = false
        currentPOI = nil
        playbackHistory.removeAll()
    }
}
```

## Running Tests

### Command Line Testing

```bash
# Run all tests
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16"

# Run only unit tests (fastest)
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests

# Run specific test class
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Apple_Maps_DemoTests/TourTests

# Run with code coverage
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" -enableCodeCoverage YES
```

### Xcode Testing

1. **All Tests**: Press `⌘+U` in Xcode
2. **Test Navigator**: View test results and coverage
3. **Test Plans**: Configure test suites and environments
4. **Parallel Testing**: Enable for faster execution

## Test-Driven Development

### TDD Workflow

1. **Red**: Write failing test first
2. **Green**: Implement minimal code to pass
3. **Refactor**: Improve code while maintaining tests

```swift
// 1. Red - Write failing test
func testPOIGeofenceRadius() {
    let poi = PointOfInterest(name: "Test", latitude: 0, longitude: 0, radius: 50)
    XCTAssertEqual(poi.optimizedRadius(for: .walking), 50)
}

// 2. Green - Implement feature
extension PointOfInterest {
    func optimizedRadius(for tourType: TourType) -> CLLocationDistance {
        switch tourType {
        case .walking: return radius
        case .driving: return radius * 2
        case .mixed: return radius * 1.5
        }
    }
}

// 3. Refactor - Improve implementation
```

## Performance Testing

### Memory Leak Detection

```swift
func testAudioManagerMemoryLeaks() {
    weak var weakAudioManager: AudioManager?
    
    autoreleasepool {
        let audioManager = AudioManager()
        weakAudioManager = audioManager
        // Use audio manager
    }
    
    XCTAssertNil(weakAudioManager, "AudioManager should be deallocated")
}
```

### Launch Performance

```swift
func testLaunchPerformance() {
    measure {
        let app = XCUIApplication()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
    }
}
```

## Continuous Integration

### GitHub Actions Configuration

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme "Apple Maps Demo" \
            -destination "platform=iOS Simulator,name=iPhone 16" \
            -enableCodeCoverage YES
```

## Test Best Practices

### Do's

- ✅ Write tests before implementing features (TDD)
- ✅ Use descriptive test names that explain behavior
- ✅ Keep tests fast and independent
- ✅ Use mocks for external dependencies
- ✅ Test edge cases and error conditions
- ✅ Maintain high code coverage (95%+)

### Don'ts

- ❌ Don't test implementation details
- ❌ Don't write overly complex test setups
- ❌ Don't ignore flaky tests
- ❌ Don't test third-party libraries
- ❌ Don't skip cleanup in test teardown

### Test Categories

1. **Fast Tests**: Unit tests that run in milliseconds
2. **Integration Tests**: Medium-speed tests for workflows
3. **UI Tests**: Slower tests for user interactions
4. **Performance Tests**: Benchmarks for critical paths
5. **Accessibility Tests**: Ensure inclusive experience

This comprehensive testing strategy ensures the Apple Maps Demo application maintains high quality, reliability, and performance across all features and user scenarios.