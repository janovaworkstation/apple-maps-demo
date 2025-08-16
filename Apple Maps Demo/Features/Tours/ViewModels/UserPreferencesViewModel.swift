import Foundation
import Combine
import SwiftUI

@MainActor
final class UserPreferencesViewModel: ObservableObject {
    // MARK: - General Settings
    @Published var preferredLanguage: String = "en"
    @Published var unitSystem: UnitSystem = .metric
    @Published var autoplayEnabled: Bool = true
    @Published var backgroundLocationEnabled: Bool = true
    @Published var notificationStyle: NotificationStyle = .both
    @Published var largeTextEnabled: Bool = false
    @Published var highContrastEnabled: Bool = false
    @Published var reduceMotionEnabled: Bool = false
    @Published var analyticsEnabled: Bool = true
    @Published var crashReportingEnabled: Bool = true
    
    // MARK: - Audio Settings
    @Published var voiceType: VoiceType = .natural
    @Published var playbackSpeed: Double = 1.0
    @Published var preferredAudioQuality: AudioQuality = .medium
    @Published var carAudioOptimization: Bool = false
    @Published var volumeNormalization: Bool = true
    @Published var preferredAudioRoute: SettingsAudioRoute = .builtin
    @Published var duckOtherAudio: Bool = true
    @Published var defaultVolume: Double = 0.8
    
    // MARK: - Content Settings
    @Published var autoDownloadTours: Bool = false
    @Published var wifiOnlyDownloads: Bool = true
    @Published var downloadQuality: AudioQuality = .medium
    @Published var aiContentEnabled: Bool = true
    @Published var contentStyle: ContentStyle = .informative
    @Published var detailLevel: DetailLevel = .standard
    @Published var adaptiveContent: Bool = true
    @Published var selectedInterests: Set<String> = []
    
    // MARK: - API Settings
    @Published var openAIAPIKey: String = ""
    @Published var openAIModel: String = "gpt-4"
    @Published var ttsModel: String = "tts-1"
    @Published var requestTimeout: Double = 30.0
    @Published var maxRetries: Int = 3
    @Published var cacheAPIResponses: Bool = true
    @Published var allowTrainingData: Bool = false
    
    // MARK: - Computed Properties
    @Published var cacheSize: String = "0 MB"
    @Published var downloadedToursCount: Int = 0
    @Published var estimatedMonthlyCost: String = "$0.00"
    @Published var requestsThisMonth: Int = 0
    
    // MARK: - Available Options
    let availableLanguages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "es", name: "Español"),
        Language(code: "fr", name: "Français"),
        Language(code: "de", name: "Deutsch"),
        Language(code: "it", name: "Italiano"),
        Language(code: "pt", name: "Português"),
        Language(code: "ru", name: "Русский"),
        Language(code: "zh", name: "中文"),
        Language(code: "ja", name: "日本語"),
        Language(code: "ko", name: "한국어")
    ]
    
    let availableInterests: [String] = [
        "History", "Architecture", "Art", "Nature", "Science",
        "Culture", "Sports", "Food", "Music", "Literature",
        "Politics", "Religion", "Technology", "Business", "Entertainment"
    ]
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "AppSettings"
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        loadSettings()
        print("⚙️ UserPreferencesViewModel initialized")
    }
    
    deinit {
        // Save settings synchronously to avoid capture issues
        // Note: In real app, consider using a more robust persistence strategy
        cancellables.removeAll()
        print("🧹 UserPreferencesViewModel cleaned up")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Auto-save when any setting changes
        Publishers.CombineLatest4(
            $preferredLanguage,
            $unitSystem,
            $autoplayEnabled,
            $backgroundLocationEnabled
        )
        .dropFirst() // Skip initial values
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $voiceType,
            $playbackSpeed,
            $preferredAudioQuality,
            $defaultVolume
        )
        .dropFirst()
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $aiContentEnabled,
            $contentStyle,
            $detailLevel,
            $selectedInterests
        )
        .dropFirst()
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $openAIAPIKey,
            $openAIModel,
            $requestTimeout,
            $maxRetries
        )
        .dropFirst()
        .debounce(for: .milliseconds(1000), scheduler: RunLoop.main) // Longer debounce for API settings
        .sink { [weak self] _ in
            self?.saveSettings()
            self?.updateUsageStatistics()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Settings Persistence
    
    func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            loadDefaultSettings()
            return
        }
        
        // General Settings
        preferredLanguage = settings.preferredLanguage
        unitSystem = settings.unitSystem
        autoplayEnabled = settings.autoplayEnabled
        backgroundLocationEnabled = settings.backgroundLocationEnabled
        notificationStyle = settings.notificationStyle
        largeTextEnabled = settings.largeTextEnabled
        highContrastEnabled = settings.highContrastEnabled
        reduceMotionEnabled = settings.reduceMotionEnabled
        analyticsEnabled = settings.analyticsEnabled
        crashReportingEnabled = settings.crashReportingEnabled
        
        // Audio Settings
        voiceType = settings.voiceType
        playbackSpeed = settings.playbackSpeed
        preferredAudioQuality = settings.preferredAudioQuality
        carAudioOptimization = settings.carAudioOptimization
        volumeNormalization = settings.volumeNormalization
        preferredAudioRoute = settings.preferredAudioRoute
        duckOtherAudio = settings.duckOtherAudio
        defaultVolume = settings.defaultVolume
        
        // Content Settings
        autoDownloadTours = settings.autoDownloadTours
        wifiOnlyDownloads = settings.wifiOnlyDownloads
        downloadQuality = settings.downloadQuality
        aiContentEnabled = settings.aiContentEnabled
        contentStyle = settings.contentStyle
        detailLevel = settings.detailLevel
        adaptiveContent = settings.adaptiveContent
        selectedInterests = settings.selectedInterests
        
        // API Settings
        openAIAPIKey = settings.openAIAPIKey
        openAIModel = settings.openAIModel
        ttsModel = settings.ttsModel
        requestTimeout = settings.requestTimeout
        maxRetries = settings.maxRetries
        cacheAPIResponses = settings.cacheAPIResponses
        allowTrainingData = settings.allowTrainingData
        
        print("✅ Settings loaded successfully")
        updateStorageStatistics()
        updateUsageStatistics()
    }
    
    func saveSettings() {
        let settings = AppSettings(
            // General
            preferredLanguage: preferredLanguage,
            unitSystem: unitSystem,
            autoplayEnabled: autoplayEnabled,
            backgroundLocationEnabled: backgroundLocationEnabled,
            notificationStyle: notificationStyle,
            largeTextEnabled: largeTextEnabled,
            highContrastEnabled: highContrastEnabled,
            reduceMotionEnabled: reduceMotionEnabled,
            analyticsEnabled: analyticsEnabled,
            crashReportingEnabled: crashReportingEnabled,
            
            // Audio
            voiceType: voiceType,
            playbackSpeed: playbackSpeed,
            preferredAudioQuality: preferredAudioQuality,
            carAudioOptimization: carAudioOptimization,
            volumeNormalization: volumeNormalization,
            preferredAudioRoute: preferredAudioRoute,
            duckOtherAudio: duckOtherAudio,
            defaultVolume: defaultVolume,
            
            // Content
            autoDownloadTours: autoDownloadTours,
            wifiOnlyDownloads: wifiOnlyDownloads,
            downloadQuality: downloadQuality,
            aiContentEnabled: aiContentEnabled,
            contentStyle: contentStyle,
            detailLevel: detailLevel,
            adaptiveContent: adaptiveContent,
            selectedInterests: selectedInterests,
            
            // API
            openAIAPIKey: openAIAPIKey,
            openAIModel: openAIModel,
            ttsModel: ttsModel,
            requestTimeout: requestTimeout,
            maxRetries: maxRetries,
            cacheAPIResponses: cacheAPIResponses,
            allowTrainingData: allowTrainingData
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            print("💾 Settings saved successfully")
        }
    }
    
    private func loadDefaultSettings() {
        print("📋 Loading default settings")
        selectedInterests = Set(["History", "Architecture", "Culture"])
        updateStorageStatistics()
        updateUsageStatistics()
    }
    
    // MARK: - Public Actions
    
    func clearCache() {
        // Implementation would clear the app cache
        print("🧹 Clearing cache...")
        
        // Simulate cache clearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.updateStorageStatistics()
        }
    }
    
    func showUsageStatistics() {
        // Implementation would show detailed usage statistics
        print("📊 Showing usage statistics")
    }
    
    func resetAllSettings() {
        // Reset to defaults
        loadDefaultSettings()
        saveSettings()
        print("🔄 All settings reset to defaults")
    }
    
    func exportSettings() -> Data? {
        // Export settings as JSON
        let settings = createCurrentSettings()
        return try? JSONEncoder().encode(settings)
    }
    
    func importSettings(from data: Data) -> Bool {
        guard let importedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return false
        }
        
        // Apply imported settings
        applySettings(importedSettings)
        return true
    }
    
    private func applySettings(_ settings: AppSettings) {
        // Apply the imported settings to the current state
        // This is a placeholder - in a real app you would apply each setting
        loadSettings()
    }
    
    // MARK: - Private Methods
    
    private func createCurrentSettings() -> AppSettings {
        return AppSettings(
            preferredLanguage: preferredLanguage,
            unitSystem: unitSystem,
            autoplayEnabled: autoplayEnabled,
            backgroundLocationEnabled: backgroundLocationEnabled,
            notificationStyle: notificationStyle,
            largeTextEnabled: largeTextEnabled,
            highContrastEnabled: highContrastEnabled,
            reduceMotionEnabled: reduceMotionEnabled,
            analyticsEnabled: analyticsEnabled,
            crashReportingEnabled: crashReportingEnabled,
            voiceType: voiceType,
            playbackSpeed: playbackSpeed,
            preferredAudioQuality: preferredAudioQuality,
            carAudioOptimization: carAudioOptimization,
            volumeNormalization: volumeNormalization,
            preferredAudioRoute: preferredAudioRoute,
            duckOtherAudio: duckOtherAudio,
            defaultVolume: defaultVolume,
            autoDownloadTours: autoDownloadTours,
            wifiOnlyDownloads: wifiOnlyDownloads,
            downloadQuality: downloadQuality,
            aiContentEnabled: aiContentEnabled,
            contentStyle: contentStyle,
            detailLevel: detailLevel,
            adaptiveContent: adaptiveContent,
            selectedInterests: selectedInterests,
            openAIAPIKey: openAIAPIKey,
            openAIModel: openAIModel,
            ttsModel: ttsModel,
            requestTimeout: requestTimeout,
            maxRetries: maxRetries,
            cacheAPIResponses: cacheAPIResponses,
            allowTrainingData: allowTrainingData
        )
    }
    
    private func updateStorageStatistics() {
        // Implementation would calculate actual cache size and downloaded tours
        // For now, use mock values
        cacheSize = "42.3 MB"
        downloadedToursCount = 3
    }
    
    private func updateUsageStatistics() {
        // Implementation would calculate actual API usage and costs
        // For now, use mock values
        estimatedMonthlyCost = "$12.45"
        requestsThisMonth = 1247
    }
}

// MARK: - Supporting Types

struct Language: Identifiable {
    let id = UUID()
    let code: String
    let name: String
}

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"
}

enum NotificationStyle: String, CaseIterable, Codable {
    case none = "none"
    case banner = "banner"
    case sound = "sound"
    case both = "both"
}

enum ContentStyle: String, CaseIterable, Codable {
    case informative = "informative"
    case conversational = "conversational"
    case educational = "educational"
    case entertainment = "entertainment"
}

enum DetailLevel: String, CaseIterable, Codable {
    case brief = "brief"
    case standard = "standard"
    case detailed = "detailed"
}

enum SettingsAudioRoute: String, CaseIterable, Codable {
    case automatic = "automatic"
    case builtin = "builtin"
    case bluetooth = "bluetooth"
    case airplay = "airplay"
}

// MARK: - Settings Model

struct AppSettings: Codable {
    // General Settings
    let preferredLanguage: String
    let unitSystem: UnitSystem
    let autoplayEnabled: Bool
    let backgroundLocationEnabled: Bool
    let notificationStyle: NotificationStyle
    let largeTextEnabled: Bool
    let highContrastEnabled: Bool
    let reduceMotionEnabled: Bool
    let analyticsEnabled: Bool
    let crashReportingEnabled: Bool
    
    // Audio Settings
    let voiceType: VoiceType
    let playbackSpeed: Double
    let preferredAudioQuality: AudioQuality
    let carAudioOptimization: Bool
    let volumeNormalization: Bool
    let preferredAudioRoute: SettingsAudioRoute
    let duckOtherAudio: Bool
    let defaultVolume: Double
    
    // Content Settings
    let autoDownloadTours: Bool
    let wifiOnlyDownloads: Bool
    let downloadQuality: AudioQuality
    let aiContentEnabled: Bool
    let contentStyle: ContentStyle
    let detailLevel: DetailLevel
    let adaptiveContent: Bool
    let selectedInterests: Set<String>
    
    // API Settings
    let openAIAPIKey: String
    let openAIModel: String
    let ttsModel: String
    let requestTimeout: Double
    let maxRetries: Int
    let cacheAPIResponses: Bool
    let allowTrainingData: Bool
}