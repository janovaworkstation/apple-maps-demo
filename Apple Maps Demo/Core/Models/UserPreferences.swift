import Foundation
import SwiftData

@Model
final class UserPreferences {
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
    var audioQuality: AudioQuality
    
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

enum AudioQuality: String, Codable, CaseIterable {
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
}