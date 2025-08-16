import Foundation
import SwiftData
import CoreLocation

// MARK: - Tour Repository Protocol

protocol TourRepositoryProtocol {
    // Basic CRUD
    func save(_ tour: Tour) async throws
    func fetchAll() async throws -> [Tour]
    func fetch(by id: UUID) async throws -> Tour?
    func delete(_ tour: Tour) async throws
    
    // Search and Filter
    func search(query: String) async throws -> [Tour]
    func filter(by category: TourCategory) async throws -> [Tour]
    func filterByDifficulty(_ difficulty: TourDifficulty) async throws -> [Tour]
    func filterByRating(minimumRating: Double) async throws -> [Tour]
    
    // Download Management
    func fetchDownloadedTours() async throws -> [Tour]
    func markAsDownloaded(_ tour: Tour) async throws
    func markAsNotDownloaded(_ tour: Tour) async throws
    
    // Statistics
    func getTourStatistics() async throws -> TourStatistics
    func getUserProgress(for tour: Tour) async throws -> TourProgress
    
    // Location-based
    func findNearbyTours(location: CLLocation, radius: CLLocationDistance) async throws -> [Tour]
}

// MARK: - Tour Repository Implementation

class TourRepository: TourRepositoryProtocol {
    private let dataManager: DataManager
    
    init(dataManager: DataManager = DataManager.shared) {
        self.dataManager = dataManager
    }
    
    // MARK: - Basic CRUD
    
    func save(_ tour: Tour) async throws {
        try await dataManager.save(tour)
    }
    
    func fetchAll() async throws -> [Tour] {
        return try await dataManager.fetch(Tour.self)
    }
    
    func fetch(by id: UUID) async throws -> Tour? {
        let predicate = #Predicate<Tour> { tour in
            tour.id == id
        }
        return try await dataManager.fetchFirst(Tour.self, predicate: predicate)
    }
    
    func delete(_ tour: Tour) async throws {
        try await dataManager.delete(tour)
    }
    
    // MARK: - Search and Filter
    
    func search(query: String) async throws -> [Tour] {
        let searchQuery = query.lowercased()
        let predicate = #Predicate<Tour> { tour in
            tour.name.localizedLowercase.contains(searchQuery) ||
            tour.tourDescription.localizedLowercase.contains(searchQuery) ||
            tour.tags.contains { $0.localizedLowercase.contains(searchQuery) }
        }
        return try await dataManager.fetch(Tour.self, predicate: predicate)
    }
    
    func filter(by category: TourCategory) async throws -> [Tour] {
        let predicate = #Predicate<Tour> { tour in
            tour.category == category
        }
        return try await dataManager.fetch(Tour.self, predicate: predicate)
    }
    
    func filterByDifficulty(_ difficulty: TourDifficulty) async throws -> [Tour] {
        let predicate = #Predicate<Tour> { tour in
            tour.difficulty == difficulty
        }
        return try await dataManager.fetch(Tour.self, predicate: predicate)
    }
    
    func filterByRating(minimumRating: Double) async throws -> [Tour] {
        let predicate = #Predicate<Tour> { tour in
            tour.rating >= minimumRating
        }
        return try await dataManager.fetch(Tour.self, predicate: predicate)
    }
    
    // MARK: - Download Management
    
    func fetchDownloadedTours() async throws -> [Tour] {
        let predicate = #Predicate<Tour> { tour in
            tour.isDownloaded == true
        }
        return try await dataManager.fetch(Tour.self, predicate: predicate)
    }
    
    func markAsDownloaded(_ tour: Tour) async throws {
        tour.isDownloaded = true
        tour.updateLastModified()
        try await dataManager.save(tour)
    }
    
    func markAsNotDownloaded(_ tour: Tour) async throws {
        tour.isDownloaded = false
        tour.updateLastModified()
        try await dataManager.save(tour)
    }
    
    // MARK: - Statistics
    
    func getTourStatistics() async throws -> TourStatistics {
        let allTours = try await fetchAll()
        let downloadedTours = try await fetchDownloadedTours()
        
        let completedTours = allTours.filter { $0.isCompleted }
        let totalPOIs = allTours.reduce(0) { $0 + $1.pointsOfInterest.count }
        let visitedPOIs = allTours.reduce(0) { $0 + $1.visitedPOICount }
        
        let averageRating = allTours.reduce(0.0) { $0 + $1.rating } / Double(max(allTours.count, 1))
        let totalDistance = allTours.reduce(0.0) { $0 + $1.totalDistance }
        let totalDuration = allTours.reduce(0.0) { $0 + $1.estimatedDuration }
        
        return TourStatistics(
            totalTours: allTours.count,
            downloadedTours: downloadedTours.count,
            completedTours: completedTours.count,
            totalPOIs: totalPOIs,
            visitedPOIs: visitedPOIs,
            averageRating: averageRating,
            totalDistance: totalDistance,
            totalDuration: totalDuration
        )
    }
    
    func getUserProgress(for tour: Tour) async throws -> TourProgress {
        let visitedCount = tour.visitedPOICount
        let totalCount = tour.pointsOfInterest.count
        let completionPercentage = tour.completionPercentage
        
        let visitedPOIs = tour.pointsOfInterest.filter { $0.isVisited }
        let totalTimeSpent = visitedPOIs.reduce(0.0) { $0 + $1.dwellTime }
        
        return TourProgress(
            tourId: tour.id,
            visitedPOIs: visitedCount,
            totalPOIs: totalCount,
            completionPercentage: completionPercentage,
            timeSpent: totalTimeSpent,
            isCompleted: tour.isCompleted,
            lastVisitedAt: visitedPOIs.compactMap { $0.visitedAt }.max()
        )
    }
    
    // MARK: - Location-based
    
    func findNearbyTours(location: CLLocation, radius: CLLocationDistance) async throws -> [Tour] {
        let allTours = try await fetchAll()
        
        return allTours.filter { tour in
            // Check if any POI in the tour is within radius
            return tour.pointsOfInterest.contains { poi in
                let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
                return location.distance(from: poiLocation) <= radius
            }
        }
    }
    
    // MARK: - Advanced Operations
    
    func fetchPopularTours(limit: Int = 10) async throws -> [Tour] {
        let allTours = try await fetchAll()
        return Array(allTours.sorted { $0.rating > $1.rating }.prefix(limit))
    }
    
    func fetchRecentTours(limit: Int = 5) async throws -> [Tour] {
        let allTours = try await fetchAll()
        return Array(allTours.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
    
    func fetchToursWithTag(_ tag: String) async throws -> [Tour] {
        let allTours = try await fetchAll()
        return allTours.filter { tour in
            tour.tags.contains { $0.lowercased() == tag.lowercased() }
        }
    }
    
    func updateTourRating(_ tour: Tour, newRating: Double, incrementReviewCount: Bool = true) async throws {
        tour.rating = newRating
        if incrementReviewCount {
            tour.reviewCount += 1
        }
        tour.updateLastModified()
        try await dataManager.save(tour)
    }
    
    func duplicateTour(_ tour: Tour, newName: String) async throws -> Tour {
        let newTour = Tour(
            name: newName,
            description: tour.tourDescription,
            pointsOfInterest: [],
            estimatedDuration: tour.estimatedDuration,
            language: tour.language,
            category: tour.category,
            totalDistance: tour.totalDistance,
            difficulty: tour.difficulty
        )
        
        // Copy basic properties
        newTour.tags = tour.tags
        newTour.coverImageURL = tour.coverImageURL
        
        try await save(newTour)
        
        // Copy POIs (they'll need new IDs)
        for originalPOI in tour.pointsOfInterest {
            let newPOI = PointOfInterest(
                tourId: newTour.id,
                name: originalPOI.name,
                description: originalPOI.poiDescription,
                latitude: originalPOI.latitude,
                longitude: originalPOI.longitude,
                radius: originalPOI.radius,
                triggerType: originalPOI.triggerType,
                order: originalPOI.order,
                category: originalPOI.category,
                importance: originalPOI.importance
            )
            
            newTour.addPOI(newPOI)
        }
        
        try await save(newTour)
        return newTour
    }
}

// MARK: - Supporting Types

struct TourStatistics {
    let totalTours: Int
    let downloadedTours: Int
    let completedTours: Int
    let totalPOIs: Int
    let visitedPOIs: Int
    let averageRating: Double
    let totalDistance: CLLocationDistance
    let totalDuration: TimeInterval
    
    var completionRate: Double {
        return totalPOIs > 0 ? Double(visitedPOIs) / Double(totalPOIs) * 100.0 : 0.0
    }
    
    var downloadRate: Double {
        return totalTours > 0 ? Double(downloadedTours) / Double(totalTours) * 100.0 : 0.0
    }
}

struct TourProgress {
    let tourId: UUID
    let visitedPOIs: Int
    let totalPOIs: Int
    let completionPercentage: Double
    let timeSpent: TimeInterval
    let isCompleted: Bool
    let lastVisitedAt: Date?
    
    var formattedTimeSpent: String {
        let hours = Int(timeSpent) / 3600
        let minutes = Int(timeSpent) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}