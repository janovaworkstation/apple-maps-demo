import Foundation
import SwiftData

@Model
final class UserPreferences: @unchecked Sendable, Codable {
    var id: UUID
    var preferredLanguage: String
    var autoplayEnabled: Bool
    var offlineMode: Bool
    var voiceSpeed: Float
    var voiceType: VoiceType
    var downloadOverCellular: Bool
    var hapticFeedback: Bool
    var reducedMotion: Bool
    var maxCacheSize: Int64
    var autoDeleteOldContent: Bool
    var daysToKeepContent: Int
    var preferredMapType: MapDisplayType
    var showVisitedPOIs: Bool
    var audioQuality: PreferredAudioQuality
    
    // Additional properties for repository compatibility
    var locationPermissionRequested: Bool
    var locationAccuracy: LocationAccuracy
    var backgroundLocationEnabled: Bool
    var downloadOnWiFiOnly: Bool
    var autoDownloadEnabled: Bool
    var maxStorageSize: Int64
    var notificationSettings: NotificationSettings
    var accessibilitySettings: AccessibilitySettings
    var dataSharingEnabled: Bool
    var analyticsEnabled: Bool
    var locationHistoryEnabled: Bool
    var themePreference: ThemePreference
    var mapStyle: MapStyle
    var unitsPreference: UnitsPreference
    var lastModified: Date
    var version: String
    
    init() {
        self.id = UUID()
        self.preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        self.autoplayEnabled = true
        self.offlineMode = false
        self.voiceSpeed = 1.0
        self.voiceType = .natural
        self.downloadOverCellular = false
        self.hapticFeedback = true
        self.reducedMotion = false
        self.maxCacheSize = 2_147_483_648 // 2GB default
        self.autoDeleteOldContent = true
        self.daysToKeepContent = 30
        self.preferredMapType = .standard
        self.showVisitedPOIs = true
        self.audioQuality = .high
        
        // Initialize additional properties
        self.locationPermissionRequested = false
        self.locationAccuracy = .balanced
        self.backgroundLocationEnabled = false
        self.downloadOnWiFiOnly = true
        self.autoDownloadEnabled = false
        self.maxStorageSize = 2_147_483_648 // 2GB default
        self.notificationSettings = NotificationSettings()
        self.accessibilitySettings = AccessibilitySettings()
        self.dataSharingEnabled = false
        self.analyticsEnabled = true
        self.locationHistoryEnabled = true
        self.themePreference = .system
        self.mapStyle = .standard
        self.unitsPreference = .metric
        self.lastModified = Date()
        self.version = "1.0"
    }
}

enum VoiceType: String, Codable, CaseIterable {
    case natural = "Natural"
    case enhanced = "Enhanced"
    case compact = "Compact"
    
    var openAIVoice: String {
        switch self {
        case .natural: return "alloy"
        case .enhanced: return "nova"
        case .compact: return "echo"
        }
    }
}

enum MapDisplayType: String, Codable, CaseIterable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"
}

struct NotificationSettings: Codable {
    var pushNotificationsEnabled: Bool
    var tourStartNotifications: Bool
    var poiApproachNotifications: Bool
    var downloadCompleteNotifications: Bool
    
    init() {
        self.pushNotificationsEnabled = true
        self.tourStartNotifications = true
        self.poiApproachNotifications = true
        self.downloadCompleteNotifications = true
    }
}

struct AccessibilitySettings: Codable {
    var voiceOverEnabled: Bool
    var largeFontSize: Bool
    var highContrast: Bool
    var reduceMotion: Bool
    
    init() {
        self.voiceOverEnabled = false
        self.largeFontSize = false
        self.highContrast = false
        self.reduceMotion = false
    }
}

enum LocationAccuracy: String, CaseIterable, Codable {
    case low = "low"
    case balanced = "balanced"
    case high = "high"
    case navigation = "navigation"
}

enum ThemePreference: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

enum MapStyle: String, CaseIterable, Codable {
    case standard = "standard"
    case satellite = "satellite"
    case hybrid = "hybrid"
    case terrain = "terrain"
}

enum UnitsPreference: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"
}

enum PreferredAudioQuality: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var bitrate: Int {
        switch self {
        case .low: return 64000
        case .medium: return 128000
        case .high: return 256000
        }
    }
}

extension UserPreferences {
    static var shared: UserPreferences {
        // This would be loaded from SwiftData in production
        return UserPreferences()
    }
    
    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: maxCacheSize)
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, preferredLanguage, autoplayEnabled, offlineMode, voiceSpeed, voiceType
        case downloadOverCellular, hapticFeedback, reducedMotion, maxCacheSize
        case autoDeleteOldContent, daysToKeepContent, preferredMapType, showVisitedPOIs, audioQuality
        case locationPermissionRequested, locationAccuracy, backgroundLocationEnabled
        case downloadOnWiFiOnly, autoDownloadEnabled, maxStorageSize, notificationSettings
        case accessibilitySettings, dataSharingEnabled, analyticsEnabled, locationHistoryEnabled
        case themePreference, mapStyle, unitsPreference, lastModified, version
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(autoplayEnabled, forKey: .autoplayEnabled)
        try container.encode(offlineMode, forKey: .offlineMode)
        try container.encode(voiceSpeed, forKey: .voiceSpeed)
        try container.encode(voiceType, forKey: .voiceType)
        try container.encode(downloadOverCellular, forKey: .downloadOverCellular)
        try container.encode(hapticFeedback, forKey: .hapticFeedback)
        try container.encode(reducedMotion, forKey: .reducedMotion)
        try container.encode(maxCacheSize, forKey: .maxCacheSize)
        try container.encode(autoDeleteOldContent, forKey: .autoDeleteOldContent)
        try container.encode(daysToKeepContent, forKey: .daysToKeepContent)
        try container.encode(preferredMapType, forKey: .preferredMapType)
        try container.encode(showVisitedPOIs, forKey: .showVisitedPOIs)
        try container.encode(audioQuality, forKey: .audioQuality)
        try container.encode(locationPermissionRequested, forKey: .locationPermissionRequested)
        try container.encode(locationAccuracy, forKey: .locationAccuracy)
        try container.encode(backgroundLocationEnabled, forKey: .backgroundLocationEnabled)
        try container.encode(downloadOnWiFiOnly, forKey: .downloadOnWiFiOnly)
        try container.encode(autoDownloadEnabled, forKey: .autoDownloadEnabled)
        try container.encode(maxStorageSize, forKey: .maxStorageSize)
        try container.encode(notificationSettings, forKey: .notificationSettings)
        try container.encode(accessibilitySettings, forKey: .accessibilitySettings)
        try container.encode(dataSharingEnabled, forKey: .dataSharingEnabled)
        try container.encode(analyticsEnabled, forKey: .analyticsEnabled)
        try container.encode(locationHistoryEnabled, forKey: .locationHistoryEnabled)
        try container.encode(themePreference, forKey: .themePreference)
        try container.encode(mapStyle, forKey: .mapStyle)
        try container.encode(unitsPreference, forKey: .unitsPreference)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(version, forKey: .version)
    }
    
    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        preferredLanguage = try container.decode(String.self, forKey: .preferredLanguage)
        autoplayEnabled = try container.decode(Bool.self, forKey: .autoplayEnabled)
        offlineMode = try container.decode(Bool.self, forKey: .offlineMode)
        voiceSpeed = try container.decode(Float.self, forKey: .voiceSpeed)
        voiceType = try container.decode(VoiceType.self, forKey: .voiceType)
        downloadOverCellular = try container.decode(Bool.self, forKey: .downloadOverCellular)
        hapticFeedback = try container.decode(Bool.self, forKey: .hapticFeedback)
        reducedMotion = try container.decode(Bool.self, forKey: .reducedMotion)
        maxCacheSize = try container.decode(Int64.self, forKey: .maxCacheSize)
        autoDeleteOldContent = try container.decode(Bool.self, forKey: .autoDeleteOldContent)
        daysToKeepContent = try container.decode(Int.self, forKey: .daysToKeepContent)
        preferredMapType = try container.decode(MapDisplayType.self, forKey: .preferredMapType)
        showVisitedPOIs = try container.decode(Bool.self, forKey: .showVisitedPOIs)
        audioQuality = try container.decode(PreferredAudioQuality.self, forKey: .audioQuality)
        locationPermissionRequested = try container.decode(Bool.self, forKey: .locationPermissionRequested)
        locationAccuracy = try container.decode(LocationAccuracy.self, forKey: .locationAccuracy)
        backgroundLocationEnabled = try container.decode(Bool.self, forKey: .backgroundLocationEnabled)
        downloadOnWiFiOnly = try container.decode(Bool.self, forKey: .downloadOnWiFiOnly)
        autoDownloadEnabled = try container.decode(Bool.self, forKey: .autoDownloadEnabled)
        maxStorageSize = try container.decode(Int64.self, forKey: .maxStorageSize)
        notificationSettings = try container.decode(NotificationSettings.self, forKey: .notificationSettings)
        accessibilitySettings = try container.decode(AccessibilitySettings.self, forKey: .accessibilitySettings)
        dataSharingEnabled = try container.decode(Bool.self, forKey: .dataSharingEnabled)
        analyticsEnabled = try container.decode(Bool.self, forKey: .analyticsEnabled)
        locationHistoryEnabled = try container.decode(Bool.self, forKey: .locationHistoryEnabled)
        themePreference = try container.decode(ThemePreference.self, forKey: .themePreference)
        mapStyle = try container.decode(MapStyle.self, forKey: .mapStyle)
        unitsPreference = try container.decode(UnitsPreference.self, forKey: .unitsPreference)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        version = try container.decode(String.self, forKey: .version)
    }
}