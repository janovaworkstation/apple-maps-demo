//
//  TourTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import CoreLocation
@testable import Apple_Maps_Demo

final class TourTests: XCTestCase {
    
    var tour: Tour!
    var samplePOIs: [PointOfInterest]!
    
    override func setUpWithError() throws {
        super.setUp()
        
        samplePOIs = TestDataFactory.samplePOIs
        tour = TestDataFactory.createTour(
            name: "Test Tour",
            description: "A comprehensive test tour",
            category: .historical,
            tourType: .walking,
            difficulty: .moderate,
            estimatedDuration: 7200,
            totalDistance: 5000,
            pointsOfInterest: samplePOIs
        )
    }
    
    override func tearDownWithError() throws {
        tour = nil
        samplePOIs = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testTourInitialization() throws {
        XCTAssertEqual(tour.name, "Test Tour")
        XCTAssertEqual(tour.tourDescription, "A comprehensive test tour")
        XCTAssertEqual(tour.category, .historical)
        XCTAssertEqual(tour.tourType, .walking)
        XCTAssertEqual(tour.difficulty, .moderate)
        XCTAssertEqual(tour.estimatedDuration, 7200)
        XCTAssertEqual(tour.totalDistance, 5000)
        XCTAssertEqual(tour.pointsOfInterest.count, samplePOIs.count)
        XCTAssertEqual(tour.language, "en")
        XCTAssertFalse(tour.isDownloaded)
        XCTAssertEqual(tour.rating, 0.0)
        XCTAssertEqual(tour.reviewCount, 0)
        XCTAssertEqual(tour.version, "1.0")
        XCTAssertTrue(tour.tags.isEmpty)
    }
    
    func testTourInitializationWithDefaults() throws {
        let simpleTour = Tour(name: "Simple Tour", description: "Simple description")
        
        XCTAssertEqual(simpleTour.name, "Simple Tour")
        XCTAssertEqual(simpleTour.tourDescription, "Simple description")
        XCTAssertEqual(simpleTour.category, .general)
        XCTAssertEqual(simpleTour.tourType, .walking)
        XCTAssertEqual(simpleTour.difficulty, .easy)
        XCTAssertEqual(simpleTour.estimatedDuration, 0)
        XCTAssertEqual(simpleTour.totalDistance, 0)
        XCTAssertTrue(simpleTour.pointsOfInterest.isEmpty)
        XCTAssertEqual(simpleTour.language, "en")
    }
    
    // MARK: - Property Tests
    
    func testTourIdentifiable() {
        let tour1 = TestDataFactory.createTour(name: "Tour 1")
        let tour2 = TestDataFactory.createTour(name: "Tour 2")
        
        XCTAssertNotEqual(tour1.id, tour2.id)
        XCTAssertEqual(tour1.id, tour1.id) // Identity consistency
    }
    
    func testTourComputedProperties() {
        // Test estimated duration formatting
        tour.estimatedDuration = 3661 // 1 hour, 1 minute, 1 second
        
        // Test total distance formatting
        tour.totalDistance = 1609.34 // Approximately 1 mile
        
        // Verify basic properties work correctly
        XCTAssertEqual(tour.estimatedDuration, 3661)
        XCTAssertEqual(tour.totalDistance, 1609.34, accuracy: 0.01)
    }
    
    func testTourCategoryProperties() {
        let categories: [TourCategory] = [.historical, .cultural, .nature, .architecture, .foodAndDrink, .general]
        
        for category in categories {
            let testTour = TestDataFactory.createTour(category: category)
            XCTAssertEqual(testTour.category, category)
        }
    }
    
    func testTourTypeProperties() {
        let walkingTour = TestDataFactory.createTour(tourType: .walking)
        let drivingTour = TestDataFactory.createTour(tourType: .driving)
        let cyclingTour = TestDataFactory.createTour(tourType: .cycling)
        
        XCTAssertEqual(walkingTour.tourType, .walking)
        XCTAssertEqual(drivingTour.tourType, .driving)
        XCTAssertEqual(cyclingTour.tourType, .cycling)
    }
    
    func testTourDifficultyProperties() {
        let easyTour = TestDataFactory.createTour(difficulty: .easy)
        let moderateTour = TestDataFactory.createTour(difficulty: .moderate)
        let difficultTour = TestDataFactory.createTour(difficulty: .difficult)
        
        XCTAssertEqual(easyTour.difficulty, .easy)
        XCTAssertEqual(moderateTour.difficulty, .moderate)
        XCTAssertEqual(difficultTour.difficulty, .difficult)
    }
    
    // MARK: - Points of Interest Tests
    
    func testTourWithPOIs() {
        XCTAssertEqual(tour.pointsOfInterest.count, samplePOIs.count)
        
        for (index, poi) in tour.pointsOfInterest.enumerated() {
            XCTAssertEqual(poi.id, samplePOIs[index].id)
            XCTAssertEqual(poi.name, samplePOIs[index].name)
        }
    }
    
    func testTourPOIOrdering() {
        let orderedPOIs = [
            TestDataFactory.createPOI(name: "First POI", order: 0),
            TestDataFactory.createPOI(name: "Second POI", order: 1),
            TestDataFactory.createPOI(name: "Third POI", order: 2)
        ]
        
        let orderedTour = TestDataFactory.createTour(pointsOfInterest: orderedPOIs)
        
        for (index, poi) in orderedTour.pointsOfInterest.enumerated() {
            XCTAssertEqual(poi.order, index)
        }
    }
    
    func testEmptyTourPOIs() {
        let emptyTour = TestDataFactory.createTour(pointsOfInterest: [])
        XCTAssertTrue(emptyTour.pointsOfInterest.isEmpty)
    }
    
    // MARK: - Download Status Tests
    
    func testTourDownloadStatus() {
        XCTAssertFalse(tour.isDownloaded)
        
        tour.isDownloaded = true
        XCTAssertTrue(tour.isDownloaded)
        
        tour.isDownloaded = false
        XCTAssertFalse(tour.isDownloaded)
    }
    
    // MARK: - Validation Tests
    
    func testTourNameValidation() {
        // Test non-empty name
        XCTAssertFalse(tour.name.isEmpty)
        
        // Test name length constraints (if any)
        let longNameTour = TestDataFactory.createTour(name: String(repeating: "A", count: 1000))
        XCTAssertEqual(longNameTour.name.count, 1000)
    }
    
    func testTourDescriptionValidation() {
        XCTAssertFalse(tour.tourDescription.isEmpty)
        
        let emptyDescTour = TestDataFactory.createTour(description: "")
        XCTAssertTrue(emptyDescTour.tourDescription.isEmpty)
    }
    
    func testTourDurationValidation() {
        // Test positive duration
        XCTAssertGreaterThanOrEqual(tour.estimatedDuration, 0)
        
        // Test zero duration
        let zeroDurationTour = TestDataFactory.createTour(estimatedDuration: 0)
        XCTAssertEqual(zeroDurationTour.estimatedDuration, 0)
        
        // Test large duration
        let longTour = TestDataFactory.createTour(estimatedDuration: 86400) // 24 hours
        XCTAssertEqual(longTour.estimatedDuration, 86400)
    }
    
    func testTourDistanceValidation() {
        // Test positive distance
        XCTAssertGreaterThanOrEqual(tour.totalDistance, 0)
        
        // Test zero distance
        let zeroDistanceTour = TestDataFactory.createTour(totalDistance: 0)
        XCTAssertEqual(zeroDistanceTour.totalDistance, 0)
        
        // Test large distance
        let longDistanceTour = TestDataFactory.createTour(totalDistance: 100000) // 100km
        XCTAssertEqual(longDistanceTour.totalDistance, 100000)
    }
    
    // MARK: - Timestamp Tests
    
    func testTourTimestamps() {
        let now = Date()
        
        // Test creation timestamp is recent
        XCTAssertLessThanOrEqual(abs(tour.createdAt.timeIntervalSince(now)), 1.0)
        
        // Test last modified is set
        XCTAssertLessThanOrEqual(abs(tour.lastModified.timeIntervalSince(now)), 1.0)
        
        // Test updating last modified
        let originalModified = tour.lastModified
        tour.lastModified = Date()
        XCTAssertGreaterThan(tour.lastModified, originalModified)
    }
    
    // MARK: - Rating and Review Tests
    
    func testTourRatingDefaults() {
        XCTAssertEqual(tour.rating, 0.0)
        XCTAssertEqual(tour.reviewCount, 0)
    }
    
    func testTourRatingValidation() {
        tour.rating = 4.5
        tour.reviewCount = 100
        
        XCTAssertEqual(tour.rating, 4.5)
        XCTAssertEqual(tour.reviewCount, 100)
        
        // Test rating bounds (assuming 0-5 scale)
        tour.rating = 5.0
        XCTAssertEqual(tour.rating, 5.0)
        
        tour.rating = 0.0
        XCTAssertEqual(tour.rating, 0.0)
    }
    
    // MARK: - Metadata Tests
    
    func testTourVersion() {
        XCTAssertEqual(tour.version, "1.0")
        
        tour.version = "2.1"
        XCTAssertEqual(tour.version, "2.1")
    }
    
    func testTourTags() {
        XCTAssertTrue(tour.tags.isEmpty)
        
        tour.tags = ["history", "walking", "family-friendly"]
        XCTAssertEqual(tour.tags.count, 3)
        XCTAssertTrue(tour.tags.contains("history"))
        XCTAssertTrue(tour.tags.contains("walking"))
        XCTAssertTrue(tour.tags.contains("family-friendly"))
    }
    
    func testTourAuthor() {
        XCTAssertEqual(tour.authorName, "Test Author")
        
        tour.authorName = "New Author"
        XCTAssertEqual(tour.authorName, "New Author")
        
        tour.authorName = nil
        XCTAssertNil(tour.authorName)
    }
    
    // MARK: - URL Tests
    
    func testTourCoverImageURL() {
        XCTAssertNil(tour.coverImageURL)
        
        let imageURL = URL(string: "https://example.com/image.jpg")
        tour.coverImageURL = imageURL
        XCTAssertEqual(tour.coverImageURL, imageURL)
    }
    
    // MARK: - Performance Tests
    
    func testTourCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = TestDataFactory.createTour()
            }
        }
    }
    
    func testTourWithManyPOIsPerformance() {
        let manyPOIs = (0..<100).map { index in
            TestDataFactory.createPOI(name: "POI \(index)")
        }
        
        measure {
            _ = TestDataFactory.createTour(pointsOfInterest: manyPOIs)
        }
    }
    
    // MARK: - Memory Tests
    
    func testTourMemoryDeallocation() {
        weak var weakTour: Tour?
        
        autoreleasepool {
            let localTour = TestDataFactory.createTour()
            weakTour = localTour
            XCTAssertNotNil(weakTour)
        }
        
        // Tour should be deallocated after autoreleasepool
        XCTAssertNil(weakTour)
    }
}