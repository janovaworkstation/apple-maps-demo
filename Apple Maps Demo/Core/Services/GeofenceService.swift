import Foundation
import CoreLocation
import Combine

// MARK: - GeofenceService Protocol

@MainActor
protocol GeofenceServiceProtocol {
    // Core Management
    func startMonitoring(tour: Tour, userLocation: CLLocation?) async throws
    func stopMonitoring() async throws
    func updateMonitoredRegions(userLocation: CLLocation) async throws
    
    // Status & Analytics
    func getMonitoredRegions() -> [POIRegion]
    func getGeofenceStatistics() -> GeofenceStatistics
    
    // Publishers
    var regionEvents: AnyPublisher<RegionEvent, Never> { get }
    var monitoringStatus: AnyPublisher<GeofenceMonitoringStatus, Never> { get }
}

// MARK: - GeofenceService Implementation

@MainActor
class GeofenceService: GeofenceServiceProtocol, ObservableObject {
    static let shared = GeofenceService()
    
    // MARK: - Dependencies
    private let locationManager: LocationManager
    private let dataService: DataService
    
    // MARK: - State
    @Published private(set) var currentTour: Tour?
    @Published private(set) var monitoredPOIRegions: [POIRegion] = []
    @Published private(set) var isMonitoringActive = false
    @Published private(set) var lastUserLocation: CLLocation?
    
    // MARK: - Publishers
    private let regionEventsSubject = PassthroughSubject<RegionEvent, Never>()
    private let monitoringStatusSubject = PassthroughSubject<GeofenceMonitoringStatus, Never>()
    
    var regionEvents: AnyPublisher<RegionEvent, Never> {
        regionEventsSubject.eraseToAnyPublisher()
    }
    
    var monitoringStatus: AnyPublisher<GeofenceMonitoringStatus, Never> {
        monitoringStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Configuration
    private let maxMonitoredRegions = 20 // iOS system limit
    private let regionUpdateThreshold: CLLocationDistance = 500 // Update every 500m
    private let maxMonitoringDistance: CLLocationDistance = 5000 // 5km radius
    private let highPriorityDistance: CLLocationDistance = 1000 // 1km for high priority
    
    // MARK: - Dynamic Configuration Properties
    
    private var effectiveGeofenceRadius: CLLocationDistance {
        return currentTour?.recommendedGeofenceRadius ?? 150.0 // Default to 150 meters
    }
    
    private func calculateDynamicRadius(for poi: PointOfInterest, userLocation: CLLocation?) -> CLLocationDistance {
        // Start with tour type default
        var radius = effectiveGeofenceRadius
        
        // Adjust based on user's current speed if available
        if let userLocation = userLocation, userLocation.speed >= 0 {
            let speedMph = userLocation.speed * 2.237 // Convert m/s to mph
            
            // Speed-based radius adjustment
            switch speedMph {
            case 0...5:
                // Stationary or very slow - smaller radius for precision
                radius = max(50.0, poi.radius * 0.8)
            case 5...15:
                // Walking/jogging speed - standard radius
                radius = max(75.0, poi.radius)
            case 15...35:
                // City driving - larger radius for early detection
                radius = max(200.0, poi.radius * 2.0)
            case 35...55:
                // Highway driving - much larger radius
                radius = max(400.0, poi.radius * 3.0)
            default:
                // Very high speed - maximum radius
                radius = max(600.0, poi.radius * 4.0)
            }
        }
        
        // POI importance can also affect radius
        switch poi.importance {
        case .critical:
            radius *= 1.3 // 30% larger for critical POIs
        case .high:
            radius *= 1.15 // 15% larger for high importance
        case .medium:
            break // No adjustment
        case .low:
            radius *= 0.85 // 15% smaller for low importance
        }
        
        // Clamp to reasonable limits
        return min(max(radius, 30.0), 1000.0) // Between 30m and 1000m
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init(
        locationManager: LocationManager? = nil,
        dataService: DataService? = nil
    ) {
        self.locationManager = locationManager ?? LocationManager.shared
        self.dataService = dataService ?? MainActor.assumeIsolated { DataService.shared }
        
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Listen for region entry/exit events from LocationManager
        NotificationCenter.default.publisher(for: .didEnterRegion)
            .sink { [weak self] notification in
                self?.handleRegionEntry(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .didExitRegion)
            .sink { [weak self] notification in
                self?.handleRegionExit(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Management
    
    func startMonitoring(tour: Tour, userLocation: CLLocation? = nil) async throws {
        print("🎯 Starting geofence monitoring for tour: \(tour.name)")
        
        // Stop any existing monitoring
        try await stopMonitoring()
        
        self.currentTour = tour
        self.lastUserLocation = userLocation
        
        // Get POIs for this tour
        let pois = try await dataService.poiRepository.fetchByTour(tour.id)
        guard !pois.isEmpty else {
            throw GeofenceError.noPOIsFound
        }
        
        // Initialize monitoring with smart region selection
        try await updateMonitoredRegionsInternal(pois: pois, userLocation: userLocation)
        
        isMonitoringActive = true
        monitoringStatusSubject.send(.started(tour: tour, regionCount: monitoredPOIRegions.count))
        
        print("✅ Geofence monitoring started with \(monitoredPOIRegions.count) regions")
    }
    
    func stopMonitoring() async throws {
        print("🛑 Stopping geofence monitoring")
        
        // Stop all location monitoring
        locationManager.stopAllMonitoring()
        
        // Clear state
        monitoredPOIRegions.removeAll()
        currentTour = nil
        isMonitoringActive = false
        
        monitoringStatusSubject.send(.stopped)
        print("✅ Geofence monitoring stopped")
    }
    
    func updateMonitoredRegions(userLocation: CLLocation) async throws {
        guard isMonitoringActive,
              let tour = currentTour,
              shouldUpdateRegions(for: userLocation) else { return }
        
        print("🔄 Updating monitored regions based on user location")
        
        let pois = try await dataService.poiRepository.fetchByTour(tour.id)
        try await updateMonitoredRegionsInternal(pois: pois, userLocation: userLocation)
        
        lastUserLocation = userLocation
        print("✅ Updated monitoring with \(monitoredPOIRegions.count) regions")
    }
    
    // MARK: - Private Implementation
    
    private func updateMonitoredRegionsInternal(pois: [PointOfInterest], userLocation: CLLocation?) async throws {
        // Stop current monitoring
        locationManager.stopAllMonitoring()
        
        // Calculate priority scores for each POI
        let prioritizedPOIs = calculatePOIPriorities(pois: pois, userLocation: userLocation)
        
        // Select top POIs to monitor (respecting iOS 20 region limit)
        let poisToMonitor = Array(prioritizedPOIs.prefix(maxMonitoredRegions))
        
        // Create POI regions
        var newRegions: [POIRegion] = []
        
        for prioritizedPOI in poisToMonitor {
            let poi = prioritizedPOI.poi
            
            // Calculate dynamic radius based on tour type, speed, and POI importance
            let geofenceRadius = calculateDynamicRadius(for: poi, userLocation: userLocation)
            
            let region = POIRegion(
                poi: poi,
                priority: prioritizedPOI.priority,
                distanceFromUser: prioritizedPOI.distanceFromUser
            )
            
            // Start monitoring this region with dynamic radius
            locationManager.startMonitoring(poi: poi, radius: geofenceRadius)
            newRegions.append(region)
            
            print("📊 POI '\(poi.name)': radius=\(Int(geofenceRadius))m, priority=\(prioritizedPOI.priority.rawValue), distance=\(Int(prioritizedPOI.distanceFromUser))m")
        }
        
        self.monitoredPOIRegions = newRegions
        
        // Notify about region updates
        monitoringStatusSubject.send(.regionsUpdated(count: newRegions.count))
    }
    
    private func calculatePOIPriorities(
        pois: [PointOfInterest],
        userLocation: CLLocation?
    ) -> [PrioritizedPOI] {
        var prioritizedPOIs: [PrioritizedPOI] = []
        
        for poi in pois {
            let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
            let distanceFromUser = userLocation?.distance(from: poiLocation) ?? Double.infinity
            
            // Skip POIs that are too far away
            guard distanceFromUser <= maxMonitoringDistance else { continue }
            
            var priority: POIPriority = .low
            var score: Double = 0
            
            // Base score from POI importance
            switch poi.importance {
            case .critical:
                score += 100
                priority = .critical
            case .high:
                score += 75
                priority = .high
            case .medium:
                score += 50
                priority = .medium
            case .low:
                score += 25
                priority = .low
            }
            
            // Distance bonus (closer is higher priority) - adjusted for tour type
            let distanceThreshold = currentTour?.tourType == .driving ? 2000.0 : highPriorityDistance // 2km for driving, 1km for walking
            
            if distanceFromUser <= distanceThreshold {
                let proximityBonus = currentTour?.tourType == .driving ? 30.0 : 50.0 // Less proximity bonus for driving tours
                score += proximityBonus
                priority = priority.elevated()
            } else {
                let distanceScale = currentTour?.tourType == .driving ? 200.0 : 100.0 // Different scaling for driving vs walking
                score += max(0, 50.0 - (distanceFromUser / distanceScale))
            }
            
            // Tour order bonus (next POIs in sequence get higher priority) - adjusted for tour type
            let orderWeight = currentTour?.tourType == .driving ? 15.0 : 20.0 // Slightly less order importance for driving tours
            let orderBonus = max(0, orderWeight - Double(poi.order))
            score += orderBonus
            
            // Visited penalty (lower priority for already visited POIs)
            if poi.isVisited {
                score -= 30
            }
            
            prioritizedPOIs.append(PrioritizedPOI(
                poi: poi,
                priority: priority,
                score: score,
                distanceFromUser: distanceFromUser
            ))
        }
        
        // Sort by score (highest first)
        return prioritizedPOIs.sorted { $0.score > $1.score }
    }
    
    private func shouldUpdateRegions(for userLocation: CLLocation) -> Bool {
        guard let lastLocation = lastUserLocation else { return true }
        
        let distanceMoved = userLocation.distance(from: lastLocation)
        return distanceMoved >= regionUpdateThreshold
    }
    
    // MARK: - Event Handling
    
    private func handleRegionEntry(_ notification: Notification) {
        guard let regionId = notification.userInfo?["regionId"] as? String,
              let poiId = UUID(uuidString: regionId),
              let region = monitoredPOIRegions.first(where: { $0.poi.id == poiId }) else {
            return
        }
        
        print("🏃‍♂️ User entered region for POI: \(region.poi.name)")
        
        let event = RegionEvent(
            type: .entry,
            poi: region.poi,
            timestamp: Date(),
            userLocation: locationManager.currentLocation
        )
        
        regionEventsSubject.send(event)
    }
    
    private func handleRegionExit(_ notification: Notification) {
        guard let regionId = notification.userInfo?["regionId"] as? String,
              let poiId = UUID(uuidString: regionId),
              let region = monitoredPOIRegions.first(where: { $0.poi.id == poiId }) else {
            return
        }
        
        print("🚪 User exited region for POI: \(region.poi.name)")
        
        let event = RegionEvent(
            type: .exit,
            poi: region.poi,
            timestamp: Date(),
            userLocation: locationManager.currentLocation
        )
        
        regionEventsSubject.send(event)
    }
    
    // MARK: - Status & Analytics
    
    func getMonitoredRegions() -> [POIRegion] {
        return monitoredPOIRegions
    }
    
    func getGeofenceStatistics() -> GeofenceStatistics {
        let totalRegions = monitoredPOIRegions.count
        let criticalRegions = monitoredPOIRegions.filter { $0.priority == .critical }.count
        let highRegions = monitoredPOIRegions.filter { $0.priority == .high }.count
        let averageDistance = monitoredPOIRegions.reduce(0.0) { $0 + $1.distanceFromUser } / Double(max(totalRegions, 1))
        
        return GeofenceStatistics(
            totalMonitoredRegions: totalRegions,
            maxRegions: maxMonitoredRegions,
            criticalPriorityCount: criticalRegions,
            highPriorityCount: highRegions,
            averageDistanceFromUser: averageDistance,
            isActive: isMonitoringActive,
            currentTour: currentTour
        )
    }
}

// MARK: - Supporting Types

struct POIRegion {
    let poi: PointOfInterest
    let priority: POIPriority
    let distanceFromUser: CLLocationDistance
    let createdAt: Date
    
    init(poi: PointOfInterest, priority: POIPriority, distanceFromUser: CLLocationDistance) {
        self.poi = poi
        self.priority = priority
        self.distanceFromUser = distanceFromUser
        self.createdAt = Date()
    }
}

struct PrioritizedPOI {
    let poi: PointOfInterest
    let priority: POIPriority
    let score: Double
    let distanceFromUser: CLLocationDistance
}

enum POIPriority: String, CaseIterable, Comparable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    static func < (lhs: POIPriority, rhs: POIPriority) -> Bool {
        return lhs.numericValue < rhs.numericValue
    }
    
    private var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
    
    func elevated() -> POIPriority {
        switch self {
        case .low: return .medium
        case .medium: return .high
        case .high: return .critical
        case .critical: return .critical
        }
    }
}

struct RegionEvent {
    let type: RegionEventType
    let poi: PointOfInterest
    let timestamp: Date
    let userLocation: CLLocation?
}

enum RegionEventType {
    case entry
    case exit
}

enum GeofenceMonitoringStatus {
    case started(tour: Tour, regionCount: Int)
    case stopped
    case regionsUpdated(count: Int)
    case error(GeofenceError)
}

struct GeofenceStatistics {
    let totalMonitoredRegions: Int
    let maxRegions: Int
    let criticalPriorityCount: Int
    let highPriorityCount: Int
    let averageDistanceFromUser: CLLocationDistance
    let isActive: Bool
    let currentTour: Tour?
    
    var utilizationPercentage: Double {
        return Double(totalMonitoredRegions) / Double(maxRegions) * 100.0
    }
    
    var formattedAverageDistance: String {
        if averageDistanceFromUser < 1000 {
            return String(format: "%.0fm", averageDistanceFromUser)
        } else {
            return String(format: "%.1fkm", averageDistanceFromUser / 1000)
        }
    }
}

enum GeofenceError: LocalizedError {
    case noPOIsFound
    case locationServicesDisabled
    case monitoringFailed(Error)
    case maxRegionsExceeded
    
    var errorDescription: String? {
        switch self {
        case .noPOIsFound:
            return "No points of interest found for tour"
        case .locationServicesDisabled:
            return "Location services are disabled"
        case .monitoringFailed(let error):
            return "Geofence monitoring failed: \(error.localizedDescription)"
        case .maxRegionsExceeded:
            return "Maximum number of monitored regions exceeded"
        }
    }
}