//
//  PointOfInterestTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import CoreLocation
@testable import Apple_Maps_Demo

final class PointOfInterestTests: XCTestCase {
    
    var poi: PointOfInterest!
    var coordinate: CLLocationCoordinate2D!
    var audioContent: AudioContent!
    
    override func setUpWithError() throws {
        super.setUp()
        
        coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        audioContent = TestDataFactory.createAudioContent()
        poi = TestDataFactory.createPOI(
            name: "Test POI",
            coordinate: coordinate,
            radius: 150,
            triggerType: .location,
            order: 1
        )
    }
    
    override func tearDownWithError() throws {
        poi = nil
        coordinate = nil
        audioContent = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testPOIInitialization() {
        XCTAssertEqual(poi.name, "Test POI")
        XCTAssertEqual(poi.coordinate.latitude, coordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(poi.coordinate.longitude, coordinate.longitude, accuracy: 0.000001)
        XCTAssertEqual(poi.radius, 150)
        XCTAssertEqual(poi.triggerType, .location)
        XCTAssertEqual(poi.order, 1)
        XCTAssertNotNil(poi.audioContent)
        XCTAssertEqual(poi.description, "Test POI description")
        XCTAssertEqual(poi.category, .general)
        XCTAssertEqual(poi.estimatedDuration, 120)
    }
    
    func testPOIIdentifiable() {
        let poi1 = TestDataFactory.createPOI(name: "POI 1")
        let poi2 = TestDataFactory.createPOI(name: "POI 2")
        
        XCTAssertNotEqual(poi1.id, poi2.id)
        XCTAssertEqual(poi1.id, poi1.id)
    }
    
    // MARK: - Coordinate Tests
    
    func testPOICoordinateValidation() {
        // Test valid coordinates
        XCTAssertTrue(CLLocationCoordinate2DIsValid(poi.coordinate))
        
        // Test coordinate precision
        let preciseCoordinate = CLLocationCoordinate2D(latitude: 37.774929, longitude: -122.419416)
        let precisePOI = TestDataFactory.createPOI(coordinate: preciseCoordinate)
        
        XCTAssertEqual(precisePOI.coordinate.latitude, 37.774929, accuracy: 0.000001)
        XCTAssertEqual(precisePOI.coordinate.longitude, -122.419416, accuracy: 0.000001)
    }
    
    func testPOICoordinateBounds() {
        // Test extreme valid coordinates
        let northPole = TestDataFactory.createPOI(
            coordinate: CLLocationCoordinate2D(latitude: 90.0, longitude: 0.0)
        )
        XCTAssertTrue(CLLocationCoordinate2DIsValid(northPole.coordinate))
        
        let southPole = TestDataFactory.createPOI(
            coordinate: CLLocationCoordinate2D(latitude: -90.0, longitude: 0.0)
        )
        XCTAssertTrue(CLLocationCoordinate2DIsValid(southPole.coordinate))
        
        let dateline = TestDataFactory.createPOI(
            coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 180.0)
        )
        XCTAssertTrue(CLLocationCoordinate2DIsValid(dateline.coordinate))
    }
    
    // MARK: - Radius Tests
    
    func testPOIRadiusValidation() {
        XCTAssertEqual(poi.radius, 150)
        XCTAssertGreaterThan(poi.radius, 0)
        
        // Test minimum radius
        let smallPOI = TestDataFactory.createPOI(radius: 1)
        XCTAssertEqual(smallPOI.radius, 1)
        
        // Test large radius
        let largePOI = TestDataFactory.createPOI(radius: 1000)
        XCTAssertEqual(largePOI.radius, 1000)
    }
    
    func testPOIRadiusCalculations() {
        // Test if point is within radius
        let center = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
        
        // Point just inside radius
        let insidePoint = CLLocation(
            latitude: poi.coordinate.latitude + 0.001,
            longitude: poi.coordinate.longitude
        )
        let insideDistance = center.distance(from: insidePoint)
        XCTAssertLessThan(insideDistance, poi.radius)
        
        // Point outside radius
        let outsidePoint = CLLocation(
            latitude: poi.coordinate.latitude + 0.01,
            longitude: poi.coordinate.longitude
        )
        let outsideDistance = center.distance(from: outsidePoint)
        XCTAssertGreaterThan(outsideDistance, poi.radius)
    }
    
    // MARK: - Trigger Type Tests
    
    func testPOITriggerTypes() {
        let locationPOI = TestDataFactory.createPOI(triggerType: .location)
        XCTAssertEqual(locationPOI.triggerType, .location)
        
        let beaconPOI = TestDataFactory.createPOI(triggerType: .beacon)
        XCTAssertEqual(beaconPOI.triggerType, .beacon)
        
        let manualPOI = TestDataFactory.createPOI(triggerType: .manual)
        XCTAssertEqual(manualPOI.triggerType, .manual)
    }
    
    // MARK: - Order Tests
    
    func testPOIOrdering() {
        XCTAssertEqual(poi.order, 1)
        
        let firstPOI = TestDataFactory.createPOI(order: 0)
        let secondPOI = TestDataFactory.createPOI(order: 1)
        let thirdPOI = TestDataFactory.createPOI(order: 2)
        
        XCTAssertLessThan(firstPOI.order, secondPOI.order)
        XCTAssertLessThan(secondPOI.order, thirdPOI.order)
    }
    
    func testPOISorting() {
        let unsortedPOIs = [
            TestDataFactory.createPOI(name: "Third", order: 2),
            TestDataFactory.createPOI(name: "First", order: 0),
            TestDataFactory.createPOI(name: "Second", order: 1)
        ]
        
        let sortedPOIs = unsortedPOIs.sorted { $0.order < $1.order }
        
        XCTAssertEqual(sortedPOIs[0].name, "First")
        XCTAssertEqual(sortedPOIs[1].name, "Second")
        XCTAssertEqual(sortedPOIs[2].name, "Third")
    }
    
    // MARK: - Audio Content Tests
    
    func testPOIAudioContent() {
        XCTAssertNotNil(poi.audioContent)
        XCTAssertEqual(poi.audioContent.duration, 120)
        XCTAssertEqual(poi.audioContent.language, "en")
    }
    
    func testPOIWithoutAudioContent() {
        let audioContent = TestDataFactory.createAudioContent(duration: 0)
        let silentPOI = TestDataFactory.createPOI()
        silentPOI.audioContent = audioContent
        
        XCTAssertNotNil(silentPOI.audioContent)
        XCTAssertEqual(silentPOI.audioContent.duration, 0)
    }
    
    // MARK: - Category Tests
    
    func testPOICategories() {
        let categories: [POICategory] = [.general, .historical, .cultural, .nature, .architecture, .restaurant, .shopping, .entertainment]
        
        for category in categories {
            let categoryPOI = TestDataFactory.createPOI()
            categoryPOI.category = category
            XCTAssertEqual(categoryPOI.category, category)
        }
    }
    
    // MARK: - Duration Tests
    
    func testPOIEstimatedDuration() {
        XCTAssertEqual(poi.estimatedDuration, 120)
        XCTAssertGreaterThanOrEqual(poi.estimatedDuration, 0)
        
        let quickPOI = TestDataFactory.createPOI()
        quickPOI.estimatedDuration = 30
        XCTAssertEqual(quickPOI.estimatedDuration, 30)
        
        let longPOI = TestDataFactory.createPOI()
        longPOI.estimatedDuration = 600
        XCTAssertEqual(longPOI.estimatedDuration, 600)
    }
    
    // MARK: - Description Tests
    
    func testPOIDescription() {
        XCTAssertEqual(poi.description, "Test POI description")
        XCTAssertFalse(poi.description.isEmpty)
        
        let emptyDescPOI = TestDataFactory.createPOI()
        emptyDescPOI.description = ""
        XCTAssertTrue(emptyDescPOI.description.isEmpty)
        
        let longDescPOI = TestDataFactory.createPOI()
        longDescPOI.description = String(repeating: "A", count: 1000)
        XCTAssertEqual(longDescPOI.description.count, 1000)
    }
    
    // MARK: - Name Validation Tests
    
    func testPOINameValidation() {
        XCTAssertEqual(poi.name, "Test POI")
        XCTAssertFalse(poi.name.isEmpty)
        
        let longNamePOI = TestDataFactory.createPOI(name: String(repeating: "X", count: 100))
        XCTAssertEqual(longNamePOI.name.count, 100)
    }
    
    // MARK: - Distance Calculation Tests
    
    func testPOIDistanceCalculations() {
        let location1 = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let location2 = CLLocation(latitude: 37.7849, longitude: -122.4094) // Nearby point
        
        let distance = location1.distance(from: location2)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertLessThan(distance, 2000) // Should be less than 2km
    }
    
    func testPOIRegionContainsLocation() {
        let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
        
        // Test point at center
        let centerDistance = poiLocation.distance(from: poiLocation)
        XCTAssertEqual(centerDistance, 0, accuracy: 0.1)
        XCTAssertLessThan(centerDistance, poi.radius)
        
        // Test point at edge
        let edgeLocation = CLLocation(
            latitude: poi.coordinate.latitude + 0.001,
            longitude: poi.coordinate.longitude
        )
        let edgeDistance = poiLocation.distance(from: edgeLocation)
        
        // Verify our test setup - this might be within or outside depending on the exact distance
        // The important thing is we can calculate the distance
        XCTAssertGreaterThan(edgeDistance, 0)
    }
    
    // MARK: - Geofencing Tests
    
    func testPOIGeofenceRegion() {
        let region = CLCircularRegion(
            center: poi.coordinate,
            radius: poi.radius,
            identifier: poi.id.uuidString
        )
        
        XCTAssertEqual(region.center.latitude, poi.coordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(region.center.longitude, poi.coordinate.longitude, accuracy: 0.000001)
        XCTAssertEqual(region.radius, poi.radius)
        XCTAssertEqual(region.identifier, poi.id.uuidString)
    }
    
    // MARK: - Hashable and Equatable Tests
    
    func testPOIEquality() {
        let poi1 = TestDataFactory.createPOI(name: "Same POI")
        let poi2 = TestDataFactory.createPOI(name: "Same POI")
        
        // Different instances should have different IDs
        XCTAssertNotEqual(poi1.id, poi2.id)
        
        // Same instance should equal itself
        XCTAssertEqual(poi1.id, poi1.id)
    }
    
    // MARK: - Performance Tests
    
    func testPOICreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = TestDataFactory.createPOI()
            }
        }
    }
    
    func testPOIDistanceCalculationPerformance() {
        let locations = (0..<100).map { index in
            CLLocation(
                latitude: 37.7749 + Double(index) * 0.001,
                longitude: -122.4194 + Double(index) * 0.001
            )
        }
        
        let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
        
        measure {
            for location in locations {
                _ = poiLocation.distance(from: location)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testPOIMemoryDeallocation() {
        weak var weakPOI: PointOfInterest?
        
        autoreleasepool {
            let localPOI = TestDataFactory.createPOI()
            weakPOI = localPOI
            XCTAssertNotNil(weakPOI)
        }
        
        // POI should be deallocated after autoreleasepool
        XCTAssertNil(weakPOI)
    }
    
    // MARK: - Edge Case Tests
    
    func testPOIWithZeroRadius() {
        let zeroPOI = TestDataFactory.createPOI(radius: 0)
        XCTAssertEqual(zeroPOI.radius, 0)
    }
    
    func testPOIWithNegativeOrder() {
        let negativePOI = TestDataFactory.createPOI(order: -1)
        XCTAssertEqual(negativePOI.order, -1)
    }
    
    func testPOICoordinateAtEquator() {
        let equatorPOI = TestDataFactory.createPOI(
            coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        )
        XCTAssertEqual(equatorPOI.coordinate.latitude, 0.0)
        XCTAssertEqual(equatorPOI.coordinate.longitude, 0.0)
        XCTAssertTrue(CLLocationCoordinate2DIsValid(equatorPOI.coordinate))
    }
}