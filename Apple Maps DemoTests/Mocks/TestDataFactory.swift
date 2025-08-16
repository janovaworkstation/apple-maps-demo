//
//  TestDataFactory.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CoreLocation
@testable import Apple_Maps_Demo

// CLVisit extension for testing
extension CLVisit {
    static func mockVisit(
        coordinate: CLLocationCoordinate2D,
        arrivalDate: Date = Date().addingTimeInterval(-3600),
        departureDate: Date = Date()
    ) -> CLVisit {
        // Since CLVisit is a system class, we can't directly create it in tests
        // This is a placeholder that would need a proper mock implementation
        // For now, we'll return a mock that represents the concept
        let visit = MockVisit()
        visit.coordinate = coordinate
        visit.arrivalDate = arrivalDate
        visit.departureDate = departureDate
        return visit as! CLVisit
    }
}

// Mock visit class for testing
class MockVisit: NSObject {
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var arrivalDate: Date = Date()
    var departureDate: Date = Date()
    var horizontalAccuracy: CLLocationAccuracy = 5.0
}

final class TestDataFactory {
    
    // MARK: - Tour Factory
    
    static func createTour(
        id: UUID = UUID(),
        name: String = "Test Tour",
        description: String = "A test tour for testing purposes",
        category: TourCategory = .general,
        tourType: TourType = .walking,
        difficulty: TourDifficulty = .easy,
        estimatedDuration: TimeInterval = 3600,
        totalDistance: CLLocationDistance = 5000,
        pointsOfInterest: [PointOfInterest] = []
    ) -> Tour {
        return Tour(
            id: id,
            name: name,
            description: description,
            pointsOfInterest: pointsOfInterest,
            estimatedDuration: estimatedDuration,
            language: "en",
            category: category,
            totalDistance: totalDistance,
            difficulty: difficulty,
            authorName: "Test Author",
            tourType: tourType
        )
    }
    
    static func createTourWithPOIs(poiCount: Int = 3) -> Tour {
        let tourId = UUID()
        let pois = (0..<poiCount).map { index in
            createPOI(
                tourId: tourId,
                name: "POI \(index + 1)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(index) * 0.001,
                    longitude: -122.4194 + Double(index) * 0.001
                )
            )
        }
        
        return createTour(
            id: tourId,
            name: "Test Tour with \(poiCount) POIs",
            pointsOfInterest: pois
        )
    }
    
    // MARK: - POI Factory
    
    static func createPOI(
        id: UUID = UUID(),
        tourId: UUID = UUID(),
        name: String = "Test POI",
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        radius: CLLocationDistance = 100,
        triggerType: TriggerType = .location,
        order: Int = 0
    ) -> PointOfInterest {
        return PointOfInterest(
            id: id,
            tourId: tourId,
            name: name,
            description: "Test POI description",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            triggerType: triggerType,
            order: order,
            category: .general,
            importance: .medium
        )
    }
    
    // MARK: - AudioContent Factory
    
    static func createAudioContent(
        id: UUID = UUID(),
        poiId: UUID = UUID(),
        duration: TimeInterval = 120,
        language: String = "en",
        isLLMGenerated: Bool = false,
        format: AudioFormat = .mp3,
        quality: AudioQuality = .medium
    ) -> AudioContent {
        let audioContent = AudioContent(
            id: id,
            poiId: poiId,
            duration: duration,
            language: language,
            isLLMGenerated: isLLMGenerated,
            format: format,
            quality: quality
        )
        audioContent.transcript = "Test audio transcript"
        audioContent.cachedAt = Date()
        audioContent.fileSize = 1024000
        return audioContent
    }
    
    // MARK: - UserPreferences Factory
    
    static func createUserPreferences(
        preferredLanguage: String = "en",
        autoplayEnabled: Bool = true,
        offlineMode: Bool = false,
        voiceSpeed: Float = 1.0,
        voiceType: VoiceType = .natural
    ) -> UserPreferences {
        let preferences = UserPreferences()
        preferences.preferredLanguage = preferredLanguage
        preferences.autoplayEnabled = autoplayEnabled
        preferences.offlineMode = offlineMode
        preferences.voiceSpeed = voiceSpeed
        preferences.voiceType = voiceType
        return preferences
    }
    
    // MARK: - Location Factory
    
    static func createLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        accuracy: Double = 5.0,
        timestamp: Date = Date()
    ) -> CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
    
    // MARK: - Mock Data Collections
    
    static var sampleTours: [Tour] {
        return [
            createTour(
                name: "San Francisco Historical Tour",
                description: "Explore the rich history of San Francisco",
                category: .historical,
                tourType: .walking,
                difficulty: .easy,
                estimatedDuration: 7200,
                totalDistance: 3000
            ),
            createTour(
                name: "Golden Gate Park Nature Walk",
                description: "A peaceful walk through Golden Gate Park",
                category: .nature,
                tourType: .walking,
                difficulty: .moderate,
                estimatedDuration: 5400,
                totalDistance: 4500
            ),
            createTour(
                name: "Architecture Drive",
                description: "Architectural marvels of the city",
                category: .architecture,
                tourType: .driving,
                difficulty: .easy,
                estimatedDuration: 9000,
                totalDistance: 15000
            )
        ]
    }
    
    static var samplePOIs: [PointOfInterest] {
        let tourId = UUID()
        return [
            createPOI(
                tourId: tourId,
                name: "Golden Gate Bridge",
                coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
            ),
            createPOI(
                tourId: tourId,
                name: "Alcatraz Island",
                coordinate: CLLocationCoordinate2D(latitude: 37.8267, longitude: -122.4230)
            ),
            createPOI(
                tourId: tourId,
                name: "Fisherman's Wharf",
                coordinate: CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177)
            )
        ]
    }
    
    // MARK: - Test File URLs
    
    static var testAudioFileURL: URL {
        let bundle = Bundle(for: TestDataFactory.self)
        return bundle.url(forResource: "test_audio", withExtension: "mp3") ?? 
               URL(fileURLWithPath: "/tmp/test_audio.mp3")
    }
    
    static var testCacheDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("TestCache")
    }
    
    // MARK: - Cleanup
    
    static func cleanupTestFiles() {
        let fileManager = FileManager.default
        let testCacheURL = testCacheDirectory
        
        if fileManager.fileExists(atPath: testCacheURL.path) {
            try? fileManager.removeItem(at: testCacheURL)
        }
    }
}