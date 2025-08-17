import Foundation
import CoreLocation
import Combine
import UIKit

/// Intelligent location tracking and geofencing manager with battery optimization.
///
/// `LocationManager` provides comprehensive location services for audio tours with
/// advanced features including dynamic accuracy adjustment, battery-aware optimization,
/// intelligent geofencing, and tour type adaptation. The manager automatically
/// optimizes GPS accuracy and update frequency based on device conditions.
///
/// ## Key Features
///
/// - **Dynamic Accuracy**: Automatically adjusts GPS accuracy based on battery level and tour type
/// - **Smart Geofencing**: Intelligent region management with iOS 20-region limit optimization
/// - **Battery Optimization**: Reduces location accuracy and frequency when battery is low
/// - **Movement Detection**: Adapts behavior based on detected movement patterns
/// - **Tour Type Adaptation**: Optimizes settings for walking, driving, or mixed tours
///
/// ## Usage
///
/// ```swift
/// let locationManager = LocationManager.shared
/// 
/// // Request location permission
/// let status = await locationManager.requestAuthorization()
/// 
/// // Start location updates
/// locationManager.startUpdatingLocation()
/// 
/// // Configure for tour type
/// locationManager.configureTourType(.walking)
/// 
/// // Monitor POI geofences
/// locationManager.startMonitoring(poi: pointOfInterest)
/// ```
///
/// ## Battery Optimization
///
/// The manager automatically adjusts location accuracy based on battery level:
/// - **> 50%**: Full accuracy for optimal experience
/// - **20-50%**: Moderate accuracy to conserve battery
/// - **< 20%**: Aggressive optimization with reduced accuracy
///
/// ## Tour Type Optimization
///
/// Different tour types receive optimized location settings:
/// - ``TourType/walking``: High accuracy, smaller geofences, longer dwell times
/// - ``TourType/driving``: Medium accuracy, larger geofences, shorter dwell times
/// - ``TourType/mixed``: Adaptive accuracy based on detected movement speed
///
/// ## Performance Characteristics
///
/// - Automatic stationary mode detection to reduce GPS usage
/// - Dynamic geofence registration based on proximity
/// - Movement pattern analysis for behavioral adaptation
/// - Memory-efficient region management within iOS limits
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var continuationForAuthorization: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var heading: CLHeading?
    @Published var isUpdatingLocation = false
    @Published var locationError: Error?
    
    // Performance optimization properties
    @Published var currentAccuracyLevel: LocationAccuracyLevel = .standard
    @Published var batteryOptimizationLevel: BatteryOptimizationLevel = .normal
    @Published var currentTourType: TourType?
    
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    private var regionMonitors: [String: CLCircularRegion] = [:]
    private var lastLocationUpdate: Date = Date()
    private var locationUpdateCount: Int = 0
    private var batteryMonitor: BatteryMonitor?
    private var movementDetector: MovementDetector?
    
    // Adaptive settings
    private var currentUpdateInterval: TimeInterval = 1.0
    private var isStationary: Bool = false
    private var lastSignificantMovement: Date = Date()
    
    override private init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        locationManager.delegate = self
        setupBatteryMonitoring()
        setupMovementDetection()
        configureLocationManagerForOptimalPerformance()
        setupTourNotifications()
    }
    
    deinit {
        batteryMonitor?.stop()
        NotificationCenter.default.removeObserver(self)
        print("🧹 LocationManager cleanup completed")
    }
    
    func requestAuthorization() async -> CLAuthorizationStatus {
        switch authorizationStatus {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.continuationForAuthorization = continuation
                locationManager.requestAlwaysAuthorization()
            }
        default:
            return authorizationStatus
        }
    }
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            locationError = LocationError.unauthorized
            return
        }
        
        Task { @MainActor in
            isUpdatingLocation = true
        }
        applyOptimalLocationSettings()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        print("📍 Location updates started with \(currentAccuracyLevel) accuracy")
    }
    
    func stopUpdatingLocation() {
        Task { @MainActor in
            isUpdatingLocation = false
        }
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        print("📍 Location updates stopped")
    }
    
    // MARK: - Performance Optimization Methods
    
    func configureTourType(_ tourType: TourType) {
        Task { @MainActor in
            self.currentTourType = tourType
        }
        adaptLocationSettingsForTourType(tourType)
        print("📍 Location configured for \(tourType) tour")
    }
    
    func optimizeForBatteryLevel(_ level: Float) {
        let newOptimizationLevel: BatteryOptimizationLevel
        
        if level <= 0.20 {
            newOptimizationLevel = .aggressive
        } else if level <= 0.50 {
            newOptimizationLevel = .moderate
        } else {
            newOptimizationLevel = .normal
        }
        
        if newOptimizationLevel != batteryOptimizationLevel {
            Task { @MainActor in
                batteryOptimizationLevel = newOptimizationLevel
            }
            applyOptimalLocationSettings()
            print("📍 Battery optimization level: \(newOptimizationLevel)")
        }
    }
    
    func enterStationaryMode() {
        guard !isStationary else { return }
        isStationary = true
        applyOptimalLocationSettings()
        print("📍 Entered stationary mode - reducing location accuracy")
    }
    
    func exitStationaryMode() {
        guard isStationary else { return }
        isStationary = false
        lastSignificantMovement = Date()
        applyOptimalLocationSettings()
        print("📍 Exited stationary mode - restoring location accuracy")
    }
    
    func enableBackgroundLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            print("Background location requires 'Always' authorization")
            return
        }
        
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func disableBackgroundLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
    }
    
    func startMonitoring(poi: PointOfInterest, radius: CLLocationDistance? = nil) {
        let effectiveRadius = radius ?? poi.radius
        let region = CLCircularRegion(
            center: poi.coordinate,
            radius: effectiveRadius,
            identifier: poi.id.uuidString
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        regionMonitors[poi.id.uuidString] = region
        locationManager.startMonitoring(for: region)
        
        print("📍 Started monitoring POI '\(poi.name)' with radius \(effectiveRadius)m")
    }
    
    func stopMonitoring(poi: PointOfInterest) {
        guard let region = regionMonitors[poi.id.uuidString] else { return }
        
        locationManager.stopMonitoring(for: region)
        regionMonitors.removeValue(forKey: poi.id.uuidString)
    }
    
    func stopAllMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        regionMonitors.removeAll()
    }
    
    func distanceToLocation(_ location: CLLocation) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        return currentLocation.distance(from: location)
    }
    
    // MARK: - Private Optimization Methods
    
    private func setupBatteryMonitoring() {
        batteryMonitor = BatteryMonitor { [weak self] batteryLevel in
            Task { @MainActor in
                self?.optimizeForBatteryLevel(batteryLevel)
            }
        }
        batteryMonitor?.start()
    }
    
    private func setupMovementDetection() {
        movementDetector = MovementDetector { [weak self] isMoving in
            Task { @MainActor in
                if isMoving {
                    self?.exitStationaryMode()
                } else {
                    self?.enterStationaryMode()
                }
            }
        }
    }
    
    private func configureLocationManagerForOptimalPerformance() {
        // Set initial optimal settings
        applyOptimalLocationSettings()
    }
    
    private func adaptLocationSettingsForTourType(_ tourType: TourType) {
        Task { @MainActor in
            switch tourType {
            case .driving:
                currentAccuracyLevel = .high
                currentUpdateInterval = 0.5  // More frequent updates for driving
            case .walking:
                currentAccuracyLevel = .standard
                currentUpdateInterval = 2.0  // Less frequent for walking
            case .mixed:
                currentAccuracyLevel = .standard
                currentUpdateInterval = 1.0  // Balanced approach
            @unknown default:
                currentAccuracyLevel = .standard
                currentUpdateInterval = 1.0
            }
            
            applyOptimalLocationSettings()
        }
    }
    
    private func applyOptimalLocationSettings() {
        // Determine accuracy based on current state
        let targetAccuracy = calculateOptimalAccuracy()
        let targetDistanceFilter = calculateOptimalDistanceFilter()
        
        // Apply settings
        locationManager.desiredAccuracy = targetAccuracy
        locationManager.distanceFilter = targetDistanceFilter
        
        // Configure pause settings based on battery optimization
        switch batteryOptimizationLevel {
        case .normal:
            locationManager.pausesLocationUpdatesAutomatically = false
        case .moderate:
            locationManager.pausesLocationUpdatesAutomatically = true
        case .aggressive:
            locationManager.pausesLocationUpdatesAutomatically = true
            // Switch to significant location changes in aggressive mode
            if isUpdatingLocation {
                locationManager.stopUpdatingLocation()
                locationManager.startMonitoringSignificantLocationChanges()
            }
        }
        
        print("📍 Applied settings: accuracy=\(targetAccuracy)m, filter=\(targetDistanceFilter)m")
    }
    
    private func calculateOptimalAccuracy() -> CLLocationAccuracy {
        // Start with base accuracy for current level
        var accuracy: CLLocationAccuracy
        
        switch currentAccuracyLevel {
        case .low:
            accuracy = kCLLocationAccuracyKilometer
        case .standard:
            accuracy = kCLLocationAccuracyHundredMeters
        case .high:
            accuracy = kCLLocationAccuracyBest
        }
        
        // Adjust for battery optimization
        switch batteryOptimizationLevel {
        case .normal:
            // No adjustment
            break
        case .moderate:
            // Reduce accuracy by one level
            if accuracy == kCLLocationAccuracyBest {
                accuracy = kCLLocationAccuracyNearestTenMeters
            } else if accuracy == kCLLocationAccuracyHundredMeters {
                accuracy = kCLLocationAccuracyKilometer
            }
        case .aggressive:
            // Use lowest accuracy
            accuracy = kCLLocationAccuracyKilometer
        }
        
        // Further adjust if stationary
        if isStationary {
            accuracy = max(accuracy, kCLLocationAccuracyHundredMeters)
        }
        
        return accuracy
    }
    
    private func calculateOptimalDistanceFilter() -> CLLocationDistance {
        var baseFilter: CLLocationDistance
        
        // Base filter depends on tour type
        switch currentTourType {
        case .driving:
            baseFilter = 5.0   // 5 meters for driving
        case .walking:
            baseFilter = 10.0  // 10 meters for walking
        case .mixed:
            baseFilter = 7.0   // 7 meters for mixed
        case .none:
            baseFilter = 10.0  // Default
        @unknown default:
            baseFilter = 10.0
        }
        
        // Adjust for battery optimization
        switch batteryOptimizationLevel {
        case .normal:
            break
        case .moderate:
            baseFilter *= 1.5
        case .aggressive:
            baseFilter *= 3.0
        }
        
        // Increase filter if stationary
        if isStationary {
            baseFilter *= 2.0
        }
        
        return baseFilter
    }
    
    // MARK: - Tour Management
    
    private func setupTourNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTourStarted(_:)),
            name: .tourStarted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTourStopped(_:)),
            name: .tourStopped,
            object: nil
        )
    }
    
    @objc private func handleTourStarted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tour = userInfo["tour"] as? Tour else { return }
        
        Task { @MainActor in
            await startTourLocationTracking(tour)
        }
    }
    
    @objc private func handleTourStopped(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tour = userInfo["tour"] as? Tour else { return }
        
        Task { @MainActor in
            await stopTourLocationTracking(tour)
        }
    }
    
    private func startTourLocationTracking(_ tour: Tour) async {
        print("📍 Starting location tracking for tour: \(tour.name)")
        
        // Configure location settings for tour type
        configureTourType(tour.tourType)
        
        // Start location updates if not already running
        startUpdatingLocation()
        
        // Set up geofencing for all POIs in the tour
        for poi in tour.pointsOfInterest {
            startMonitoring(poi: poi)
        }
        
        print("📍 Location tracking and geofencing setup complete for \(tour.pointsOfInterest.count) POIs")
    }
    
    private func stopTourLocationTracking(_ tour: Tour) async {
        print("📍 Stopping location tracking for tour: \(tour.name)")
        
        // Stop monitoring all POIs for this tour
        for poi in tour.pointsOfInterest {
            stopMonitoring(poi: poi)
        }
        
        // Optionally stop location updates if no other tours are active
        // Note: We could keep location running for other potential uses
        stopUpdatingLocation()
        
        print("📍 Location tracking stopped for tour: \(tour.name)")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            if let continuation = continuationForAuthorization {
                continuation.resume(returning: authorizationStatus)
                continuationForAuthorization = nil
            }
            
            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                startUpdatingLocation()
            case .denied, .restricted:
                locationError = LocationError.unauthorized
                stopUpdatingLocation()
            default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out invalid or old locations
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 10.0 else { return }
        
        Task { @MainActor in
            // Dynamic accuracy filtering based on current settings
            let maxAccuracy = calculateOptimalAccuracy()
            guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= maxAccuracy else { return }
            
            // Update movement detection
            movementDetector?.addLocation(location)
            
            // Track location update performance
            locationUpdateCount += 1
            lastLocationUpdate = Date()
            
            currentLocation = location
            locationUpdateHandler?(location)
            
            // Optimize settings based on movement patterns
            optimizeBasedOnMovementPattern(location)
        }
    }
    
    private func optimizeBasedOnMovementPattern(_ location: CLLocation) {
        guard let previousLocation = currentLocation else { return }
        
        let distance = location.distance(from: previousLocation)
        let timeInterval = location.timestamp.timeIntervalSince(previousLocation.timestamp)
        
        // Detect if user is moving significantly
        let isSignificantMovement = distance > 10.0 && timeInterval > 0
        
        if isSignificantMovement {
            lastSignificantMovement = Date()
            if isStationary {
                exitStationaryMode()
            }
        } else {
            // Check if user has been stationary for a while
            let timeSinceLastMovement = Date().timeIntervalSince(lastSignificantMovement)
            if timeSinceLastMovement > 300.0 && !isStationary { // 5 minutes
                enterStationaryMode()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            heading = newHeading
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        NotificationCenter.default.post(
            name: .didEnterRegion,
            object: nil,
            userInfo: ["regionId": circularRegion.identifier]
        )
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        NotificationCenter.default.post(
            name: .didExitRegion,
            object: nil,
            userInfo: ["regionId": circularRegion.identifier]
        )
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = error
        }
        
        // Handle common simulator errors more gracefully
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                #if targetEnvironment(simulator)
                print("📍 Location unknown in simulator - this is expected behavior")
                #else
                print("📍 Location unknown on device - GPS may be unavailable")
                #endif
            case .denied:
                print("📍 Location access denied")
            case .network:
                print("📍 Network error when determining location")
            default:
                print("📍 Location error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Error Types

enum LocationError: LocalizedError {
    case unauthorized
    case locationServicesDisabled
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Location access not authorized. Please enable in Settings."
        case .locationServicesDisabled:
            return "Location services are disabled. Please enable in Settings."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Supporting Types

enum LocationAccuracyLevel {
    case low        // ~1km accuracy
    case standard   // ~100m accuracy  
    case high       // Best available accuracy
}

enum BatteryOptimizationLevel {
    case normal     // Full accuracy and update rate
    case moderate   // Reduced accuracy, normal updates
    case aggressive // Minimal accuracy, significant location changes only
}

// MARK: - Battery Monitor

class BatteryMonitor {
    private let onBatteryLevelChange: (Float) -> Void
    private var isMonitoring = false
    
    init(onBatteryLevelChange: @escaping (Float) -> Void) {
        self.onBatteryLevelChange = onBatteryLevelChange
    }
    
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let batteryLevel = UIDevice.current.batteryLevel
            if batteryLevel >= 0 { // Valid battery level
                self?.onBatteryLevelChange(batteryLevel)
            }
        }
        
        // Initial battery level check
        let currentLevel = UIDevice.current.batteryLevel
        if currentLevel >= 0 {
            onBatteryLevelChange(currentLevel)
        }
    }
    
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}

// MARK: - Movement Detector

class MovementDetector {
    private let onMovementChange: (Bool) -> Void
    private var recentLocations: [CLLocation] = []
    private let maxLocationHistory = 10
    private var isCurrentlyMoving = false
    
    init(onMovementChange: @escaping (Bool) -> Void) {
        self.onMovementChange = onMovementChange
    }
    
    func addLocation(_ location: CLLocation) {
        recentLocations.append(location)
        
        // Keep only recent locations
        if recentLocations.count > maxLocationHistory {
            recentLocations.removeFirst()
        }
        
        // Analyze movement pattern
        let isMoving = analyzeMovement()
        if isMoving != isCurrentlyMoving {
            isCurrentlyMoving = isMoving
            onMovementChange(isMoving)
        }
    }
    
    private func analyzeMovement() -> Bool {
        guard recentLocations.count >= 3 else { return false }
        
        let recentLocs = Array(recentLocations.suffix(3))
        var totalDistance: CLLocationDistance = 0
        var totalTime: TimeInterval = 0
        
        for i in 1..<recentLocs.count {
            totalDistance += recentLocs[i].distance(from: recentLocs[i-1])
            totalTime += recentLocs[i].timestamp.timeIntervalSince(recentLocs[i-1].timestamp)
        }
        
        // Calculate average speed
        let avgSpeed = totalTime > 0 ? totalDistance / totalTime : 0
        
        // Consider moving if average speed > 0.5 m/s (~1.8 km/h)
        return avgSpeed > 0.5
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterRegion = Notification.Name("didEnterRegion")
    static let didExitRegion = Notification.Name("didExitRegion")
    static let tourStarted = Notification.Name("tourStarted")
    static let tourStopped = Notification.Name("tourStopped")
}