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
    var tourType: TourType
    var maxSpeed: Double? // Maximum expected speed for this tour (mph)
    var dwellTimeOverride: TimeInterval? // Custom dwell time if different from tour type default
    
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
        authorName: String? = nil,
        tourType: TourType = .walking,
        maxSpeed: Double? = nil,
        dwellTimeOverride: TimeInterval? = nil
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
        self.tourType = tourType
        self.maxSpeed = maxSpeed ?? tourType.defaultMaxSpeed
        self.dwellTimeOverride = dwellTimeOverride
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
    
    // MARK: - Tour Type Properties
    
    var effectiveDwellTime: TimeInterval {
        return dwellTimeOverride ?? tourType.defaultDwellTime
    }
    
    var effectiveMaxSpeed: Double {
        return maxSpeed ?? tourType.defaultMaxSpeed
    }
    
    var recommendedGeofenceRadius: CLLocationDistance {
        return tourType.defaultGeofenceRadius
    }
    
    var supportsContinuousMovement: Bool {
        return tourType == .driving || tourType == .mixed
    }
    
    var requiresSpeedBasedValidation: Bool {
        return tourType != .walking
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
        // Base time varies by tour type
        let contentTimePerPOI = tourType.estimatedContentTimePerPOI
        let contentTime = TimeInterval(pointsOfInterest.count) * contentTimePerPOI
        
        // Travel time based on tour type
        let travelTime: TimeInterval
        switch tourType {
        case .walking:
            travelTime = totalDistance / 1.4 // Average walking speed 1.4 m/s
        case .driving:
            // Assume 25 mph average for city driving (11.2 m/s)
            travelTime = totalDistance / 11.2
        case .mixed:
            // Weighted average: 70% driving, 30% walking
            let drivingTime = totalDistance / 11.2
            let walkingTime = totalDistance / 1.4
            travelTime = (drivingTime * 0.7) + (walkingTime * 0.3)
        }
        
        estimatedDuration = contentTime + travelTime
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

enum TourType: String, Codable, CaseIterable {
    case walking = "Walking"
    case driving = "Driving" 
    case mixed = "Mixed"
    
    var iconName: String {
        switch self {
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        case .mixed: return "figure.walk.circle"
        }
    }
    
    var color: String {
        switch self {
        case .walking: return "green"
        case .driving: return "blue"
        case .mixed: return "purple"
        }
    }
    
    var description: String {
        switch self {
        case .walking: return "Explore on foot with detailed stops"
        case .driving: return "Scenic driving route with audio commentary"
        case .mixed: return "Combined walking and driving experience"
        }
    }
    
    /// Default dwell time required for a valid visit (seconds)
    var defaultDwellTime: TimeInterval {
        switch self {
        case .walking: return 30.0 // 30 seconds for walking tours
        case .driving: return 5.0  // 5 seconds for driving tours
        case .mixed: return 15.0   // 15 seconds for mixed tours
        }
    }
    
    /// Default maximum expected speed (mph)
    var defaultMaxSpeed: Double {
        switch self {
        case .walking: return 5.0   // 5 mph walking/jogging
        case .driving: return 45.0  // 45 mph city driving
        case .mixed: return 25.0    // 25 mph mixed scenarios
        }
    }
    
    /// Default geofence radius (meters)
    var defaultGeofenceRadius: CLLocationDistance {
        switch self {
        case .walking: return 75.0   // 75 meters for walking
        case .driving: return 300.0  // 300 meters for driving
        case .mixed: return 150.0    // 150 meters for mixed
        }
    }
    
    /// Estimated content time per POI (seconds)
    var estimatedContentTimePerPOI: TimeInterval {
        switch self {
        case .walking: return 180.0  // 3 minutes per POI for walking
        case .driving: return 90.0   // 1.5 minutes per POI for driving
        case .mixed: return 135.0    // 2.25 minutes per POI for mixed
        }
    }
    
    /// Speed threshold for automatic tour type detection (mph)
    var speedThresholds: (min: Double, max: Double) {
        switch self {
        case .walking: return (0.0, 8.0)     // 0-8 mph
        case .driving: return (15.0, 80.0)   // 15-80 mph  
        case .mixed: return (5.0, 25.0)      // 5-25 mph
        }
    }
    
    /// Minimum validation interval (seconds)
    var validationInterval: TimeInterval {
        switch self {
        case .walking: return 5.0   // Check every 5 seconds
        case .driving: return 2.0   // Check every 2 seconds (faster response)
        case .mixed: return 3.0     // Check every 3 seconds
        }
    }
    
    /// Whether this tour type supports "drive-by" visits (no stopping required)
    var supportsDriveByVisits: Bool {
        switch self {
        case .walking: return false
        case .driving: return true
        case .mixed: return true
        }
    }
    
    /// Accuracy threshold required for valid GPS readings (meters)
    var requiredGPSAccuracy: CLLocationAccuracy {
        switch self {
        case .walking: return 15.0   // 15 meters for walking
        case .driving: return 25.0   // 25 meters for driving (less strict)
        case .mixed: return 20.0     // 20 meters for mixed
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