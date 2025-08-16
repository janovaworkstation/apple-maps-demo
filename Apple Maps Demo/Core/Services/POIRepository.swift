import Foundation
import SwiftData
import CoreLocation

// MARK: - POI Repository Protocol

protocol POIRepositoryProtocol {
    // Basic CRUD
    func save(_ poi: PointOfInterest) async throws
    func fetchAll() async throws -> [PointOfInterest]
    func fetch(by id: UUID) async throws -> PointOfInterest?
    func fetchByTour(_ tourId: UUID) async throws -> [PointOfInterest]
    func delete(_ poi: PointOfInterest) async throws
    
    // Search and Filter
    func search(query: String, in tourId: UUID?) async throws -> [PointOfInterest]
    func filterByCategory(_ category: POICategory) async throws -> [PointOfInterest]
    func filterByImportance(_ importance: POIImportance) async throws -> [PointOfInterest]
    func filterByTriggerType(_ triggerType: TriggerType) async throws -> [PointOfInterest]
    
    // Location-based queries
    func findNearbyPOIs(location: CLLocation, radius: CLLocationDistance) async throws -> [PointOfInterest]
    func findPOIsInRegion(northEast: CLLocationCoordinate2D, southWest: CLLocationCoordinate2D) async throws -> [PointOfInterest]
    
    // Visit tracking
    func fetchVisitedPOIs(for tourId: UUID?) async throws -> [PointOfInterest]
    func fetchUnvisitedPOIs(for tourId: UUID?) async throws -> [PointOfInterest]
    func markAsVisited(_ poi: PointOfInterest, at date: Date) async throws
    func markAsNotVisited(_ poi: PointOfInterest) async throws
    
    // Analytics
    func getPOIStatistics(for tourId: UUID?) async throws -> POIStatistics
    func getVisitHistory(for poi: PointOfInterest) async throws -> [POIVisit]
    
    // Geofencing
    func fetchPOIsForGeofencing(limit: Int) async throws -> [PointOfInterest]
    func updateGeofenceStatus(_ poi: PointOfInterest, isActive: Bool) async throws
}

// MARK: - POI Repository Implementation

class POIRepository: POIRepositoryProtocol {
    private let dataManager: DataManager
    
    init(dataManager: DataManager = DataManager.shared) {
        self.dataManager = dataManager
    }
    
    // MARK: - Basic CRUD
    
    func save(_ poi: PointOfInterest) async throws {
        try await dataManager.save(poi)
    }
    
    func fetchAll() async throws -> [PointOfInterest] {
        return try await dataManager.fetch(PointOfInterest.self)
    }
    
    func fetch(by id: UUID) async throws -> PointOfInterest? {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.id == id
        }
        return try await dataManager.fetchFirst(PointOfInterest.self, predicate: predicate)
    }
    
    func fetchByTour(_ tourId: UUID) async throws -> [PointOfInterest] {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.tourId == tourId
        }
        return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
    }
    
    func delete(_ poi: PointOfInterest) async throws {
        try await dataManager.delete(poi)
    }
    
    // MARK: - Search and Filter
    
    func search(query: String, in tourId: UUID?) async throws -> [PointOfInterest] {
        let searchQuery = query.lowercased()
        
        if let tourId = tourId {
            let predicate = #Predicate<PointOfInterest> { poi in
                poi.tourId == tourId &&
                (poi.name.localizedLowercase.contains(searchQuery) ||
                 poi.poiDescription.localizedLowercase.contains(searchQuery))
            }
            return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        } else {
            let predicate = #Predicate<PointOfInterest> { poi in
                poi.name.localizedLowercase.contains(searchQuery) ||
                poi.poiDescription.localizedLowercase.contains(searchQuery)
            }
            return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        }
    }
    
    func filterByCategory(_ category: POICategory) async throws -> [PointOfInterest] {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.category == category
        }
        return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
    }
    
    func filterByImportance(_ importance: POIImportance) async throws -> [PointOfInterest] {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.importance == importance
        }
        return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
    }
    
    func filterByTriggerType(_ triggerType: TriggerType) async throws -> [PointOfInterest] {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.triggerType == triggerType
        }
        return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
    }
    
    // MARK: - Location-based queries
    
    func findNearbyPOIs(location: CLLocation, radius: CLLocationDistance) async throws -> [PointOfInterest] {
        let allPOIs = try await fetchAll()
        
        return allPOIs.filter { poi in
            let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
            return location.distance(from: poiLocation) <= radius
        }.sorted { poi1, poi2 in
            let distance1 = location.distance(from: CLLocation(latitude: poi1.latitude, longitude: poi1.longitude))
            let distance2 = location.distance(from: CLLocation(latitude: poi2.latitude, longitude: poi2.longitude))
            return distance1 < distance2
        }
    }
    
    func findPOIsInRegion(northEast: CLLocationCoordinate2D, southWest: CLLocationCoordinate2D) async throws -> [PointOfInterest] {
        let allPOIs = try await fetchAll()
        
        return allPOIs.filter { poi in
            return poi.latitude >= southWest.latitude &&
                   poi.latitude <= northEast.latitude &&
                   poi.longitude >= southWest.longitude &&
                   poi.longitude <= northEast.longitude
        }
    }
    
    // MARK: - Visit tracking
    
    func fetchVisitedPOIs(for tourId: UUID?) async throws -> [PointOfInterest] {
        if let tourId = tourId {
            let predicate = #Predicate<PointOfInterest> { poi in
                poi.tourId == tourId && poi.isVisited == true
            }
            return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        } else {
            let predicate = #Predicate<PointOfInterest> { poi in
                poi.isVisited == true
            }
            return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        }
    }
    
    func fetchUnvisitedPOIs(for tourId: UUID?) async throws -> [PointOfInterest] {
        if let tourId = tourId {
            let predicate = #Predicate<PointOfInterest> { poi in
                poi.tourId == tourId && poi.isVisited == false
            }
            return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        } else {
            let predicate = #Predicate<PointOfInterest> { poi in
                poi.isVisited == false
            }
            return try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        }
    }
    
    func markAsVisited(_ poi: PointOfInterest, at date: Date = Date()) async throws {
        poi.isVisited = true
        poi.visitedAt = date
        try await dataManager.save(poi)
    }
    
    func markAsNotVisited(_ poi: PointOfInterest) async throws {
        poi.isVisited = false
        poi.visitedAt = nil
        poi.dwellTime = 0
        try await dataManager.save(poi)
    }
    
    // MARK: - Analytics
    
    func getPOIStatistics(for tourId: UUID?) async throws -> POIStatistics {
        let pois: [PointOfInterest]
        
        if let tourId = tourId {
            pois = try await fetchByTour(tourId)
        } else {
            pois = try await fetchAll()
        }
        
        let visitedPOIs = pois.filter { $0.isVisited }
        let totalDwellTime = visitedPOIs.reduce(0) { $0 + $1.dwellTime }
        let averageDwellTime = visitedPOIs.isEmpty ? 0 : totalDwellTime / Double(visitedPOIs.count)
        
        let categoryBreakdown = Dictionary(grouping: pois) { $0.category }
            .mapValues { $0.count }
        
        let importanceBreakdown = Dictionary(grouping: pois) { $0.importance }
            .mapValues { $0.count }
        
        return POIStatistics(
            totalPOIs: pois.count,
            visitedPOIs: visitedPOIs.count,
            averageDwellTime: averageDwellTime,
            totalDwellTime: totalDwellTime,
            categoryBreakdown: categoryBreakdown,
            importanceBreakdown: importanceBreakdown,
            mostVisitedCategory: categoryBreakdown.max { $0.value < $1.value }?.key
        )
    }
    
    func getVisitHistory(for poi: PointOfInterest) async throws -> [POIVisit] {
        // This would typically come from a separate visit tracking table
        // For now, return single visit if POI is visited
        guard poi.isVisited, let visitedAt = poi.visitedAt else {
            return []
        }
        
        return [POIVisit(
            id: UUID(),
            poiId: poi.id,
            tourId: poi.tourId,
            visitedAt: visitedAt,
            dwellTime: poi.dwellTime,
            wasAudioPlayed: true // Assuming audio was played if visited
        )]
    }
    
    // MARK: - Geofencing
    
    func fetchPOIsForGeofencing(limit: Int = 20) async throws -> [PointOfInterest] {
        // Get POIs that should be monitored for geofencing
        // Prioritize by importance and proximity to user location if available
        let allPOIs = try await fetchAll()
        
        // Filter to unvisited POIs first, then by importance
        let unvisitedPOIs = allPOIs.filter { !$0.isVisited }
        let sortedPOIs = unvisitedPOIs.sorted { poi1, poi2 in
            if poi1.importance != poi2.importance {
                return poi1.importance.rawValue > poi2.importance.rawValue // Higher importance first
            }
            return poi1.order < poi2.order // Then by order in tour
        }
        
        return Array(sortedPOIs.prefix(limit))
    }
    
    func updateGeofenceStatus(_ poi: PointOfInterest, isActive: Bool) async throws {
        // Update POI metadata to track geofence status
        // This could be extended to include a separate GeofenceStatus property
        try await dataManager.save(poi)
    }
    
    // MARK: - Advanced Operations
    
    func fetchPOIsAlongRoute(coordinates: [CLLocationCoordinate2D], tolerance: CLLocationDistance = 100) async throws -> [PointOfInterest] {
        let allPOIs = try await fetchAll()
        
        return allPOIs.filter { poi in
            let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
            
            // Check if POI is within tolerance of any point on the route
            return coordinates.contains { coordinate in
                let routePoint = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                return poiLocation.distance(from: routePoint) <= tolerance
            }
        }
    }
    
    func fetchNextPOI(for tourId: UUID, after currentOrder: Int) async throws -> PointOfInterest? {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.tourId == tourId && poi.order > currentOrder && !poi.isVisited
        }
        
        let nextPOIs = try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        return nextPOIs.min { $0.order < $1.order }
    }
    
    func fetchPreviousPOI(for tourId: UUID, before currentOrder: Int) async throws -> PointOfInterest? {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.tourId == tourId && poi.order < currentOrder
        }
        
        let previousPOIs = try await dataManager.fetch(PointOfInterest.self, predicate: predicate)
        return previousPOIs.max { $0.order < $1.order }
    }
    
    func reorderPOIs(in tourId: UUID, newOrder: [(UUID, Int)]) async throws {
        for (poiId, newOrderValue) in newOrder {
            if let poi = try await fetch(by: poiId), poi.tourId == tourId {
                poi.order = newOrderValue
                try await save(poi)
            }
        }
    }
    
    func duplicatePOI(_ poi: PointOfInterest, toTour tourId: UUID) async throws -> PointOfInterest {
        let newPOI = PointOfInterest(
            tourId: tourId,
            name: poi.name,
            description: poi.poiDescription,
            latitude: poi.latitude,
            longitude: poi.longitude,
            radius: poi.radius,
            triggerType: poi.triggerType,
            order: poi.order,
            category: poi.category,
            importance: poi.importance
        )
        
        // Copy additional properties
        newPOI.beaconUUID = poi.beaconUUID
        newPOI.beaconMajor = poi.beaconMajor
        newPOI.beaconMinor = poi.beaconMinor
        newPOI.operatingHours = poi.operatingHours
        newPOI.accessibility = poi.accessibility
        
        try await save(newPOI)
        return newPOI
    }
}

// MARK: - Supporting Types

struct POIStatistics {
    let totalPOIs: Int
    let visitedPOIs: Int
    let averageDwellTime: TimeInterval
    let totalDwellTime: TimeInterval
    let categoryBreakdown: [POICategory: Int]
    let importanceBreakdown: [POIImportance: Int]
    let mostVisitedCategory: POICategory?
    
    var visitationRate: Double {
        return totalPOIs > 0 ? Double(visitedPOIs) / Double(totalPOIs) * 100.0 : 0.0
    }
    
    var formattedAverageDwellTime: String {
        let minutes = Int(averageDwellTime) / 60
        let seconds = Int(averageDwellTime) % 60
        return "\(minutes)m \(seconds)s"
    }
}

struct POIVisit {
    let id: UUID
    let poiId: UUID
    let tourId: UUID
    let visitedAt: Date
    let dwellTime: TimeInterval
    let wasAudioPlayed: Bool
    
    init(id: UUID = UUID(), poiId: UUID, tourId: UUID, visitedAt: Date, dwellTime: TimeInterval, wasAudioPlayed: Bool) {
        self.id = id
        self.poiId = poiId
        self.tourId = tourId
        self.visitedAt = visitedAt
        self.dwellTime = dwellTime
        self.wasAudioPlayed = wasAudioPlayed
    }
}