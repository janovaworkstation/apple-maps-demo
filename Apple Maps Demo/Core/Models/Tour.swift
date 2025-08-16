import Foundation
import CoreLocation
import SwiftData

@Model
final class Tour: @unchecked Sendable {
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
    var difficulty: TourDifficulty
    var rating: Double
    var reviewCount: Int
    var authorName: String?
    var version: String
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        pointsOfInterest: [PointOfInterest] = [],
        estimatedDuration: TimeInterval = 0,
        language: String = "en",
        category: TourCategory = .general,
        totalDistance: CLLocationDistance = 0,
        difficulty: TourDifficulty = .easy,
        authorName: String? = nil
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
        self.difficulty = difficulty
        self.rating = 0.0
        self.reviewCount = 0
        self.authorName = authorName
        self.version = "1.0"
        self.tags = []
    }
}

// MARK: - Tour Extensions
extension Tour {
    // MARK: - Computed Properties
    
    var isValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !tourDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               pointsOfInterest.count >= 2
    }
    
    var visitedPOICount: Int {
        return pointsOfInterest.filter { $0.isVisited }.count
    }
    
    var completionPercentage: Double {
        guard !pointsOfInterest.isEmpty else { return 0.0 }
        return Double(visitedPOICount) / Double(pointsOfInterest.count) * 100.0
    }
    
    var isCompleted: Bool {
        return completionPercentage >= 100.0
    }
    
    var formattedDuration: String {
        let hours = Int(estimatedDuration) / 3600
        let minutes = Int(estimatedDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        
        let distance = Measurement(value: totalDistance, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }
    
    var downloadSizeEstimate: Int64 {
        let audioContentSize = pointsOfInterest.compactMap { $0.audioContent?.fileSize }.reduce(0, +)
        let imageSize: Int64 = coverImageURL != nil ? 1_048_576 : 0 // 1MB estimate for cover image
        return audioContentSize + imageSize
    }
    
    var formattedDownloadSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: downloadSizeEstimate)
    }
    
    var averageRating: String {
        return String(format: "%.1f", rating)
    }
    
    // MARK: - Validation Methods
    
    func validateName() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw TourValidationError.emptyName
        }
        if trimmedName.count > 100 {
            throw TourValidationError.nameTooLong
        }
    }
    
    func validateDescription() throws {
        let trimmedDescription = tourDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            throw TourValidationError.emptyDescription
        }
        if trimmedDescription.count > 2000 {
            throw TourValidationError.descriptionTooLong
        }
    }
    
    func validatePOIs() throws {
        if pointsOfInterest.count < 2 {
            throw TourValidationError.insufficientPOIs
        }
        if pointsOfInterest.count > 50 {
            throw TourValidationError.tooManyPOIs
        }
    }
    
    func validate() throws {
        try validateName()
        try validateDescription()
        try validatePOIs()
    }
    
    // MARK: - Business Logic Methods
    
    func updateLastModified() {
        lastModified = Date()
    }
    
    func addPOI(_ poi: PointOfInterest) {
        poi.tourId = self.id
        poi.order = pointsOfInterest.count
        pointsOfInterest.append(poi)
        updateLastModified()
    }
    
    func removePOI(_ poi: PointOfInterest) {
        pointsOfInterest.removeAll { $0.id == poi.id }
        // Reorder remaining POIs
        for (index, remainingPOI) in pointsOfInterest.enumerated() {
            remainingPOI.order = index
        }
        updateLastModified()
    }
    
    func reorderPOIs(from source: IndexSet, to destination: Int) {
        pointsOfInterest.move(fromOffsets: source, toOffset: destination)
        // Update order values
        for (index, poi) in pointsOfInterest.enumerated() {
            poi.order = index
        }
        updateLastModified()
    }
    
    func calculateTotalDistance() {
        guard pointsOfInterest.count >= 2 else {
            totalDistance = 0
            return
        }
        
        var total: CLLocationDistance = 0
        for i in 0..<(pointsOfInterest.count - 1) {
            let currentPOI = pointsOfInterest[i]
            let nextPOI = pointsOfInterest[i + 1]
            
            let currentLocation = CLLocation(latitude: currentPOI.latitude, longitude: currentPOI.longitude)
            let nextLocation = CLLocation(latitude: nextPOI.latitude, longitude: nextPOI.longitude)
            
            total += currentLocation.distance(from: nextLocation)
        }
        
        totalDistance = total
        updateLastModified()
    }
    
    func estimateDuration() {
        // Base time: 2 minutes per POI for content + walking time based on distance
        let contentTime = TimeInterval(pointsOfInterest.count * 120) // 2 minutes per POI
        let walkingTime = totalDistance / 1.4 // Average walking speed 1.4 m/s
        
        estimatedDuration = contentTime + walkingTime
        updateLastModified()
    }
    
    func addTag(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            updateLastModified()
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0.lowercased() == tag.lowercased() }
        updateLastModified()
    }
}

// MARK: - Enums

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
    
    var color: String {
        switch self {
        case .historical: return "brown"
        case .cultural: return "purple"
        case .nature: return "green"
        case .architecture: return "blue"
        case .foodAndDrink: return "orange"
        case .general: return "gray"
        }
    }
}

enum TourDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case challenging = "Challenging"
    case expert = "Expert"
    
    var iconName: String {
        switch self {
        case .easy: return "1.circle.fill"
        case .moderate: return "2.circle.fill"
        case .challenging: return "3.circle.fill"
        case .expert: return "4.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .moderate: return "yellow"
        case .challenging: return "orange"
        case .expert: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "Suitable for all fitness levels"
        case .moderate: return "Requires basic fitness level"
        case .challenging: return "Requires good fitness level"
        case .expert: return "Requires excellent fitness level"
        }
    }
}

enum TourValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case emptyDescription
    case descriptionTooLong
    case insufficientPOIs
    case tooManyPOIs
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Tour name cannot be empty"
        case .nameTooLong:
            return "Tour name cannot exceed 100 characters"
        case .emptyDescription:
            return "Tour description cannot be empty"
        case .descriptionTooLong:
            return "Tour description cannot exceed 2000 characters"
        case .insufficientPOIs:
            return "Tour must have at least 2 points of interest"
        case .tooManyPOIs:
            return "Tour cannot have more than 50 points of interest"
        }
    }
}