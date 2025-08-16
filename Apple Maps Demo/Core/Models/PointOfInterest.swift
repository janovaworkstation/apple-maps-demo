import Foundation
import CoreLocation
import SwiftData

@Model
final class PointOfInterest: @unchecked Sendable {
    var id: UUID
    var tourId: UUID
    var name: String
    var poiDescription: String
    var latitude: Double
    var longitude: Double
    var radius: CLLocationDistance
    var audioContent: AudioContent?
    var triggerType: TriggerType
    var order: Int
    var imageURL: URL?
    var visitedAt: Date?
    var isVisited: Bool
    var dwellTime: TimeInterval
    var minAccuracy: CLLocationAccuracy
    var beaconUUID: String?
    var beaconMajor: Int?
    var beaconMinor: Int?
    var altitude: Double?
    var category: POICategory
    var estimatedVisitDuration: TimeInterval
    var importance: POIImportance
    var accessibility: AccessibilityInfo
    var operatingHours: OperatingHours?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        if let altitude = altitude {
            return CLLocation(coordinate: coordinate, altitude: altitude, horizontalAccuracy: minAccuracy, verticalAccuracy: -1, timestamp: Date())
        } else {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
    }
    
    init(
        id: UUID = UUID(),
        tourId: UUID,
        name: String,
        description: String,
        latitude: Double,
        longitude: Double,
        radius: CLLocationDistance = 50,
        triggerType: TriggerType = .location,
        order: Int = 0,
        category: POICategory = .general,
        importance: POIImportance = .medium
    ) {
        self.id = id
        self.tourId = tourId
        self.name = name
        self.poiDescription = description
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.triggerType = triggerType
        self.order = order
        self.isVisited = false
        self.dwellTime = 0
        self.minAccuracy = 20 // 20 meters default accuracy requirement
        self.category = category
        self.estimatedVisitDuration = 120 // 2 minutes default
        self.importance = importance
        self.accessibility = AccessibilityInfo()
    }
}

// MARK: - PointOfInterest Extensions
extension PointOfInterest {
    // MARK: - Computed Properties
    
    var isValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !poiDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               CLLocationCoordinate2DIsValid(coordinate)
    }
    
    var formattedCoordinate: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
    
    var formattedDwellTime: String {
        guard dwellTime > 0 else { return "Not visited" }
        let minutes = Int(dwellTime) / 60
        let seconds = Int(dwellTime) % 60
        return "\(minutes)m \(seconds)s"
    }
    
    var statusIcon: String {
        if isVisited {
            return "checkmark.circle.fill"
        } else {
            switch importance {
            case .critical: return "exclamationmark.circle.fill"
            case .high: return "star.circle.fill"
            case .medium: return "circle"
            case .low: return "circle.dotted"
            }
        }
    }
    
    var isCurrentlyOpen: Bool {
        guard let operatingHours = operatingHours else { return true }
        return operatingHours.isCurrentlyOpen
    }
    
    // MARK: - Location & Geofencing Methods
    
    func distanceFrom(_ location: CLLocation) -> CLLocationDistance {
        return location.distance(from: self.location)
    }
    
    func isWithinRange(of location: CLLocation, accuracyThreshold: CLLocationAccuracy = 100) -> Bool {
        guard location.horizontalAccuracy <= accuracyThreshold else { return false }
        return distanceFrom(location) <= radius
    }
    
    func isAccurateEnough(for location: CLLocation) -> Bool {
        return location.horizontalAccuracy > 0 && location.horizontalAccuracy <= minAccuracy
    }
    
    func createGeofence() -> CLCircularRegion {
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: id.uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
    
    func createBeaconRegion() -> CLBeaconRegion? {
        guard triggerType == .beacon,
              let uuidString = beaconUUID,
              let uuid = UUID(uuidString: uuidString) else { return nil }
        
        let beaconRegion = CLBeaconRegion(uuid: uuid, identifier: id.uuidString)
        
        if let major = beaconMajor {
            if let minor = beaconMinor {
                return CLBeaconRegion(uuid: uuid, major: CLBeaconMajorValue(major), minor: CLBeaconMinorValue(minor), identifier: id.uuidString)
            } else {
                return CLBeaconRegion(uuid: uuid, major: CLBeaconMajorValue(major), identifier: id.uuidString)
            }
        }
        
        return beaconRegion
    }
    
    // MARK: - Visit Tracking
    
    func markAsVisited() {
        isVisited = true
        visitedAt = Date()
    }
    
    func recordDwellTime(_ duration: TimeInterval) {
        dwellTime += duration
    }
    
    func resetVisitStatus() {
        isVisited = false
        visitedAt = nil
        dwellTime = 0
    }
    
    // MARK: - Validation Methods
    
    func validateName() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw POIValidationError.emptyName
        }
        if trimmedName.count > 100 {
            throw POIValidationError.nameTooLong
        }
    }
    
    func validateDescription() throws {
        let trimmedDescription = poiDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            throw POIValidationError.emptyDescription
        }
    }
    
    func validateCoordinates() throws {
        if !CLLocationCoordinate2DIsValid(coordinate) {
            throw POIValidationError.invalidCoordinates
        }
        if latitude < -90 || latitude > 90 {
            throw POIValidationError.invalidLatitude
        }
        if longitude < -180 || longitude > 180 {
            throw POIValidationError.invalidLongitude
        }
    }
    
    func validateRadius() throws {
        if radius <= 0 {
            throw POIValidationError.invalidRadius
        }
        if radius > 1000 {
            throw POIValidationError.radiusTooLarge
        }
    }
    
    func validateBeaconData() throws {
        if triggerType == .beacon {
            guard let uuidString = beaconUUID, UUID(uuidString: uuidString) != nil else {
                throw POIValidationError.invalidBeaconUUID
            }
            if let major = beaconMajor, (major < 0 || major > 65535) {
                throw POIValidationError.invalidBeaconMajor
            }
            if let minor = beaconMinor, (minor < 0 || minor > 65535) {
                throw POIValidationError.invalidBeaconMinor
            }
        }
    }
    
    func validate() throws {
        try validateName()
        try validateDescription()
        try validateCoordinates()
        try validateRadius()
        try validateBeaconData()
    }
    
    // MARK: - Business Logic
    
    func updateCoordinate(latitude: Double, longitude: Double) throws {
        self.latitude = latitude
        self.longitude = longitude
        try validateCoordinates()
    }
    
    func updateRadius(_ newRadius: CLLocationDistance) throws {
        self.radius = newRadius
        try validateRadius()
    }
    
    func configureAsBeacon(uuid: String, major: Int? = nil, minor: Int? = nil) throws {
        guard UUID(uuidString: uuid) != nil else {
            throw POIValidationError.invalidBeaconUUID
        }
        
        self.triggerType = .beacon
        self.beaconUUID = uuid
        self.beaconMajor = major
        self.beaconMinor = minor
        
        try validateBeaconData()
    }
}

// MARK: - Supporting Types

enum TriggerType: String, Codable, CaseIterable {
    case location = "location"
    case beacon = "beacon"
    case manual = "manual"
    case time = "time"
    
    var description: String {
        switch self {
        case .location: return "GPS Location"
        case .beacon: return "Bluetooth Beacon"
        case .manual: return "Manual Trigger"
        case .time: return "Time-based"
        }
    }
    
    var iconName: String {
        switch self {
        case .location: return "location.circle"
        case .beacon: return "dot.radiowaves.left.and.right"
        case .manual: return "hand.tap"
        case .time: return "clock"
        }
    }
}

enum POICategory: String, Codable, CaseIterable {
    case landmark = "Landmark"
    case museum = "Museum"
    case restaurant = "Restaurant"
    case shop = "Shop"
    case park = "Park"
    case building = "Building"
    case monument = "Monument"
    case viewpoint = "Viewpoint"
    case general = "General"
    
    var iconName: String {
        switch self {
        case .landmark: return "mappin.and.ellipse"
        case .museum: return "building.columns"
        case .restaurant: return "fork.knife"
        case .shop: return "storefront"
        case .park: return "tree"
        case .building: return "building"
        case .monument: return "building.columns.fill"
        case .viewpoint: return "mountain.2"
        case .general: return "mappin"
        }
    }
}

enum POIImportance: String, Codable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var priority: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "gray"
        }
    }
}

struct AccessibilityInfo: Codable {
    var wheelchairAccessible: Bool = false
    var hearingImpairedSupport: Bool = false
    var visuallyImpairedSupport: Bool = false
    var additionalNotes: String = ""
    
    var hasAccessibilityFeatures: Bool {
        return wheelchairAccessible || hearingImpairedSupport || visuallyImpairedSupport
    }
}

struct OperatingHours: Codable {
    var monday: DayHours?
    var tuesday: DayHours?
    var wednesday: DayHours?
    var thursday: DayHours?
    var friday: DayHours?
    var saturday: DayHours?
    var sunday: DayHours?
    
    var isCurrentlyOpen: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        
        let dayHours: DayHours?
        switch weekday {
        case 1: dayHours = sunday
        case 2: dayHours = monday
        case 3: dayHours = tuesday
        case 4: dayHours = wednesday
        case 5: dayHours = thursday
        case 6: dayHours = friday
        case 7: dayHours = saturday
        default: dayHours = nil
        }
        
        guard let hours = dayHours, !hours.isClosed else { return false }
        
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        
        return currentMinutes >= hours.openMinutes && currentMinutes <= hours.closeMinutes
    }
}

struct DayHours: Codable {
    var openTime: String // "09:00"
    var closeTime: String // "17:00"
    var isClosed: Bool = false
    
    var openMinutes: Int {
        let components = openTime.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return 0 }
        return components[0] * 60 + components[1]
    }
    
    var closeMinutes: Int {
        let components = closeTime.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return 1440 } // End of day
        return components[0] * 60 + components[1]
    }
}

enum POIValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case emptyDescription
    case invalidCoordinates
    case invalidLatitude
    case invalidLongitude
    case invalidRadius
    case radiusTooLarge
    case invalidBeaconUUID
    case invalidBeaconMajor
    case invalidBeaconMinor
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "POI name cannot be empty"
        case .nameTooLong:
            return "POI name cannot exceed 100 characters"
        case .emptyDescription:
            return "POI description cannot be empty"
        case .invalidCoordinates:
            return "Invalid GPS coordinates"
        case .invalidLatitude:
            return "Latitude must be between -90 and 90 degrees"
        case .invalidLongitude:
            return "Longitude must be between -180 and 180 degrees"
        case .invalidRadius:
            return "Radius must be greater than 0"
        case .radiusTooLarge:
            return "Radius cannot exceed 1000 meters"
        case .invalidBeaconUUID:
            return "Invalid beacon UUID format"
        case .invalidBeaconMajor:
            return "Beacon major value must be between 0 and 65535"
        case .invalidBeaconMinor:
            return "Beacon minor value must be between 0 and 65535"
        }
    }
}