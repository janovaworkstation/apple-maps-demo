//
//  MockLocationManager.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CoreLocation
import Combine
@testable import Apple_Maps_Demo

@MainActor
final class MockLocationManager: ObservableObject {
    
    // MARK: - Published Properties (Mirror LocationManager)
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationServicesEnabled = true
    @Published var accuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    @Published var isMonitoringLocation = false
    @Published var visitHistory: [CLVisit] = []
    @Published var currentSpeed: CLLocationSpeed = 0
    @Published var currentHeading: CLLocationDirection = 0
    @Published var locationError: Error?
    
    // MARK: - Mock State
    var requestPermissionCallCount = 0
    var startLocationUpdatesCallCount = 0
    var stopLocationUpdatesCallCount = 0
    var addGeofenceCallCount = 0
    var removeGeofenceCallCount = 0
    
    var monitoredRegions: Set<CLRegion> = []
    var simulatedLocations: [CLLocation] = []
    var simulatedVisits: [CLVisit] = []
    
    // MARK: - Mock Implementation
    
    func requestLocationPermission() {
        requestPermissionCallCount += 1
        // Simulate permission granted
        authorizationStatus = .authorizedWhenInUse
    }
    
    func startLocationUpdates() {
        startLocationUpdatesCallCount += 1
        isMonitoringLocation = true
        
        // Simulate initial location
        if let firstLocation = simulatedLocations.first {
            currentLocation = firstLocation
        } else {
            currentLocation = TestDataFactory.createLocation()
        }
    }
    
    func stopLocationUpdates() {
        stopLocationUpdatesCallCount += 1
        isMonitoringLocation = false
    }
    
    func addGeofence(for poi: PointOfInterest) {
        addGeofenceCallCount += 1
        
        let region = CLCircularRegion(
            center: poi.coordinate,
            radius: poi.radius,
            identifier: poi.id.uuidString
        )
        
        monitoredRegions.insert(region)
    }
    
    func removeGeofence(for poi: PointOfInterest) {
        removeGeofenceCallCount += 1
        
        if let region = monitoredRegions.first(where: { $0.identifier == poi.id.uuidString }) {
            monitoredRegions.remove(region)
        }
    }
    
    func removeAllGeofences() {
        monitoredRegions.removeAll()
    }
    
    func calculateDistance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        return from.distance(from: to)
    }
    
    func calculateSpeed(from previousLocation: CLLocation, to currentLocation: CLLocation) -> CLLocationSpeed {
        let distance = calculateDistance(from: previousLocation, to: currentLocation)
        let timeInterval = currentLocation.timestamp.timeIntervalSince(previousLocation.timestamp)
        
        guard timeInterval > 0 else { return 0 }
        return distance / timeInterval
    }
    
    // MARK: - Mock Simulation Methods
    
    func simulateLocationUpdate(_ location: CLLocation) {
        currentLocation = location
        currentSpeed = calculateSpeedFromLocation(location)
    }
    
    func simulateLocationSequence(_ locations: [CLLocation]) {
        simulatedLocations = locations
        
        for (index, location) in locations.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                self.simulateLocationUpdate(location)
            }
        }
    }
    
    func simulateGeofenceEntry(for poi: PointOfInterest) {
        // Simulate entering a geofenced region
        let region = CLCircularRegion(
            center: poi.coordinate,
            radius: poi.radius,
            identifier: poi.id.uuidString
        )
        
        // This would normally trigger delegate methods
        // For testing, we can publish a notification or update state
    }
    
    func simulateGeofenceExit(for poi: PointOfInterest) {
        // Simulate exiting a geofenced region
        let region = CLCircularRegion(
            center: poi.coordinate,
            radius: poi.radius,
            identifier: poi.id.uuidString
        )
        
        // This would normally trigger delegate methods
    }
    
    func simulateVisit(_ visit: CLVisit) {
        visitHistory.append(visit)
    }
    
    func simulatePermissionChange(to status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
    
    func simulateLocationError(_ error: Error) {
        locationError = error
    }
    
    // MARK: - Private Helpers
    
    private func calculateSpeedFromLocation(_ location: CLLocation) -> CLLocationSpeed {
        guard let previousLocation = simulatedLocations.last else { return 0 }
        return calculateSpeed(from: previousLocation, to: location)
    }
    
    // MARK: - Mock Reset
    
    func reset() {
        requestPermissionCallCount = 0
        startLocationUpdatesCallCount = 0
        stopLocationUpdatesCallCount = 0
        addGeofenceCallCount = 0
        removeGeofenceCallCount = 0
        
        monitoredRegions.removeAll()
        simulatedLocations.removeAll()
        simulatedVisits.removeAll()
        
        currentLocation = nil
        authorizationStatus = .notDetermined
        isMonitoringLocation = false
        visitHistory.removeAll()
        currentSpeed = 0
        currentHeading = 0
        locationError = nil
    }
}

// MARK: - Mock CLVisit Extension

extension CLVisit {
    static func mockVisit(
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        horizontalAccuracy: CLLocationAccuracy = 10.0,
        arrivalDate: Date = Date().addingTimeInterval(-3600),
        departureDate: Date = Date()
    ) -> CLVisit {
        // Since CLVisit is not directly initializable, we need to create a mock
        // In a real implementation, this would use a test double or mock framework
        let visit = MockCLVisit()
        visit.mockCoordinate = coordinate
        visit.mockHorizontalAccuracy = horizontalAccuracy
        visit.mockArrivalDate = arrivalDate
        visit.mockDepartureDate = departureDate
        return visit
    }
}

private class MockCLVisit: CLVisit {
    var mockCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var mockHorizontalAccuracy: CLLocationAccuracy = 0
    var mockArrivalDate: Date = Date()
    var mockDepartureDate: Date = Date()
    
    override var coordinate: CLLocationCoordinate2D { return mockCoordinate }
    override var horizontalAccuracy: CLLocationAccuracy { return mockHorizontalAccuracy }
    override var arrivalDate: Date { return mockArrivalDate }
    override var departureDate: Date { return mockDepartureDate }
}