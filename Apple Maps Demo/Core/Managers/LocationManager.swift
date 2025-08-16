import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var continuationForAuthorization: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var heading: CLHeading?
    @Published var isUpdatingLocation = false
    @Published var locationError: Error?
    
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    private var regionMonitors: [String: CLCircularRegion] = [:]
    
    override private init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.pausesLocationUpdatesAutomatically = false
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
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func enableBackgroundLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            print("Background location requires 'Always' authorization")
            return
        }
        
        do {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
        } catch {
            print("Failed to enable background location updates: \(error)")
        }
    }
    
    func disableBackgroundLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
    }
    
    func startMonitoring(poi: PointOfInterest) {
        let region = CLCircularRegion(
            center: poi.coordinate,
            radius: poi.radius,
            identifier: poi.id.uuidString
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        regionMonitors[poi.id.uuidString] = region
        locationManager.startMonitoring(for: region)
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
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100 else { return }
        
        currentLocation = location
        locationUpdateHandler?(location)
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

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterRegion = Notification.Name("didEnterRegion")
    static let didExitRegion = Notification.Name("didExitRegion")
}