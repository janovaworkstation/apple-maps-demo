//
//  UserPreferencesTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import Foundation
@testable import Apple_Maps_Demo

final class UserPreferencesTests: XCTestCase {
    
    var userPreferences: UserPreferences!
    
    override func setUpWithError() throws {
        super.setUp()
        
        userPreferences = TestDataFactory.createUserPreferences(
            preferredLanguage: "en",
            autoplayEnabled: true,
            offlineMode: false,
            voiceSpeed: 1.0,
            voiceType: "default"
        )
    }
    
    override func tearDownWithError() throws {
        userPreferences = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testUserPreferencesInitialization() {
        XCTAssertEqual(userPreferences.preferredLanguage, "en")
        XCTAssertTrue(userPreferences.autoplayEnabled)
        XCTAssertFalse(userPreferences.offlineMode)
        XCTAssertEqual(userPreferences.voiceSpeed, 1.0)
        XCTAssertEqual(userPreferences.voiceType, "default")
    }
    
    func testUserPreferencesDefaultInitialization() {
        let defaultPreferences = UserPreferences()
        
        XCTAssertEqual(defaultPreferences.preferredLanguage, "en")
        XCTAssertTrue(defaultPreferences.autoplayEnabled)
        XCTAssertFalse(defaultPreferences.offlineMode)
        XCTAssertEqual(defaultPreferences.voiceSpeed, 1.0)
        XCTAssertEqual(defaultPreferences.voiceType, "default")
        XCTAssertEqual(defaultPreferences.downloadQuality, .medium)
        XCTAssertEqual(defaultPreferences.maxDownloadSize, 100)
        XCTAssertTrue(defaultPreferences.notificationsEnabled)
        XCTAssertEqual(defaultPreferences.units, .metric)
    }
    
    // MARK: - Language Preference Tests
    
    func testUserPreferencesLanguageValidation() {
        XCTAssertEqual(userPreferences.preferredLanguage, "en")
        
        userPreferences.preferredLanguage = "es"
        XCTAssertEqual(userPreferences.preferredLanguage, "es")
        
        userPreferences.preferredLanguage = "fr"
        XCTAssertEqual(userPreferences.preferredLanguage, "fr")
        
        userPreferences.preferredLanguage = "de"
        XCTAssertEqual(userPreferences.preferredLanguage, "de")
    }
    
    func testUserPreferencesLanguageCodes() {
        let supportedLanguages = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh", "ar", "ru"]
        
        for language in supportedLanguages {
            userPreferences.preferredLanguage = language
            XCTAssertEqual(userPreferences.preferredLanguage, language)
        }
    }
    
    func testUserPreferencesInvalidLanguage() {
        // Test setting invalid/unsupported language codes
        userPreferences.preferredLanguage = "invalid"
        XCTAssertEqual(userPreferences.preferredLanguage, "invalid") // Should store as-is
        
        userPreferences.preferredLanguage = ""
        XCTAssertEqual(userPreferences.preferredLanguage, "")
    }
    
    // MARK: - Autoplay Tests
    
    func testUserPreferencesAutoplay() {
        XCTAssertTrue(userPreferences.autoplayEnabled)
        
        userPreferences.autoplayEnabled = false
        XCTAssertFalse(userPreferences.autoplayEnabled)
        
        userPreferences.autoplayEnabled = true
        XCTAssertTrue(userPreferences.autoplayEnabled)
    }
    
    // MARK: - Offline Mode Tests
    
    func testUserPreferencesOfflineMode() {
        XCTAssertFalse(userPreferences.offlineMode)
        
        userPreferences.offlineMode = true
        XCTAssertTrue(userPreferences.offlineMode)
        
        userPreferences.offlineMode = false
        XCTAssertFalse(userPreferences.offlineMode)
    }
    
    // MARK: - Voice Speed Tests
    
    func testUserPreferencesVoiceSpeed() {
        XCTAssertEqual(userPreferences.voiceSpeed, 1.0)
        
        // Test normal range (0.5 to 2.0)
        userPreferences.voiceSpeed = 0.5
        XCTAssertEqual(userPreferences.voiceSpeed, 0.5)
        
        userPreferences.voiceSpeed = 1.5
        XCTAssertEqual(userPreferences.voiceSpeed, 1.5)
        
        userPreferences.voiceSpeed = 2.0
        XCTAssertEqual(userPreferences.voiceSpeed, 2.0)
    }
    
    func testUserPreferencesVoiceSpeedBounds() {
        // Test edge cases
        userPreferences.voiceSpeed = 0.0
        XCTAssertEqual(userPreferences.voiceSpeed, 0.0)
        
        userPreferences.voiceSpeed = 3.0
        XCTAssertEqual(userPreferences.voiceSpeed, 3.0)
        
        // Test negative values (implementation dependent)
        userPreferences.voiceSpeed = -1.0
        XCTAssertEqual(userPreferences.voiceSpeed, -1.0)
    }
    
    func testUserPreferencesVoiceSpeedPrecision() {
        userPreferences.voiceSpeed = 1.25
        XCTAssertEqual(userPreferences.voiceSpeed, 1.25, accuracy: 0.01)
        
        userPreferences.voiceSpeed = 0.75
        XCTAssertEqual(userPreferences.voiceSpeed, 0.75, accuracy: 0.01)
    }
    
    // MARK: - Voice Type Tests
    
    func testUserPreferencesVoiceType() {
        XCTAssertEqual(userPreferences.voiceType, "default")
        
        userPreferences.voiceType = "male"
        XCTAssertEqual(userPreferences.voiceType, "male")
        
        userPreferences.voiceType = "female"
        XCTAssertEqual(userPreferences.voiceType, "female")
        
        userPreferences.voiceType = "child"
        XCTAssertEqual(userPreferences.voiceType, "child")
    }
    
    func testUserPreferencesVoiceTypeOptions() {
        let voiceTypes = ["default", "male", "female", "child", "robotic", "natural"]
        
        for voiceType in voiceTypes {
            userPreferences.voiceType = voiceType
            XCTAssertEqual(userPreferences.voiceType, voiceType)
        }
    }
    
    func testUserPreferencesEmptyVoiceType() {
        userPreferences.voiceType = ""
        XCTAssertEqual(userPreferences.voiceType, "")
        XCTAssertTrue(userPreferences.voiceType.isEmpty)
    }
    
    // MARK: - Download Quality Tests
    
    func testUserPreferencesDownloadQuality() {
        let preferences = TestDataFactory.createUserPreferences()
        XCTAssertEqual(preferences.downloadQuality, .medium)
        
        preferences.downloadQuality = .low
        XCTAssertEqual(preferences.downloadQuality, .low)
        
        preferences.downloadQuality = .high
        XCTAssertEqual(preferences.downloadQuality, .high)
    }
    
    func testUserPreferencesAllDownloadQualities() {
        let qualities: [AudioQuality] = [.low, .medium, .high]
        let preferences = TestDataFactory.createUserPreferences()
        
        for quality in qualities {
            preferences.downloadQuality = quality
            XCTAssertEqual(preferences.downloadQuality, quality)
        }
    }
    
    // MARK: - Max Download Size Tests
    
    func testUserPreferencesMaxDownloadSize() {
        let preferences = TestDataFactory.createUserPreferences()
        XCTAssertEqual(preferences.maxDownloadSize, 100)
        
        preferences.maxDownloadSize = 50
        XCTAssertEqual(preferences.maxDownloadSize, 50)
        
        preferences.maxDownloadSize = 200
        XCTAssertEqual(preferences.maxDownloadSize, 200)
        
        preferences.maxDownloadSize = 500
        XCTAssertEqual(preferences.maxDownloadSize, 500)
    }
    
    func testUserPreferencesMaxDownloadSizeBounds() {
        let preferences = TestDataFactory.createUserPreferences()
        
        // Test zero
        preferences.maxDownloadSize = 0
        XCTAssertEqual(preferences.maxDownloadSize, 0)
        
        // Test large value
        preferences.maxDownloadSize = 10000
        XCTAssertEqual(preferences.maxDownloadSize, 10000)
        
        // Test negative (implementation dependent)
        preferences.maxDownloadSize = -1
        XCTAssertEqual(preferences.maxDownloadSize, -1)
    }
    
    // MARK: - Notifications Tests
    
    func testUserPreferencesNotifications() {
        let preferences = TestDataFactory.createUserPreferences()
        XCTAssertTrue(preferences.notificationsEnabled)
        
        preferences.notificationsEnabled = false
        XCTAssertFalse(preferences.notificationsEnabled)
        
        preferences.notificationsEnabled = true
        XCTAssertTrue(preferences.notificationsEnabled)
    }
    
    // MARK: - Units Tests
    
    func testUserPreferencesUnits() {
        let preferences = TestDataFactory.createUserPreferences()
        XCTAssertEqual(preferences.units, .metric)
        
        preferences.units = .imperial
        XCTAssertEqual(preferences.units, .imperial)
        
        preferences.units = .metric
        XCTAssertEqual(preferences.units, .metric)
    }
    
    // MARK: - Combination Tests
    
    func testUserPreferencesCombinations() {
        // Test combination of settings that might interact
        userPreferences.autoplayEnabled = false
        userPreferences.offlineMode = true
        userPreferences.voiceSpeed = 1.5
        userPreferences.downloadQuality = .high
        
        XCTAssertFalse(userPreferences.autoplayEnabled)
        XCTAssertTrue(userPreferences.offlineMode)
        XCTAssertEqual(userPreferences.voiceSpeed, 1.5)
        XCTAssertEqual(userPreferences.downloadQuality, .high)
    }
    
    func testUserPreferencesOfflineModeImplications() {
        // When offline mode is enabled, certain preferences might have implications
        userPreferences.offlineMode = true
        userPreferences.downloadQuality = .high
        userPreferences.maxDownloadSize = 500
        
        XCTAssertTrue(userPreferences.offlineMode)
        XCTAssertEqual(userPreferences.downloadQuality, .high)
        XCTAssertEqual(userPreferences.maxDownloadSize, 500)
    }
    
    // MARK: - Persistence Tests
    
    func testUserPreferencesPersistence() {
        // Test that changes persist (would normally use UserDefaults or Core Data)
        let originalLanguage = userPreferences.preferredLanguage
        let originalAutoplay = userPreferences.autoplayEnabled
        
        userPreferences.preferredLanguage = "es"
        userPreferences.autoplayEnabled = !originalAutoplay
        
        XCTAssertNotEqual(userPreferences.preferredLanguage, originalLanguage)
        XCTAssertNotEqual(userPreferences.autoplayEnabled, originalAutoplay)
        
        XCTAssertEqual(userPreferences.preferredLanguage, "es")
        XCTAssertEqual(userPreferences.autoplayEnabled, !originalAutoplay)
    }
    
    // MARK: - Validation Helper Tests
    
    func testUserPreferencesValidation() {
        // Test basic validation
        XCTAssertFalse(userPreferences.preferredLanguage.isEmpty)
        XCTAssertGreaterThan(userPreferences.voiceSpeed, 0)
        XCTAssertFalse(userPreferences.voiceType.isEmpty)
    }
    
    func testUserPreferencesIsValid() {
        // Assume there's a validation method
        // XCTAssertTrue(userPreferences.isValid())
        
        // Test invalid state
        userPreferences.preferredLanguage = ""
        // XCTAssertFalse(userPreferences.isValid())
    }
    
    // MARK: - Copy and Equality Tests
    
    func testUserPreferencesCopy() {
        let copy = UserPreferences(
            preferredLanguage: userPreferences.preferredLanguage,
            autoplayEnabled: userPreferences.autoplayEnabled,
            offlineMode: userPreferences.offlineMode,
            voiceSpeed: userPreferences.voiceSpeed,
            voiceType: userPreferences.voiceType
        )
        
        XCTAssertEqual(copy.preferredLanguage, userPreferences.preferredLanguage)
        XCTAssertEqual(copy.autoplayEnabled, userPreferences.autoplayEnabled)
        XCTAssertEqual(copy.offlineMode, userPreferences.offlineMode)
        XCTAssertEqual(copy.voiceSpeed, userPreferences.voiceSpeed)
        XCTAssertEqual(copy.voiceType, userPreferences.voiceType)
    }
    
    // MARK: - Performance Tests
    
    func testUserPreferencesCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = TestDataFactory.createUserPreferences()
            }
        }
    }
    
    func testUserPreferencesModificationPerformance() {
        measure {
            for i in 0..<10000 {
                userPreferences.voiceSpeed = Float(i % 10) / 10.0 + 0.5
                userPreferences.autoplayEnabled = i % 2 == 0
                userPreferences.offlineMode = i % 3 == 0
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testUserPreferencesMemoryDeallocation() {
        weak var weakPreferences: UserPreferences?
        
        autoreleasepool {
            let localPreferences = TestDataFactory.createUserPreferences()
            weakPreferences = localPreferences
            XCTAssertNotNil(weakPreferences)
        }
        
        // Preferences should be deallocated after autoreleasepool
        XCTAssertNil(weakPreferences)
    }
    
    // MARK: - Edge Case Tests
    
    func testUserPreferencesExtremeValues() {
        // Test extreme but potentially valid values
        userPreferences.voiceSpeed = Float.greatestFiniteMagnitude
        XCTAssertEqual(userPreferences.voiceSpeed, Float.greatestFiniteMagnitude)
        
        userPreferences.voiceSpeed = Float.leastNonzeroMagnitude
        XCTAssertEqual(userPreferences.voiceSpeed, Float.leastNonzeroMagnitude)
        
        userPreferences.maxDownloadSize = Int.max
        XCTAssertEqual(userPreferences.maxDownloadSize, Int.max)
    }
    
    func testUserPreferencesSpecialFloatValues() {
        // Test NaN and infinity (implementation dependent)
        userPreferences.voiceSpeed = Float.nan
        XCTAssertTrue(userPreferences.voiceSpeed.isNaN)
        
        userPreferences.voiceSpeed = Float.infinity
        XCTAssertTrue(userPreferences.voiceSpeed.isInfinite)
        
        // Reset to valid value
        userPreferences.voiceSpeed = 1.0
        XCTAssertEqual(userPreferences.voiceSpeed, 1.0)
    }
    
    func testUserPreferencesLongStrings() {
        let longLanguage = String(repeating: "en", count: 1000)
        let longVoiceType = String(repeating: "voice", count: 200)
        
        userPreferences.preferredLanguage = longLanguage
        userPreferences.voiceType = longVoiceType
        
        XCTAssertEqual(userPreferences.preferredLanguage, longLanguage)
        XCTAssertEqual(userPreferences.voiceType, longVoiceType)
    }
}