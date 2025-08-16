//
//  LocationManagerTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import CoreLocation
import Combine
@testable import Apple_Maps_Demo

@MainActor
final class LocationManagerTests: XCTestCase {
    
    var mockLocationManager: MockLocationManager!
    var cancellables: Set<AnyCancellable>!
    var testPOI: PointOfInterest!
    var testLocations: [CLLocation]!
    
    override func setUpWithError() throws {
        super.setUp()
        
        mockLocationManager = MockLocationManager()
        cancellables = Set<AnyCancellable>()
        testPOI = TestDataFactory.createPOI(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 100
        )
        
        testLocations = [
            TestDataFactory.createLocation(latitude: 37.7749, longitude: -122.4194),
            TestDataFactory.createLocation(latitude: 37.7750, longitude: -122.4195),
            TestDataFactory.createLocation(latitude: 37.7751, longitude: -122.4196)
        ]
    }
    
    override func tearDownWithError() throws {
        mockLocationManager?.reset()
        mockLocationManager = nil
        cancellables?.removeAll()
        cancellables = nil
        testPOI = nil
        testLocations = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testLocationManagerInitialization() {
        XCTAssertNil(mockLocationManager.currentLocation)
        XCTAssertEqual(mockLocationManager.authorizationStatus, .notDetermined)
        XCTAssertTrue(mockLocationManager.isLocationServicesEnabled)
        XCTAssertEqual(mockLocationManager.accuracy, kCLLocationAccuracyBest)
        XCTAssertFalse(mockLocationManager.isMonitoringLocation)
        XCTAssertTrue(mockLocationManager.visitHistory.isEmpty)
        XCTAssertEqual(mockLocationManager.currentSpeed, 0)
        XCTAssertEqual(mockLocationManager.currentHeading, 0)
        XCTAssertNil(mockLocationManager.locationError)
    }
    
    // MARK: - Permission Tests
    
    func testLocationManagerRequestPermission() {
        XCTAssertEqual(mockLocationManager.requestPermissionCallCount, 0)
        XCTAssertEqual(mockLocationManager.authorizationStatus, .notDetermined)
        
        mockLocationManager.requestLocationPermission()
        
        XCTAssertEqual(mockLocationManager.requestPermissionCallCount, 1)
        XCTAssertEqual(mockLocationManager.authorizationStatus, .authorizedWhenInUse)
    }
    
    func testLocationManagerPermissionStates() {
        let permissionStates: [CLAuthorizationStatus] = [
            .notDetermined,
            .denied,
            .restricted,
            .authorizedWhenInUse,
            .authorizedAlways
        ]
        
        for status in permissionStates {
            mockLocationManager.simulatePermissionChange(to: status)
            XCTAssertEqual(mockLocationManager.authorizationStatus, status)
        }
    }
    
    // MARK: - Location Updates Tests
    
    func testLocationManagerStartLocationUpdates() {
        XCTAssertEqual(mockLocationManager.startLocationUpdatesCallCount, 0)
        XCTAssertFalse(mockLocationManager.isMonitoringLocation)
        XCTAssertNil(mockLocationManager.currentLocation)
        
        mockLocationManager.startLocationUpdates()
        
        XCTAssertEqual(mockLocationManager.startLocationUpdatesCallCount, 1)
        XCTAssertTrue(mockLocationManager.isMonitoringLocation)
        XCTAssertNotNil(mockLocationManager.currentLocation)
    }
    
    func testLocationManagerStopLocationUpdates() {
        mockLocationManager.startLocationUpdates()
        XCTAssertTrue(mockLocationManager.isMonitoringLocation)
        XCTAssertEqual(mockLocationManager.stopLocationUpdatesCallCount, 0)
        
        mockLocationManager.stopLocationUpdates()
        
        XCTAssertEqual(mockLocationManager.stopLocationUpdatesCallCount, 1)
        XCTAssertFalse(mockLocationManager.isMonitoringLocation)
    }
    
    func testLocationManagerLocationSequence() {
        mockLocationManager.simulateLocationSequence(testLocations)
        
        // Wait a bit for async updates
        let expectation = XCTestExpectation(description: "Location sequence")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Should have the last location
        XCTAssertEqual(mockLocationManager.currentLocation?.coordinate.latitude, testLocations.last?.coordinate.latitude)
        XCTAssertEqual(mockLocationManager.currentLocation?.coordinate.longitude, testLocations.last?.coordinate.longitude)
    }
    
    // MARK: - Geofencing Tests
    
    func testLocationManagerAddGeofence() {
        XCTAssertEqual(mockLocationManager.addGeofenceCallCount, 0)
        XCTAssertTrue(mockLocationManager.monitoredRegions.isEmpty)
        
        mockLocationManager.addGeofence(for: testPOI)
        
        XCTAssertEqual(mockLocationManager.addGeofenceCallCount, 1)
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 1)
        
        let region = mockLocationManager.monitoredRegions.first
        XCTAssertEqual(region?.identifier, testPOI.id.uuidString)
    }
    
    func testLocationManagerRemoveGeofence() {
        mockLocationManager.addGeofence(for: testPOI)
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 1)
        XCTAssertEqual(mockLocationManager.removeGeofenceCallCount, 0)
        
        mockLocationManager.removeGeofence(for: testPOI)
        
        XCTAssertEqual(mockLocationManager.removeGeofenceCallCount, 1)
        XCTAssertTrue(mockLocationManager.monitoredRegions.isEmpty)
    }
    
    func testLocationManagerRemoveAllGeofences() {
        let poi1 = TestDataFactory.createPOI(name: "POI 1")
        let poi2 = TestDataFactory.createPOI(name: "POI 2")
        let poi3 = TestDataFactory.createPOI(name: "POI 3")
        
        mockLocationManager.addGeofence(for: poi1)
        mockLocationManager.addGeofence(for: poi2)
        mockLocationManager.addGeofence(for: poi3)
        
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 3)
        
        mockLocationManager.removeAllGeofences()
        
        XCTAssertTrue(mockLocationManager.monitoredRegions.isEmpty)
    }
    
    func testLocationManagerGeofenceLimit() {
        // Test adding more than the typical 20 region limit
        var pois: [PointOfInterest] = []
        for i in 0..<25 {
            let poi = TestDataFactory.createPOI(
                name: "POI \(i)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001
                )
            )
            pois.append(poi)
            mockLocationManager.addGeofence(for: poi)
        }
        
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 25)
        XCTAssertEqual(mockLocationManager.addGeofenceCallCount, 25)
    }
    
    // MARK: - Distance Calculation Tests
    
    func testLocationManagerDistanceCalculation() {
        let location1 = testLocations[0]
        let location2 = testLocations[1]
        
        let distance = mockLocationManager.calculateDistance(from: location1, to: location2)
        let expectedDistance = location1.distance(from: location2)
        
        XCTAssertEqual(distance, expectedDistance, accuracy: 0.1)
        XCTAssertGreaterThan(distance, 0)
    }
    
    func testLocationManagerDistanceToSameLocation() {
        let location = testLocations[0]
        
        let distance = mockLocationManager.calculateDistance(from: location, to: location)
        
        XCTAssertEqual(distance, 0, accuracy: 0.1)
    }
    
    func testLocationManagerLongDistance() {
        let sanFrancisco = TestDataFactory.createLocation(latitude: 37.7749, longitude: -122.4194)
        let newYork = TestDataFactory.createLocation(latitude: 40.7128, longitude: -74.0060)
        
        let distance = mockLocationManager.calculateDistance(from: sanFrancisco, to: newYork)
        
        // Distance between SF and NYC is approximately 4,000 km
        XCTAssertGreaterThan(distance, 3500000) // 3500 km
        XCTAssertLessThan(distance, 5000000)    // 5000 km
    }
    
    // MARK: - Speed Calculation Tests
    
    func testLocationManagerSpeedCalculation() {
        let location1 = TestDataFactory.createLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: Date()
        )
        
        let location2 = TestDataFactory.createLocation(
            latitude: 37.7750,
            longitude: -122.4195,
            timestamp: Date().addingTimeInterval(1.0) // 1 second later
        )
        
        let speed = mockLocationManager.calculateSpeed(from: location1, to: location2)
        
        XCTAssertGreaterThanOrEqual(speed, 0)
        // Speed should be reasonable (distance/time)
        let distance = location1.distance(from: location2)
        let expectedSpeed = distance / 1.0 // 1 second
        XCTAssertEqual(speed, expectedSpeed, accuracy: 0.1)
    }
    
    func testLocationManagerSpeedCalculationWithZeroTime() {
        let timestamp = Date()
        let location1 = TestDataFactory.createLocation(timestamp: timestamp)
        let location2 = TestDataFactory.createLocation(timestamp: timestamp) // Same timestamp
        
        let speed = mockLocationManager.calculateSpeed(from: location1, to: location2)
        
        XCTAssertEqual(speed, 0)
    }
    
    // MARK: - Geofence Entry/Exit Simulation Tests
    
    func testLocationManagerGeofenceEntry() {
        mockLocationManager.addGeofence(for: testPOI)
        
        // Simulate entering the geofence
        mockLocationManager.simulateGeofenceEntry(for: testPOI)
        
        // In a real implementation, this would trigger delegate methods
        // For now, just verify the geofence exists
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 1)
    }
    
    func testLocationManagerGeofenceExit() {
        mockLocationManager.addGeofence(for: testPOI)
        mockLocationManager.simulateGeofenceEntry(for: testPOI)
        
        // Simulate exiting the geofence
        mockLocationManager.simulateGeofenceExit(for: testPOI)
        
        // In a real implementation, this would trigger delegate methods
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 1)
    }
    
    // MARK: - Visit Tracking Tests
    
    func testLocationManagerVisitSimulation() {
        XCTAssertTrue(mockLocationManager.visitHistory.isEmpty)
        
        let mockVisit = CLVisit.mockVisit(
            coordinate: testPOI.coordinate,
            arrivalDate: Date().addingTimeInterval(-3600),
            departureDate: Date()
        )
        
        mockLocationManager.simulateVisit(mockVisit)
        
        XCTAssertEqual(mockLocationManager.visitHistory.count, 1)
        XCTAssertEqual(mockLocationManager.visitHistory.first?.coordinate.latitude, testPOI.coordinate.latitude, accuracy: 0.000001)
    }
    
    func testLocationManagerMultipleVisits() {
        let visits = [
            CLVisit.mockVisit(coordinate: testLocations[0].coordinate),
            CLVisit.mockVisit(coordinate: testLocations[1].coordinate),
            CLVisit.mockVisit(coordinate: testLocations[2].coordinate)
        ]
        
        for visit in visits {
            mockLocationManager.simulateVisit(visit)
        }
        
        XCTAssertEqual(mockLocationManager.visitHistory.count, 3)
    }
    
    // MARK: - Error Handling Tests
    
    func testLocationManagerLocationError() {
        XCTAssertNil(mockLocationManager.locationError)
        
        let testError = NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue, userInfo: nil)
        mockLocationManager.simulateLocationError(testError)
        
        XCTAssertNotNil(mockLocationManager.locationError)
        XCTAssertEqual((mockLocationManager.locationError as? NSError)?.code, CLError.denied.rawValue)
    }
    
    func testLocationManagerPermissionDeniedError() {
        mockLocationManager.simulatePermissionChange(to: .denied)
        
        let deniedError = NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue, userInfo: nil)
        mockLocationManager.simulateLocationError(deniedError)
        
        XCTAssertEqual(mockLocationManager.authorizationStatus, .denied)
        XCTAssertNotNil(mockLocationManager.locationError)
    }
    
    // MARK: - Combine Publisher Tests
    
    func testLocationManagerCurrentLocationPublisher() {
        let expectation = XCTestExpectation(description: "currentLocation publisher")
        var receivedLocations: [CLLocation?] = []
        
        mockLocationManager.$currentLocation
            .sink { location in
                receivedLocations.append(location)
                if receivedLocations.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockLocationManager.simulateLocationUpdate(testLocations[0])
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedLocations.count, 2)
        XCTAssertNil(receivedLocations[0]) // Initial value
        XCTAssertNotNil(receivedLocations[1]) // Updated value
        XCTAssertEqual(receivedLocations[1]?.coordinate.latitude, testLocations[0].coordinate.latitude, accuracy: 0.000001)
    }
    
    func testLocationManagerAuthorizationStatusPublisher() {
        let expectation = XCTestExpectation(description: "authorizationStatus publisher")
        var receivedStatuses: [CLAuthorizationStatus] = []
        
        mockLocationManager.$authorizationStatus
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockLocationManager.simulatePermissionChange(to: .authorizedWhenInUse)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedStatuses.count, 2)
        XCTAssertEqual(receivedStatuses[0], .notDetermined) // Initial value
        XCTAssertEqual(receivedStatuses[1], .authorizedWhenInUse) // Updated value
    }
    
    // MARK: - Accuracy Tests
    
    func testLocationManagerAccuracySettings() {
        XCTAssertEqual(mockLocationManager.accuracy, kCLLocationAccuracyBest)
        
        mockLocationManager.accuracy = kCLLocationAccuracyNearestTenMeters
        XCTAssertEqual(mockLocationManager.accuracy, kCLLocationAccuracyNearestTenMeters)
        
        mockLocationManager.accuracy = kCLLocationAccuracyHundredMeters
        XCTAssertEqual(mockLocationManager.accuracy, kCLLocationAccuracyHundredMeters)
    }
    
    // MARK: - Heading Tests
    
    func testLocationManagerHeading() {
        XCTAssertEqual(mockLocationManager.currentHeading, 0)
        
        mockLocationManager.currentHeading = 45.0 // Northeast
        XCTAssertEqual(mockLocationManager.currentHeading, 45.0)
        
        mockLocationManager.currentHeading = 180.0 // South
        XCTAssertEqual(mockLocationManager.currentHeading, 180.0)
        
        mockLocationManager.currentHeading = 270.0 // West
        XCTAssertEqual(mockLocationManager.currentHeading, 270.0)
    }
    
    func testLocationManagerHeadingValidation() {
        // Test valid heading range (0-360)
        mockLocationManager.currentHeading = 0
        XCTAssertEqual(mockLocationManager.currentHeading, 0)
        
        mockLocationManager.currentHeading = 359.9
        XCTAssertEqual(mockLocationManager.currentHeading, 359.9, accuracy: 0.1)
        
        // Test invalid headings (implementation dependent)
        mockLocationManager.currentHeading = -1
        XCTAssertEqual(mockLocationManager.currentHeading, -1)
        
        mockLocationManager.currentHeading = 361
        XCTAssertEqual(mockLocationManager.currentHeading, 361)
    }
    
    // MARK: - Mock Reset Tests
    
    func testLocationManagerMockReset() {
        // Set up some state
        mockLocationManager.startLocationUpdates()
        mockLocationManager.addGeofence(for: testPOI)
        mockLocationManager.currentLocation = testLocations[0]
        mockLocationManager.simulatePermissionChange(to: .authorizedAlways)
        
        // Verify state is set
        XCTAssertTrue(mockLocationManager.isMonitoringLocation)
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 1)
        XCTAssertNotNil(mockLocationManager.currentLocation)
        XCTAssertEqual(mockLocationManager.authorizationStatus, .authorizedAlways)
        
        // Reset
        mockLocationManager.reset()
        
        // Verify state is reset
        XCTAssertFalse(mockLocationManager.isMonitoringLocation)
        XCTAssertTrue(mockLocationManager.monitoredRegions.isEmpty)
        XCTAssertNil(mockLocationManager.currentLocation)
        XCTAssertEqual(mockLocationManager.authorizationStatus, .notDetermined)
        XCTAssertEqual(mockLocationManager.requestPermissionCallCount, 0)
    }
    
    // MARK: - Performance Tests
    
    func testLocationManagerGeofencePerformance() {
        let pois = (0..<100).map { index in
            TestDataFactory.createPOI(
                name: "POI \(index)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.0 + Double(index) * 0.01,
                    longitude: -122.0 + Double(index) * 0.01
                )
            )
        }
        
        measure {
            for poi in pois {
                mockLocationManager.addGeofence(for: poi)
            }
        }
        
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 100)
    }
    
    func testLocationManagerDistanceCalculationPerformance() {
        let locations = (0..<1000).map { index in
            TestDataFactory.createLocation(
                latitude: 37.0 + Double(index) * 0.001,
                longitude: -122.0 + Double(index) * 0.001
            )
        }
        
        let baseLocation = locations[0]
        
        measure {
            for location in locations {
                _ = mockLocationManager.calculateDistance(from: baseLocation, to: location)
            }
        }
    }
}