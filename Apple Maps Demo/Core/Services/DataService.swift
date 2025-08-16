import Foundation
@preconcurrency import SwiftData
import SwiftUI
import CoreLocation

// MARK: - Data Service Protocol

@MainActor
protocol DataServiceProtocol {
    // Repository Access
    var tourRepository: TourRepositoryProtocol { get }
    var poiRepository: POIRepositoryProtocol { get }
    var audioRepository: AudioContentRepositoryProtocol { get }
    var preferencesRepository: UserPreferencesRepositoryProtocol { get }
    
    // Initialization and Migration
    func initialize() async throws
    func performMigrationIfNeeded() async throws
    func validateDataIntegrity() async throws -> DataIntegrityReport
    
    // Unified Operations
    func createTourWithPOIs(_ tourData: TourCreationData) async throws -> Tour
    func deleteTourCompletely(_ tour: Tour) async throws
    func downloadTourContent(_ tour: Tour, priority: DownloadPriority) async throws
    func exportUserData() async throws -> Data
    func importUserData(_ data: Data) async throws
    
    // Cross-entity queries
    func searchAllContent(query: String) async throws -> SearchResults
    func getUpcomingPOIs(for location: CLLocation, radius: CLLocationDistance) async throws -> [PointOfInterest]
    func getTourProgress(for tourId: UUID) async throws -> TourProgressData
    
    // Analytics and Statistics
    func getOverallStatistics() async throws -> OverallStatistics
    func getStorageReport() async throws -> StorageReport
    
    // Maintenance
    func performMaintenance() async throws
    func clearCache(olderThan date: Date) async throws
    func repairDataIssues() async throws
}

// MARK: - Data Service Implementation

@MainActor
class DataService: DataServiceProtocol, ObservableObject {
    static let shared = DataService()
    
    // MARK: - Repository Properties
    
    let tourRepository: TourRepositoryProtocol
    let poiRepository: POIRepositoryProtocol
    let audioRepository: AudioContentRepositoryProtocol
    let preferencesRepository: UserPreferencesRepositoryProtocol
    
    private let dataManager: DataManager
    private let migrationManager: DataMigrationManager
    
    @Published var isInitialized = false
    @Published var isPerformingMaintenance = false
    @Published var lastError: DataError?
    
    private init() {
        self.dataManager = DataManager.shared
        self.migrationManager = DataMigrationManager(dataManager: dataManager)
        
        // Initialize repositories
        self.tourRepository = TourRepository(dataManager: dataManager)
        self.poiRepository = POIRepository(dataManager: dataManager)
        self.audioRepository = AudioContentRepository(dataManager: dataManager)
        self.preferencesRepository = UserPreferencesRepository(dataManager: dataManager)
    }
    
    // MARK: - Initialization and Migration
    
    func initialize() async throws {
        do {
            // Perform migration if needed
            try await performMigrationIfNeeded()
            
            // Validate data integrity
            let integrityReport = try await validateDataIntegrity()
            if !integrityReport.isHealthy {
                try await repairDataIssues()
            }
            
            // Ensure user preferences exist
            _ = try await preferencesRepository.fetchPreferences()
            
            isInitialized = true
            lastError = nil
            
        } catch {
            lastError = error as? DataError ?? DataError.repositoryError(error.localizedDescription)
            throw error
        }
    }
    
    func performMigrationIfNeeded() async throws {
        if try await migrationManager.needsMigration() {
            try await migrationManager.performMigration()
        }
    }
    
    func validateDataIntegrity() async throws -> DataIntegrityReport {
        return try await migrationManager.validateDataIntegrity()
    }
    
    // MARK: - Unified Operations
    
    func createTourWithPOIs(_ tourData: TourCreationData) async throws -> Tour {
        let tour = Tour(
            name: tourData.name,
            description: tourData.description,
            pointsOfInterest: [],
            estimatedDuration: tourData.estimatedDuration,
            language: tourData.language,
            category: tourData.category,
            totalDistance: tourData.totalDistance,
            difficulty: tourData.difficulty
        )
        
        // Set additional properties
        tour.tags = tourData.tags
        if let coverImageURLString = tourData.coverImageURL {
            tour.coverImageURL = URL(string: coverImageURLString)
        }
        
        try await tourRepository.save(tour)
        
        // Create POIs
        for (index, poiData) in tourData.pois.enumerated() {
            let poi = PointOfInterest(
                tourId: tour.id,
                name: poiData.name,
                description: poiData.description,
                latitude: poiData.coordinate.latitude,
                longitude: poiData.coordinate.longitude,
                radius: poiData.radius,
                triggerType: poiData.triggerType,
                order: index,
                category: poiData.category,
                importance: poiData.importance
            )
            
            try await poiRepository.save(poi)
            tour.addPOI(poi)
            
            // Create audio content placeholder
            if let audioData = poiData.audioContent {
                let audioContent = AudioContent(
                    poiId: poi.id,
                    duration: audioData.duration,
                    language: tour.language,
                    isLLMGenerated: audioData.isLLMGenerated,
                    quality: audioData.quality
                )
                
                // Set additional properties
                if let url = audioData.localURL {
                    audioContent.localFileURL = url.path
                }
                audioContent.transcript = audioData.transcript
                
                try await audioRepository.save(audioContent)
            }
        }
        
        try await tourRepository.save(tour)
        return tour
    }
    
    func deleteTourCompletely(_ tour: Tour) async throws {
        // Get all POIs for the tour
        let pois = try await poiRepository.fetchByTour(tour.id)
        
        // Delete all audio content for each POI
        for poi in pois {
            let audioContent = try await audioRepository.fetchByPOI(poi.id)
            for content in audioContent {
                try await audioRepository.delete(content)
            }
            
            // Delete the POI
            try await poiRepository.delete(poi)
        }
        
        // Finally delete the tour
        try await tourRepository.delete(tour)
    }
    
    func downloadTourContent(_ tour: Tour, priority: DownloadPriority = .normal) async throws {
        let pois = try await poiRepository.fetchByTour(tour.id)
        
        for poi in pois {
            let audioContent = try await audioRepository.fetchByPOI(poi.id)
            for content in audioContent {
                if content.downloadStatus == .notStarted {
                    try await audioRepository.addToDownloadQueue(content, priority: priority)
                }
            }
        }
        
        // Mark tour as downloaded
        try await tourRepository.markAsDownloaded(tour)
    }
    
    func exportUserData() async throws -> Data {
        var exportData: [String: Any] = [:]
        
        // Export tours as simplified data
        let tours = try await tourRepository.fetchAll()
        let toursData = tours.map { tour in
            return [
                "id": tour.id.uuidString,
                "name": tour.name,
                "description": tour.tourDescription,
                "language": tour.language,
                "category": tour.category.rawValue,
                "difficulty": tour.difficulty.rawValue,
                "estimatedDuration": tour.estimatedDuration,
                "totalDistance": tour.totalDistance
            ]
        }
        exportData["tours"] = toursData
        
        // Export user preferences
        let preferences = try await preferencesRepository.fetchPreferences()
        let preferencesData = try JSONEncoder().encode(preferences)
        exportData["preferences"] = try JSONSerialization.jsonObject(with: preferencesData)
        
        // Export metadata
        exportData["exportedAt"] = Date().timeIntervalSince1970
        exportData["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    func importUserData(_ data: Data) async throws {
        let importDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let importData = importDict else {
            throw DataError.invalidData("Invalid import format")
        }
        
        // Import preferences
        if let preferencesJson = importData["preferences"] {
            let preferencesData = try JSONSerialization.data(withJSONObject: preferencesJson)
            try await preferencesRepository.importPreferences(from: preferencesData)
        }
        
        // Import tours (as new tours to avoid conflicts)
        if let toursData = importData["tours"] as? [[String: Any]] {
            for tourDict in toursData {
                guard let name = tourDict["name"] as? String,
                      let description = tourDict["description"] as? String,
                      let language = tourDict["language"] as? String else { continue }
                
                let categoryRaw = tourDict["category"] as? String ?? "general"
                let difficultyRaw = tourDict["difficulty"] as? String ?? "easy"
                let duration = tourDict["estimatedDuration"] as? TimeInterval ?? 0
                let distance = tourDict["totalDistance"] as? CLLocationDistance ?? 0
                
                let category = TourCategory(rawValue: categoryRaw) ?? .general
                let difficulty = TourDifficulty(rawValue: difficultyRaw) ?? .easy
                
                // Create new tour with imported data
                let newTour = Tour(
                    name: name + " (Imported)",
                    description: description,
                    pointsOfInterest: [],
                    estimatedDuration: duration,
                    language: language,
                    category: category,
                    totalDistance: distance,
                    difficulty: difficulty
                )
                
                try await tourRepository.save(newTour)
            }
        }
    }
    
    // MARK: - Cross-entity queries
    
    func searchAllContent(query: String) async throws -> SearchResults {
        let tours = try await tourRepository.search(query: query)
        let pois = try await poiRepository.search(query: query, in: nil)
        
        return SearchResults(
            tours: tours,
            pointsOfInterest: pois,
            totalResults: tours.count + pois.count,
            query: query
        )
    }
    
    func getUpcomingPOIs(for location: CLLocation, radius: CLLocationDistance) async throws -> [PointOfInterest] {
        let nearbyPOIs = try await poiRepository.findNearbyPOIs(location: location, radius: radius)
        
        // Filter to unvisited POIs and sort by distance
        return nearbyPOIs.filter { !$0.isVisited }
    }
    
    func getTourProgress(for tourId: UUID) async throws -> TourProgressData {
        let tour = try await tourRepository.fetch(by: tourId)
        guard let tour = tour else {
            throw DataError.entityNotFound("Tour")
        }
        
        let pois = try await poiRepository.fetchByTour(tourId)
        let visitedPOIs = pois.filter { $0.isVisited }
        
        let totalDistance = tour.totalDistance
        let visitedDistance = visitedPOIs.reduce(0.0) { total, poi in
            // Calculate distance based on order - this is simplified
            return total + (totalDistance / Double(pois.count))
        }
        
        return TourProgressData(
            tourId: tourId,
            tourName: tour.name,
            totalPOIs: pois.count,
            visitedPOIs: visitedPOIs.count,
            totalDistance: totalDistance,
            visitedDistance: visitedDistance,
            estimatedTimeRemaining: tour.estimatedDuration * (1.0 - Double(visitedPOIs.count) / Double(pois.count)),
            completionPercentage: tour.completionPercentage,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Analytics and Statistics
    
    func getOverallStatistics() async throws -> OverallStatistics {
        let tourStats = try await tourRepository.getTourStatistics()
        let poiStats = try await poiRepository.getPOIStatistics(for: nil)
        let storageStats = try await audioRepository.getStorageStatistics()
        let downloadStats = try await audioRepository.getDownloadStatistics()
        
        return OverallStatistics(
            tourStatistics: tourStats,
            poiStatistics: poiStats,
            storageStatistics: storageStats,
            downloadStatistics: downloadStats,
            generatedAt: Date()
        )
    }
    
    func getStorageReport() async throws -> StorageReport {
        let cacheSize = try await audioRepository.getCacheSize()
        let downloadedContent = try await audioRepository.fetchDownloadedContent()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let totalDiskSpace = try documentsPath.resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity ?? 0
        let availableDiskSpace = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity ?? 0
        
        return StorageReport(
            totalDiskSpace: Int64(totalDiskSpace),
            availableDiskSpace: Int64(availableDiskSpace),
            appCacheSize: cacheSize,
            downloadedContentCount: downloadedContent.count,
            recommendations: generateStorageRecommendations(cacheSize: cacheSize, availableSpace: Int64(availableDiskSpace))
        )
    }
    
    // MARK: - Maintenance
    
    func performMaintenance() async throws {
        isPerformingMaintenance = true
        defer { isPerformingMaintenance = false }
        
        // Clean up expired cache
        try await clearCache(olderThan: Date().addingTimeInterval(-7 * 24 * 60 * 60)) // 7 days
        
        // Clean up old backups
        try await migrationManager.cleanupOldBackups()
        
        // Validate and repair data integrity
        let integrityReport = try await validateDataIntegrity()
        if !integrityReport.isHealthy {
            try await repairDataIssues()
        }
        
        // Clean up orphaned files  
        if let concreteRepository = audioRepository as? AudioContentRepository {
            try await concreteRepository.cleanupOrphanedFiles()
        }
    }
    
    func clearCache(olderThan date: Date) async throws {
        try await audioRepository.clearExpiredCache()
    }
    
    func repairDataIssues() async throws {
        let integrityReport = try await validateDataIntegrity()
        try await migrationManager.repairDataIntegrity(integrityReport)
    }
    
    // MARK: - Helper Methods
    
    private func generateStorageRecommendations(cacheSize: Int64, availableSpace: Int64) -> [StorageRecommendation] {
        var recommendations: [StorageRecommendation] = []
        
        let cachePercentage = Double(cacheSize) / Double(availableSpace + cacheSize) * 100
        
        if cachePercentage > 10 {
            recommendations.append(.clearOldCache)
        }
        
        if availableSpace < 1024 * 1024 * 1024 { // Less than 1GB
            recommendations.append(.freeUpSpace)
        }
        
        if cacheSize > 500 * 1024 * 1024 { // Cache over 500MB
            recommendations.append(.reviewDownloadedContent)
        }
        
        return recommendations
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        if let dataError = error as? DataError {
            lastError = dataError
        } else {
            lastError = DataError.repositoryError(error.localizedDescription)
        }
    }
    
    func clearLastError() {
        lastError = nil
    }
}

// MARK: - Supporting Types

struct TourCreationData {
    let name: String
    let description: String
    let estimatedDuration: TimeInterval
    let language: String
    let category: TourCategory
    let totalDistance: CLLocationDistance
    let difficulty: TourDifficulty
    let tags: [String]
    let coverImageURL: String?
    let pois: [POICreationData]
}

struct POICreationData {
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let triggerType: TriggerType
    let category: POICategory
    let importance: POIImportance
    let audioContent: AudioCreationData?
}

struct AudioCreationData {
    let localURL: URL?
    let transcript: String?
    let duration: TimeInterval
    let isLLMGenerated: Bool
    let quality: AudioQuality
}

struct SearchResults {
    let tours: [Tour]
    let pointsOfInterest: [PointOfInterest]
    let totalResults: Int
    let query: String
}

struct TourProgressData {
    let tourId: UUID
    let tourName: String
    let totalPOIs: Int
    let visitedPOIs: Int
    let totalDistance: CLLocationDistance
    let visitedDistance: CLLocationDistance
    let estimatedTimeRemaining: TimeInterval
    let completionPercentage: Double
    let lastUpdated: Date
    
    var progressDescription: String {
        return "\(visitedPOIs)/\(totalPOIs) points visited (\(Int(completionPercentage))%)"
    }
}

struct OverallStatistics {
    let tourStatistics: TourStatistics
    let poiStatistics: POIStatistics
    let storageStatistics: AudioStorageStatistics
    let downloadStatistics: AudioDownloadStatistics
    let generatedAt: Date
}

struct StorageReport {
    let totalDiskSpace: Int64
    let availableDiskSpace: Int64
    let appCacheSize: Int64
    let downloadedContentCount: Int
    let recommendations: [StorageRecommendation]
    
    var usedSpacePercentage: Double {
        let usedSpace = totalDiskSpace - availableDiskSpace
        return Double(usedSpace) / Double(totalDiskSpace) * 100.0
    }
    
    var formattedTotalSpace: String {
        ByteCountFormatter().string(fromByteCount: totalDiskSpace)
    }
    
    var formattedAvailableSpace: String {
        ByteCountFormatter().string(fromByteCount: availableDiskSpace)
    }
    
    var formattedCacheSize: String {
        ByteCountFormatter().string(fromByteCount: appCacheSize)
    }
}

enum StorageRecommendation: CaseIterable {
    case clearOldCache
    case freeUpSpace
    case reviewDownloadedContent
    case enableAutoCleanup
    
    var title: String {
        switch self {
        case .clearOldCache:
            return "Clear Old Cache"
        case .freeUpSpace:
            return "Free Up Device Storage"
        case .reviewDownloadedContent:
            return "Review Downloaded Content"
        case .enableAutoCleanup:
            return "Enable Auto Cleanup"
        }
    }
    
    var description: String {
        switch self {
        case .clearOldCache:
            return "Remove cached audio files older than 7 days to free up space"
        case .freeUpSpace:
            return "Your device is running low on storage space"
        case .reviewDownloadedContent:
            return "You have a large amount of downloaded content that could be managed"
        case .enableAutoCleanup:
            return "Automatically clean up old cache files to maintain optimal performance"
        }
    }
}

// MARK: - SwiftUI Environment

struct DataServiceKey: EnvironmentKey {
    static let defaultValue: DataService = {
        MainActor.assumeIsolated {
            DataService.shared
        }
    }()
}

extension EnvironmentValues {
    var dataService: DataService {
        get { self[DataServiceKey.self] }
        set { self[DataServiceKey.self] = newValue }
    }
}