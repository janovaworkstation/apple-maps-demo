# Troubleshooting Guide

Comprehensive solutions for common issues in the Apple Maps Demo application.

## Location Services Issues

### Location Not Updating

#### Symptoms
- Blue dot not moving on map
- "Location Not Available" message
- Geofences not triggering
- Outdated location coordinates

#### Diagnosis Steps
1. **Check Location Services Status**:
   ```swift
   print("Location Services Enabled: \(CLLocationManager.locationServicesEnabled())")
   print("Authorization Status: \(locationManager.authorizationStatus)")
   ```

2. **Verify App Permissions**:
   - iOS Settings → Privacy & Security → Location Services
   - Find "Apple Maps Demo" in app list
   - Check permission level (Never/Ask Next Time/While Using App/Always)

3. **Test GPS Signal**:
   - Move outdoors for better satellite reception
   - Check GPS accuracy: `location.horizontalAccuracy`
   - Accuracy > 0 and < 100 meters is generally good

#### Solutions

**Permission Issues**:
```swift
// Request appropriate permission level
func requestLocationPermission() async {
    let status = await locationManager.requestAuthorization()
    switch status {
    case .denied, .restricted:
        // Guide user to Settings app
        showLocationSettingsAlert()
    case .notDetermined:
        // Permission dialog will appear
        break
    case .authorizedWhenInUse, .authorizedAlways:
        // Permission granted
        startLocationUpdates()
    }
}
```

**GPS Signal Issues**:
- Move to open area away from buildings
- Wait 30-60 seconds for GPS lock
- Restart device if GPS consistently fails
- Check for iOS updates

**Location Manager Reset**:
```swift
func resetLocationManager() {
    locationManager.stopUpdatingLocation()
    locationManager.stopMonitoringSignificantLocationChanges()
    
    // Wait briefly
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.locationManager.startUpdatingLocation()
    }
}
```

### Geofences Not Triggering

#### Symptoms
- Audio doesn't play when entering POI areas
- No region enter/exit notifications
- Map shows correct location but no audio triggers

#### Diagnosis Steps
1. **Check Region Monitoring**:
   ```swift
   print("Monitored Regions: \(locationManager.monitoredRegions.count)")
   for region in locationManager.monitoredRegions {
       print("Region: \(region.identifier), Center: \(region.center)")
   }
   ```

2. **Verify Region Limits**:
   - iOS limits to 20 simultaneously monitored regions
   - Check if limit exceeded
   - Verify regions are properly registered

3. **Test Region Entry**:
   ```swift
   func testRegionEntry() {
       let testLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
       let distance = currentLocation.distance(from: testLocation)
       print("Distance to POI: \(distance) meters, Radius: \(poi.radius)")
   }
   ```

#### Solutions

**Region Limit Management**:
```swift
func optimizeRegionMonitoring() {
    // Remove distant regions, add nearby ones
    let nearbyPOIs = selectNearestPOIs(from: currentLocation, count: 18)
    
    // Clear existing regions
    locationManager.monitoredRegions.forEach { region in
        locationManager.stopMonitoring(for: region)
    }
    
    // Add nearby regions
    nearbyPOIs.forEach { poi in
        startMonitoring(poi: poi)
    }
}
```

**Region Size Adjustment**:
```swift
func adjustRegionSize(for tourType: TourType) -> CLLocationDistance {
    switch tourType {
    case .walking:
        return max(50, poi.radius) // Minimum 50m for walking
    case .driving:
        return max(100, poi.radius * 2) // Larger for driving
    case .mixed:
        return max(75, poi.radius * 1.5) // Adaptive size
    }
}
```

**Manual Region Testing**:
```swift
func simulateRegionEntry(for poi: PointOfInterest) {
    let region = CLCircularRegion(
        center: poi.coordinate,
        radius: poi.radius,
        identifier: poi.id.uuidString
    )
    
    // Manually trigger region entry
    locationManager(locationManager, didEnter: region)
}
```

## Audio Playback Issues

### No Audio Output

#### Symptoms
- Audio player shows playing but no sound
- Volume controls not responding
- Audio works in other apps

#### Diagnosis Steps
1. **Check Audio Session**:
   ```swift
   let audioSession = AVAudioSession.sharedInstance()
   print("Audio Session Category: \(audioSession.category)")
   print("Audio Session Active: \(audioSession.isOtherAudioPlaying)")
   print("Current Route: \(audioSession.currentRoute)")
   ```

2. **Verify Audio Files**:
   ```swift
   func validateAudioFile(url: URL) -> Bool {
       return FileManager.default.fileExists(atPath: url.path) &&
              url.pathExtension.lowercased() == "mp3"
   }
   ```

3. **Test Audio Route**:
   - Check device mute switch
   - Test with headphones
   - Verify Bluetooth connections

#### Solutions

**Audio Session Configuration**:
```swift
func configureAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .allowAirPlay, .allowBluetoothA2DP]
        )
        try audioSession.setActive(true)
    } catch {
        print("Audio session setup failed: \(error)")
    }
}
```

**Audio Route Management**:
```swift
func handleAudioRouteChange() {
    NotificationCenter.default.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: .main
    ) { notification in
        self.updateAudioRoute()
    }
}
```

**Player Validation**:
```swift
func validateAudioPlayer() -> Bool {
    guard let player = currentAudioPlayer else {
        print("No audio player available")
        return false
    }
    
    guard player.isFileURL else {
        print("Invalid audio URL")
        return false
    }
    
    return true
}
```

### Audio Interruptions

#### Symptoms
- Audio stops during phone calls
- Other apps interrupt playback
- Audio doesn't resume after interruption

#### Solutions

**Interruption Handling**:
```swift
func handleAudioInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
        return
    }
    
    switch type {
    case .began:
        // Interruption started - pause audio
        pause()
        wasPlayingBeforeInterruption = isPlaying
        
    case .ended:
        // Interruption ended - potentially resume
        guard let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
            return
        }
        
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
        if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
            resume()
        }
    }
}
```

## Network and API Issues

### OpenAI API Failures

#### Symptoms
- "Content generation failed" errors
- Long delays for AI content
- Fallback to cached content

#### Diagnosis Steps
1. **Check API Key**:
   ```swift
   func validateAPIKey() -> Bool {
       let apiKey = UserPreferences.shared.openAIApiKey
       return !apiKey.isEmpty && apiKey.hasPrefix("sk-")
   }
   ```

2. **Test Network Connectivity**:
   ```swift
   func testAPIConnectivity() async {
       do {
           let url = URL(string: "https://api.openai.com/v1/models")!
           let (_, response) = try await URLSession.shared.data(from: url)
           
           if let httpResponse = response as? HTTPURLResponse {
               print("API Status: \(httpResponse.statusCode)")
           }
       } catch {
           print("API connectivity test failed: \(error)")
       }
   }
   ```

#### Solutions

**API Key Validation**:
```swift
func validateAndSetupAPI() {
    guard validateAPIKey() else {
        showAPIKeySetupAlert()
        return
    }
    
    // Test API connectivity
    Task {
        await testAPIConnectivity()
    }
}
```

**Retry Logic with Backoff**:
```swift
func retryAPIRequest<T>(
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            if attempt == maxAttempts - 1 {
                throw error
            }
            
            let delay = baseDelay * pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    
    fatalError("Should not reach here")
}
```

**Fallback Content Strategy**:
```swift
func getContentWithFallback(for poi: PointOfInterest) async -> AudioContent {
    // Try live AI generation
    do {
        return try await openAIService.generateContent(for: poi)
    } catch {
        print("Live AI failed: \(error)")
    }
    
    // Try cached AI content
    if let cachedContent = contentCache.getCachedContent(for: poi) {
        return cachedContent
    }
    
    // Fallback to local content
    return loadLocalContent(for: poi)
}
```

### Poor Network Performance

#### Symptoms
- Slow content loading
- Frequent timeouts
- High data usage

#### Solutions

**Network Quality Assessment**:
```swift
func assessNetworkQuality() -> NetworkQuality {
    let reachability = Reachability.shared
    
    guard reachability.isConnected else {
        return .none
    }
    
    // Measure network speed
    let startTime = Date()
    Task {
        do {
            let testURL = URL(string: "https://httpbin.org/bytes/1024")!
            let _ = try await URLSession.shared.data(from: testURL)
            let duration = Date().timeIntervalSince(startTime)
            let speedMbps = (1024.0 * 8.0) / (duration * 1_000_000.0)
            
            updateNetworkQuality(speedMbps: speedMbps)
        } catch {
            print("Network speed test failed")
        }
    }
    
    return currentNetworkQuality
}
```

**Adaptive Content Loading**:
```swift
func adaptContentForNetwork() {
    switch networkQuality {
    case .excellent:
        enableHighQualityContent()
    case .good:
        enableMediumQualityContent()
    case .fair:
        enableLowQualityContent()
    case .poor:
        enableOfflineMode()
    }
}
```

## CarPlay Issues

### CarPlay Not Appearing

#### Symptoms
- CarPlay interface doesn't show when connected
- App doesn't appear in CarPlay launcher
- CarPlay templates not loading

#### Diagnosis Steps
1. **Check CarPlay Entitlement**:
   ```swift
   #if canImport(CarPlay)
   print("CarPlay framework available")
   #else
   print("CarPlay framework not available")
   #endif
   ```

2. **Verify Scene Configuration**:
   ```swift
   func application(
       _ application: UIApplication,
       configurationForConnecting connectingSceneSession: UISceneSession,
       options: UIScene.ConnectionOptions
   ) -> UISceneConfiguration {
       
       if connectingSceneSession.role == .carTemplateApplication {
           return UISceneConfiguration(
               name: "CarPlay",
               sessionRole: connectingSceneSession.role
           )
       }
       
       return UISceneConfiguration(
           name: "Default Configuration",
           sessionRole: connectingSceneSession.role
       )
   }
   ```

#### Solutions

**CarPlay Entitlement Request**:
1. Apple Developer Portal → Certificates, Identifiers & Profiles
2. App IDs → Select your app → Edit
3. Capabilities → CarPlay → Request access
4. Provide justification for CarPlay usage

**Scene Delegate Setup**:
```swift
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupCarPlayInterface()
    }
}
```

### CarPlay Template Issues

#### Symptoms
- Templates not updating
- Navigation buttons not working
- Audio controls unresponsive

#### Solutions

**Template Refresh**:
```swift
func refreshCarPlayTemplate() {
    guard let interfaceController = interfaceController else { return }
    
    let updatedTemplate = createMapTemplate()
    interfaceController.setRootTemplate(updatedTemplate, animated: true)
}
```

**Template Validation**:
```swift
func validateTemplate(_ template: CPTemplate) -> Bool {
    switch template {
    case let mapTemplate as CPMapTemplate:
        return mapTemplate.mapButtons.count <= 4 // CarPlay limit
    case let listTemplate as CPListTemplate:
        return listTemplate.sections.count <= 1000 // Reasonable limit
    default:
        return true
    }
}
```

## Performance Issues

### Memory Issues

#### Symptoms
- App crashes with memory warnings
- Slow performance
- UI freezing

#### Diagnosis Tools
```swift
func monitorMemoryUsage() {
    let memoryInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let memoryUsage = memoryInfo.resident_size / 1024 / 1024 // MB
        print("Memory usage: \(memoryUsage) MB")
    }
}
```

#### Solutions

**Memory Pressure Handling**:
```swift
func handleMemoryWarning() {
    // Clear image cache
    ImageCacheManager.shared.clearMemoryCache()
    
    // Stop unnecessary location updates
    if !isActivelyTour {
        locationManager.stopUpdatingLocation()
    }
    
    // Clean up audio players
    audioManager.cleanupInactivePlayers()
    
    // Clear expired content cache
    contentCache.removeExpiredContent()
}
```

**Lazy Loading Implementation**:
```swift
class LazyImageLoader {
    private var imageCache: [String: UIImage] = [:]
    
    func loadImage(for poi: PointOfInterest) -> UIImage? {
        let cacheKey = poi.id.uuidString
        
        if let cachedImage = imageCache[cacheKey] {
            return cachedImage
        }
        
        // Load image asynchronously
        Task {
            let image = await loadImageFromDisk(poi: poi)
            imageCache[cacheKey] = image
        }
        
        return placeholderImage
    }
}
```

### Battery Drain Issues

#### Symptoms
- Rapid battery drain during tours
- Device heating up
- Location services using excessive power

#### Solutions

**Battery Optimization**:
```swift
func optimizeForBattery() {
    // Reduce location accuracy
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    
    // Increase distance filter
    locationManager.distanceFilter = 20.0
    
    // Reduce region monitoring
    limitActiveRegions(to: 10)
    
    // Lower audio quality
    audioManager.setQuality(.medium)
}
```

**Adaptive Performance**:
```swift
func adaptToBatteryLevel(_ level: Float) {
    switch level {
    case 0.0...0.1: // < 10%
        enableUltraLowPowerMode()
    case 0.1...0.2: // 10-20%
        enableLowPowerMode()
    case 0.2...0.5: // 20-50%
        enableBalancedMode()
    default: // > 50%
        enableFullPerformanceMode()
    }
}
```

## Data and Storage Issues

### Download Failures

#### Symptoms
- Tours fail to download
- Partial downloads that don't complete
- Storage full errors

#### Solutions

**Download Queue Management**:
```swift
func retryFailedDownloads() {
    let failedDownloads = downloadQueue.filter { $0.status == .failed }
    
    for download in failedDownloads {
        // Reset and retry
        download.status = .pending
        download.retryCount += 1
        
        if download.retryCount <= maxRetries {
            enqueueDownload(download)
        }
    }
}
```

**Storage Space Validation**:
```swift
func validateStorageSpace(for download: DownloadTask) -> Bool {
    let availableSpace = getAvailableStorageSpace()
    let requiredSpace = download.estimatedSize * 1.2 // 20% buffer
    
    if availableSpace < requiredSpace {
        showStorageWarning()
        return false
    }
    
    return true
}
```

### Cache Corruption

#### Symptoms
- Tours won't load offline
- Audio files skip or cut out
- Unexpected app crashes when loading content

#### Solutions

**Cache Validation**:
```swift
func validateCacheIntegrity() {
    let corruptedFiles = contentCache.validateAllContent()
    
    for file in corruptedFiles {
        contentCache.removeCorruptedContent(file)
        
        // Re-download if needed
        if isEssentialContent(file) {
            scheduleRedownload(file)
        }
    }
}
```

**Cache Repair**:
```swift
func repairCache() {
    // Clear potentially corrupted content
    contentCache.clearAll()
    
    // Re-download essential tours
    let essentialTours = getDownloadedTours()
    for tour in essentialTours {
        scheduleRedownload(tour)
    }
    
    showCacheRepairNotification()
}
```

## Simulator-Specific Issues

### eligibility.plist Warning

#### Symptoms
- Console warning: `load_eligibility_plist: Failed to open ...eligibility.plist: No such file or directory`
- Only appears in iOS Simulator, not on physical devices
- Does not affect app functionality

#### Cause
This is a known iOS Simulator issue with Apple's location eligibility system introduced in iOS 17.4. The eligibility system determines region-specific features (EU Digital Markets Act compliance), but the simulator doesn't properly create the required system files.

#### Solutions
**For Development**: This warning can be safely ignored as it:
- Only affects iOS Simulator
- Does not impact app functionality
- Does not appear on physical devices
- Is related to Apple's internal location compliance system

**For Testing**: If the warning is distracting during development:
```swift
// Suppress simulator-specific warnings in debug builds
#if targetEnvironment(simulator) && DEBUG
// Known simulator issue - eligibility.plist warnings can be ignored
#endif
```

**Alternative**: Reset the simulator if warnings become excessive:
1. Device → Erase All Content and Settings
2. Clean build folder (⌘⇧K)
3. Rebuild and run

### default.csv Resource Warning

#### Symptoms
- Console warning: `Failed to locate resource named "default.csv"`
- Occurs during app initialization
- Does not prevent normal app operation

#### Cause
This warning typically originates from:
- CarPlay framework internal initialization
- System frameworks attempting to load default configuration
- Third-party dependencies with missing configuration files

#### Solutions
**Investigation Steps**:
1. Check if warning correlates with specific features (CarPlay, location, audio)
2. Monitor if warning appears on physical devices
3. Verify all app bundle resources are properly included

**Resolution**: In most cases, this warning can be safely ignored unless it correlates with actual missing functionality.

### Core Analytics Event Failures

#### Symptoms
- Console warning: `Failed to send CA Event for app launch measurements`
- Includes event types for FirstFramePresentationMetric and ExtendedLaunchMetrics
- Only appears in iOS Simulator during app launch

#### Cause
Core Analytics (CA) launch measurement system cannot properly communicate with simulator infrastructure. This affects Apple's internal app launch performance metrics collection.

#### Solutions
**For Development**: These warnings are harmless and can be ignored:
- Only affect simulator analytics collection
- Do not impact app functionality or performance
- Real device deployment will not show these warnings

### Audio Factory Registration Warnings

#### Symptoms
- Console warning: `AddInstanceForFactory: No factory registered for id <CFUUID> F8BB1C28-BAE8-11D6-9C31-00039315CD46`
- Appears during audio system initialization
- Only occurs in iOS Simulator

#### Cause
Audio framework factory registration issues in simulator environment. The CFUUID corresponds to audio component factory registration that fails in simulator.

#### Solutions
**For Development**: This warning is harmless:
- Audio functionality works normally despite the warning
- Physical devices will not show this warning
- Simulator audio system has known limitations compared to real hardware

**Code Recognition**: The app already handles this correctly:
```swift
#if targetEnvironment(simulator)
print("ℹ️ Running on simulator, using basic audio configuration")
#endif
```

## Emergency Recovery

### Complete App Reset

When all else fails, provide users with a nuclear option:

```swift
func performCompleteReset() {
    // Clear all user data
    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    
    // Clear all caches
    contentCache.clearAll()
    imageCache.clearAll()
    
    // Reset location manager
    locationManager.stopUpdatingLocation()
    locationManager.stopMonitoringSignificantLocationChanges()
    
    // Clear keychain
    SecureStorage.shared.clearAll()
    
    // Restart app
    showRestartRequiredAlert()
}
```

### Diagnostic Information Collection

Help users report issues with comprehensive diagnostic data:

```swift
func generateDiagnosticReport() -> DiagnosticReport {
    return DiagnosticReport(
        deviceInfo: getDeviceInfo(),
        appVersion: getAppVersion(),
        locationStatus: getLocationStatus(),
        audioStatus: getAudioStatus(),
        networkStatus: getNetworkStatus(),
        storageInfo: getStorageInfo(),
        recentErrors: getRecentErrors()
    )
}
```

This troubleshooting guide covers the most common issues users and developers encounter with the Apple Maps Demo application, providing systematic diagnosis and resolution steps for each category of problems.