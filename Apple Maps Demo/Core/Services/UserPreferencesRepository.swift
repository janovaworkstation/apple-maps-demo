import Foundation
import SwiftData

// MARK: - UserPreferences Repository Protocol

protocol UserPreferencesRepositoryProtocol {
    // Basic CRUD
    func save(_ preferences: UserPreferences) async throws
    func fetchPreferences() async throws -> UserPreferences
    func updatePreferences(_ updateBlock: @escaping (UserPreferences) -> Void) async throws
    func resetToDefaults() async throws
    
    // Specific Setting Updates
    func updateLanguage(_ language: String) async throws
    func updateAutoplayEnabled(_ enabled: Bool) async throws
    func updateOfflineMode(_ enabled: Bool) async throws
    func updateVoiceSpeed(_ speed: Float) async throws
    func updateVoiceType(_ voiceType: String) async throws
    func updateAudioQuality(_ quality: PreferredAudioQuality) async throws
    
    // Location Preferences
    func updateLocationPermissionRequested(_ requested: Bool) async throws
    func updateLocationAccuracy(_ accuracy: LocationAccuracy) async throws
    func updateBackgroundLocationEnabled(_ enabled: Bool) async throws
    
    // Notification Preferences
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    func updatePushNotificationsEnabled(_ enabled: Bool) async throws
    
    // Tour Preferences
    func updateDownloadOnWiFiOnly(_ enabled: Bool) async throws
    func updateAutoDownloadEnabled(_ enabled: Bool) async throws
    func updateMaxStorageSize(_ size: Int64) async throws
    
    // Accessibility Preferences
    func updateAccessibilitySettings(_ settings: AccessibilitySettings) async throws
    func updateVoiceOverEnabled(_ enabled: Bool) async throws
    func updateLargeFontSize(_ enabled: Bool) async throws
    
    // Privacy Preferences
    func updateDataSharingEnabled(_ enabled: Bool) async throws
    func updateAnalyticsEnabled(_ enabled: Bool) async throws
    func updateLocationHistoryEnabled(_ enabled: Bool) async throws
    
    // Theme and Display
    func updateThemePreference(_ theme: ThemePreference) async throws
    func updateMapStyle(_ style: MapStyle) async throws
    func updateUnitsPreference(_ units: UnitsPreference) async throws
    
    // Export/Import
    func exportPreferences() async throws -> Data
    func importPreferences(from data: Data) async throws
    func getPreferencesForBackup() async throws -> [String: Any]
    func restoreFromBackup(_ backup: [String: Any]) async throws
}

// MARK: - UserPreferences Repository Implementation

class UserPreferencesRepository: UserPreferencesRepositoryProtocol {
    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Basic CRUD
    
    func save(_ preferences: UserPreferences) async throws {
        try await dataManager.save(preferences)
    }
    
    func fetchPreferences() async throws -> UserPreferences {
        // UserPreferences should be a singleton - only one instance per user
        if let preferences = try await dataManager.fetchFirst(UserPreferences.self, predicate: nil) {
            return preferences
        } else {
            // Create default preferences if none exist
            let defaultPreferences = UserPreferences()
            try await save(defaultPreferences)
            return defaultPreferences
        }
    }
    
    func updatePreferences(_ updateBlock: @escaping (UserPreferences) -> Void) async throws {
        let preferences = try await fetchPreferences()
        updateBlock(preferences)
        preferences.lastModified = Date()
        try await save(preferences)
    }
    
    func resetToDefaults() async throws {
        let preferences = try await fetchPreferences()
        
        // Reset to default values
        preferences.preferredLanguage = "en"
        preferences.autoplayEnabled = true
        preferences.offlineMode = false
        preferences.voiceSpeed = 1.0
        preferences.voiceType = .natural
        preferences.audioQuality = .high
        preferences.locationPermissionRequested = false
        preferences.locationAccuracy = .balanced
        preferences.backgroundLocationEnabled = false
        preferences.downloadOnWiFiOnly = true
        preferences.autoDownloadEnabled = false
        preferences.maxStorageSize = 2 * 1024 * 1024 * 1024 // 2GB
        preferences.dataSharingEnabled = false
        preferences.analyticsEnabled = true
        preferences.locationHistoryEnabled = true
        preferences.themePreference = .system
        preferences.mapStyle = .standard
        preferences.unitsPreference = .metric
        preferences.lastModified = Date()
        
        try await save(preferences)
    }
    
    // MARK: - Specific Setting Updates
    
    func updateLanguage(_ language: String) async throws {
        try await updatePreferences { preferences in
            preferences.preferredLanguage = language
        }
    }
    
    func updateAutoplayEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.autoplayEnabled = enabled
        }
    }
    
    func updateOfflineMode(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.offlineMode = enabled
        }
    }
    
    func updateVoiceSpeed(_ speed: Float) async throws {
        let clampedSpeed = max(0.5, min(2.0, speed)) // Clamp between 0.5x and 2.0x
        try await updatePreferences { preferences in
            preferences.voiceSpeed = clampedSpeed
        }
    }
    
    func updateVoiceType(_ voiceType: String) async throws {
        guard let voiceTypeEnum = VoiceType(rawValue: voiceType) else {
            throw DataError.validationFailed("Invalid voice type: \(voiceType)")
        }
        try await updatePreferences { preferences in
            preferences.voiceType = voiceTypeEnum
        }
    }
    
    func updateAudioQuality(_ quality: PreferredAudioQuality) async throws {
        try await updatePreferences { preferences in
            preferences.audioQuality = quality
        }
    }
    
    // MARK: - Location Preferences
    
    func updateLocationPermissionRequested(_ requested: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.locationPermissionRequested = requested
        }
    }
    
    func updateLocationAccuracy(_ accuracy: LocationAccuracy) async throws {
        try await updatePreferences { preferences in
            preferences.locationAccuracy = accuracy
        }
    }
    
    func updateBackgroundLocationEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.backgroundLocationEnabled = enabled
        }
    }
    
    // MARK: - Notification Preferences
    
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        try await updatePreferences { preferences in
            preferences.notificationSettings = settings
        }
    }
    
    func updatePushNotificationsEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.notificationSettings.pushNotificationsEnabled = enabled
        }
    }
    
    // MARK: - Tour Preferences
    
    func updateDownloadOnWiFiOnly(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.downloadOnWiFiOnly = enabled
        }
    }
    
    func updateAutoDownloadEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.autoDownloadEnabled = enabled
        }
    }
    
    func updateMaxStorageSize(_ size: Int64) async throws {
        let validSize = max(100 * 1024 * 1024, size) // Minimum 100MB
        try await updatePreferences { preferences in
            preferences.maxStorageSize = validSize
        }
    }
    
    // MARK: - Accessibility Preferences
    
    func updateAccessibilitySettings(_ settings: AccessibilitySettings) async throws {
        try await updatePreferences { preferences in
            preferences.accessibilitySettings = settings
        }
    }
    
    func updateVoiceOverEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.accessibilitySettings.voiceOverEnabled = enabled
        }
    }
    
    func updateLargeFontSize(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.accessibilitySettings.largeFontSize = enabled
        }
    }
    
    // MARK: - Privacy Preferences
    
    func updateDataSharingEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.dataSharingEnabled = enabled
        }
    }
    
    func updateAnalyticsEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.analyticsEnabled = enabled
        }
    }
    
    func updateLocationHistoryEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { preferences in
            preferences.locationHistoryEnabled = enabled
        }
    }
    
    // MARK: - Theme and Display
    
    func updateThemePreference(_ theme: ThemePreference) async throws {
        try await updatePreferences { preferences in
            preferences.themePreference = theme
        }
    }
    
    func updateMapStyle(_ style: MapStyle) async throws {
        try await updatePreferences { preferences in
            preferences.mapStyle = style
        }
    }
    
    func updateUnitsPreference(_ units: UnitsPreference) async throws {
        try await updatePreferences { preferences in
            preferences.unitsPreference = units
        }
    }
    
    // MARK: - Export/Import
    
    func exportPreferences() async throws -> Data {
        let preferences = try await fetchPreferences()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(preferences)
    }
    
    func importPreferences(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importedPreferences = try decoder.decode(UserPreferences.self, from: data)
        
        // Update existing preferences with imported values
        let currentPreferences = try await fetchPreferences()
        
        // Copy all settings from imported preferences
        currentPreferences.preferredLanguage = importedPreferences.preferredLanguage
        currentPreferences.autoplayEnabled = importedPreferences.autoplayEnabled
        currentPreferences.offlineMode = importedPreferences.offlineMode
        currentPreferences.voiceSpeed = importedPreferences.voiceSpeed
        currentPreferences.voiceType = importedPreferences.voiceType
        currentPreferences.audioQuality = importedPreferences.audioQuality
        currentPreferences.locationAccuracy = importedPreferences.locationAccuracy
        currentPreferences.backgroundLocationEnabled = importedPreferences.backgroundLocationEnabled
        currentPreferences.downloadOnWiFiOnly = importedPreferences.downloadOnWiFiOnly
        currentPreferences.autoDownloadEnabled = importedPreferences.autoDownloadEnabled
        currentPreferences.maxStorageSize = importedPreferences.maxStorageSize
        currentPreferences.notificationSettings = importedPreferences.notificationSettings
        currentPreferences.accessibilitySettings = importedPreferences.accessibilitySettings
        currentPreferences.dataSharingEnabled = importedPreferences.dataSharingEnabled
        currentPreferences.analyticsEnabled = importedPreferences.analyticsEnabled
        currentPreferences.locationHistoryEnabled = importedPreferences.locationHistoryEnabled
        currentPreferences.themePreference = importedPreferences.themePreference
        currentPreferences.mapStyle = importedPreferences.mapStyle
        currentPreferences.unitsPreference = importedPreferences.unitsPreference
        currentPreferences.lastModified = Date()
        
        try await save(currentPreferences)
    }
    
    func getPreferencesForBackup() async throws -> [String: Any] {
        let preferences = try await fetchPreferences()
        
        return [
            "preferredLanguage": preferences.preferredLanguage,
            "autoplayEnabled": preferences.autoplayEnabled,
            "offlineMode": preferences.offlineMode,
            "voiceSpeed": preferences.voiceSpeed,
            "voiceType": preferences.voiceType,
            "audioQuality": preferences.audioQuality.rawValue,
            "locationAccuracy": preferences.locationAccuracy.rawValue,
            "backgroundLocationEnabled": preferences.backgroundLocationEnabled,
            "downloadOnWiFiOnly": preferences.downloadOnWiFiOnly,
            "autoDownloadEnabled": preferences.autoDownloadEnabled,
            "maxStorageSize": preferences.maxStorageSize,
            "dataSharingEnabled": preferences.dataSharingEnabled,
            "analyticsEnabled": preferences.analyticsEnabled,
            "locationHistoryEnabled": preferences.locationHistoryEnabled,
            "themePreference": preferences.themePreference.rawValue,
            "mapStyle": preferences.mapStyle.rawValue,
            "unitsPreference": preferences.unitsPreference.rawValue,
            "lastModified": preferences.lastModified.timeIntervalSince1970
        ]
    }
    
    func restoreFromBackup(_ backup: [String: Any]) async throws {
        let preferences = try await fetchPreferences()
        
        if let language = backup["preferredLanguage"] as? String {
            preferences.preferredLanguage = language
        }
        
        if let autoplay = backup["autoplayEnabled"] as? Bool {
            preferences.autoplayEnabled = autoplay
        }
        
        if let offline = backup["offlineMode"] as? Bool {
            preferences.offlineMode = offline
        }
        
        if let speed = backup["voiceSpeed"] as? Float {
            preferences.voiceSpeed = speed
        }
        
        if let voiceRaw = backup["voiceType"] as? String,
           let voice = VoiceType(rawValue: voiceRaw) {
            preferences.voiceType = voice
        }
        
        if let qualityRaw = backup["audioQuality"] as? String,
           let quality = PreferredAudioQuality(rawValue: qualityRaw) {
            preferences.audioQuality = quality
        }
        
        if let accuracyRaw = backup["locationAccuracy"] as? String,
           let accuracy = LocationAccuracy(rawValue: accuracyRaw) {
            preferences.locationAccuracy = accuracy
        }
        
        if let backgroundLocation = backup["backgroundLocationEnabled"] as? Bool {
            preferences.backgroundLocationEnabled = backgroundLocation
        }
        
        if let wifiOnly = backup["downloadOnWiFiOnly"] as? Bool {
            preferences.downloadOnWiFiOnly = wifiOnly
        }
        
        if let autoDownload = backup["autoDownloadEnabled"] as? Bool {
            preferences.autoDownloadEnabled = autoDownload
        }
        
        if let storage = backup["maxStorageSize"] as? Int64 {
            preferences.maxStorageSize = storage
        }
        
        if let dataSharing = backup["dataSharingEnabled"] as? Bool {
            preferences.dataSharingEnabled = dataSharing
        }
        
        if let analytics = backup["analyticsEnabled"] as? Bool {
            preferences.analyticsEnabled = analytics
        }
        
        if let locationHistory = backup["locationHistoryEnabled"] as? Bool {
            preferences.locationHistoryEnabled = locationHistory
        }
        
        if let themeRaw = backup["themePreference"] as? String,
           let theme = ThemePreference(rawValue: themeRaw) {
            preferences.themePreference = theme
        }
        
        if let mapStyleRaw = backup["mapStyle"] as? String,
           let mapStyle = MapStyle(rawValue: mapStyleRaw) {
            preferences.mapStyle = mapStyle
        }
        
        if let unitsRaw = backup["unitsPreference"] as? String,
           let units = UnitsPreference(rawValue: unitsRaw) {
            preferences.unitsPreference = units
        }
        
        preferences.lastModified = Date()
        try await save(preferences)
    }
    
    // MARK: - Advanced Operations
    
    func validatePreferences() async throws -> [String] {
        let preferences = try await fetchPreferences()
        var validationErrors: [String] = []
        
        // Validate voice speed
        if preferences.voiceSpeed < 0.5 || preferences.voiceSpeed > 2.0 {
            validationErrors.append("Voice speed must be between 0.5x and 2.0x")
        }
        
        // Validate storage size
        if preferences.maxStorageSize < 100 * 1024 * 1024 {
            validationErrors.append("Maximum storage size must be at least 100MB")
        }
        
        // Validate language code
        let supportedLanguages = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh"]
        if !supportedLanguages.contains(preferences.preferredLanguage) {
            validationErrors.append("Unsupported language: \(preferences.preferredLanguage)")
        }
        
        return validationErrors
    }
    
    func getPreferencesVersion() async throws -> String {
        let preferences = try await fetchPreferences()
        return preferences.version
    }
    
    func migratePreferences(from oldVersion: String, to newVersion: String) async throws {
        // Handle preferences migration between versions
        let preferences = try await fetchPreferences()
        
        switch (oldVersion, newVersion) {
        case ("1.0", "1.1"):
            // Example migration: add new default settings
            if preferences.maxStorageSize == 0 {
                preferences.maxStorageSize = 2 * 1024 * 1024 * 1024 // 2GB
            }
            
        default:
            break
        }
        
        preferences.version = newVersion
        preferences.lastModified = Date()
        try await save(preferences)
    }
    
    func getStorageUsageForPreferences() async throws -> Int64 {
        // Return storage used by preferences and related data
        let data = try await exportPreferences()
        return Int64(data.count)
    }
    
    func clearSensitiveData() async throws {
        try await updatePreferences { preferences in
            // Clear any sensitive cached data
            preferences.locationHistoryEnabled = false
            preferences.dataSharingEnabled = false
        }
    }
}

// Supporting enums are now defined in UserPreferences.swift