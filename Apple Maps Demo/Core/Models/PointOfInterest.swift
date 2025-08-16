import Foundation
import CoreLocation
import SwiftData

@Model
final class PointOfInterest {
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
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        order: Int = 0
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
    }
}

enum TriggerType: String, Codable {
    case location = "location"
    case beacon = "beacon"
    case manual = "manual"
    case time = "time"
}

extension PointOfInterest {
    func distanceFrom(_ location: CLLocation) -> CLLocationDistance {
        let poiLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: poiLocation)
    }
    
    func isWithinRange(of location: CLLocation) -> Bool {
        return distanceFrom(location) <= radius
    }
}