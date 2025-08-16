//
//  TestDataFactory.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CoreLocation
@testable import Apple_Maps_Demo

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
        let pois = (0..<poiCount).map { index in
            createPOI(
                name: "POI \(index + 1)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(index) * 0.001,
                    longitude: -122.4194 + Double(index) * 0.001
                )
            )
        }
        
        return createTour(
            name: "Test Tour with \(poiCount) POIs",
            pointsOfInterest: pois
        )
    }
    
    // MARK: - POI Factory
    
    static func createPOI(
        id: UUID = UUID(),
        name: String = "Test POI",
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        radius: CLLocationDistance = 100,
        triggerType: TriggerType = .location,
        order: Int = 0
    ) -> PointOfInterest {
        let audioContent = createAudioContent()
        
        return PointOfInterest(
            id: id,
            name: name,
            coordinate: coordinate,
            radius: radius,
            audioContent: audioContent,
            triggerType: triggerType,
            order: order,
            description: "Test POI description",
            category: .general,
            estimatedDuration: 120
        )
    }
    
    // MARK: - AudioContent Factory
    
    static func createAudioContent(
        id: UUID = UUID(),
        localFileURL: URL? = nil,
        transcript: String? = "Test audio transcript",
        duration: TimeInterval = 120,
        isLLMGenerated: Bool = false,
        language: String = "en"
    ) -> AudioContent {
        return AudioContent(
            id: id,
            localFileURL: localFileURL,
            transcript: transcript,
            duration: duration,
            isLLMGenerated: isLLMGenerated,
            cachedAt: Date(),
            language: language,
            quality: .medium,
            fileSize: 1024000,
            format: .mp3
        )
    }
    
    // MARK: - UserPreferences Factory
    
    static func createUserPreferences(
        preferredLanguage: String = "en",
        autoplayEnabled: Bool = true,
        offlineMode: Bool = false,
        voiceSpeed: Float = 1.0,
        voiceType: String = "default"
    ) -> UserPreferences {
        return UserPreferences(
            preferredLanguage: preferredLanguage,
            autoplayEnabled: autoplayEnabled,
            offlineMode: offlineMode,
            voiceSpeed: voiceSpeed,
            voiceType: voiceType
        )
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
        return [
            createPOI(
                name: "Golden Gate Bridge",
                coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
            ),
            createPOI(
                name: "Alcatraz Island",
                coordinate: CLLocationCoordinate2D(latitude: 37.8267, longitude: -122.4230)
            ),
            createPOI(
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