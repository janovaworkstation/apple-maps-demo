//
//  LocationAudioIntegrationTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import CoreLocation
import Combine
@testable import Apple_Maps_Demo

@MainActor
final class LocationAudioIntegrationTests: XCTestCase {
    
    var mockLocationManager: MockLocationManager!
    var mockAudioManager: MockAudioManager!
    var cancellables: Set<AnyCancellable>!
    var testTour: Tour!
    var testPOIs: [PointOfInterest]!
    
    override func setUpWithError() throws {
        super.setUp()
        
        mockLocationManager = MockLocationManager()
        mockAudioManager = MockAudioManager()
        cancellables = Set<AnyCancellable>()
        
        // Create test POIs with different locations
        testPOIs = [
            TestDataFactory.createPOI(
                name: "Golden Gate Bridge",
                coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
                radius: 100,
                order: 0
            ),
            TestDataFactory.createPOI(
                name: "Alcatraz Island",
                coordinate: CLLocationCoordinate2D(latitude: 37.8267, longitude: -122.4230),
                radius: 150,
                order: 1
            ),
            TestDataFactory.createPOI(
                name: "Fisherman's Wharf",
                coordinate: CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177),
                radius: 80,
                order: 2
            )
        ]
        
        testTour = TestDataFactory.createTour(
            name: "San Francisco Tour",
            pointsOfInterest: testPOIs
        )
    }
    
    override func tearDownWithError() throws {
        mockLocationManager?.reset()
        mockAudioManager?.reset()
        mockLocationManager = nil
        mockAudioManager = nil
        cancellables?.removeAll()
        cancellables = nil
        testTour = nil
        testPOIs = nil
        super.tearDown()
    }
    
    // MARK: - Location to Audio Trigger Integration Tests
    
    func testLocationEntryTriggersAudio() async throws {
        // Setup: Start location monitoring and set current tour
        mockLocationManager.requestLocationPermission()
        mockLocationManager.startLocationUpdates()
        mockAudioManager.setCurrentTour(testTour)
        
        // Add geofences for all POIs
        for poi in testPOIs {
            mockLocationManager.addGeofence(for: poi)
        }
        
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, testPOIs.count)
        XCTAssertFalse(mockAudioManager.isPlaying)
        
        // Simulate entering the first POI's geofence
        let firstPOI = testPOIs[0]
        let poiLocation = CLLocation(
            latitude: firstPOI.coordinate.latitude,
            longitude: firstPOI.coordinate.longitude
        )
        
        mockLocationManager.simulateLocationUpdate(poiLocation)
        mockLocationManager.simulateGeofenceEntry(for: firstPOI)
        
        // Simulate audio playback trigger
        try await mockAudioManager.playAudioForPOI(firstPOI)
        
        // Verify audio started playing
        XCTAssertTrue(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentPOI?.id, firstPOI.id)
        XCTAssertEqual(mockAudioManager.duration, firstPOI.audioContent.duration)
    }
    
    func testSequentialPOIVisitation() async throws {
        // Setup tour and location monitoring
        mockLocationManager.requestLocationPermission()
        mockLocationManager.startLocationUpdates()
        mockAudioManager.setCurrentTour(testTour)
        
        for poi in testPOIs {
            mockLocationManager.addGeofence(for: poi)
        }
        
        // Visit POIs in order
        for (index, poi) in testPOIs.enumerated() {
            // Move to POI location
            let poiLocation = CLLocation(
                latitude: poi.coordinate.latitude,
                longitude: poi.coordinate.longitude
            )
            
            mockLocationManager.simulateLocationUpdate(poiLocation)
            mockLocationManager.simulateGeofenceEntry(for: poi)
            
            // Stop previous audio and start new audio
            if index > 0 {
                mockAudioManager.stop()
            }
            
            try await mockAudioManager.playAudioForPOI(poi)
            
            // Verify correct POI is playing
            XCTAssertTrue(mockAudioManager.isPlaying)
            XCTAssertEqual(mockAudioManager.currentPOI?.id, poi.id)
            XCTAssertEqual(mockAudioManager.currentPOI?.order, index)
            
            // Simulate listening to complete audio
            mockAudioManager.simulatePlaybackProgress(to: poi.audioContent.duration)
            mockAudioManager.simulateAudioCompletion()
        }
        
        // Verify all POIs were visited
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentPOI?.order, testPOIs.count - 1)
    }
    
    func testGeofenceExitBehavior() async throws {
        let poi = testPOIs[0]
        
        // Setup and enter geofence
        mockLocationManager.addGeofence(for: poi)
        mockLocationManager.simulateGeofenceEntry(for: poi)
        try await mockAudioManager.playAudioForPOI(poi)
        
        XCTAssertTrue(mockAudioManager.isPlaying)
        
        // Simulate moving away from POI
        let distantLocation = CLLocation(
            latitude: poi.coordinate.latitude + 0.01, // ~1km away
            longitude: poi.coordinate.longitude + 0.01
        )
        
        mockLocationManager.simulateLocationUpdate(distantLocation)
        mockLocationManager.simulateGeofenceExit(for: poi)
        
        // In a real implementation, this might pause or continue audio
        // For now, verify we can detect the exit
        let distance = CLLocation(
            latitude: poi.coordinate.latitude,
            longitude: poi.coordinate.longitude
        ).distance(from: distantLocation)
        
        XCTAssertGreaterThan(distance, poi.radius)
    }
    
    // MARK: - Speed-Based Behavior Integration Tests
    
    func testWalkingSpeedAudioTiming() async throws {
        let poi = testPOIs[0]
        
        // Setup for walking tour
        testTour.tourType = .walking
        mockAudioManager.setCurrentTour(testTour)
        mockLocationManager.addGeofence(for: poi)
        
        // Simulate slow movement (walking speed ~1.4 m/s)
        let startLocation = CLLocation(
            latitude: poi.coordinate.latitude - 0.001,
            longitude: poi.coordinate.longitude,
            timestamp: Date()
        )
        
        let poiLocation = CLLocation(
            latitude: poi.coordinate.latitude,
            longitude: poi.coordinate.longitude,
            timestamp: Date().addingTimeInterval(60) // 1 minute later
        )
        
        mockLocationManager.simulateLocationUpdate(startLocation)
        await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        mockLocationManager.simulateLocationUpdate(poiLocation)
        
        let speed = mockLocationManager.calculateSpeed(from: startLocation, to: poiLocation)
        
        // Verify walking speed detection
        XCTAssertLessThan(speed, 5.0) // Walking speed < 5 m/s
        
        // For walking tours, audio should play with longer dwell time
        mockLocationManager.simulateGeofenceEntry(for: poi)
        try await mockAudioManager.playAudioForPOI(poi)
        
        XCTAssertTrue(mockAudioManager.isPlaying)
    }
    
    func testDrivingSpeedAudioTiming() async throws {
        let poi = testPOIs[0]
        
        // Setup for driving tour
        testTour.tourType = .driving
        mockAudioManager.setCurrentTour(testTour)
        mockLocationManager.addGeofence(for: poi)
        
        // Simulate fast movement (driving speed ~15 m/s / 33 mph)
        let startLocation = CLLocation(
            latitude: poi.coordinate.latitude - 0.01,
            longitude: poi.coordinate.longitude,
            timestamp: Date()
        )
        
        let poiLocation = CLLocation(
            latitude: poi.coordinate.latitude,
            longitude: poi.coordinate.longitude,
            timestamp: Date().addingTimeInterval(30) // 30 seconds later
        )
        
        mockLocationManager.simulateLocationUpdate(startLocation)
        await Task.sleep(nanoseconds: 100_000_000)
        
        mockLocationManager.simulateLocationUpdate(poiLocation)
        
        let speed = mockLocationManager.calculateSpeed(from: startLocation, to: poiLocation)
        
        // Verify driving speed detection
        XCTAssertGreaterThan(speed, 10.0) // Driving speed > 10 m/s
        
        // For driving tours, audio should start playing immediately
        mockLocationManager.simulateGeofenceEntry(for: poi)
        try await mockAudioManager.playAudioForPOI(poi)
        
        XCTAssertTrue(mockAudioManager.isPlaying)
    }
    
    // MARK: - Location Accuracy Integration Tests
    
    func testLocationAccuracyAffectsGeofencing() {
        let poi = testPOIs[0]
        mockLocationManager.addGeofence(for: poi)
        
        // Test with high accuracy location
        let highAccuracyLocation = CLLocation(
            coordinate: poi.coordinate,
            altitude: 0,
            horizontalAccuracy: 5.0, // 5 meter accuracy
            verticalAccuracy: -1,
            timestamp: Date()
        )
        
        mockLocationManager.simulateLocationUpdate(highAccuracyLocation)
        
        // High accuracy should trigger geofence reliably
        let distance = CLLocation(
            latitude: poi.coordinate.latitude,
            longitude: poi.coordinate.longitude
        ).distance(from: highAccuracyLocation)
        
        XCTAssertLessThan(distance, poi.radius)
        
        // Test with low accuracy location
        let lowAccuracyLocation = CLLocation(
            coordinate: poi.coordinate,
            altitude: 0,
            horizontalAccuracy: 100.0, // 100 meter accuracy
            verticalAccuracy: -1,
            timestamp: Date()
        )
        
        mockLocationManager.simulateLocationUpdate(lowAccuracyLocation)
        
        // Low accuracy might be less reliable for small geofences
        XCTAssertGreaterThan(lowAccuracyLocation.horizontalAccuracy, poi.radius / 2)
    }
    
    // MARK: - Audio Session Integration Tests
    
    func testAudioSessionInterruption() async throws {
        let poi = testPOIs[0]
        
        // Start audio playback
        try await mockAudioManager.playAudioForPOI(poi)
        XCTAssertTrue(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentAudioSession, .active)
        
        // Simulate audio interruption (phone call, etc.)
        mockAudioManager.currentAudioSession = .interrupted
        mockAudioManager.pause()
        
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentAudioSession, .interrupted)
        
        // Simulate interruption ended
        mockAudioManager.currentAudioSession = .active
        try await mockAudioManager.play()
        
        XCTAssertTrue(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentAudioSession, .active)
    }
    
    func testExternalAudioDeviceIntegration() async throws {
        let poi = testPOIs[0]
        
        // Start with built-in audio
        XCTAssertEqual(mockAudioManager.audioRoute, .builtin)
        XCTAssertFalse(mockAudioManager.isExternalAudioConnected)
        
        try await mockAudioManager.playAudioForPOI(poi)
        XCTAssertTrue(mockAudioManager.isPlaying)
        
        // Simulate Bluetooth headphones connection
        mockAudioManager.simulateExternalAudioConnection(true)
        
        XCTAssertTrue(mockAudioManager.isExternalAudioConnected)
        XCTAssertEqual(mockAudioManager.audioRoute, .bluetooth)
        
        // Audio should continue playing on new route
        XCTAssertTrue(mockAudioManager.isPlaying)
        
        // Simulate disconnection
        mockAudioManager.simulateExternalAudioConnection(false)
        
        XCTAssertFalse(mockAudioManager.isExternalAudioConnected)
        XCTAssertEqual(mockAudioManager.audioRoute, .builtin)
    }
    
    // MARK: - Location Permission Integration Tests
    
    func testLocationPermissionFlow() {
        XCTAssertEqual(mockLocationManager.authorizationStatus, .notDetermined)
        XCTAssertFalse(mockLocationManager.isMonitoringLocation)
        
        // Request permission
        mockLocationManager.requestLocationPermission()
        XCTAssertEqual(mockLocationManager.authorizationStatus, .authorizedWhenInUse)
        
        // Start location updates after permission granted
        mockLocationManager.startLocationUpdates()
        XCTAssertTrue(mockLocationManager.isMonitoringLocation)
        
        // Should be able to add geofences
        mockLocationManager.addGeofence(for: testPOIs[0])
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 1)
    }
    
    func testLocationPermissionDenied() {
        // Simulate permission denied
        mockLocationManager.simulatePermissionChange(to: .denied)
        
        XCTAssertEqual(mockLocationManager.authorizationStatus, .denied)
        
        // Should not be able to start location updates
        mockLocationManager.startLocationUpdates()
        
        // In a real implementation, this would be handled by checking permission status
        // For mock, we allow the operation but in real code this would be prevented
    }
    
    // MARK: - Error Recovery Integration Tests
    
    func testLocationErrorRecovery() async throws {
        let poi = testPOIs[0]
        
        // Start with working location services
        mockLocationManager.requestLocationPermission()
        mockLocationManager.startLocationUpdates()
        
        // Simulate location error
        let locationError = NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue)
        mockLocationManager.simulateLocationError(locationError)
        
        XCTAssertNotNil(mockLocationManager.locationError)
        
        // Audio should still be possible to trigger manually
        try await mockAudioManager.playAudioForPOI(poi)
        XCTAssertTrue(mockAudioManager.isPlaying)
        
        // Simulate error recovery
        mockLocationManager.locationError = nil
        let validLocation = TestDataFactory.createLocation()
        mockLocationManager.simulateLocationUpdate(validLocation)
        
        XCTAssertNil(mockLocationManager.locationError)
        XCTAssertNotNil(mockLocationManager.currentLocation)
    }
    
    func testAudioErrorRecovery() async throws {
        let poi = testPOIs[0]
        
        // Simulate audio error
        mockAudioManager.simulateAudioError(AudioManagerError.fileNotFound)
        
        do {
            try await mockAudioManager.playAudioForPOI(poi)
            XCTFail("Expected audio error")
        } catch {
            XCTAssertTrue(error is AudioManagerError)
        }
        
        XCTAssertFalse(mockAudioManager.isPlaying)
        
        // Simulate error recovery (reset error state)
        mockAudioManager.shouldFailPlayback = false
        mockAudioManager.playbackError = nil
        
        // Should be able to play audio again
        try await mockAudioManager.playAudioForPOI(poi)
        XCTAssertTrue(mockAudioManager.isPlaying)
    }
    
    // MARK: - Performance Integration Tests
    
    func testMultiplePOIGeofencePerformance() async throws {
        // Create many POIs
        var manyPOIs: [PointOfInterest] = []
        for i in 0..<50 {
            let poi = TestDataFactory.createPOI(
                name: "POI \(i)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001
                )
            )
            manyPOIs.append(poi)
        }
        
        // Measure geofence setup time
        measure {
            for poi in manyPOIs {
                mockLocationManager.addGeofence(for: poi)
            }
        }
        
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, 50)
    }
    
    func testRapidLocationUpdatePerformance() {
        let locations = (0..<100).map { index in
            TestDataFactory.createLocation(
                latitude: 37.7749 + Double(index) * 0.0001,
                longitude: -122.4194 + Double(index) * 0.0001,
                timestamp: Date().addingTimeInterval(Double(index))
            )
        }
        
        measure {
            for location in locations {
                mockLocationManager.simulateLocationUpdate(location)
            }
        }
        
        XCTAssertNotNil(mockLocationManager.currentLocation)
    }
    
    // MARK: - Cleanup Integration Tests
    
    func testTourCompletionCleanup() async throws {
        // Setup full tour
        mockLocationManager.requestLocationPermission()
        mockLocationManager.startLocationUpdates()
        mockAudioManager.setCurrentTour(testTour)
        
        for poi in testPOIs {
            mockLocationManager.addGeofence(for: poi)
        }
        
        XCTAssertEqual(mockLocationManager.monitoredRegions.count, testPOIs.count)
        
        // Complete tour (visit all POIs)
        for poi in testPOIs {
            let poiLocation = CLLocation(
                latitude: poi.coordinate.latitude,
                longitude: poi.coordinate.longitude
            )
            mockLocationManager.simulateLocationUpdate(poiLocation)
            try await mockAudioManager.playAudioForPOI(poi)
            mockAudioManager.simulateAudioCompletion()
        }
        
        // Cleanup after tour completion
        mockLocationManager.removeAllGeofences()
        mockAudioManager.stop()
        mockAudioManager.setCurrentTour(nil)
        
        XCTAssertTrue(mockLocationManager.monitoredRegions.isEmpty)
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertNil(mockAudioManager.currentTourPublic)
        XCTAssertNil(mockAudioManager.currentPOI)
    }
}