import Foundation
import CoreLocation
import Combine
import UIKit

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
    }
    
    deinit {
        batteryMonitor?.stop()
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
        
        isUpdatingLocation = true
        applyOptimalLocationSettings()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        print("📍 Location updates started with \(currentAccuracyLevel) accuracy")
    }
    
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        print("📍 Location updates stopped")
    }
    
    // MARK: - Performance Optimization Methods
    
    func configureTourType(_ tourType: TourType) {
        self.currentTourType = tourType
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
            batteryOptimizationLevel = newOptimizationLevel
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
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out invalid or old locations
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 10.0 else { return }
        
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        NotificationCenter.default.post(
            name: .didEnterRegion,
            object: nil,
            userInfo: ["regionId": circularRegion.identifier]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        NotificationCenter.default.post(
            name: .didExitRegion,
            object: nil,
            userInfo: ["regionId": circularRegion.identifier]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
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
}