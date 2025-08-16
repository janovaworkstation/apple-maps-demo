import Foundation
import CoreLocation
import SwiftData

@Model
final class Tour {
    var id: UUID
    var name: String
    var tourDescription: String
    var pointsOfInterest: [PointOfInterest]
    var estimatedDuration: TimeInterval
    var language: String
    var createdAt: Date
    var lastModified: Date
    var coverImageURL: URL?
    var category: TourCategory
    var isDownloaded: Bool
    var totalDistance: CLLocationDistance
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        pointsOfInterest: [PointOfInterest] = [],
        estimatedDuration: TimeInterval = 0,
        language: String = "en",
        category: TourCategory = .general,
        totalDistance: CLLocationDistance = 0
    ) {
        self.id = id
        self.name = name
        self.tourDescription = description
        self.pointsOfInterest = pointsOfInterest
        self.estimatedDuration = estimatedDuration
        self.language = language
        self.createdAt = Date()
        self.lastModified = Date()
        self.category = category
        self.isDownloaded = false
        self.totalDistance = totalDistance
    }
}

enum TourCategory: String, Codable, CaseIterable {
    case historical = "Historical"
    case cultural = "Cultural"
    case nature = "Nature"
    case architecture = "Architecture"
    case foodAndDrink = "Food & Drink"
    case general = "General"
    
    var iconName: String {
        switch self {
        case .historical: return "building.columns"
        case .cultural: return "theatermasks"
        case .nature: return "leaf"
        case .architecture: return "building"
        case .foodAndDrink: return "fork.knife"
        case .general: return "map"
        }
    }
}