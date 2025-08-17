# Configuration Guide

Detailed configuration options for the Apple Maps Demo application.

## Environment Setup

### Development Configuration

#### Xcode Project Settings

**Build Settings**:
- **iOS Deployment Target**: 17.0
- **Swift Language Version**: 6.0
- **Code Signing Style**: Automatic
- **Architecture**: arm64 (and x86_64 for Simulator)

**Capabilities Required**:
- Location Services (Always and When In Use)
- Background Modes (Audio, Location updates)
- CarPlay (optional, requires Apple approval)

#### Info.plist Configuration

Essential entries for location and audio functionality:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses location to trigger audio content when you visit tour locations.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app uses location to provide continuous audio tours, even when running in the background.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>This app uses location to provide seamless audio tour experiences.</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>location</string>
    <string>background-fetch</string>
</array>
```

### API Configuration

#### OpenAI Integration

Set up OpenAI API access for dynamic content generation:

1. **Obtain API Key**: Register at [OpenAI Platform](https://platform.openai.com/)
2. **Configure in App**: Settings → API Configuration
3. **Environment Variable** (Development):
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

**API Settings**:
- **Model**: GPT-4 (recommended) or GPT-3.5-turbo
- **Max Tokens**: 500 for tour content
- **Temperature**: 0.7 for creative but consistent content
- **Rate Limiting**: 60 requests per minute

## User Preferences

### Location Settings

#### Accuracy Levels
- **High**: Best for walking tours, higher battery usage
- **Standard**: Balanced accuracy and battery life
- **Low**: Battery saving mode, reduced accuracy

#### Tour Type Optimization
```swift
// Automatically configured based on tour type
enum TourType {
    case walking    // High accuracy, 30s dwell time
    case driving    // Medium accuracy, 5s dwell time
    case mixed      // Adaptive based on detected speed
}
```

### Audio Configuration

#### Quality Settings
- **High**: 256 kbps, larger files, best quality
- **Medium**: 128 kbps, balanced size/quality
- **Low**: 64 kbps, smallest files, acceptable quality

#### Playback Settings
- **Auto-play**: Automatically start audio at POIs
- **Crossfade Duration**: 2-5 seconds between content
- **Volume Normalization**: Consistent volume across content
- **Background Playback**: Continue when app minimized

### Content Management

#### Download Strategy
```swift
enum DownloadStrategy {
    case wifiOnly       // Download only on WiFi
    case cellular       // Allow cellular downloads
    case manual         // User-initiated downloads only
    case predictive     // Smart pre-downloading
}
```

#### Cache Management
- **Cache Size Limit**: 500MB to 2GB based on device storage
- **Cleanup Policy**: LRU (Least Recently Used)
- **Automatic Cleanup**: Remove content older than 30 days
- **Emergency Cleanup**: Free space when storage is low

## Performance Tuning

### Memory Optimization

#### Image Caching
```swift
// Configure image cache limits
let imageCacheConfig = ImageCacheConfiguration(
    memoryLimit: 50 * 1024 * 1024,  // 50MB
    diskLimit: 200 * 1024 * 1024,   // 200MB
    compressionQuality: 0.8
)
```

#### Audio Buffer Management
```swift
// Dynamic buffer sizing based on device capability
let bufferConfig = AudioBufferConfiguration(
    bufferSize: deviceCapability.recommendedBufferSize,
    preloadCount: deviceCapability.maxPreloadCount,
    compressionEnabled: true
)
```

### Battery Optimization

#### Location Accuracy Tuning
```swift
// Automatic adjustment based on battery level
func optimizeForBattery(level: Float) {
    switch level {
    case 0.0...0.2:  // < 20%
        setAccuracy(.reduced)
        enableAggressiveOptimization()
    case 0.2...0.5:  // 20-50%
        setAccuracy(.balanced)
        enableModerateOptimization()
    default:         // > 50%
        setAccuracy(.full)
        disableOptimizations()
    }
}
```

#### Network Request Optimization
- **Request Batching**: Combine multiple API calls
- **Compression**: Gzip request/response compression
- **Caching**: Aggressive caching of generated content
- **Offline Fallback**: Local content when network unavailable

## Security Configuration

### API Key Management

#### Secure Storage
```swift
// Store API keys in Keychain
class SecureStorage {
    func storeAPIKey(_ key: String) {
        let keychain = Keychain(service: "com.example.apple-maps-demo")
        keychain["openai_api_key"] = key
    }
    
    func retrieveAPIKey() -> String? {
        let keychain = Keychain(service: "com.example.apple-maps-demo")
        return keychain["openai_api_key"]
    }
}
```

#### Network Security
- **Certificate Pinning**: Validate OpenAI API certificates
- **Request Validation**: Sanitize all API requests
- **Rate Limiting**: Prevent API abuse
- **Error Handling**: No sensitive data in error messages

### Privacy Configuration

#### Location Data Handling
```swift
// Privacy-compliant location usage
class LocationPrivacyManager {
    func requestMinimalPermissions() {
        // Request only necessary permissions
        locationManager.requestWhenInUseAuthorization()
    }
    
    func handleBackgroundRequirement() {
        // Upgrade to Always permission only when needed
        if userStartsTour && tourRequiresBackground {
            locationManager.requestAlwaysAuthorization()
        }
    }
}
```

#### Data Retention Policy
- **Location History**: 30 days maximum retention
- **Audio Cache**: Automatic cleanup after tours
- **Analytics**: Anonymized usage data only
- **User Control**: Complete data deletion option

## CarPlay Configuration

### Entitlement Setup

#### Developer Portal Configuration
1. **App ID**: Enable CarPlay capability
2. **Provisioning Profile**: Include CarPlay entitlement
3. **Entitlement Request**: Submit justification to Apple

#### CarPlay Entitlements File
```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
<key>com.apple.developer.carplay-maps</key>
<true/>
```

### Template Configuration

#### Map Template Settings
```swift
let mapTemplate = CPMapTemplate()
mapTemplate.mapButtons = [
    currentLocationButton,
    zoomInButton,
    zoomOutButton
]
mapTemplate.automaticallyHidesNavigationBar = false
mapTemplate.hidesButtonsWithNavigationBar = false
```

#### Now Playing Template
```swift
let nowPlayingTemplate = CPNowPlayingTemplate.shared
nowPlayingTemplate.add(observer: self)
nowPlayingTemplate.isUpNextButtonEnabled = true
nowPlayingTemplate.isAlbumArtistButtonEnabled = false
```

## Testing Configuration

### Test Environment Setup

#### Mock Services Configuration
```swift
#if DEBUG
let audioManager = MockAudioManager()
let locationManager = MockLocationManager()
let openAIService = MockOpenAIService()
#else
let audioManager = AudioManager.shared
let locationManager = LocationManager.shared
let openAIService = OpenAIService.shared
#endif
```

#### Test Data Configuration
```swift
enum TestConfiguration {
    static let enableLocationSimulation = true
    static let useFixedTestTours = true
    static let skipAPIKeyValidation = true
    static let enablePerformanceProfiling = true
}
```

### Performance Testing

#### Memory Profiling
```swift
#if DEBUG
class MemoryProfiler {
    func trackMemoryUsage() {
        let memoryUsage = ProcessInfo.processInfo.physicalMemory
        print("Memory usage: \(memoryUsage / 1024 / 1024) MB")
    }
}
#endif
```

#### Battery Monitoring
```swift
#if DEBUG
class BatteryProfiler {
    func monitorBatteryImpact() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        // Log battery drain rate
    }
}
#endif
```

## Deployment Configuration

### Build Configurations

#### Debug Configuration
- **Optimization Level**: None
- **Debug Symbols**: Full
- **Assertions**: Enabled
- **Logging**: Verbose
- **Mock Services**: Enabled

#### Release Configuration
- **Optimization Level**: Speed
- **Debug Symbols**: Separate file
- **Assertions**: Disabled
- **Logging**: Error only
- **Mock Services**: Disabled

### Environment Variables

#### Development
```bash
# .env.development
ENVIRONMENT=development
OPENAI_API_KEY=sk-dev-key-here
API_BASE_URL=https://api.openai.com/v1
ENABLE_ANALYTICS=false
LOG_LEVEL=debug
```

#### Production
```bash
# .env.production
ENVIRONMENT=production
API_BASE_URL=https://api.openai.com/v1
ENABLE_ANALYTICS=true
LOG_LEVEL=error
CRASH_REPORTING=true
```

## Advanced Configuration

### Hybrid Content Strategy

#### Content Priority Configuration
```swift
enum ContentPriority {
    case liveAI     // Real-time OpenAI generation
    case cachedAI   // Previously generated AI content
    case local      // Pre-recorded audio files
    
    static let fallbackChain: [ContentPriority] = [.liveAI, .cachedAI, .local]
}
```

#### Network Quality Thresholds
```swift
struct NetworkQualityThresholds {
    static let excellentMbps: Double = 10.0
    static let goodMbps: Double = 5.0
    static let fairMbps: Double = 1.0
    static let poorMbps: Double = 0.5
}
```

### Accessibility Configuration

#### VoiceOver Customization
```swift
// Configure accessibility labels and hints
extension UIView {
    func configureAccessibility(
        label: String,
        hint: String? = nil,
        traits: UIAccessibilityTraits = []
    ) {
        accessibilityLabel = label
        accessibilityHint = hint
        accessibilityTraits = traits
        isAccessibilityElement = true
    }
}
```

#### Dynamic Type Support
```swift
// Font scaling configuration
enum FontConfiguration {
    static let minimumScale: CGFloat = 0.8
    static let maximumScale: CGFloat = 2.0
    static let defaultFont = UIFont.preferredFont(forTextStyle: .body)
}
```

This comprehensive configuration guide ensures optimal setup and customization of the Apple Maps Demo application for all deployment scenarios and user preferences.